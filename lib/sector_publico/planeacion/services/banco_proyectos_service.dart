/// Servicio de Banco de Proyectos MGA
/// Metodología General Ajustada - DNP
/// Integración real con BPIN del DNP
library;

import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:merka_erp/core/currency/money_value.dart';
import 'package:merka_erp/core/currency/public_sector_money.dart';
import '../models/proyecto_mga.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

class BancoProyectosService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Dio _dio;
  final Uuid _uuid = const Uuid();

  // Configuración de BPIN DNP
  static const String _bpinBaseUrl = 'https://www.dnp.gov.co';
  static const String _bpinServicePath = '/api/v1/bpin';
  static const Duration _timeout = Duration(seconds: 30);

  BancoProyectosService({
    required this.db,
    required this.auditoriaService,
    String? apiKey,
    String? entidadId,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: _bpinBaseUrl,
           connectTimeout: _timeout,
           receiveTimeout: _timeout,
           headers: {
             'Content-Type': 'application/json',
             'Accept': 'application/json',
             if (apiKey != null) 'Authorization': 'Bearer $apiKey',
             if (entidadId != null) 'X-Entidad-ID': entidadId,
           },
         ),
       );

  /// Registra un proyecto en BPIN localmente
  Future<ProyectoMGA> registrarProyecto({
    required String entidadId,
    required String usuarioId,
    required String codigoBPIN,
    required String nombreProyecto,
    required TipoProyecto tipoProyecto,
    required String sector,
    required String programa,
    required String subprograma,
    required MoneyValue valorTotal,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required String responsable,
    required String dependencia,
  }) async {
    final id = _uuid.v4();

    final proyecto = ProyectoMGA(
      id: id,
      entidadId: entidadId,
      codigoBPIN: codigoBPIN,
      nombreProyecto: nombreProyecto,
      tipoProyecto: tipoProyecto,
      sector: sector,
      programa: programa,
      subprograma: subprograma,
      valorTotal: valorTotal,
      valorEjecutado: publicMoneyZero(),
      saldoPorEjecutar: valorTotal,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      responsable: responsable,
      dependencia: dependencia,
      estado: EstadoProyecto.formulado,
    );

    await db.insert('proyectos_mga', proyecto.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'planeacion',
      accion: 'registro_proyecto_bpin',
      valorAnterior: {},
      valorNuevo: {
        'proyecto_id': id,
        'codigo_bpin': codigoBPIN,
        'valor_total': valorTotal.toWireMap(),
      },
      referenciaId: id,
    );

    return proyecto;
  }

  /// Asocia CDP a un proyecto
  Future<ProyectoMGA> asociarCDP({
    required String entidadId,
    required String usuarioId,
    required String proyectoId,
    required String codigoCDP,
  }) async {
    final proyectoResult = await db.query(
      'proyectos_mga',
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    if (proyectoResult.isEmpty) {
      throw Exception('Proyecto no encontrado');
    }

    await db.update(
      'proyectos_mga',
      {'codigo_cdp': codigoCDP},
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'planeacion',
      accion: 'asociacion_cdp_proyecto',
      valorAnterior: {'proyecto_id': proyectoId},
      valorNuevo: {'codigo_cdp': codigoCDP},
      referenciaId: proyectoId,
    );

    final proyecto = ProyectoMGA.fromJson(proyectoResult.first);
    return proyecto.copyWith(codigoCDP: codigoCDP);
  }

  /// Asocia RP a un proyecto
  Future<ProyectoMGA> asociarRP({
    required String entidadId,
    required String usuarioId,
    required String proyectoId,
    required String codigoRP,
  }) async {
    final proyectoResult = await db.query(
      'proyectos_mga',
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    if (proyectoResult.isEmpty) {
      throw Exception('Proyecto no encontrado');
    }

    await db.update(
      'proyectos_mga',
      {'codigo_rp': codigoRP},
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'planeacion',
      accion: 'asociacion_rp_proyecto',
      valorAnterior: {'proyecto_id': proyectoId},
      valorNuevo: {'codigo_rp': codigoRP},
      referenciaId: proyectoId,
    );

    final proyecto = ProyectoMGA.fromJson(proyectoResult.first);
    return proyecto.copyWith(codigoRP: codigoRP);
  }

  /// Actualiza ejecución del proyecto
  Future<ProyectoMGA> actualizarEjecucion({
    required String entidadId,
    required String usuarioId,
    required String proyectoId,
    required MoneyValue valorEjecutado,
  }) async {
    final proyectoResult = await db.query(
      'proyectos_mga',
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    if (proyectoResult.isEmpty) {
      throw Exception('Proyecto no encontrado');
    }

    final proyecto = ProyectoMGA.fromJson(proyectoResult.first);

    if (valorEjecutado > proyecto.valorTotal) {
      throw Exception('El valor ejecutado no puede exceder el valor total');
    }

    final nuevoSaldo = proyecto.valorTotal - valorEjecutado;

    await db.update(
      'proyectos_mga',
      {
        'valor_ejecutado': valorEjecutado.toSql(),
        'saldo_por_ejecutar': nuevoSaldo.toSql(),
      },
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'planeacion',
      accion: 'actualizacion_ejecucion_proyecto',
      valorAnterior: {
        'valor_ejecutado_anterior': proyecto.valorEjecutado.toWireMap(),
        'saldo_anterior': proyecto.saldoPorEjecutar.toWireMap(),
      },
      valorNuevo: {
        'valor_ejecutado_nuevo': valorEjecutado.toWireMap(),
        'saldo_nuevo': nuevoSaldo.toWireMap(),
      },
      referenciaId: proyectoId,
    );

    return proyecto.copyWith(
      valorEjecutado: valorEjecutado,
      saldoPorEjecutar: nuevoSaldo,
    );
  }

  Future<List<ProyectoMGA>> consultarProyectos({
    required String entidadId,
    EstadoProyecto? estado,
  }) async {
    String query = 'SELECT * FROM proyectos_mga WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado.toString().split('.').last);
    }

    query += ' ORDER BY fecha_inicio DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados.map((r) => ProyectoMGA.fromJson(r)).toList();
  }

  /// Sincroniza proyecto con BPIN del DNP
  Future<ProyectoMGA> sincronizarConBPIN({
    required String entidadId,
    required String usuarioId,
    required String proyectoId,
  }) async {
    final proyectoResult = await db.query(
      'proyectos_mga',
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    if (proyectoResult.isEmpty) {
      throw Exception('Proyecto no encontrado');
    }

    final proyecto = ProyectoMGA.fromJson(proyectoResult.first);

    try {
      final payload = {
        'codigo_bpin': proyecto.codigoBPIN,
        'nombre_proyecto': proyecto.nombreProyecto,
        'tipo_proyecto': proyecto.tipoProyecto.toString().split('.').last,
        'sector': proyecto.sector,
        'programa': proyecto.programa,
        'subprograma': proyecto.subprograma,
        'valor_total': publicMoneyForDisplay(proyecto.valorTotal),
        'fecha_inicio': proyecto.fechaInicio.toIso8601String(),
        'fecha_fin': proyecto.fechaFin.toIso8601String(),
      };

      final response = await _dio.post(
        '$_bpinServicePath/proyectos',
        data: payload,
      );

      if (response.statusCode != 201) {
        throw Exception(
          'Error al sincronizar con BPIN: ${response.statusCode}',
        );
      }

      await auditoriaService.registrarEvento(
        entidadId: entidadId,
        usuarioId: usuarioId,
        tipoEvento: TipoEventoAuditoria.modificacionRegistro,
        modulo: 'planeacion',
        accion: 'sincronizacion_bpin_dnp',
        valorAnterior: {'proyecto_id': proyectoId},
        valorNuevo: {
          'codigo_bpin': proyecto.codigoBPIN,
          'respuesta_api': response.data,
        },
        referenciaId: proyectoId,
      );

      return proyecto;
    } on DioException catch (e) {
      throw Exception('Error de conexión con BPIN del DNP: ${e.message}');
    }
  }

  /// Consulta proyecto en BPIN del DNP
  Future<Map<String, dynamic>> consultarProyectoBPIN({
    required String codigoBPIN,
  }) async {
    try {
      final response = await _dio.get(
        '$_bpinServicePath/proyectos/$codigoBPIN',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error al consultar proyecto en BPIN: ${response.statusCode}',
        );
      }

      return response.data;
    } on DioException catch (e) {
      throw Exception('Error de conexión con BPIN del DNP: ${e.message}');
    }
  }
}
