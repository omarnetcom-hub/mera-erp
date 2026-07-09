// ============================================================
// financial_consolidation.dart
// Servicio de consolidación financiera multi-empresa
// ============================================================

import 'package:sqflite/sqflite.dart';

class FinancialConsolidationService {
  static final FinancialConsolidationService instance = FinancialConsolidationService._internal();
  
  FinancialConsolidationService._internal();
  
  /// Obtiene el consolidado financiero de múltiples empresas
  Future<Map<String, dynamic>> getConsolidatedFinancials(
    Database db,
    List<int> companyIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (companyIds.isEmpty) {
      return _emptyConsolidation();
    }
    
    final effectiveStartDate = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final effectiveEndDate = endDate ?? DateTime.now();
    
    // Ventas consolidadas
    final consolidatedSales = await _getConsolidatedSales(
      db,
      companyIds,
      effectiveStartDate,
      effectiveEndDate,
    );
    
    // Gastos consolidados
    final consolidatedExpenses = await _getConsolidatedExpenses(
      db,
      companyIds,
      effectiveStartDate,
      effectiveEndDate,
    );
    
    // Inventario consolidado
    final consolidatedInventory = await _getConsolidatedInventory(db, companyIds);
    
    // Cuentas por cobrar consolidadas
    final consolidatedReceivables = await _getConsolidatedReceivables(db, companyIds);
    
    // Cuentas por pagar consolidadas
    final consolidatedPayables = await _getConsolidatedPayables(db, companyIds);
    
    final totalRevenue = consolidatedSales['total'] as double;
    final totalExpenses = consolidatedExpenses['total'] as double;
    final totalProfit = totalRevenue - totalExpenses;
    
    return {
      'period': {
        'start': effectiveStartDate.toIso8601String(),
        'end': effectiveEndDate.toIso8601String(),
      },
      'companies': companyIds.length,
      'sales': consolidatedSales,
      'expenses': consolidatedExpenses,
      'inventory': consolidatedInventory,
      'accounts_receivable': consolidatedReceivables,
      'accounts_payable': consolidatedPayables,
      'profit': totalProfit,
      'profit_margin': totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0,
      'net_cash_position': (consolidatedInventory['total_value'] as double) + 
                           (consolidatedReceivables['total'] as double) - 
                           (consolidatedPayables['total'] as double),
    };
  }
  
  /// Obtiene ventas consolidadas
  Future<Map<String, dynamic>> _getConsolidatedSales(
    Database db,
    List<int> companyIds,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final placeholders = List.filled(companyIds.length, '?').join(',');
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(total) as total,
        SUM(subtotal) as subtotal,
        SUM(impuesto_total) as tax,
        AVG(total) as average_ticket
      FROM ventas
      WHERE company_id IN ($placeholders) 
        AND fecha >= ? 
        AND fecha <= ? 
        AND estado = 'emitida'
    ''', [...companyIds, startDate.toIso8601String(), endDate.toIso8601String()]);
    
    return {
      'count': Sqflite.firstIntValue(result) ?? 0,
      'total': (result.first['total'] as num?)?.toDouble() ?? 0,
      'subtotal': (result.first['subtotal'] as num?)?.toDouble() ?? 0,
      'tax': (result.first['tax'] as num?)?.toDouble() ?? 0,
      'average_ticket': (result.first['average_ticket'] as num?)?.toDouble() ?? 0,
    };
  }
  
  /// Obtiene gastos consolidados
  Future<Map<String, dynamic>> _getConsolidatedExpenses(
    Database db,
    List<int> companyIds,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final placeholders = List.filled(companyIds.length, '?').join(',');
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(monto) as total
      FROM gastos
      WHERE company_id IN ($placeholders) 
        AND fecha >= ? 
        AND fecha <= ?
    ''', [...companyIds, startDate.toIso8601String(), endDate.toIso8601String()]);
    
