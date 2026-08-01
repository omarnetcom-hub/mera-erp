/// Vincula rubros presupuestales a metas MGA y calcula desviaciones de avance.
library;

import 'package:sqflite/sqflite.dart';

class SeguimientoProyectoRubroMeta {
  const SeguimientoProyectoRubroMeta({
    required this.metaCodigo,
    required this.avanceFisicoPorcentaje,
    required this.ejecucionFinancieraPorcentaje,
    required this.alertaDesviacion,
  });

  final String metaCodigo;
  final double avanceFisicoPorcentaje;
  final double ejecucionFinancieraPorcentaje;
  final bool alertaDesviacion;
}

class TrazabilidadPlanPresupuestoService {
  const TrazabilidadPlanPresupuestoService(this._db);

  final Database _db;

  Future<void> vincularRubroAMeta({
    required String id,
    required String entidadId,
    required String proyectoId,
    required String apropiacionId,
    required String metaCodigo,
    required String metaDescripcion,
    required double avanceFisicoPorcentaje,
    required DateTime fechaReporte,
  }) async {
    if (avanceFisicoPorcentaje < 0 || avanceFisicoPorcentaje > 100) {
      throw ArgumentError.value(
        avanceFisicoPorcentaje,
        'avanceFisicoPorcentaje',
        'Debe estar entre 0 y 100',
      );
    }

    final proyecto = await _db.query(
      'proyectos_mga',
      where: 'id = ? AND entidad_id = ?',
      whereArgs: [proyectoId, entidadId],
    );
    final apropiacion = await _db.query(
      'apropiaciones',
      where: 'id = ? AND entidad_id = ?',
      whereArgs: [apropiacionId, entidadId],
    );
    if (proyecto.isEmpty || apropiacion.isEmpty) {
      throw StateError(
        'Proyecto y apropiacion deben pertenecer a la misma entidad',
      );
    }

    await _db.insert('proyecto_rubros_metas', {
      'id': id,
      'entidad_id': entidadId,
      'proyecto_id': proyectoId,
      'apropiacion_id': apropiacionId,
      'meta_codigo': metaCodigo,
      'meta_descripcion': metaDescripcion,
      'avance_fisico_porcentaje': avanceFisicoPorcentaje,
      'fecha_reporte': fechaReporte.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SeguimientoProyectoRubroMeta>> consultarSeguimiento({
    required String entidadId,
    required String proyectoId,
  }) async {
    final filas = await _db.rawQuery(
      '''
      SELECT m.meta_codigo, m.avance_fisico_porcentaje,
             a.valor_apropiado, a.valor_pagado
      FROM proyecto_rubros_metas m
      JOIN apropiaciones a ON a.id = m.apropiacion_id
      WHERE m.entidad_id = ? AND m.proyecto_id = ?
    ''',
      [entidadId, proyectoId],
    );

    return filas.map((fila) {
      final apropiado = (fila['valor_apropiado'] as num).toDouble();
      final pagado = (fila['valor_pagado'] as num).toDouble();
      final financiero = apropiado == 0 ? 0.0 : (pagado / apropiado) * 100;
      final fisico = (fila['avance_fisico_porcentaje'] as num).toDouble();
      return SeguimientoProyectoRubroMeta(
        metaCodigo: fila['meta_codigo'] as String,
        avanceFisicoPorcentaje: fisico,
        ejecucionFinancieraPorcentaje: financiero,
        alertaDesviacion: (financiero - fisico).abs() > 20,
      );
    }).toList();
  }
}
