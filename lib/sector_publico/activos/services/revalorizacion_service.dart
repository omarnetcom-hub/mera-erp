/// Servicio de Revalorización de Activos
/// NICSP 17 - Propiedades, Planta y Equipo
/// Revalorización de activos cuando el valor razonable aumenta significativamente
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/auditoria_service.dart';

enum MetodoRevalorizacion {
  valor_razonable,
  revaluacion_especializada,
}

class RevalorizacionService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  RevalorizacionService({
    required this.db,
    required this.auditoriaService,
  });

  /// Registra una revalorización de activo
  Future<Map<String, dynamic>> registrarRevalorizacion({
    required String entidadId,
    required String usuarioId,
    required String activoId,
    required MetodoRevalorizacion metodo,
    required double valorAnterior,
    required double valorNuevo,
    required DateTime fechaRevalorizacion,
    required String peritoAvaluo,
    required String numeroDictamen,
    required String motivo,
    String? observaciones,
  }) async {
    final id = _uuid.v4();

    // Verificar que el activo existe
    final activo = await db.query(
      'activos_estado',
      where: 'id = ?',
      whereArgs: [activoId],
    );

    if (activo.isEmpty) {
      throw Exception('Activo no encontrado');
    }

    // Validar que el valor nuevo sea mayor al anterior
    if (valorNuevo <= valorAnterior) {
      throw Exception('El valor nuevo debe ser mayor al valor anterior para revalorización');
    }

    // Calcular incremento
    final incremento = valorNuevo - valorAnterior;
    final porcentajeIncremento = (incremento / valorAnterior) * 100;

    // Validar que el incremento sea significativo (mínimo 10% según NICSP 17)
    if (porcentajeIncremento < 10) {
      throw Exception('El incremento debe ser al menos del 10% para proceder con revalorización');
    }

    await db.insert('revalorizaciones', {
      'id': id,
      'entidad_id': entidadId,
      'activo_id': activoId,
      'numero_inventario': activo.first['numero_inventario'],
      'metodo': metodo.toString().split('.').last,
      'valor_anterior': valorAnterior,
      'valor_nuevo': valorNuevo,
      'incremento': incremento,
      'porcentaje_incremento': porcentajeIncremento,
      'fecha_revalorizacion': fechaRevalorizacion.toIso8601String(),
      'perito_avaluo': peritoAvaluo,
      'numero_dictamen': numeroDictamen,
      'motivo': motivo,
      'observaciones': observaciones,
      'fecha_registro': DateTime.now().toIso8601String(),
      'estado': 'aprobado',
    });

    // Actualizar valor del activo
    await db.update(
      'activos_estado',
      {
        'valor_libros': valorNuevo,
        'valor_neto': valorNuevo - (activo.first['depreciacion_acumulada'] as num).toDouble(),
      },
      where: 'id = ?',
      whereArgs: [activoId],
    );

    // Generar asiento contable de revalorización
    final asientoId = await _generarAsientoRevalorizacion(
      entidadId: entidadId,
      usuarioId: usuarioId,
      revalorizacionId: id,
      activoId: activoId,
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      incremento: incremento,
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'activos',
      accion: 'revalorizacion_activo',
      valorAnterior: {
        'valor_anterior': valorAnterior,
      },
      valorNuevo: {
        'valor_nuevo': valorNuevo,
        'incremento': incremento,
        'porcentaje_incremento': porcentajeIncremento,
        'asiento_id': asientoId,
      },
      referenciaId: id,
    );

    return {
      'revalorizacion_id': id,
      'activo_id': activoId,
      'valor_nuevo': valorNuevo,
      'incremento': incremento,
      'porcentaje_incremento': porcentajeIncremento,
      'asiento_id': asientoId,
      'estado': 'aprobado',
    };
  }

  /// Genera el asiento contable de revalorización
  Future<String> _generarAsientoRevalorizacion({
    required String entidadId,
    required String usuarioId,
    required String revalorizacionId,
    required String activoId,
    required double valorAnterior,
    required double valorNuevo,
    required double incremento,
  }) async {
    final asientoId = _uuid.v4();
    final numeroAsiento = await _generarNumeroAsiento(entidadId);
    final fechaAsiento = DateTime.now();

    // Cuentas contables según NICSP 17
    // Débito: Activo revalorizado (cuenta de activo)
    // Crédito: Superávit por revalorización (cuenta de patrimonio)
    final cuentaActivo = '160501'; // Propiedades planta y equipo revalorizadas
    final cuentaSuperavit = '310501'; // Superávit por revalorización

    await db.insert('asientos_contables', {
      'id': asientoId,
      'entidad_id': entidadId,
      'numero_asiento': numeroAsiento,
      'fecha_asiento': fechaAsiento.toIso8601String(),
      'descripcion': 'Revalorización de activo - $activoId',
      'tipo_asiento': 'automatico',
      'estado': 'aprobado',
      'total_debito': incremento,
      'total_credito': incremento,
      'usuario_creo': usuarioId,
      'usuario_reviso': usuarioId,
      'fecha_revision': DateTime.now().toIso8601String(),
      'referencia_origen': revalorizacionId,
      'tipo_documento_origen': 'revalorizacion',
      'observaciones': 'Asiento generado automáticamente por revalorización NICSP 17',
    });

    await db.insert('detalles_asientos', {
      'id': _uuid.v4(),
      'asiento_id': asientoId,
      'cuenta_codigo': cuentaActivo,
      'cuenta_nombre': 'Propiedades planta y equipo revalorizadas',
      'debito': incremento,
      'credito': 0,
      'referencia_id': revalorizacionId,
    });

    await db.insert('detalles_asientos', {
      'id': _uuid.v4(),
      'asiento_id': asientoId,
      'cuenta_codigo': cuentaSuperavit,
      'cuenta_nombre': 'Superávit por revalorización de activos',
      'debito': 0,
      'credito': incremento,
      'referencia_id': revalorizacionId,
    });

    return asientoId;
  }

  /// Consulta revalorizaciones por entidad
  Future<List<Map<String, dynamic>>> consultarRevalorizaciones({
    required String entidadId,
    String? activoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    String query = 'SELECT * FROM revalorizaciones WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (activoId != null) {
      query += ' AND activo_id = ?';
      args.add(activoId);
    }

    if (fechaInicio != null) {
      query += ' AND fecha_revalorizacion >= ?';
      args.add(fechaInicio.toIso8601String());
    }

    if (fechaFin != null) {
      query += ' AND fecha_revalorizacion <= ?';
      args.add(fechaFin.toIso8601String());
    }

    query += ' ORDER BY fecha_revalorizacion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Consulta revalorizaciones de un activo
  Future<List<Map<String, dynamic>>> consultarRevalorizacionesActivo({
    required String activoId,
  }) async {
    final resultados = await db.query(
      'revalorizaciones',
      where: 'activo_id = ?',
      whereArgs: [activoId],
      orderBy: 'fecha_revalorizacion DESC',
    );

    return resultados;
  }

  /// Genera reporte de revalor
  Future<Map<String, dynamic>> generarReporteRevalorizaciones({
    required String entidadId,
    String? periodo,
  }) async {
    String query = 'SELECT * FROM revalorizaciones WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodo != null) {
      query += ' AND fecha_revalorizacion LIKE ?';
      args.add('$periodo%');
    }

    final revalorizaciones = await db.rawQuery(query, args);

    double totalIncremento = revalorizaciones.fold<double>(
      0,
      (sum, r) => sum + (r['incremento'] as num).toDouble(),
    );

    double promedioPorcentaje = revalorizaciones.isNotEmpty
        ? revalorizaciones.fold<double>(
            0,
            (sum, r) => sum + (r['porcentaje_incremento'] as num).toDouble(),
          ) / revalorizaciones.length
        : 0;

    // Por método
    final porMetodo = <String, int>{};
    for (final r in revalorizaciones) {
      final metodo = r['metodo'];
      porMetodo[metodo] = (porMetodo[metodo] ?? 0) + 1;
    }

    // Por tipo de activo
    final porTipoActivo = <String, int>{};
    for (final r in revalorizaciones) {
      final activo = await db.query(
        'activos_estado',
        where: 'id = ?',
        whereArgs: [r['activo_id']],
      );
      if (activo.isNotEmpty) {
        final tipo = activo.first['tipo_activo'];
        porTipoActivo[tipo] = (porTipoActivo[tipo] ?? 0) + 1;
      }
    }

    return {
      'periodo': periodo,
      'total_revalorizaciones': revalorizaciones.length,
      'total_incremento': totalIncremento,
      'promedio_porcentaje': promedioPorcentaje,
      'por_metodo': porMetodo,
      'por_tipo_activo': porTipoActivo,
      'detalles': revalorizaciones,
    };
  }

  /// Valida si un activo es candidato a revalorización
  Future<Map<String, dynamic>> validarCandidatoRevalorizacion({
    required String activoId,
    required double valorEstimadoActual,
  }) async {
    final activo = await db.query(
      'activos_estado',
      where: 'id = ?',
      whereArgs: [activoId],
    );

    if (activo.isEmpty) {
      throw Exception('Activo no encontrado');
    }

    final valorLibros = activo.first['valor_libros'] as double;
    final diferencia = valorEstimadoActual - valorLibros;
    final porcentajeDiferencia = (diferencia / valorLibros) * 100;

    final esCandidato = porcentajeDiferencia >= 10;

    return {
      'activo_id': activoId,
      'valor_libros': valorLibros,
      'valor_estimado_actual': valorEstimadoActual,
      'diferencia': diferencia,
      'porcentaje_diferencia': porcentajeDiferencia,
      'es_candidato': esCandidato,
      'recomendacion': esCandidato
          ? 'El activo es candidato a revalorización (incremento >= 10%)'
          : 'El activo no es candidato a revalorización (incremento < 10%)',
    };
  }

  /// Genera el número de asiento siguiente
  Future<String> _generarNumeroAsiento(String entidadId) async {
    final resultado = await db.rawQuery(
      "SELECT MAX(numero_asiento) as max_numero FROM asientos_contables WHERE entidad_id = ?",
      [entidadId],
    );

    final maxNumero = resultado.first['max_numero'];
    if (maxNumero == null) return 'AS-0001';

    final numeroActual = int.parse(maxNumero.toString().split('-')[1]);
    return 'AS-${(numeroActual + 1).toString().padLeft(4, '0')}';
  }
}
