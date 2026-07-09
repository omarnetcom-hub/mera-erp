/// Servicio PILA (Planilla Integrada de Liquidación de Aportes)
/// Integración real con operador de información PILA
library;

import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/liquidacion_nomina.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

class PILAService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Dio _dio;
  final Uuid _uuid = const Uuid();
  
  // Configuración de PILA (operador de información)
  static const String _pilaBaseUrl = 'https://www.pila.gov.co';
  static const String _pilaServicePath = '/api/v1';
  static const Duration _timeout = Duration(seconds: 30);

  PILAService({
    required this.db,
    required this.auditoriaService,
    String? apiKey,
    String? operadorId,
  }) : _dio = Dio(BaseOptions(
    baseUrl: _pilaBaseUrl,
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      'X-Operador-ID': ?operadorId,
    },
  ));

  /// Genera reporte PILA para un periodo
  Future<Map<String, dynamic>> generarReportePILA({
    required String entidadId,
    required String usuarioId,
    required String periodo,
  }) async {
    final liquidaciones = await db.query(
      'liquidaciones_nomina',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    if (liquidaciones.isEmpty) {
      throw Exception('No hay liquidaciones para el periodo');
    }

    final reporteId = _uuid.v4();
    final totalSalud = liquidaciones.fold(
0.0, (sum, r) => sum + (r['salud'] as num).toDouble());
    final totalPension = liquidaciones.fold(
0.0, (sum, r) => sum + (r['pension'] as num).toDouble());
    final totalFondoSolidaridad = liquidaciones.fold(
0.0, (sum, r) => sum + (r['fondo_solidaridad'] as num).toDouble());
    final totalRiesgos = liquidaciones.fold(
0.0, (sum, r) => sum + (r['riesgos_laborales'] as num).toDouble());
    final totalCaja = liquidaciones.fold(
0.0, (sum, r) => sum + (r['caja_compensacion'] as num).toDouble());
    final totalSena = liquidaciones.fold(
0.0, (sum, r) => sum + (r['sena'] as num).toDouble());
    final totalICBF = liquidaciones.fold(
0.0, (sum, r) => sum + (r['icbf'] as num).toDouble());

    final reporte = {
      'reporte_id': reporteId,
      'entidad_id': entidadId,
      'periodo': periodo,
      'fecha_generacion': DateTime.now().toIso8601String(),
      'total_empleados': liquidaciones.length,
      'total_salud': totalSalud,
      'total_pension': totalPension,
      'total_fondo_solidaridad': totalFondoSolidaridad,
      'total_riesgos_laborales': totalRiesgos,
      'total_caja_compensacion': totalCaja,
      'total_sena': totalSena,
      'total_icbf': totalICBF,
      'gran_total': totalSalud + totalPension + totalFondoSolidaridad + totalRiesgos + totalCaja + totalSena + totalICBF,
    };

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'nomina',
      accion: 'generacion_reporte_pila',
      valorAnterior: {},
      valorNuevo: reporte,
      referenciaId: reporteId,
    );

    return reporte;
  }

  /// Envía reporte PILA al operador de información
  Future<String> enviarReportePILA({
    required String entidadId,
    required String usuarioId,
    required String periodo,
    required String nitEntidad,
  }) async {
    final liquidaciones = await db.query(
      'liquidaciones_nomina',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    if (liquidaciones.isEmpty) {
      throw Exception('No hay liquidaciones para el periodo');
    }

    try {
      // Preparar payload para PILA
      final payload = {
        'tipo_registro': '1',
        'nit_entidad': nitEntidad,
        'periodo': periodo,
        'fecha_generacion': DateTime.now().toIso8601String(),
        'total_registros': liquidaciones.length,
        'detalles': liquidaciones.map((liq) => {
          'identificacion': liq['empleado_identificacion'],
          'nombre': liq['empleado_nombre'],
          'salud': liq['salud'],
          'pension': liq['pension'],
          'fondo_solidaridad': liq['fondo_solidaridad'],
          'riesgos_laborales': liq['riesgos_laborales'],
          'caja_compensacion': liq['caja_compensacion'],
          'sena': liq['sena'],
          'icbf': liq['icbf'],
        }).toList(),
      };

      // Llamada a API PILA
      final response = await _dio.post(
        '$_pilaServicePath/enviar',
        data: payload,
      );

      if (response.statusCode != 201) {
        throw Exception('Error al enviar reporte PILA: ${response.statusCode}');
      }

      final pilaId = response.data['pila_id'];

      await auditoriaService.registrarEvento(
        entidadId: entidadId,
        usuarioId: usuarioId,
        tipoEvento: TipoEventoAuditoria.modificacionRegistro,
        modulo: 'nomina',
        accion: 'envio_reporte_pila',
        valorAnterior: {'periodo': periodo},
        valorNuevo: {
          'pila_id': pilaId,
          'respuesta_api': response.data,
        },
      );

      return pilaId;
    } on DioException catch (e) {
      throw Exception('Error de conexión con PILA: ${e.message}');
    }
  }

  /// Recibe confirmación de PILA
  Future<Map<String, dynamic>> recibirConfirmacionPILA({
    required String pilaId,
  }) async {
    try {
      final response = await _dio.get(
        '$_pilaServicePath/confirmacion/$pilaId',
      );

      if (response.statusCode != 200) {
        throw Exception('Error al recibir confirmación PILA: ${response.statusCode}');
      }

      return response.data;
    } on DioException catch (e) {
      throw Exception('Error de conexión con PILA: ${e.message}');
    }
  }

  /// Asocia PILA a liquidaciones
  Future<void> asociarPILA({
    required String entidadId,
    required String usuarioId,
    required List<String> liquidacionIds,
    required String pilaId,
  }) async {
    for (final liquidacionId in liquidacionIds) {
      await db.update(
        'liquidaciones_nomina',
        {'pila_id': pilaId},
        where: 'id = ?',
        whereArgs: [liquidacionId],
      );
    }

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'nomina',
      accion: 'asociacion_pila',
      valorAnterior: {},
      valorNuevo: {'pila_id': pilaId, 'cantidad': liquidacionIds.length},
    );
  }

  /// Exporta formato plano para PILA
  Future<String> exportarFormatoPlano({
    required String entidadId,
    required String periodo,
  }) async {
    final liquidaciones = await db.query(
      'liquidaciones_nomina',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final buffer = StringBuffer();
    buffer.writeln('TIPO_REGISTRO;1');
    buffer.writeln('ENTIDAD;$entidadId');
    buffer.writeln('PERIODO;$periodo');
    buffer.writeln('FECHA_GENERACION;${DateTime.now().toIso8601String()}');
    buffer.writeln('TOTAL_REGISTROS;${liquidaciones.length}');

    for (final liq in liquidaciones) {
      buffer.writeln('DETALLE');
      buffer.writeln('IDENTIFICACION;${liq['empleado_identificacion']}');
      buffer.writeln('NOMBRE;${liq['empleado_nombre']}');
      buffer.writeln('SALUD;${liq['salud']}');
      buffer.writeln('PENSION;${liq['pension']}');
      buffer.writeln('FONDO_SOLIDARIDAD;${liq['fondo_solidaridad']}');
      buffer.writeln('RIESGOS_LABORALES;${liq['riesgos_laborales']}');
      buffer.writeln('CAJA_COMPENSACION;${liq['caja_compensacion']}');
      buffer.writeln('SENA;${liq['sena']}');
      buffer.writeln('ICBF;${liq['icbf']}');
    }

    return buffer.toString();
  }
}

