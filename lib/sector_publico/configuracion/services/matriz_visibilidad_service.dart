/// Servicio de Matriz de Visibilidad de Módulos
/// Define qué módulos son visibles según tipo y subtipo de entidad
/// Matriz definitiva de configuración de módulos
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

enum Modulo {
  presupuesto,
  contabilidad,
  auditoria,
  rentas,
  contratacion,
  nomina,
  planeacion,
  activos,
  salud,
  regalias,
  transparencia,
}

class MatrizVisibilidadService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  // Matriz de visibilidad definitiva según tipo/subtipo de entidad
  static const Map<String, Set<Modulo>> _matrizDefinitiva = {
    // Departamentos
    'departamento': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.salud,
      Modulo.regalias,
      Modulo.transparencia,
    },
    // Municipios - Categoría Especial
    'municipio_categoriaEspecial': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.salud,
      Modulo.regalias,
      Modulo.transparencia,
    },
    // Municipios - Categoría Primera
    'municipio_categoriaPrimera': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.salud,
      Modulo.transparencia,
    },
    // Municipios - Categoría Segunda
    'municipio_categoriaSegunda': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.transparencia,
    },
    // Municipios - Categoría Tercera
    'municipio_categoriaTercera': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.transparencia,
    },
    // Municipios - Categoría Cuarta
    'municipio_categoriaCuarta': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.transparencia,
    },
    // Municipios - Categoría Quinta
    'municipio_categoriaQuinta': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.transparencia,
    },
    // Municipios - Categoría Sexta
    'municipio_categoriaSexta': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.transparencia,
    },
    // Distrito Capital
    'distrito_distritoCapital': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.salud,
      Modulo.regalias,
      Modulo.transparencia,
    },
    // Distrito Especial
    'distrito_distritoEspecial': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.salud,
      Modulo.transparencia,
    },
    // Distrito Turístico
    'distrito_distritoTuristico': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.transparencia,
    },
    // Distrito Cultural
    'distrito_distritoCultural': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.rentas,
      Modulo.contratacion,
      Modulo.nomina,
      Modulo.planeacion,
      Modulo.activos,
      Modulo.transparencia,
    },
    // Región Metropolitana
    'regionMetropolitana': {
      Modulo.presupuesto,
      Modulo.contabilidad,
      Modulo.auditoria,
      Modulo.planeacion,
      Modulo.transparencia,
    },
  };

  MatrizVisibilidadService({
    required this.db,
    required this.auditoriaService,
  });

  /// Obtiene los módulos visibles para un tipo/subtipo de entidad
  Set<Modulo> obtenerModulosVisibles({
    required String tipo,
    String? subtipo,
  }) {
    final clave = subtipo != null ? '${tipo}_$subtipo' : tipo;
    return _matrizDefinitiva[clave] ?? _matrizDefinitiva[tipo] ?? {};
  }

  /// Verifica si un módulo es visible para un tipo/subtipo
  bool esModuloVisible({
    required String tipo,
    String? subtipo,
    required Modulo modulo,
  }) {
    final modulosVisibles = obtenerModulosVisibles(tipo: tipo, subtipo: subtipo);
    return modulosVisibles.contains(modulo);
  }

  /// Configura una visibilidad personalizada (sobrescribe la matriz definitiva)
  Future<Map<String, dynamic>> configurarVisibilidadPersonalizada({
    required String entidadId,
    required String usuarioId,
    required String tipo,
    String? subtipo,
    required Set<Modulo> modulosHabilitados,
    required String motivo,
  }) async {
    final id = _uuid.v4();

    await db.insert('configuracion_visibilidad', {
      'id': id,
      'entidad_id': entidadId,
      'tipo': tipo,
      'subtipo': subtipo,
      'modulos_habilitados': modulosHabilitados.map((e) => e.toString().split('.').last).join(','),
      'motivo': motivo,
      'fecha_configuracion': DateTime.now().toIso8601String(),
      'configurado_por': usuarioId,
      'estado': 'activo',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'configuracion',
      accion: 'configuracion_visibilidad_personalizada',
      valorAnterior: {},
      valorNuevo: {
        'configuracion_id': id,
        'tipo': tipo,
        'subtipo': subtipo,
        'modulos_habilitados': modulosHabilitados.length,
      },
      referenciaId: id,
    );

    return {
      'configuracion_id': id,
      'tipo': tipo,
      'subtipo': subtipo,
      'modulos_habilitados': modulosHabilitados.length,
      'estado': 'activo',
    };
  }

  /// Consulta la configuración de visibilidad de una entidad
  Future<Map<String, dynamic>?> consultarConfiguracionVisibilidad({
    required String entidadId,
  }) async {
    final resultado = await db.query(
      'configuracion_visibilidad',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activo'],
    );

    if (resultado.isEmpty) return null;
    return resultado.first;
  }

  /// Obtiene los módulos visibles para una entidad (considerando configuración personalizada)
  Future<Set<Modulo>> obtenerModulosVisiblesEntidad({
    required String entidadId,
  }) async {
    // Primero verificar si hay configuración personalizada
    final configPersonalizada = await consultarConfiguracionVisibilidad(entidadId: entidadId);

    if (configPersonalizada != null) {
      final modulosStr = configPersonalizada['modulos_habilitados'] as String;
      final modulosLista = modulosStr.split(',');
      return modulosLista
          .map((m) => Modulo.values.firstWhere((e) => e.toString().split('.').last == m.trim()))
          .toSet();
    }

    // Si no hay configuración personalizada, usar la configuración de tipo de entidad
    final configEntidad = await db.query(
      'configuracion_entidad',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activo'],
    );

    if (configEntidad.isEmpty) {
      return {}; // Sin configuración, sin módulos
    }

    final tipo = configEntidad.first['tipo'] as String;
    final subtipo = configEntidad.first['subtipo'] as String?;

    return obtenerModulosVisibles(tipo: tipo, subtipo: subtipo);
  }

  /// Restaura la configuración por defecto (matriz definitiva)
  Future<Map<String, dynamic>> restaurarConfiguracionPorDefecto({
    required String entidadId,
    required String usuarioId,
  }) async {
    final configPersonalizada = await consultarConfiguracionVisibilidad(entidadId: entidadId);

    if (configPersonalizada != null) {
      await db.update(
        'configuracion_visibilidad',
        {'estado': 'inactivo'},
        where: 'entidad_id = ? AND estado = ?',
        whereArgs: [entidadId, 'activo'],
      );

      await auditoriaService.registrarEvento(
        entidadId: entidadId,
        usuarioId: usuarioId,
        tipoEvento: TipoEventoAuditoria.modificacionRegistro,
        modulo: 'configuracion',
        accion: 'restauracion_configuracion_defecto',
        valorAnterior: {
          'configuracion_anterior': configPersonalizada['id'],
        },
        valorNuevo: {
          'configuracion_nueva': 'matriz_definitiva',
        },
        referenciaId: configPersonalizada['id'],
      );
    }

    return {
      'entidad_id': entidadId,
      'configuracion': 'matriz_definitiva',
      'estado': 'restaurado',
    };
  }

  /// Genera reporte de visibilidad de módulos
  Future<Map<String, dynamic>> generarReporteVisibilidad({
    String? tipo,
    String? subtipo,
  }) async {
    final modulosVisibles = obtenerModulosVisibles(tipo: tipo ?? 'departamento', subtipo: subtipo);

    return {
      'tipo': tipo,
      'subtipo': subtipo,
      'total_modulos': modulosVisibles.length,
      'modulos_visibles': modulosVisibles.map((e) => e.toString().split('.').last).toList(),
    };
  }

  /// Obtiene la matriz completa de visibilidad
  Map<String, List<String>> obtenerMatrizCompleta() {
    final matriz = <String, List<String>>{};
    for (final entry in _matrizDefinitiva.entries) {
      matriz[entry.key] = entry.value.map((e) => e.toString().split('.').last).toList();
    }
    return matriz;
  }

  /// Consulta todas las configuraciones personalizadas
  Future<List<Map<String, dynamic>>> consultarConfiguracionesPersonalizadas({
    String? tipo,
  }) async {
    String query = 'SELECT * FROM configuracion_visibilidad WHERE estado = ?';
    List<dynamic> args = ['activo'];

    if (tipo != null) {
      query += ' AND tipo = ?';
      args.add(tipo);
    }

    query += ' ORDER BY fecha_configuracion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }
}
