/// Servicio de auditoría append-only con hash encadenado
/// Implementa las reglas no negociables: nada se borra, todo se audita
library;

import 'package:uuid/uuid.dart';
import '../models/registro_auditoria.dart';
import 'package:sqflite/sqflite.dart';

class AuditoriaService {
  final DatabaseExecutor? _db;
  final Uuid _uuid = const Uuid();

  AuditoriaService(this._db);

  /// Registra un evento de auditoría de forma append-only
  /// Nunca se permite eliminación física de registros
  Future<RegistroAuditoria> registrarEvento({
    required String entidadId,
    required String usuarioId,
    String? usuarioNombre,
    String? ipDireccion,
    required TipoEventoAuditoria tipoEvento,
    required String modulo,
    required String accion,
    required Map<String, dynamic> valorAnterior,
    required Map<String, dynamic> valorNuevo,
    String? referenciaId,
    String? observaciones,
  }) async {
    if (_db == null) {
      throw Exception('Base de datos no inicializada');
    }

    // Obtener el último hash para encadenamiento
    final ultimoHash = await _obtenerUltimoHash(entidadId);

    // Crear el registro de auditoría
    final id = _uuid.v4();
    final fechaHora = DateTime.now();
    
    final datosRegistro = {
      'id': id,
      'entidad_id': entidadId,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'ip_direccion': ipDireccion,
      'fecha_hora': fechaHora.toIso8601String(),
      'tipo_evento': tipoEvento.toString().split('.').last,
      'modulo': modulo,
      'accion': accion,
      'valor_anterior': valorAnterior,
      'valor_nuevo': valorNuevo,
      'hash_anterior': ultimoHash,
      'referencia_id': referenciaId,
      'observaciones': observaciones,
    };

    // Calcular hash actual
    final hashActual = RegistroAuditoria.calcularHash(datosRegistro);
    datosRegistro['hash_actual'] = hashActual;

    // Insertar en base de datos (append-only)
    await _db.insert(
      'auditoria_registros',
      {
        'id': id,
        'entidad_id': entidadId,
        'usuario_id': usuarioId,
        'usuario_nombre': usuarioNombre,
        'ip_direccion': ipDireccion,
        'fecha_hora': fechaHora.toIso8601String(),
        'tipo_evento': tipoEvento.toString().split('.').last,
        'modulo': modulo,
        'accion': accion,
        'valor_anterior': valorAnterior.toString(), // JSON como string
        'valor_nuevo': valorNuevo.toString(),
        'hash_anterior': ultimoHash,
        'hash_actual': hashActual,
        'referencia_id': referenciaId,
        'observaciones': observaciones,
      },
    );

    return RegistroAuditoria(
      id: id,
      entidadId: entidadId,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      ipDireccion: ipDireccion,
      fechaHora: fechaHora,
      tipoEvento: tipoEvento,
      modulo: modulo,
      accion: accion,
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      hashAnterior: ultimoHash,
      hashActual: hashActual,
      referenciaId: referenciaId,
      observaciones: observaciones,
    );
  }

  /// Obtiene el hash del último registro de auditoría para una entidad
  Future<String?> _obtenerUltimoHash(String entidadId) async {
    if (_db == null) return null;

    final result = await _db.rawQuery('''
      SELECT hash_actual 
      FROM auditoria_registros 
      WHERE entidad_id = ? 
      ORDER BY fecha_hora DESC 
      LIMIT 1
    ''', [entidadId]);

    if (result.isEmpty) return null;
    return result.first['hash_actual'] as String?;
  }

  /// Verifica la integridad de la cadena de auditoría para una entidad
  Future<bool> verificarIntegridadCadena(String entidadId) async {
    if (_db == null) return false;

    final registros = await _db.query(
      'auditoria_registros',
      where: 'entidad_id = ?',
      whereArgs: [entidadId],
      orderBy: 'fecha_hora ASC',
    );

    String? hashEsperado;

    for (final registro in registros) {
      final hashActual = registro['hash_actual'] as String?;
      final hashAnterior = registro['hash_anterior'] as String?;

      if (hashAnterior != hashEsperado) {
        return false; // Cadena rota
      }

      hashEsperado = hashActual;
    }

    return true;
  }

