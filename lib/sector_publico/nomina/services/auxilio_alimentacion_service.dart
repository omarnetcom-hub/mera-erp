/// Servicio de Auxilio de Alimentación
/// Decreto 1250/2021 y normas complementarias
/// Auxilio no salarial de alimentación para trabajadores
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/auditoria_service.dart';

class AuxilioAlimentacionService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  // Valor actual del auxilio de alimentación (actualizado por decreto)
  static const double _valorAuxilioActual = 162000; // Valor 2024

  AuxilioAlimentacionService({
    required this.db,
    required this.auditoriaService,
  });

  /// Registra pago de auxilio de alimentación
  Future<Map<String, dynamic>> registrarPagoAuxilio({
    required String entidadId,
    required String usuarioId,
    required String empleadoId,
    required String periodo, // Formato: '2024-06'
    required int diasTrabajados,
    required double valorDia,
    String? observaciones,
  }) async {
    final id = _uuid.v4();

    // Validar días trabajados (máximo 30 días)
    if (diasTrabajados > 30) {
      throw Exception('El número de días trabajados no puede exceder 30');
    }

    // Calcular valor total del auxilio
    final valorTotal = diasTrabajados * valorDia;

    await db.insert('auxilio_alimentacion', {
      'id': id,
      'entidad_id': entidadId,
      'empleado_id': empleadoId,
      'periodo': periodo,
      'dias_trabajados': diasTrabajados,
      'valor_dia': valorDia,
      'valor_total': valorTotal,
      'observaciones': observaciones,
      'fecha_registro': DateTime.now().toIso8601String(),
      'estado': 'pagado',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'nomina',
      accion: 'pago_auxilio_alimentacion',
      valorAnterior: {},
      valorNuevo: {
        'auxilio_id': id,
        'empleado_id': empleadoId,
        'periodo': periodo,
        'dias_trabajados': diasTrabajados,
        'valor_total': valorTotal,
      },
      referenciaId: id,
    );

    return {
      'auxilio_id': id,
      'empleado_id': empleadoId,
      'periodo': periodo,
      'dias_trabajados': diasTrabajados,
      'valor_total': valorTotal,
      'estado': 'pagado',
    };
  }

  /// Calcula automáticamente el auxilio de alimentación para un periodo
  Future<Map<String, dynamic>> calcularAuxilioPeriodo({
    required String entidadId,
    required String usuarioId,
    required String empleadoId,
    required String periodo,
  }) async {
    // Obtener registros de asistencia del periodo
    final partesPeriodo = periodo.split('-');
    final anio = int.parse(partesPeriodo[0]);
    final mes = int.parse(partesPeriodo[1]);

    final fechaInicio = DateTime(anio, mes, 1);
    final fechaFin = DateTime(anio, mes + 1, 0);

    final registrosAsistencia = await db.query(
      'asistencia',
      where: 'empleado_id = ? AND fecha BETWEEN ? AND ?',
      whereArgs: [
        empleadoId,
        fechaInicio.toIso8601String(),
        fechaFin.toIso8601String(),
      ],
    );

    // Contar días trabajados (presentes)
    int diasTrabajados = 0;
    for (final registro in registrosAsistencia) {
      if (registro['estado'] == 'presente') {
        diasTrabajados++;
      }
    }

    // Calcular valor por día (valor auxilio actual / 30)
    final valorDia = _valorAuxilioActual / 30;

    // Calcular valor total
    final valorTotal = diasTrabajados * valorDia;

    return {
      'empleado_id': empleadoId,
      'periodo': periodo,
      'dias_trabajados': diasTrabajados,
      'valor_dia': valorDia,
      'valor_total': valorTotal,
      'valor_auxilio_actual': _valorAuxilioActual,
    };
  }

  /// Genera liquidación de auxilio de alimentación para nómina
  Future<Map<String, dynamic>> generarLiquidacionAuxilio({
    required String entidadId,
    required String usuarioId,
    required String periodo,
  }) async {
    // Obtener todos los empleados activos
    final empleados = await db.query(
      'empleados',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activo'],
    );

    double totalAuxilio = 0;
    final detalles = <Map<String, dynamic>>[];

    for (final empleado in empleados) {
      final empleadoId = empleado['id'];
      final calculo = await calcularAuxilioPeriodo(
        entidadId: entidadId,
        usuarioId: usuarioId,
        empleadoId: empleadoId,
        periodo: periodo,
      );

      if (calculo['dias_trabajados'] > 0) {
        totalAuxilio += calculo['valor_total'];
        detalles.add({
          'empleado_id': empleadoId,
          'empleado_nombre': empleado['nombre'],
          'dias_trabajados': calculo['dias_trabajados'],
          'valor_dia': calculo['valor_dia'],
          'valor_total': calculo['valor_total'],
        });
      }
    }

    return {
      'periodo': periodo,
      'total_empleados': empleados.length,
      'empleados_con_auxilio': detalles.length,
      'total_auxilio': totalAuxilio,
      'detalles': detalles,
    };
  }

  /// Actualiza el valor del auxilio de alimentación (cuando cambia por decreto)
  Future<Map<String, dynamic>> actualizarValorAuxilio({
    required String entidadId,
    required String usuarioId,
    required double nuevoValor,
    required String decretoReferencia,
    required DateTime fechaVigencia,
  }) async {
    // Verificar que el nuevo valor sea mayor al actual
    if (nuevoValor <= _valorAuxilioActual) {
      throw Exception('El nuevo valor debe ser mayor al valor actual');
    }

    await db.insert('historico_valor_auxilio', {
      'id': _uuid.v4(),
      'entidad_id': entidadId,
      'valor_anterior': _valorAuxilioActual,
      'valor_nuevo': nuevoValor,
      'decreto_referencia': decretoReferencia,
      'fecha_vigencia': fechaVigencia.toIso8601String(),
      'fecha_actualizacion': DateTime.now().toIso8601String(),
      'actualizado_por': usuarioId,
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'nomina',
      accion: 'actualizacion_valor_auxilio_alimentacion',
      valorAnterior: {
        'valor_anterior': _valorAuxilioActual,
      },
      valorNuevo: {
        'valor_nuevo': nuevoValor,
        'decreto_referencia': decretoReferencia,
        'fecha_vigencia': fechaVigencia.toIso8601String(),
      },
    );

    return {
      'valor_anterior': _valorAuxilioActual,
      'valor_nuevo': nuevoValor,
      'decreto_referencia': decretoReferencia,
      'fecha_vigencia': fechaVigencia.toIso8601String(),
    };
  }

  /// Consulta pagos de auxilio de alimentación de un empleado
  Future<List<Map<String, dynamic>>> consultarPagosAuxilio({
    required String empleadoId,
    String? periodo,
  }) async {
    String query = 'SELECT * FROM auxilio_alimentacion WHERE empleado_id = ?';
    List<dynamic> args = [empleadoId];

    if (periodo != null) {
      query += ' AND periodo = ?';
      args.add(periodo);
    }

    query += ' ORDER BY periodo DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Consulta histórico de valores del auxilio
  Future<List<Map<String, dynamic>>> consultarHistoricoValores({
    required String entidadId,
  }) async {
    final resultados = await db.query(
      'historico_valor_auxilio',
      where: 'entidad_id = ?',
      whereArgs: [entidadId],
      orderBy: 'fecha_actualizacion DESC',
    );

    return resultados;
  }

  /// Obtiene el valor actual del auxilio de alimentación
  double obtenerValorActual() {
    return _valorAuxilioActual;
  }

  /// Genera reporte de auxilio de alimentación por periodo
  Future<Map<String, dynamic>> generarReporteAuxilio({
    required String entidadId,
    required String periodoInicio,
    required String periodoFin,
  }) async {
    final pagos = await db.query(
      'auxilio_alimentacion',
      where: 'entidad_id = ? AND periodo BETWEEN ? AND ?',
      whereArgs: [entidadId, periodoInicio, periodoFin],
    );

    double totalPagado = pagos.fold<double>(
      0,
      (sum, r) => sum + (r['valor_total'] as num).toDouble(),
    );

    int totalDias = pagos.fold<int>(
      0,
      (sum, r) => sum + (r['dias_trabajados'] as int),
    );

    // Por empleado
    final porEmpleado = <String, Map<String, dynamic>>{};
    for (final pago in pagos) {
      final empleadoId = pago['empleado_id'];
      if (!porEmpleado.containsKey(empleadoId)) {
        porEmpleado[empleadoId] = {
          'empleado_id': empleadoId,
          'total_dias': 0,
          'total_valor': 0,
        };
      }
      porEmpleado[empleadoId]!['total_dias'] += pago['dias_trabajados'];
      porEmpleado[empleadoId]!['total_valor'] += pago['valor_total'];
    }

    return {
      'periodo_inicio': periodoInicio,
      'periodo_fin': periodoFin,
      'total_pagos': pagos.length,
      'total_dias': totalDias,
      'total_pagado': totalPagado,
      'promedio_por_empleado': pagos.isNotEmpty ? totalPagado / pagos.length : 0,
      'por_empleado': porEmpleado.values.toList(),
    };
  }
}
