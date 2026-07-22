/// Servicio de Actas de Responsabilidad de Activos Públicos (Cuentadantes)
/// Asignación, custodia y traspaso de bienes del Estado
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/acta_responsabilidad.dart';
import '../../security/auditoria_service.dart';
import '../../models/registro_auditoria.dart';

class ActaResponsabilidadService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  ActaResponsabilidadService({
    required this.db,
    required this.auditoriaService,
  });

  /// Asigna la custodia de un bien a un funcionario (Crear Acta de Responsabilidad)
  Future<ActaResponsabilidad> asignarResponsabilidad({
    required String entidadId,
    required String usuarioId,
    required String activoId,
    required String funcionarioId,
    required String funcionarioNombre,
    required String funcionarioIdentificacion,
    required String dependencia,
    required String ubicacionFisica,
    String? observaciones,
  }) async {
    final id = _uuid.v4();
    final numeroActa = 'ACTA-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final fechaAsignacion = DateTime.now();

    final acta = ActaResponsabilidad(
      id: id,
      entidadId: entidadId,
      numeroActa: numeroActa,
      activoId: activoId,
      funcionarioId: funcionarioId,
      funcionarioNombre: funcionarioNombre,
      funcionarioIdentificacion: funcionarioIdentificacion,
      dependencia: dependencia,
      ubicacionFisica: ubicacionFisica,
      fechaAsignacion: fechaAsignacion,
      estadoActa: EstadoActaResponsabilidad.activa,
      observaciones: observaciones,
    );

    await db.insert('actas_responsabilidad', acta.toJson());

    // Actualizar el responsable y ubicación en la tabla principal de activos_estado
    await db.update(
      'activos_estado',
      {
        'responsable': funcionarioNombre,
        'ubicacion': ubicacionFisica,
      },
      where: 'id = ?',
      whereArgs: [activoId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'activos',
      accion: 'asignar_acta_responsabilidad',
      valorAnterior: {},
      valorNuevo: {
        'acta_id': id,
        'numero_acta': numeroActa,
        'activo_id': activoId,
        'funcionario_nombre': funcionarioNombre,
      },
      referenciaId: id,
    );

    return acta;
  }

  /// Traspasar o devolver la custodia de un activo
  Future<ActaResponsabilidad> trasladarResponsabilidad({
    required String entidadId,
    required String usuarioId,
    required String actaId,
    required String nuevoFuncionarioId,
    required String nuevoFuncionarioNombre,
    required String nuevoFuncionarioIdentificacion,
    required String nuevaDependencia,
    required String nuevaUbicacionFisica,
  }) async {
    final res = await db.query('actas_responsabilidad', where: 'id = ?', whereArgs: [actaId]);
    if (res.isEmpty) throw Exception('Acta de responsabilidad no encontrada');

    final actaAnterior = ActaResponsabilidad.fromJson(res.first);

    // Marcar acta anterior como trasladada
    await db.update(
      'actas_responsabilidad',
      {
        'estado_acta': EstadoActaResponsabilidad.trasladada.name,
        'fecha_devolucion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [actaId],
    );

    // Crear nueva acta para el nuevo cuentadante
    return await asignarResponsabilidad(
      entidadId: entidadId,
      usuarioId: usuarioId,
      activoId: actaAnterior.activoId,
      funcionarioId: nuevoFuncionarioId,
      funcionarioNombre: nuevoFuncionarioNombre,
      funcionarioIdentificacion: nuevoFuncionarioIdentificacion,
      dependencia: nuevaDependencia,
      ubicacionFisica: nuevaUbicacionFisica,
      observaciones: 'Traspaso desde acta #${actaAnterior.numeroActa}',
    );
  }

  /// Consultar actas por activo o por entidad
  Future<List<ActaResponsabilidad>> consultarActas({
    required String entidadId,
    String? activoId,
  }) async {
    String query = 'SELECT * FROM actas_responsabilidad WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (activoId != null) {
      query += ' AND activo_id = ?';
      args.add(activoId);
    }

    query += ' ORDER BY fecha_asignacion DESC';
    final result = await db.rawQuery(query, args);
    return result.map((r) => ActaResponsabilidad.fromJson(r)).toList();
  }

  /// Exporta el documento de Acta de Responsabilidad a formato plano .txt
  Future<String> exportarActaAPlano(String actaId) async {
    final res = await db.query('actas_responsabilidad', where: 'id = ?', whereArgs: [actaId]);
    if (res.isEmpty) throw Exception('Acta de responsabilidad no encontrada');
    final acta = ActaResponsabilidad.fromJson(res.first);

    final buffer = StringBuffer();
    buffer.writeln('ACTA_RESPONSABILIDAD_HEADER|${acta.numeroActa}|${acta.entidadId}|${acta.fechaAsignacion.toIso8601String()}');
    buffer.writeln('CUENTADANTE|${acta.funcionarioIdentificacion}|${acta.funcionarioNombre}|${acta.dependencia}');
    buffer.writeln('UBICACION|${acta.ubicacionFisica}');
    buffer.writeln('ACTIVO_ID|${acta.activoId}');
    buffer.writeln('ESTADO|${acta.estadoActa.name}');
    buffer.writeln('ACTA_RESPONSABILIDAD_FOOTER|FIN_DOCUMENTO');

    return buffer.toString();
  }
}
