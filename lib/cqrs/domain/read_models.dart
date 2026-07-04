class KpiMetric {
  const KpiMetric({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  final String key;
  final double value;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'key': key,
    'value': value,
    'updated_at': updatedAt.toIso8601String(),
  };
}

class ExecutiveDashboardReadModel {
  const ExecutiveDashboardReadModel({
    required this.companyId,
    required this.branchId,
    required this.metrics,
  });

  final int companyId;
  final int branchId;
  final List<KpiMetric> metrics;

  double value(String key) {
    return metrics
        .where((metric) => metric.key == key)
        .fold<double>(0, (sum, metric) => sum + metric.value);
  }

  Map<String, Object?> toMap() => {
    'company_id': companyId,
    'branch_id': branchId,
    'metrics': metrics.map((metric) => metric.toMap()).toList(),
    'summary': {
      'sales_total': value('sales_total'),
      'purchases_total': value('purchases_total'),
      'inventory_adjustments': value('inventory_adjustments'),
      'payments_total': value('payments_total'),
    },
  };
}
