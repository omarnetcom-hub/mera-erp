/// Servicio de Job de Depreciación Automática
/// Ejecuta periódicamente (mensual) el cálculo de depreciación de activos
/// Genera asiento contable correspondiente sin intervención manual
/// NICSP 17 - Propiedades, Planta y Equipo
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

class DepreciacionJobService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  DepreciacionJobService({
    required this.db,
    required this.auditoriaService,
  });

  /// Ejecuta el job de depreciación mensual
  Future<Map<String, dynamic>> ejecutarDepreciacionMensual({
    required String entidadId,
    required String usuarioId,
    required String periodo, // Formato: '2024-06'
  }) async {
    final fechaPeriodo = DateTime.parse('$periodo-01');
    final fechaUltimoDia = DateTime(fechaPeriodo.year, fechaPeriodo.month + 1, 0);
    
    // 1. Consultar activos activos
    final activos = await db.query(
      'activos_estado',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activo'],
    );

    if (activos.isEmpty) {
      return {
        'periodo': periodo,
        'total_activos': 0,
        'total_depreciacion': 0.0,
        'asiento_id': null,
        'mensaje': 'No hay activos activos para depreciar',
      };
    }

    // 2. Consultar configuración de depreciación
    final configuraciones = await db.query(
      'configuracion_depreciacion',
      where: 'entidad_id = ? AND activo = 1',
      whereArgs: [entidadId],
    );

    final configMap = <String, Map<String, dynamic>>{};
    for (final config in configuraciones) {
      configMap[config['tipo_activo'] as String] = {
        'vida_util_anios': config['vida_util_anios'],
        'metodo_depreciacion': config['metodo_depreciacion'],
        'porcentaje_depreciacion': config['porcentaje_depreciacion'],
      };
    }

    // 3. Calcular depreciación por activo
    final detallesDepreciacion = <Map<String, dynamic>>[];
    double totalDepreciacion = 0;

    for (final activo in activos) {
      final tipoActivo = activo['tipo_activo'];
      final config = configMap[tipoActivo];

      if (config == null) continue;

      final valorAdquisicion = activo['valor_adquisicion'] as double;
      final valorResidual = activo['valor_residual'] as double;
      final vidaUtilAnios = config['vida_util_anios'] as int;
      final metodo = config['metodo_depreciacion'] as String;

      final depreciacionMensual = _calcularDepreciacionMensual(
        valorAdquisicion: valorAdquisicion,
        valorResidual: valorResidual,
        vidaUtilAnios: vidaUtilAnios,
        metodo: metodo,
      );

      if (depreciacionMensual > 0) {
        detallesDepreciacion.add({
          'activo_id': activo['id'],
          'numero_inventario': activo['numero_inventario'],
          'tipo_activo': tipoActivo,
          'valor_adquisicion': valorAdquisicion,
          'depreciacion_mensual': depreciacionMensual,
        });

        totalDepreciacion += depreciacionMensual;

        // Actualizar depreciación acumulada del activo
        final depreciacionAcumuladaActual = (activo['depreciacion_acumulada'] as num).toDouble();
        await db.update(
          'activos_estado',
          {
            'depreciacion_acumulada': depreciacionAcumuladaActual + depreciacionMensual,
            'valor_neto': valorAdquisicion - (depreciacionAcumuladaActual + depreciacionMensual),
          },
          where: 'id = ?',
          whereArgs: [activo['id']],
        );
      }
    }

    if (detallesDepreciacion.isEmpty) {
      return {
        'periodo': periodo,
        'total_activos': activos.length,
        'total_depreciacion': 0.0,
        'asiento_id': null,
        'mensaje': 'No se generó depreciación para ningún activo',
      };
    }

    // 4. Generar asiento contable automático
    final asientoId = await _generarAsientoDepreciacion(
      entidadId: entidadId,
      usuarioId: usuarioId,
      periodo: periodo,
      totalDepreciacion: totalDepreciacion,
      detallesDepreciacion: detallesDepreciacion,
    );

    // 5. Registrar evento en auditoría
    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'contabilidad',
      accion: 'job_depreciacion_mensual',
      valorAnterior: {},
      valorNuevo: {
        'periodo': periodo,
        'total_activos': activos.length,
        'total_depreciacion': totalDepreciacion,
        'asiento_id': asientoId,
      },
    );

    return {
      'periodo': periodo,
      'total_activos': activos.length,
      'total_depreciacion': totalDepreciacion,
      'asiento_id': asientoId,
      'detalles': detallesDepreciacion,
      'mensaje': 'Depreciación mensual ejecutada exitosamente',
    };
  }

  /// Calcula la depreciación mensual según el método
  double _calcularDepreciacionMensual({
    required double valorAdquisicion,
    required double valorResidual,
    required int vidaUtilAnios,
    required String metodo,
  }) {
    final valorDepreciable = valorAdquisicion - valorResidual;

    switch (metodo) {
      case 'linea_recta':
        // Método de línea recta: (Valor depreciable / Vida útil) / 12
        return valorDepreciable / (vidaUtilAnios * 12);
      default:
        return valorDepreciable / (vidaUtilAnios * 12);
    }
  }

  /// Genera el asiento contable de depreciación
  Future<String> _generarAsientoDepreciacion({
    required String entidadId,
    required String usuarioId,
    required String periodo,
    required double totalDepreciacion,
    required List<Map<String, dynamic>> detallesDepreciacion,
  }) async {
    final asientoId = _uuid.v4();
    final numeroAsiento = await _generarNumeroAsiento(entidadId);
    final fechaAsiento = DateTime.parse('$periodo-01');

    // Cuentas contables según NICSP 17
    // Débito: Gasto por depreciación (cuenta de resultado)
    // Crédito: Depreciación acumulada (cuenta de activo)
    final cuentaGastoDepreciacion = '620101'; // Gasto por depreciación
    final cuentaDepreciacionAcumulada = '160401'; // Depreciación acumulada

    // Crear asiento contable
    await db.insert('asientos_contables_sp', {
      'id': asientoId,
      'entidad_id': entidadId,
      'numero_asiento': numeroAsiento,
      'fecha_asiento': fechaAsiento.toIso8601String(),
      'descripcion': 'Depreciación mensual de activos fijos - $periodo',
      'tipo_asiento': 'automatico',
      'estado': 'aprobado',
      'total_debito': totalDepreciacion,
      'total_credito': totalDepreciacion,
      'usuario_creo': usuarioId,
      'usuario_reviso': usuarioId,
      'fecha_revision': DateTime.now().toIso8601String(),
      'referencia_origen': 'job_depreciacion',
      'tipo_documento_origen': 'job',
      'observaciones': 'Asiento generado automáticamente por job de depreciación',
    });

    // Crear detalle de débito (gasto)
    await db.insert('detalles_asientos', {
      'id': _uuid.v4(),
      'asiento_id': asientoId,
      'cuenta_codigo': cuentaGastoDepreciacion,
      'cuenta_nombre': 'Gasto por depreciación de propiedades, planta y equipo',
      'debito': totalDepreciacion,
      'credito': 0,
      'referencia_id': asientoId,
    });

    // Crear detalle de crédito (depreciación acumulada)
    await db.insert('detalles_asientos', {
      'id': _uuid.v4(),
      'asiento_id': asientoId,
      'cuenta_codigo': cuentaDepreciacionAcumulada,
      'cuenta_nombre': 'Depreciación acumulada - Propiedades, planta y equipo',
      'debito': 0,
      'credito': totalDepreciacion,
      'referencia_id': asientoId,
    });

    // Actualizar saldos de cuentas
    await _actualizarSaldosCuentas(
      entidadId: entidadId,
      periodo: periodo,
      cuentaCodigo: cuentaGastoDepreciacion,
      cuentaNombre: 'Gasto por depreciación de propiedades, planta y equipo',
      debito: totalDepreciacion,
      credito: 0,
    );

    await _actualizarSaldosCuentas(
      entidadId: entidadId,
      periodo: periodo,
      cuentaCodigo: cuentaDepreciacionAcumulada,
      cuentaNombre: 'Depreciación acumulada - Propiedades, planta y equipo',
      debito: 0,
      credito: totalDepreciacion,
    );

    return asientoId;
  }

  /// Genera el número de asiento siguiente
  Future<String> _generarNumeroAsiento(String entidadId) async {
    final resultado = await db.rawQuery(
      "SELECT MAX(numero_asiento) as max_numero FROM asientos_contables_sp WHERE entidad_id = ?",
      [entidadId],
    );

    final maxNumero = resultado.first['max_numero'];
    if (maxNumero == null) return 'AS-0001';

    final numeroActual = int.parse(maxNumero.toString().split('-')[1]);
    return 'AS-${(numeroActual + 1).toString().padLeft(4, '0')}';
  }

  /// Actualiza los saldos de las cuentas contables
  Future<void> _actualizarSaldosCuentas({
    required String entidadId,
    required String periodo,
    required String cuentaCodigo,
    required String cuentaNombre,
    required double debito,
    required double credito,
  }) async {
    final saldoExistente = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND cuenta_codigo = ? AND vigencia = ?',
      whereArgs: [entidadId, cuentaCodigo, periodo],
    );

    if (saldoExistente.isEmpty) {
      await db.insert('saldos_cuentas', {
        'id': _uuid.v4(),
        'entidad_id': entidadId,
        'cuenta_codigo': cuentaCodigo,
        'cuenta_nombre': cuentaNombre,
        'saldo_deudor': debito,
        'saldo_acreedor': credito,
        'saldo_neto': debito - credito,
        'fecha_ultimo_movimiento': DateTime.now().toIso8601String(),
        'vigencia': periodo,
      });
    } else {
      final saldoActual = saldoExistente.first;
      final nuevoSaldoDeudor = (saldoActual['saldo_deudor'] as num).toDouble() + debito;
      final nuevoSaldoAcreedor = (saldoActual['saldo_acreedor'] as num).toDouble() + credito;

      await db.update(
        'saldos_cuentas',
        {
          'saldo_deudor': nuevoSaldoDeudor,
          'saldo_acreedor': nuevoSaldoAcreedor,
          'saldo_neto': nuevoSaldoDeudor - nuevoSaldoAcreedor,
          'fecha_ultimo_movimiento': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [saldoActual['id']],
      );
    }
  }

  /// Verifica si el job ya se ejecutó para el periodo
  Future<bool> jobEjecutadoParaPeriodo({
    required String entidadId,
    required String periodo,
  }) async {
    final resultado = await db.query(
      'asientos_contables_sp',
      where: 'entidad_id = ? AND tipo_documento_origen = ? AND referencia_origen = ? AND fecha_asiento LIKE ?',
      whereArgs: [entidadId, 'job', 'job_depreciacion', '$periodo%'],
    );

    return resultado.isNotEmpty;
  }
}

