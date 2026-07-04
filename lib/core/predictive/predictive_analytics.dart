// ============================================================
// predictive_analytics.dart
// Servicio de analítica predictiva (pronósticos y anomalías)
// ============================================================

import 'dart:math';
import 'package:sqflite/sqflite.dart';

class PredictiveAnalytics {
  static final PredictiveAnalytics instance = PredictiveAnalytics._internal();
  
  PredictiveAnalytics._internal();
  
  /// Pronostica ventas para los próximos N días usando promedio móvil
  Future<List<Map<String, dynamic>>> forecastSales(
    Database db,
    int companyId, {
    int days = 30,
    int historicalDays = 90,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: historicalDays));
    
    // Obtener datos históricos de ventas
    final historicalData = await db.rawQuery('''
      SELECT 
        DATE(fecha) as date,
        SUM(total) as total
      FROM ventas
      WHERE company_id = ? AND fecha >= ? AND estado = 'emitida'
      GROUP BY DATE(fecha)
      ORDER BY date ASC
    ''', [companyId, startDate.toIso8601String()]);
    
    if (historicalData.isEmpty) {
      // Retornar pronóstico basado en cero si no hay datos
      final forecast = <Map<String, dynamic>>[];
      for (int i = 1; i <= days; i++) {
        final date = DateTime.now().add(Duration(days: i));
        forecast.add({
          'date': date.toIso8601String(),
          'predicted_sales': 0.0,
          'confidence': 0.0,
        });
      }
      return forecast;
    }
    
