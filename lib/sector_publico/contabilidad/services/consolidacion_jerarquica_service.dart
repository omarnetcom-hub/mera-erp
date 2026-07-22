import 'package:sqflite/sqflite.dart';

/// Servicio de Consolidación Jerárquica de Saldos Contables y Presupuestales (NICSP 40 / CGN).
///
/// NOTA DE LIMITACIÓN ARQUITECTÓNICA:
/// Este servicio es estrictamente de SOLO LECTURA (no modifica ningún registro transaccional).
/// Agrega los saldos de una Entidad Territorial Padre (Gobernación) y sus entidades hijas
/// asociadas mediante `gobernacion_id`.
///
/// ADVERTENCIA: Este servicio NO realiza la eliminación de operaciones recíprocas entre entidades
/// (por ejemplo, transferencias inter-entidades entre la gobernación y un municipio pueden figurar
/// duplicadas: como gasto en la entidad emisora y como ingreso en la receptora).
/// La eliminación automatizada de partidas recíprocas queda pendiente para una fase futura.
class ConsolidacionJerarquicaService {
  final Database db;

  ConsolidacionJerarquicaService({required this.db});

  /// Resuelve la jerarquía de entidades (Entidad Padre + Entidades Hijas).
  /// Lanza [StateError] de forma Fail-Closed si la entidad padre no existe o no tiene hijas.
  Future<List<Map<String, dynamic>>> _resolverEntidadesJerarquia(
    String entidadIdPadre,
  ) async {
    final padreRows = await db.query(
      'entidades_territoriales',
      where: 'id = ? AND activo = 1',
      whereArgs: [entidadIdPadre],
    );

    if (padreRows.isEmpty) {
      throw StateError(
        'La entidad padre "$entidadIdPadre" no existe o no está activa en la base de datos.',
      );
    }

    final hijasRows = await db.query(
      'entidades_territoriales',
      where: 'gobernacion_id = ? AND activo = 1',
      whereArgs: [entidadIdPadre],
    );

    if (hijasRows.isEmpty) {
      throw StateError(
        'La entidad padre "$entidadIdPadre" no tiene entidades hijas adscritas para consolidar (gobernacion_id).',
      );
    }

    final todas = <Map<String, dynamic>>[
      padreRows.first,
      ...hijasRows,
    ];

    return todas;
  }

  /// Genera el consolidado de saldos contables agrupado por clase de cuenta (1, 2, 3, 4, 5...).
  Future<Map<String, dynamic>> obtenerConsolidadoContable({
    required String entidadIdPadre,
    required String vigencia,
  }) async {
    final entidades = await _resolverEntidadesJerarquia(entidadIdPadre);
    final entidadIds = entidades.map((e) => e['id'].toString()).toList();
    final placeholders = List.filled(entidadIds.length, '?').join(',');

    final result = await db.rawQuery('''
      SELECT 
        SUBSTR(cuenta_codigo, 1, 1) AS clase,
        SUM(saldo_deudor) AS total_deudor,
        SUM(saldo_acreedor) AS total_acreedor,
        SUM(saldo_neto) AS total_neto,
        COUNT(DISTINCT cuenta_codigo) AS total_cuentas
      FROM saldos_cuentas
      WHERE entidad_id IN ($placeholders) AND vigencia = ?
      GROUP BY SUBSTR(cuenta_codigo, 1, 1)
      ORDER BY clase ASC
    ''', [...entidadIds, vigencia]);

    final clasesMap = <String, Map<String, dynamic>>{};
    double totalActivos = 0;
    double totalPasivos = 0;
    double totalPatrimonio = 0;
    double totalIngresos = 0;
    double totalGastos = 0;

    for (final row in result) {
      final clase = row['clase']?.toString() ?? '0';
      final deudor = (row['total_deudor'] as num?)?.toDouble() ?? 0.0;
      final acreedor = (row['total_acreedor'] as num?)?.toDouble() ?? 0.0;
      final neto = (row['total_neto'] as num?)?.toDouble() ?? 0.0;
      final totalCuentas = (row['total_cuentas'] as num?)?.toInt() ?? 0;

      clasesMap[clase] = {
        'clase': clase,
        'deudor': deudor,
        'acreedor': acreedor,
        'neto': neto,
        'total_cuentas': totalCuentas,
      };

      if (clase == '1') totalActivos += neto;
      if (clase == '2') totalPasivos += neto;
      if (clase == '3') totalPatrimonio += neto;
      if (clase == '4') totalIngresos += neto;
      if (clase == '5') totalGastos += neto;
    }

    return {
      'entidad_padre_id': entidadIdPadre,
      'entidad_padre_nombre': entidades.first['razon_social'],
      'vigencia': vigencia,
      'total_entidades_consolidadas': entidades.length,
      'entidades': entidades.map((e) => {
        'id': e['id'],
        'razon_social': e['razon_social'],
        'nit': e['nit'],
        'tipo_entidad': e['tipo_entidad'],
      }).toList(),
      'clases': clasesMap,
      'resumen': {
        'activos': totalActivos,
        'pasivos': totalPasivos,
        'patrimonio': totalPatrimonio,
        'ingresos': totalIngresos,
        'gastos': totalGastos,
        'superavit_deficit': totalIngresos - totalGastos,
      },
    };
  }

  /// Genera el consolidado del flujo presupuestal (Apropiaciones, CDPs, RPs, Pagos).
  Future<Map<String, dynamic>> obtenerConsolidadoPresupuestal({
    required String entidadIdPadre,
    required String vigencia,
  }) async {
    final entidades = await _resolverEntidadesJerarquia(entidadIdPadre);
    final entidadIds = entidades.map((e) => e['id'].toString()).toList();
    final placeholders = List.filled(entidadIds.length, '?').join(',');

    final resApropiado = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_apropiado), 0) AS total FROM apropiaciones 
      WHERE entidad_id IN ($placeholders) AND vigencia = ?
    ''', [...entidadIds, vigencia]);

    final resCDP = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_cdp), 0) AS total FROM cdps 
      WHERE entidad_id IN ($placeholders) AND vigencia = ?
    ''', [...entidadIds, vigencia]);

    final resRP = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_rp), 0) AS total FROM rps 
      WHERE entidad_id IN ($placeholders) AND vigencia = ?
    ''', [...entidadIds, vigencia]);

    final resPagos = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_pagado), 0) AS total FROM pagos 
      WHERE entidad_id IN ($placeholders) AND vigencia = ?
    ''', [...entidadIds, vigencia]);

    final totalApropiado = (resApropiado.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalCDP = (resCDP.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalRP = (resRP.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPagado = (resPagos.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'entidad_padre_id': entidadIdPadre,
      'vigencia': vigencia,
      'total_entidades_consolidadas': entidades.length,
      'apropiacion_total': totalApropiado,
      'cdp_total': totalCDP,
      'rp_total': totalRP,
      'pago_total': totalPagado,
      'saldo_por_comprometer': totalApropiado - totalCDP,
      'saldo_por_pagar': totalRP - totalPagado,
    };
  }
}
