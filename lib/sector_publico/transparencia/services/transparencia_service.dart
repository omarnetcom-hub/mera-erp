/// Servicio de Transparencia
/// Ley 1712 de 2014
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/reporte_transparencia.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

class TransparenciaService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  TransparenciaService({
    required this.db,
    required this.auditoriaService,
  });

  /// Crea un reporte de transparencia
  Future<ReporteTransparencia> crearReporteTransparencia({
    required String entidadId,
    required String usuarioId,
    required TipoReporteTransparencia tipoReporte,
    required String titulo,
    required String descripcion,
    required DateTime periodoInicio,
    required DateTime periodoFin,
  }) async {
    final id = _uuid.v4();
    final numeroReporte = 'RT-${DateTime.now().year}-${_generarNumeroSecuencial()}';
    final fechaPublicacion = DateTime.now();

    final reporte = ReporteTransparencia(
      id: id,
      entidadId: entidadId,
      numeroReporte: numeroReporte,
      tipoReporte: tipoReporte,
      titulo: titulo,
      descripcion: descripcion,
      periodoInicio: periodoInicio,
      periodoFin: periodoFin,
      estado: EstadoReporte.borrador,
      fechaPublicacion: fechaPublicacion,
      usuarioPublico: usuarioId,
    );

    await db.insert('reportes_transparencia', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'transparencia',
      accion: 'creacion_reporte_transparencia',
      valorAnterior: {},
      valorNuevo: {
        'reporte_id': id,
        'numero_reporte': numeroReporte,
        'tipo_reporte': tipoReporte.toString(),
      },
      referenciaId: id,
    );

    return reporte;
  }

  /// Publica un reporte de transparencia
  Future<ReporteTransparencia> publicarReporte({
    required String entidadId,
    required String usuarioId,
    required String reporteId,
    required String urlPublicacion,
  }) async {
    final reporteResult = await db.query(
      'reportes_transparencia',
      where: 'id = ?',
      whereArgs: [reporteId],
    );

    if (reporteResult.isEmpty) {
      throw Exception('Reporte no encontrado');
    }

    final reporte = ReporteTransparencia.fromJson(reporteResult.first);

    if (reporte.estado != EstadoReporte.borrador) {
      throw Exception('Solo se pueden publicar reportes en estado borrador');
    }

    await db.update(
      'reportes_transparencia',
      {
        'estado': EstadoReporte.publicado.toString().split('.').last,
        'url_publicacion': urlPublicacion,
      },
      where: 'id = ?',
      whereArgs: [reporteId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'transparencia',
      accion: 'publicacion_reporte_transparencia',
      valorAnterior: {'estado_anterior': reporte.estado.toString()},
      valorNuevo: {
        'estado_nuevo': EstadoReporte.publicado.toString(),
        'url_publicacion': urlPublicacion,
      },
      referenciaId: reporteId,
    );

    return reporte.copyWith(
      estado: EstadoReporte.publicado,
      urlPublicacion: urlPublicacion,
    );
  }

  Future<List<ReporteTransparencia>> consultarReportes({
    required String entidadId,
    EstadoReporte? estado,
  }) async {
    String query = 'SELECT * FROM reportes_transparencia WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado.toString().split('.').last);
    }

    query += ' ORDER BY fecha_publicacion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados.map((r) => ReporteTransparencia.fromJson(r)).toList();
  }

  String _generarNumeroSecuencial() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }
}

