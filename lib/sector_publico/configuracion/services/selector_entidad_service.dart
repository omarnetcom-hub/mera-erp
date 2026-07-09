/// Servicio de Selector de Tipo de Entidad
/// Gestión de tipos y subtipos de entidades territoriales
/// Configuración inicial de la entidad en onboarding
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/auditoria_service.dart';

enum TipoEntidad {
  departamento,
  municipio,
  distrito,
  regionMetropolitana,
}

enum SubtipoMunicipio {
  categoriaEspecial,
  categoriaPrimera,
  categoriaSegunda,
  categoriaTercera,
  categoriaCuarta,
  categoriaQuinta,
  categoriaSexta,
}

enum SubtipoDistrito {
  distritoCapital,
  distritoEspecial,
  distritoTuristico,
  distritoCultural,
  distritoPortuario,
  distritoIndustrial,
}

class SelectorEntidadService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  SelectorEntidadService({
    required this.db,
    required this.auditoriaService,
  });

  /// Registra la configuración de tipo de entidad
  Future<Map<String, dynamic>> configurarTipoEntidad({
    required String entidadId,
    required String usuarioId,
    required TipoEntidad tipo,
    String? subtipo,
    required String nombreEntidad,
    required String codigoDANE,
    required String departamento,
    String? municipio,
  }) async {
    final id = _uuid.v4();

    // Validar subtipo según tipo
    if (tipo == TipoEntidad.municipio && subtipo != null) {
      if (!_esSubtipoMunicipioValido(subtipo)) {
        throw Exception('Subtipo no válido para municipio');
      }
    }

    if (tipo == TipoEntidad.distrito && subtipo != null) {
      if (!_esSubtipoDistritoValido(subtipo)) {
        throw Exception('Subtipo no válido para distrito');
      }
    }

    await db.insert('configuracion_entidad', {
      'id': id,
      'entidad_id': entidadId,
      'tipo': tipo.toString().split('.').last,
      'subtipo': subtipo,
      'nombre_entidad': nombreEntidad,
      'codigo_dane': codigoDANE,
      'departamento': departamento,
      'municipio': municipio,
      'fecha_configuracion': DateTime.now().toIso8601String(),
      'configurado_por': usuarioId,
      'estado': 'activo',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'configuracion',
      accion: 'configuracion_tipo_entidad',
      valorAnterior: {},
      valorNuevo: {
        'configuracion_id': id,
        'tipo': tipo.toString(),
        'subtipo': subtipo,
        'nombre_entidad': nombreEntidad,
      },
      referenciaId: id,
    );

    return {
      'configuracion_id': id,
      'tipo': tipo.toString(),
      'subtipo': subtipo,
      'nombre_entidad': nombreEntidad,
      'estado': 'activo',
    };
  }

  /// Actualiza el tipo de entidad
  Future<Map<String, dynamic>> actualizarTipoEntidad({
    required String entidadId,
    required String usuarioId,
    required TipoEntidad nuevoTipo,
    String? nuevoSubtipo,
    required String motivo,
  }) async {
    final configuracion = await db.query(
      'configuracion_entidad',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activo'],
    );

    if (configuracion.isEmpty) {
      throw Exception('No hay configuración activa para esta entidad');
    }

    final configId = configuracion.first['id'];
    final tipoAnterior = configuracion.first['tipo'];
    final subtipoAnterior = configuracion.first['subtipo'];

    await db.update(
      'configuracion_entidad',
      {
        'tipo': nuevoTipo.toString().split('.').last,
        'subtipo': nuevoSubtipo,
        'estado': 'inactivo', // Marcar anterior como inactivo
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [configId],
    );

    // Crear nueva configuración
    final nuevaConfigId = _uuid.v4();
    await db.insert('configuracion_entidad', {
      'id': nuevaConfigId,
      'entidad_id': entidadId,
      'tipo': nuevoTipo.toString().split('.').last,
      'subtipo': nuevoSubtipo,
      'nombre_entidad': configuracion.first['nombre_entidad'],
      'codigo_dane': configuracion.first['codigo_dane'],
      'departamento': configuracion.first['departamento'],
      'municipio': configuracion.first['municipio'],
      'fecha_configuracion': DateTime.now().toIso8601String(),
      'configurado_por': usuarioId,
      'motivo_cambio': motivo,
      'estado': 'activo',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'configuracion',
      accion: 'cambio_tipo_entidad',
      valorAnterior: {
        'tipo_anterior': tipoAnterior,
        'subtipo_anterior': subtipoAnterior,
      },
      valorNuevo: {
        'tipo_nuevo': nuevoTipo.toString(),
        'subtipo_nuevo': nuevoSubtipo,
        'motivo': motivo,
      },
      referenciaId: nuevaConfigId,
    );

    return {
      'configuracion_id': nuevaConfigId,
      'tipo_nuevo': nuevoTipo.toString(),
      'subtipo_nuevo': nuevoSubtipo,
      'estado': 'activo',
    };
  }

  /// Consulta la configuración actual de una entidad
  Future<Map<String, dynamic>?> consultarConfiguracion({
    required String entidadId,
  }) async {
    final resultado = await db.query(
      'configuracion_entidad',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activo'],
    );

    if (resultado.isEmpty) return null;
    return resultado.first;
  }

  /// Obtiene los subtipos válidos para un tipo de entidad
  List<String> obtenerSubtiposValidos(TipoEntidad tipo) {
    switch (tipo) {
      case TipoEntidad.municipio:
        return SubtipoMunicipio.values.map((e) => e.toString().split('.').last).toList();
      case TipoEntidad.distrito:
        return SubtipoDistrito.values.map((e) => e.toString().split('.').last).toList();
      case TipoEntidad.departamento:
      case TipoEntidad.regionMetropolitana:
        return []; // No tienen subtipos
    }
  }

  /// Valida si un subtipo es válido para municipio
  bool _esSubtipoMunicipioValido(String subtipo) {
    return SubtipoMunicipio.values.any((e) => e.toString().split('.').last == subtipo);
  }

  /// Valida si un subtipo es válido para distrito
  bool _esSubtipoDistritoValido(String subtipo) {
    return SubtipoDistrito.values.any((e) => e.toString().split('.').last == subtipo);
  }

  /// Obtiene todos los tipos de entidad disponibles
  List<String> obtenerTiposEntidad() {
    return TipoEntidad.values.map((e) => e.toString().split('.').last).toList();
  }

  /// Consulta historial de cambios de tipo de entidad
  Future<List<Map<String, dynamic>>> consultarHistorialCambios({
    required String entidadId,
  }) async {
    final resultados = await db.query(
      'configuracion_entidad',
      where: 'entidad_id = ?',
      whereArgs: [entidadId],
      orderBy: 'fecha_configuracion DESC',
    );

    return resultados;
  }

  /// Genera reporte de configuraciones de entidades
  Future<Map<String, dynamic>> generarReporteConfiguraciones({
    TipoEntidad? tipo,
  }) async {
    String query = 'SELECT * FROM configuracion_entidad WHERE estado = ?';
    List<dynamic> args = ['activo'];

    if (tipo != null) {
      query += ' AND tipo = ?';
      args.add(tipo.toString().split('.').last);
    }

    final configuraciones = await db.rawQuery(query, args);

    // Por tipo
    final porTipo = <String, int>{};
    for (final c in configuraciones) {
      final tipo = c['tipo'];
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }

    // Por subtipo
    final porSubtipo = <String, int>{};
    for (final c in configuraciones) {
      final subtipo = c['subtipo'];
      if (subtipo != null) {
        porSubtipo[subtipo] = (porSubtipo[subtipo] ?? 0) + 1;
      }
    }

    return {
      'total_configuraciones': configuraciones.length,
      'por_tipo': porTipo,
      'por_subtipo': porSubtipo,
      'detalles': configuraciones,
    };
  }
}