    // Calcular promedio móvil simple
    final windowSize = min(7, historicalData.length);
    final forecast = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= days; i++) {
      final date = DateTime.now().add(Duration(days: i));
      
      // Calcular promedio de los últimos N días
      double sum = 0;
      int count = 0;
      
      for (int j = 0; j < windowSize && j < historicalData.length; j++) {
        final index = historicalData.length - 1 - j;
        if (index >= 0) {
          sum += (historicalData[index]['total'] as num).toDouble();
          count++;
        }
      }
      
      final predictedValue = count > 0 ? sum / count : 0;
      
      // Calcular confianza basada en variabilidad
      final variance = _calculateVariance(historicalData, windowSize);
      final confidence = variance > 0 ? max(0.5, 1 - (sqrt(variance) / predictedValue)) : 0.8;
      
      // Ajustar por estacionalidad (día de la semana)
      final dayOfWeek = date.weekday;
      final seasonalFactor = _getSeasonalFactor(historicalData, dayOfWeek);
      
      forecast.add({
        'date': date.toIso8601String(),
        'predicted_sales': predictedValue * seasonalFactor,
        'confidence': confidence.clamp(0.0, 1.0),
        'seasonal_factor': seasonalFactor,
      });
    }
    
    return forecast;
  }
  
  /// Calcula la varianza de los datos
  double _calculateVariance(List<Map<String, dynamic>> data, int windowSize) {
    if (data.isEmpty) return 0;
    
    final values = data.take(windowSize).map((e) => (e['total'] as num).toDouble()).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return variance;
  }
  
  /// Obtiene factor estacional basado en el día de la semana
  double _getSeasonalFactor(List<Map<String, dynamic>> data, int dayOfWeek) {
    // Agrupar por día de la semana
    final dayTotals = <int, List<double>>{};
    
    for (final row in data) {
      final date = DateTime.parse(row['date'] as String);
      final dow = date.weekday;
      final value = (row['total'] as num).toDouble();
      
      dayTotals.putIfAbsent(dow, () => []).add(value);
    }
    
    if (!dayTotals.containsKey(dayOfWeek)) return 1.0;
    
    final dayValues = dayTotals[dayOfWeek]!;
    final dayAvg = dayValues.reduce((a, b) => a + b) / dayValues.length;
    
    // Calcular promedio global
    final allValues = data.map((e) => (e['total'] as num).toDouble()).toList();
    final globalAvg = allValues.reduce((a, b) => a + b) / allValues.length;
    
    return globalAvg > 0 ? dayAvg / globalAvg : 1.0;
  }
  
  /// Detecta anomalías en ventas
  Future<List<Map<String, dynamic>>> detectSalesAnomalies(
    Database db,
    int companyId, {
    int days = 30,
    double threshold = 2.0, // Desviaciones estándar
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    final salesData = await db.rawQuery('''
      SELECT 
        DATE(fecha) as date,
        SUM(total) as total
      FROM ventas
      WHERE company_id = ? AND fecha >= ? AND estado = 'emitida'
      GROUP BY DATE(fecha)
      ORDER BY date ASC
    ''', [companyId, startDate.toIso8601String()]);
    
    if (salesData.length < 7) return [];
    
    final values = salesData.map((e) => (e['total'] as num).toDouble()).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);
    
    final anomalies = <Map<String, dynamic>>[];
    
    for (int i = 0; i < salesData.length; i++) {
      final value = values[i];
      final zScore = stdDev > 0 ? (value - mean) / stdDev : 0;
      
      if (zScore.abs() > threshold) {
        anomalies.add({
          'date': salesData[i]['date'],
          'value': value,
          'mean': mean,
          'z_score': zScore,
          'type': zScore > 0 ? 'high' : 'low',
          'severity': zScore.abs() > 3 ? 'critical' : 'warning',
        });
      }
    }
    
    return anomalies;
  }
  
  /// Pronostica stock requerido para productos
  Future<List<Map<String, dynamic>>> forecastStockRequirements(
    Database db,
    int companyId, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: 30));
    
    // Obtener consumo histórico por producto
    final consumptionData = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.nombre as product_name,
        p.stock as current_stock,
        p.stock_minimo as min_stock,
        SUM(vd.cantidad) as total_consumed
      FROM productos p
      LEFT JOIN ventas_detalle vd ON p.id = vd.producto_id
      LEFT JOIN ventas v ON vd.venta_id = v.id
      WHERE p.company_id = ? AND (v.fecha >= ? OR v.fecha IS NULL)
      GROUP BY p.id, p.nombre, p.stock, p.stock_minimo
    ''', [companyId, startDate.toIso8601String()]);
    
    final forecast = <Map<String, dynamic>>[];
    
    for (final row in consumptionData) {
      final currentStock = (row['current_stock'] as num?)?.toDouble() ?? 0;
      final minStock = (row['min_stock'] as num?)?.toDouble() ?? 0;
      final totalConsumed = (row['total_consumed'] as num?)?.toDouble() ?? 0;
      
      // Calcular consumo diario promedio
      final dailyConsumption = totalConsumed / 30;
      
      // Pronosticar stock requerido para los próximos N días
      final requiredStock = dailyConsumption * days;
      
      // Calcular días hasta stock bajo
      final daysUntilLow = dailyConsumption > 0 
          ? ((currentStock - minStock) / dailyConsumed).floor() 
          : -1;
      
      forecast.add({
        'product_id': row['product_id'],
        'product_name': row['product_name'],
        'current_stock': currentStock,
        'min_stock': minStock,
        'daily_consumption': dailyConsumption,
        'required_stock': requiredStock,
        'days_until_low': daysUntilLow,
        'needs_reorder': daysUntilLow <= 7,
        'recommended_order': max(0, requiredStock - currentStock),
      });
    }
    
    // Ordenar por urgencia
    forecast.sort((a, b) => (a['days_until_low'] as int).compareTo(b['days_until_low'] as int));
    
    return forecast;
  }
  
  /// Detecta productos con comportamiento anormal en ventas
  Future<List<Map<String, dynamic>>> detectProductAnomalies(
    Database db,
    int companyId, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    final productData = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.nombre as product_name,
        COUNT(v.id) as sales_count,
        SUM(v.total) as total_sales,
        AVG(v.total) as avg_sale
      FROM productos p
      LEFT JOIN ventas v ON p.id = v.producto_id AND v.fecha >= ? AND v.estado = 'emitida'
      WHERE p.company_id = ?
      GROUP BY p.id, p.nombre
    ''', [startDate.toIso8601String(), companyId]);
    
    if (productData.isEmpty) return [];
    
    // Calcular estadísticas globales
    final salesCounts = productData.map((e) => (e['sales_count'] as num).toInt()).toList();
    final avgSales = salesCounts.reduce((a, b) => a + b) / salesCounts.length;
    final variance = salesCounts.map((v) => pow(v - avgSales, 2)).reduce((a, b) => a + b) / salesCounts.length;
    final stdDev = sqrt(variance);
    
    final anomalies = <Map<String, dynamic>>[];
    
    for (final row in productData) {
      final salesCount = (row['sales_count'] as num).toInt();
      final zScore = stdDev > 0 ? (salesCount - avgSales) / stdDev : 0;
      
      if (zScore.abs() > 2) {
        anomalies.add({
          'product_id': row['product_id'],
          'product_name': row['product_name'],
          'sales_count': salesCount,
          'avg_sales': avgSales,
          'z_score': zScore,
          'type': zScore > 0 ? 'high_performer' : 'underperformer',
        });
      }
    }
    
    return anomalies;
  }
  
  /// Pronostica flujo de caja
  Future<List<Map<String, dynamic>>> forecastCashFlow(
    Database db,
    int companyId, {
    int days = 30,
  }) async {
    final forecast = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= days; i++) {
      final date = DateTime.now().add(Duration(days: i));
      
      // Pronóstico de ingresos (basado en ventas históricas)
      final incomeForecast = await _forecastIncome(db, companyId, date);
      
      // Pronóstico de egresos (basado en gastos históricos)
      final expenseForecast = await _forecastExpenses(db, companyId, date);
      
      forecast.add({
        'date': date.toIso8601String(),
        'predicted_income': incomeForecast,
        'predicted_expense': expenseForecast,
        'net_cash_flow': incomeForecast - expenseForecast,
      });
    }
    
    return forecast;
  }
  
  /// Pronostica ingresos para una fecha específica
  Future<double> _forecastIncome(Database db, int companyId, DateTime date) async {
    // Obtener ventas del mismo día de la semana en las últimas 4 semanas
    final dayOfWeek = date.weekday;
    final startDate = DateTime.now().subtract(const Duration(days: 28));
    
    final result = await db.rawQuery('''
      SELECT AVG(total) as avg_total
      FROM ventas
      WHERE company_id = ? 
        AND fecha >= ? 
        AND strftime('%w', fecha) = ?
        AND estado = 'emitida'
    ''', [companyId, startDate.toIso8601String(), dayOfWeek.toString()]);
    
    return (result.first['avg_total'] as num?)?.toDouble() ?? 0;
  }
  
  /// Pronostica egresos para una fecha específica
  Future<double> _forecastExpenses(Database db, int companyId, DateTime date) async {
    // Obtener gastos del mismo día de la semana en las últimas 4 semanas
    final dayOfWeek = date.weekday;
    final startDate = DateTime.now().subtract(const Duration(days: 28));
    
    final result = await db.rawQuery('''
      SELECT AVG(monto) as avg_monto
      FROM gastos
      WHERE company_id = ? 
        AND fecha >= ? 
        AND strftime('%w', fecha) = ?
    ''', [companyId, startDate.toIso8601String(), dayOfWeek.toString()]);
    
    return (result.first['avg_monto'] as num?)?.toDouble() ?? 0;
  }
  
  /// Obtiene recomendaciones basadas en análisis predictivo
  Future<List<Map<String, dynamic>>> getRecommendations(
    Database db,
    int companyId,
  ) async {
    final recommendations = <Map<String, dynamic>>[];
    
    // Verificar stock bajo pronosticado
    final stockForecast = await forecastStockRequirements(db, companyId);
    final lowStockProducts = stockForecast.where((e) => e['needs_reorder'] as bool).toList();
    
    if (lowStockProducts.isNotEmpty) {
      recommendations.add({
        'type': 'inventory',
        'priority': 'high',
        'message': '${lowStockProducts.length} productos necesitan reabastecimiento pronto',
        'details': lowStockProducts.take(5).toList(),
      });
    }
    
    // Verificar anomalías en ventas
    final salesAnomalies = await detectSalesAnomalies(db, companyId);
    if (salesAnomalies.isNotEmpty) {
      recommendations.add({
        'type': 'sales',
        'priority': 'medium',
        'message': 'Se detectaron ${salesAnomalies.length} anomalías en ventas',
        'details': salesAnomalies.take(3).toList(),
      });
    }
    
    // Verificar flujo de caja pronosticado
    final cashFlowForecast = await forecastCashFlow(db, companyId, days: 7);
    final negativeCashFlowDays = cashFlowForecast.where((e) => (e['net_cash_flow'] as double) < 0).toList();
    
    if (negativeCashFlowDays.isNotEmpty) {
      recommendations.add({
        'type': 'cash_flow',
        'priority': 'high',
        'message': 'Se pronostican ${negativeCashFlowDays.length} días con flujo de caja negativo',
        'details': negativeCashFlowDays,
      });
    }
    
    return recommendations;
  }
}