  /// Consulta registros de auditoría con filtros
  Future<List<RegistroAuditoria>> consultarRegistros({
    required String entidadId,
    String? usuarioId,
    TipoEventoAuditoria? tipoEvento,
    String? modulo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    String? referenciaId,
    int? limite,
  }) async {
    if (_db == null) return [];

    String query = 'SELECT * FROM auditoria_registros WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (usuarioId != null) {
      query += ' AND usuario_id = ?';
      args.add(usuarioId);
    }

    if (tipoEvento != null) {
      query += ' AND tipo_evento = ?';
      args.add(tipoEvento.toString().split('.').last);
    }

    if (modulo != null) {
      query += ' AND modulo = ?';
      args.add(modulo);
    }

    if (fechaDesde != null) {
      query += ' AND fecha_hora >= ?';
      args.add(fechaDesde.toIso8601String());
    }

    if (fechaHasta != null) {
      query += ' AND fecha_hora <= ?';
      args.add(fechaHasta.toIso8601String());
    }

    if (referenciaId != null) {
      query += ' AND referencia_id = ?';
      args.add(referenciaId);
    }

    query += ' ORDER BY fecha_hora DESC';

    if (limite != null) {
      query += ' LIMIT ?';
      args.add(limite);
    }

    final resultados = await _db.rawQuery(query, args);

    return resultados.map((r) => RegistroAuditoria.fromJson({
      'id': r['id'],
      'entidad_id': r['entidad_id'],
      'usuario_id': r['usuario_id'],
      'usuario_nombre': r['usuario_nombre'],
      'ip_direccion': r['ip_direccion'],
      'fecha_hora': r['fecha_hora'],
      'tipo_evento': r['tipo_evento'],
      'modulo': r['modulo'],
      'accion': r['accion'],
      'valor_anterior': r['valor_anterior'],
      'valor_nuevo': r['valor_nuevo'],
      'hash_anterior': r['hash_anterior'],
      'hash_actual': r['hash_actual'],
      'referencia_id': r['referencia_id'],
      'observaciones': r['observaciones'],
    })).toList();
  }

  /// Registra un intento de eliminación (siempre bloqueado)
  /// Esta función se llama cuando alguien intenta eliminar un registro sensible
  Future<void> registrarIntentoEliminacion({
    required String entidadId,
    required String usuarioId,
    String? usuarioNombre,
    String? ipDireccion,
    required String modulo,
    required String referenciaId,
    required Map<String, dynamic> datosIntentados,
  }) async {
    await registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      ipDireccion: ipDireccion,
      tipoEvento: TipoEventoAuditoria.intentoEliminacion,
      modulo: modulo,
      accion: 'INTENTO DE ELIMINACIÓN - BLOQUEADO POR SISTEMA',
      valorAnterior: datosIntentados,
      valorNuevo: {'mensaje': 'Operación bloqueada: prohibido eliminar registros'},
      referenciaId: referenciaId,
      observaciones: 'El usuario intentó eliminar un registro sensible. La operación fue bloqueada por el sistema.',
    );
  }

  /// Limpia registros antiguos según tiempo de retención
  /// NOTA: Esta función NO elimina físicamente, solo marca para archivo histórico
  Future<void> archivarRegistrosAntiguos(String entidadId) async {
    if (_db == null) return;

    final fechaLimite = DateTime.now().subtract(const Duration(days: 365 * 50)); // 50 años

    // Marcar como archivados (soft delete)
    await _db.update(
      'auditoria_registros',
      {'archivado': 1},
      where: 'entidad_id = ? AND fecha_hora < ?',
      whereArgs: [entidadId, fechaLimite.toIso8601String()],
    );
  }
}
