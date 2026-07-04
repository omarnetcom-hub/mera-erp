import '../../core/database/database_gateway.dart';
import '../../core/events/event_dispatcher.dart';
import '../../core/events/event_store.dart';

class PurchaseAnalyticsProjection implements EventProjection {
  PurchaseAnalyticsProjection({
    DatabaseGateway gateway = const SqliteDatabaseGateway(),
  }) : _gateway = gateway;

  final DatabaseGateway _gateway;

  @override
  String get name => 'purchase_analytics';

  @override
  Future<void> apply(EventEnvelope event) async {
    if (!_supported.contains(event.name)) return;
    final sign = event.name == 'PurchaseReversedEvent' ? -1.0 : 1.0;
    await _gateway.insert('purchase_analytics_read_model', {
      'company_id': event.companyId,
      'branch_id': event.branchId,
      'document_id':
          event.payload['purchase_id']?.toString() ?? event.aggregateId,
      'event_name': event.name,
      'spend': _number(event.payload['total']) * sign,
      'tax': _number(event.payload['tax']) * sign,
      'retention': _number(event.payload['retention']) * sign,
      'occurred_at': event.occurredAt.toIso8601String(),
      'correlation_id': event.correlationId,
    });
  }

  static const _supported = {
    'PurchaseApprovedEvent',
    'GoodsReceivedEvent',
    'SupplierInvoicePostedEvent',
    'PurchaseReversedEvent',
    'SupplierBalanceUpdatedEvent',
    'purchases.approved',
  };

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
