import '../../core/company/company_context.dart';
import '../../core/database/database_gateway.dart';
import '../../core/database/tenant_database_gateway.dart';
import '../../db_helper.dart';
import '../../features/feature_key.dart';
import '../domain/purchase.dart';

abstract class PurchaseRepository {
  Future<List<Purchase>> findAll();

  Future<List<Purchase>> findActive();

  Future<List<PurchaseLine>> findDetails(int purchaseId);

  Future<double> totalPurchases();

  Future<int> createHeader(Map<String, dynamic> values);

  Future<void> cancel(int purchaseId);
}

class SqlitePurchaseRepository implements PurchaseRepository {
  SqlitePurchaseRepository({
    DatabaseHelper? db,
    DatabaseGateway gateway = const SqliteDatabaseGateway(),
    CompanyContextProvider? companyContext,
    Future<void> Function(String featureKey)? validateFeature,
  }) : _db = db ?? DatabaseHelper.instance,
       _gateway = gateway,
       _tenantGateway = TenantDatabaseGateway(
         gateway: gateway,
         companyContext: companyContext ?? CompanyContextService.instance,
       ),
       _validateFeature =
           validateFeature ?? DatabaseHelper.instance.validarFeatureHabilitada;

  final DatabaseHelper _db;
  final DatabaseGateway _gateway;
  final TenantDatabaseGateway _tenantGateway;
  final Future<void> Function(String featureKey) _validateFeature;

  @override
  Future<void> cancel(int purchaseId) async {
    await _db.eliminarCompra(purchaseId);
  }

  @override
  Future<int> createHeader(Map<String, dynamic> values) async {
    await _validateFeature(FeatureKey.purchases);
    return await _tenantGateway.insert('compras', values);
  }

  @override
  Future<List<Purchase>> findActive() async {
    final rows = await _tenantGateway.query(
      'compras',
      query: const TenantQuery(
        where: "COALESCE(estado, 'pagada') != 'anulada'",
        orderBy: 'fecha DESC',
      ),
    );
    return rows.map(Purchase.fromMap).toList();
  }

  @override
  Future<List<Purchase>> findAll() async {
    final rows = await _tenantGateway.query(
      'compras',
      query: const TenantQuery(orderBy: 'fecha DESC'),
    );
    return rows.map(Purchase.fromMap).toList();
  }

  @override
  Future<List<PurchaseLine>> findDetails(int purchaseId) async {
    final companyId = await _tenantGateway.companyId;
    final rows = await _gateway.rawQuery(
      '''
      SELECT
        cd.*,
        p.unidad_base,
        p.codigo_barras
      FROM compras_detalle cd
      INNER JOIN compras c ON c.id = cd.compra_id
      LEFT JOIN productos p ON p.id = cd.producto_id
      WHERE cd.compra_id = ? AND c.company_id = ?
      ORDER BY cd.id ASC
      ''',
      [purchaseId, companyId],
    );
    return rows.map(PurchaseLine.fromMap).toList();
  }

  @override
  Future<double> totalPurchases() async {
    final companyId = await _tenantGateway.companyId;
    final rows = await _gateway.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM compras WHERE company_id = ? AND COALESCE(estado, 'pagada') != 'anulada'",
      [companyId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }
}