    return {
      'count': Sqflite.firstIntValue(result) ?? 0,
      'total': (result.first['total'] as num?)?.toDouble() ?? 0,
    };
  }
  
  /// Obtiene inventario consolidado
  Future<Map<String, dynamic>> _getConsolidatedInventory(Database db, List<int> companyIds) async {
    final placeholders = List.filled(companyIds.length, '?').join(',');
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_products,
        SUM(stock) as total_stock,
        SUM(stock * costo) as total_value
      FROM productos
      WHERE company_id IN ($placeholders)
    ''', companyIds);
    
    return {
      'total_products': Sqflite.firstIntValue(result) ?? 0,
      'total_stock': (result.first['total_stock'] as num?)?.toDouble() ?? 0,
      'total_value': (result.first['total_value'] as num?)?.toDouble() ?? 0,
    };
  }
  
  /// Obtiene cuentas por cobrar consolidadas
  Future<Map<String, dynamic>> _getConsolidatedReceivables(Database db, List<int> companyIds) async {
    final placeholders = List.filled(companyIds.length, '?').join(',');
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(monto) as total
      FROM cuentas_por_cobrar
      WHERE company_id IN ($placeholders) AND estado = 'pendiente'
    ''', companyIds);
    
    return {
      'count': Sqflite.firstIntValue(result) ?? 0,
      'total': (result.first['total'] as num?)?.toDouble() ?? 0,
    };
  }
  
  /// Obtiene cuentas por pagar consolidadas
  Future<Map<String, dynamic>> _getConsolidatedPayables(Database db, List<int> companyIds) async {
    final placeholders = List.filled(companyIds.length, '?').join(',');
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(monto) as total
      FROM cuentas_por_pagar
      WHERE company_id IN ($placeholders) AND estado = 'pendiente'
    ''', companyIds);
    
    return {
      'count': Sqflite.firstIntValue(result) ?? 0,
      'total': (result.first['total'] as num?)?.toDouble() ?? 0,
    };
  }
  
  /// Obtiene desglose por empresa
  Future<List<Map<String, dynamic>>> getBreakdownByCompany(
    Database db,
    List<int> companyIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final effectiveStartDate = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final effectiveEndDate = endDate ?? DateTime.now();
    
    final breakdown = <Map<String, dynamic>>[];
    
    for (final companyId in companyIds) {
      final companyData = await _getCompanyFinancials(
        db,
        companyId,
        effectiveStartDate,
        effectiveEndDate,
      );
      
      breakdown.add({
        'company_id': companyId,
        ...companyData,
      });
    }
    
    return breakdown;
  }
  
  /// Obtiene financieras de una empresa específica
  Future<Map<String, dynamic>> _getCompanyFinancials(
    Database db,
    int companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(total) as total
      FROM ventas
      WHERE company_id = ? AND fecha >= ? AND fecha <= ? AND estado = 'emitida'
    ''', [companyId, startDate.toIso8601String(), endDate.toIso8601String()]);
    
    final expensesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(monto) as total
      FROM gastos
      WHERE company_id = ? AND fecha >= ? AND fecha <= ?
    ''', [companyId, startDate.toIso8601String(), endDate.toIso8601String()]);
    
    final inventoryResult = await db.rawQuery('''
      SELECT 
        SUM(stock * costo) as total_value
      FROM productos
      WHERE company_id = ?
    ''', [companyId]);
    
    final sales = (salesResult.first['total'] as num?)?.toDouble() ?? 0;
    final expenses = (expensesResult.first['total'] as num?)?.toDouble() ?? 0;
    
    return {
      'sales': {
        'count': Sqflite.firstIntValue(salesResult) ?? 0,
        'total': sales,
      },
      'expenses': {
        'count': Sqflite.firstIntValue(expensesResult) ?? 0,
        'total': expenses,
      },
      'inventory_value': (inventoryResult.first['total_value'] as num?)?.toDouble() ?? 0,
      'profit': sales - expenses,
    };
  }
  
  /// Genera reporte de consolidación en formato para exportación
  Future<Map<String, dynamic>> generateConsolidationReport(
    Database db,
    List<int> companyIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final consolidated = await getConsolidatedFinancials(
      db,
      companyIds,
      startDate: startDate,
      endDate: endDate,
    );
    
    final breakdown = await getBreakdownByCompany(
      db,
      companyIds,
      startDate: startDate,
      endDate: endDate,
    );
    
    return {
      'report_type': 'financial_consolidation',
      'generated_at': DateTime.now().toIso8601String(),
      'consolidated': consolidated,
      'breakdown_by_company': breakdown,
    };
  }
  
  /// Calcula KPIs consolidados
  Future<Map<String, dynamic>> getConsolidatedKPIs(
    Database db,
    List<int> companyIds,
  ) async {
    final consolidated = await getConsolidatedFinancials(db, companyIds);
    
    final sales = consolidated['sales'] as Map<String, dynamic>;
    final inventory = consolidated['inventory'] as Map<String, dynamic>;
    
    return {
      'revenue_per_company': (sales['total'] as double) / companyIds.length,
      'inventory_turnover': (sales['total'] as double) / (inventory['total_value'] as double),
      'profit_per_company': (consolidated['profit'] as double) / companyIds.length,
      'companies_count': companyIds.length,
    };
  }
  
  /// Consolidación vacía
  Map<String, dynamic> _emptyConsolidation() {
    return {
      'period': {
        'start': DateTime.now().toIso8601String(),
        'end': DateTime.now().toIso8601String(),
      },
      'companies': 0,
      'sales': {'count': 0, 'total': 0, 'subtotal': 0, 'tax': 0, 'average_ticket': 0},
      'expenses': {'count': 0, 'total': 0},
      'inventory': {'total_products': 0, 'total_stock': 0, 'total_value': 0},
      'accounts_receivable': {'count': 0, 'total': 0},
      'accounts_payable': {'count': 0, 'total': 0},
      'profit': 0,
      'profit_margin': 0,
      'net_cash_position': 0,
    };
  }
}
