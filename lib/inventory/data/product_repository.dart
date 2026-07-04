import 'package:sqflite/sqflite.dart';

import '../../core/company/company_context.dart';
import '../../core/database/database_gateway.dart';
import '../../core/database/tenant_database_gateway.dart';
import '../../db_helper.dart';
import '../../features/feature_key.dart';
import '../domain/product.dart';

abstract class ProductRepository {
  Future<List<Product>> findAll();

  Future<Product?> findById(int id);

  Future<int> save(Product product);

  Future<void> delete(int id);

  Future<void> updateStock(int id, double stock);
}

class SqliteProductRepository implements ProductRepository {
  SqliteProductRepository({
    DatabaseGateway gateway = const SqliteDatabaseGateway(),
    CompanyContextProvider? companyContext,
  }) : _tenantGateway = TenantDatabaseGateway(
         gateway: gateway,
         companyContext: companyContext ?? CompanyContextService.instance,
       );

  final TenantDatabaseGateway _tenantGateway;

  @override
  Future<void> delete(int id) async {
    await DatabaseHelper.instance.validarFeatureHabilitada(
      FeatureKey.inventory,
    );
    await _tenantGateway.delete(
      'productos',
      query: TenantQuery(where: 'id = ?', whereArgs: [id]),
    );
  }

  @override
  Future<List<Product>> findAll() async {
    final rows = await _tenantGateway.query(
      'productos',
      query: const TenantQuery(orderBy: 'nombre ASC'),
    );
    return rows.map(Product.fromMap).toList();
  }

  @override
  Future<Product?> findById(int id) async {
    final row = await _tenantGateway.findById('productos', id);
    return row == null ? null : Product.fromMap(row);
  }

  @override
  Future<int> save(Product product) async {
    await DatabaseHelper.instance.validarFeatureHabilitada(
      FeatureKey.inventory,
    );
    final data = product.toPersistenceMap()..remove('company_id');

    final id = product.id;
    if (id == null) {
      return await _tenantGateway.insert('productos', data);
    }

    return await _tenantGateway.update(
      'productos',
      data,
      query: TenantQuery(where: 'id = ?', whereArgs: [id]),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateStock(int id, double stock) async {
    if (stock < 0) {
      throw Exception('El stock no puede quedar negativo.');
    }
    await _tenantGateway.update('productos', {
      'stock': stock,
    }, query: TenantQuery(where: 'id = ?', whereArgs: [id]));
  }
}
