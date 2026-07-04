import '../../core/database/database_gateway.dart';
import '../../core/events/event_dispatcher.dart';
import '../../core/events/event_store.dart';

class SalesAnalyticsProjection implements EventProjection {
  SalesAnalyticsProjection({
    DatabaseGateway gateway = const SqliteDatabaseGateway(),
  }) : _gateway = gateway;

  final DatabaseGateway _gateway;

  @override
  String get name => 'sales_analytics';

  @override
  Future<void> apply(EventEnvelope event) async {
    if (event.name != 'SalePostedEvent' && event.name != 'sales.reversed') {
      return;
    }
    final amount = _number(event.payload['total']);
    final tax = _number(event.payload['tax']);
    final saleId = event.payload['sale_id']?.toString() ?? event.aggregateId;
    final sign = event.name == 'sales.reversed' ? -1.0 : 1.0;
    await _gateway.insert('sales_analytics_read_model', {
      'company_id': event.companyId,
      'branch_id': event.branchId,
      'document_id': saleId,
      'event_name': event.name,
      'revenue': amount * sign,
      'tax': tax * sign,
      'occurred_at': event.occurredAt.toIso8601String(),
      'correlation_id': event.correlationId,
    });
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
