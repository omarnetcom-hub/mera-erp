import '../data/final_enterprise_repository.dart';

class FinalEnterpriseQueryHandlers {
  FinalEnterpriseQueryHandlers({required FinalEnterpriseRepository repository})
    : _repository = repository;

  final FinalEnterpriseRepository _repository;

  Future<List<Map<String, Object?>>> arLedger({int? customerId}) async {
    final rows = await _repository.queryScoped(
      'ar_ledger_entries',
      where: customerId == null ? null : 'customer_id = ?',
      whereArgs: customerId == null ? null : [customerId],
      orderBy: 'occurred_at DESC',
      limit: 500,
    );
    return rows;
  }

  Future<Map<String, Object?>> arAging() =>
      _aging(table: 'ar_ledger_entries', openField: 'open_amount');

  Future<List<Map<String, Object?>>> apLedger({int? supplierId}) async {
    final rows = await _repository.queryScoped(
      'ap_supplier_ledger',
      where: supplierId == null ? null : 'supplier_id = ?',
      whereArgs: supplierId == null ? null : [supplierId],
      orderBy: 'occurred_at DESC',
      limit: 500,
    );
    return rows;
  }

  Future<Map<String, Object?>> apAging() =>
      _aging(table: 'ap_supplier_ledger', openField: 'open_amount');

  Future<Map<String, Object?>> treasuryDashboard() async {
    final accounts = await _repository.queryScoped('treasury_bank_accounts');
    final movements = await _repository.queryScoped('treasury_bank_movements');
    final balance = accounts.fold<double>(
      0,
      (sum, row) => sum + ((row['balance'] as num?)?.toDouble() ?? 0),
    );
    final inflow = movements
        .where((row) => row['direction'] == 'in')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    final outflow = movements
        .where((row) => row['direction'] == 'out')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    return {
      'bank_accounts': accounts.length,
      'treasury_position': balance,
      'projected_cash_flow': balance + inflow - outflow,
      'inflow': inflow,
      'outflow': outflow,
    };
  }

  Future<List<Map<String, Object?>>> unmatchedBankOperations() async {
    return _repository.queryScoped(
      'bank_statement_lines',
      where: 'status = ?',
      whereArgs: ['unmatched'],
      orderBy: 'movement_date DESC',
      limit: 500,
    );
  }

  Future<List<Map<String, Object?>>> assets() async {
    return _repository.queryScoped(
      'enterprise_fixed_assets',
      orderBy: 'acquired_at DESC',
      limit: 500,
    );
  }

  Future<Map<String, Object?>> crmPipeline() async {
    final rows = await _repository.queryScoped('crm_opportunities');
    final totals = <String, double>{};
    for (final row in rows) {
      final stage = row['stage']?.toString() ?? 'lead';
      totals[stage] =
          (totals[stage] ?? 0) + ((row['value'] as num?)?.toDouble() ?? 0);
    }
    return {'count': rows.length, 'value_by_stage': totals, 'items': rows};
  }

  Future<List<Map<String, Object?>>> materializedReports() {
    return _repository.queryScoped(
      'materialized_reports',
      orderBy: 'created_at DESC',
      limit: 200,
    );
  }

  Future<Map<String, Object?>> _aging({
    required String table,
    required String openField,
  }) async {
    final rows = await _repository.queryScoped(table);
    final buckets = {
      'current': 0.0,
      '1_30': 0.0,
      '31_60': 0.0,
      '61_90': 0.0,
      '90_plus': 0.0,
    };
    final now = DateTime.now();
    for (final row in rows) {
      final amount = (row[openField] as num?)?.toDouble() ?? 0;
      if (amount <= 0) continue;
      final dueDate =
          DateTime.tryParse(row['due_date']?.toString() ?? '') ?? now;
      final days = now.difference(dueDate).inDays;
      if (days <= 0) {
        buckets['current'] = buckets['current']! + amount;
      } else if (days <= 30) {
        buckets['1_30'] = buckets['1_30']! + amount;
      } else if (days <= 60) {
        buckets['31_60'] = buckets['31_60']! + amount;
      } else if (days <= 90) {
        buckets['61_90'] = buckets['61_90']! + amount;
      } else {
        buckets['90_plus'] = buckets['90_plus']! + amount;
      }
    }
    return buckets;
  }
}
