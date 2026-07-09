/// Servicio de Glosas
/// Gestión de glosas por parte de EPS
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/glosa.dart';
import '../../security/auditoria_service.dart';

class GlosasService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  GlosasService({
    required this.db,
    required this.auditoriaService,
  });

  /// Genera una glosa
  Future<Glosa> generarGlosa({
    required String entidadId,
    required String usuarioId,
    required String ripsId,
    required String numeroFactura,
    required String eps,
    required TipoGlosa tipoGlosa,
    required String motivo,
    required double valorGlosado,
    required double valorAceptado,
    required double valorRechazado,
  }) async {
    final id = _uuid.v4();
    final numeroGlosa = 'GL-${DateTime.now().year}-${_generarNumeroSecuencial()}';
    final fechaGeneracion = DateTime.now();
    final fechaEnvio = DateTime.now();

    final glosa = Glosa(
      id: id,
      entidadId: entidadId,
      numeroGlosa: numeroGlosa,
      tipoGlosa: tipoGlosa,
      ripsId: ripsId,
      numeroFactura: numeroFactura,
      eps: eps,
      motivo: motivo,
      valorGlosado: valorGlosado,
      valorAceptado: valorAceptado,
      valorRechazado: valorRechazado,
      fechaGeneracion: fechaGeneracion,
      fechaEnvio: fechaEnvio,
      estado: EstadoGlosa.generada,
    );

    await db.insert('glosas', glosa.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'salud',
      accion: 'generacion_glosa',
      valorAnterior: {'rips_id': ripsId},
      valorNuevo: {
        'glosa_id': id,
        'numero_glosa': numeroGlosa,
        'valor_glosado': valorGlosado,
      },
      referenciaId: id,
    );

    return glosa;
  }

  /// Registra respuesta de glosa
  Future<Glosa> registrarRespuestaGlosa({
    required String entidadId,
    required String usuarioId,
    required String glosaId,
    required EstadoGlosa estadoRespuesta,
    required String justificacionRespuesta,
  }) async {
    final glosaResult = await db.query(
      'glosas',
      where: 'id = ?',
      whereArgs: [glosaId],
    );

    if (glosaResult.isEmpty) {
      throw Exception('Glosa no encontrada');
    }

    final glosa = Glosa.fromJson(glosaResult.first);

    if (glosa.estaRespondida()) {
      throw Exception('La glosa ya tiene respuesta');
    }

    final fechaRespuesta = DateTime.now();

    await db.update(
      'glosas',
      {
        'estado': estadoRespuesta.toString().split('.').last,
        'fecha_respuesta': fechaRespuesta.toIso8601String(),
        'justificacion_respuesta': justificacionRespuesta,
      },
      where: 'id = ?',
      whereArgs: [glosaId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'salud',
      accion: 'respuesta_glosa',
      valorAnterior: {'estado_anterior': glosa.estado.toString()},
      valorNuevo: {
        'estado_nuevo': estadoRespuesta.toString(),
        'justificacion': justificacionRespuesta,
      },
      referenciaId: glosaId,
    );

    return glosa.copyWith(
      estado: estadoRespuesta,
      fechaRespuesta: fechaRespuesta,
      justificacionRespuesta: justificacionRespuesta,
    );
  }

  Future<List<Glosa>> consultarGlosas({
    required String entidadId,
    EstadoGlosa? estado,
  }) async {
    String query = 'SELECT * FROM glosas WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado.toString().split('.').last);
    }

    query += ' ORDER BY fecha_generacion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados.map((r) => Glosa.fromJson(r)).toList();
  }

  String _generarNumeroSecuencial() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }
}
