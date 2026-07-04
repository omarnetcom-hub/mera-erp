import '../../core/database/database_gateway.dart';
import '../../core/events/event_dispatcher.dart';
import '../../core/events/event_store.dart';
import '../domain/read_models.dart';

class DashboardReadModelProjection implements EventProjection {
  DashboardReadModelProjection({
    DatabaseGateway gateway = const SqliteDatabaseGateway(),
  }) : _gateway = gateway;

  final DatabaseGateway _gateway;

  @override
  String get name => 'executive_dashboard';

  @override
  Future<void> apply(EventEnvelope event) async {
    final sequence = event.sequence ?? 0;
    if (sequence <= await _lastSequence(event.companyId, event.branchId)) {
      return;
    }

    switch (event.name) {
      case 'sales.created':
        await _increment(event, 'sales_total', _amount(event, 'total'));
        await _increment(event, 'sales_count', 1);
        break;
      case 'purchases.created':
      case 'purchases.approved':
        await _increment(event, 'purchases_total', _amount(event, 'total'));
        await _increment(event, 'purchases_count', 1);
        break;
      case 'inventory.adjusted':
        await _increment(
          event,
          'inventory_adjustments',
          _amount(event, 'quantity'),
        );
        break;
      case 'payments.registered':
        await _increment(event, 'payments_total', _amount(event, 'amount'));
        break;
    }

    await _saveOffset(event.companyId, event.branchId, sequence);
  }

  Future<ExecutiveDashboardReadModel> read({
    required int companyId,
    required int branchId,
  }) async {
    final rows = await _gateway.query(
      'executive_kpi_read_model',
      where: 'company_id = ? AND branch_id = ?',
      whereArgs: [companyId, branchId],
      orderBy: 'metric_key ASC',
    );
    return ExecutiveDashboardReadModel(
      companyId: companyId,
      branchId: branchId,
      metrics: rows
          .map(
            (row) => KpiMetric(
              key: row['metric_key']?.toString() ?? '',
              value: (row['metric_value'] as num?)?.toDouble() ?? 0,
              updatedAt:
                  DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          )
          .toList(),
    );
  }

  Future<double> _lastSequence(int companyId, int branchId) async {
    final rows = await _gateway.query(
      'cqrs_projection_offsets',
      where: 'projection_name = ? AND company_id = ? AND branch_id = ?',
      whereArgs: [name, companyId, branchId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['last_sequence'] as num?)?.toDouble() ?? 0;
  }

  Future<void> _saveOffset(int companyId, int branchId, int sequence) async {
    final updated = await _gateway.update(
      'cqrs_projection_offsets',
      {
        'last_sequence': sequence,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'projection_name = ? AND company_id = ? AND branch_id = ?',
      whereArgs: [name, companyId, branchId],
    );
    if (updated == 0) {
      await _gateway.insert('cqrs_projection_offsets', {
        'projection_name': name,
        'company_id': companyId,
        'branch_id': branchId,
        'last_sequence': sequence,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _increment(
    EventEnvelope event,
    String metric,
    double amount,
  ) async {
    final rows = await _gateway.query(
      'executive_kpi_read_model',
      where: 'company_id = ? AND branch_id = ? AND metric_key = ?',
      whereArgs: [event.companyId, event.branchId, metric],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    if (rows.isEmpty) {
      await _gateway.insert('executive_kpi_read_model', {
        'company_id': event.companyId,
        'branch_id': event.branchId,
        'metric_key': metric,
        'metric_value': amount,
        'updated_at': now,
      });
      return;
    }
    final current = (rows.first['metric_value'] as num?)?.toDouble() ?? 0;
    await _gateway.update(
      'executive_kpi_read_model',
      {'metric_value': current + amount, 'updated_at': now},
      where: 'company_id = ? AND branch_id = ? AND metric_key = ?',
      whereArgs: [event.companyId, event.branchId, metric],
    );
  }

  double _amount(EventEnvelope event, String key) {
    final value = event.payload[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
