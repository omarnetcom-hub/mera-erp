import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/core/currency/currency.dart';
import 'package:merka_erp/core/currency/money_value.dart';
import 'package:merka_erp/features/company_configuration_service.dart';
import 'package:merka_erp/sales/application/create_sale_use_case.dart';

void main() {
  final cop = Currency(
    code: 'COP',
    name: 'Colombian Peso',
    symbol: r'$',
    decimalPlaces: 2,
  );
  late final Directory dbDir;
  late final Database db;
  late final int companyId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.resetForTests();
    CompanyConfigurationService.instance.resetForTests();
    dbDir = await Directory.systemTemp.createTemp('merkaerp_sales_flow_db_');
    await databaseFactory.setDatabasesPath(dbDir.path);
    db = await DatabaseHelper.instance.database;
    companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    await DatabaseHelper.instance.guardarCompanySettings(companyId, {
      'onboarding_completed': '1',
      'country': 'Colombia',
      'currency': 'COP',
      'timezone': 'America/Bogota',
    });
  });

  setUp(() async {
    await db.delete(
      'reglas_retenciones_empresa',
      where: 'company_id = ? AND aplica_ventas = 1',
      whereArgs: [companyId],
    );
  });

  test(
    'venta POS descuenta inventario, registra caja y asiento contable',
    () async {
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final productName = 'Producto venta flujo $suffix';
      final productId = await db.insert('productos', {
        'company_id': companyId,
        'nombre': productName,
        'unidad_base': 'unid.',
        'stock': 5,
        'costo': 100000,
        'precio': 250000,
        'impuesto_pct': 0,
        'codigo_barras': 'FLOW$suffix',
      });

      final result = await CreateSaleUseCase().execute(
        CreateSaleRequest(
          items: [
            SaleItemInput(
              productId: productId,
              productName: productName,
              quantity: 2,
              unitPrice: MoneyValue.fromMajorUnits('2500', currency: cop),
              unitCost: MoneyValue.fromMajorUnits('1000', currency: cop),
              subtotal: MoneyValue.fromMajorUnits('5000', currency: cop),
              taxRate: 0,
              taxTotal: MoneyValue(minorUnits: 0, currency: cop),
            ),
          ],
          paymentMethodId: 1,
          paymentMethodName: 'EFECTIVO',
          clientName: 'Cliente general',
          efectivo: MoneyValue(minorUnits: 0, currency: cop),
          transferencia: MoneyValue(minorUnits: 0, currency: cop),
          credito: MoneyValue(minorUnits: 0, currency: cop),
          retefuente: MoneyValue(minorUnits: 0, currency: cop),
          reteiva: MoneyValue(minorUnits: 0, currency: cop),
          reteica: MoneyValue(minorUnits: 0, currency: cop),
        ),
      );

      expect(result.total.toMajorUnitsString(), '5000.00');

      final saleRows = await db.query(
        'ventas',
        columns: ['reteica'],
        where: 'id = ? AND company_id = ?',
        whereArgs: [result.saleId, companyId],
      );
      expect((saleRows.single['reteica'] as num).toDouble(), 0);

      final detailRows = await db.rawQuery(
        '''
      SELECT vd.*
      FROM ventas_detalle vd
      INNER JOIN ventas v ON v.id = vd.venta_id
      WHERE v.company_id = ? AND vd.producto = ?
      ORDER BY vd.id DESC
      LIMIT 1
      ''',
        [companyId, productName],
      );
      expect(detailRows, isNotEmpty);

      final productRows = await db.query(
        'productos',
        where: 'id = ? AND company_id = ?',
        whereArgs: [productId, companyId],
      );
      final cashRows = await db.query(
        'movimientos_caja',
        where: 'concepto = ? AND company_id = ?',
        whereArgs: ['Factura POS #${result.saleId}', companyId],
      );
      final inventoryRows = await db.query(
        'movimientos_inventario',
        where: 'motivo = ? AND company_id = ?',
        whereArgs: ['FACTURA POS #${result.saleId}', companyId],
      );
      final accountingRows = await db.query(
        'asientos_contables',
        where: 'referencia = ? AND company_id = ?',
        whereArgs: ['VENTA-${result.saleId}', companyId],
      );

      expect((productRows.single['stock'] as num).toDouble(), 3);
      expect(cashRows, isNotEmpty);
      expect(inventoryRows, isNotEmpty);
      expect(accountingRows, isNotEmpty);
    },
  );

  test('venta POS aplica ReteICA solo desde regla activa de ventas', () async {
    await db.insert('reglas_retenciones_empresa', {
      'company_id': companyId + 1000,
      'codigo': 'RTEICA_OTRA_EMPRESA_TEST',
      'nombre': 'ReteICA de otra empresa',
      'tasa': 9.9,
      'base_minima': 0,
      'cuenta_contable': '2367',
      'aplica_ventas': 1,
      'aplica_compras': 0,
      'activo': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('reglas_retenciones_empresa', {
      'company_id': companyId,
      'codigo': 'RTEICA_INACTIVA_TEST',
      'nombre': 'ReteICA inactiva',
      'tasa': 8.8,
      'base_minima': 0,
      'cuenta_contable': '2367',
      'aplica_ventas': 1,
      'aplica_compras': 0,
      'activo': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('reglas_retenciones_empresa', {
      'company_id': companyId,
      'codigo': 'RTEICA_VENTAS_TEST',
      'nombre': 'ReteICA ventas de prueba',
      'tasa': 1.1,
      'base_minima': 500000,
      'cuenta_contable': '2367',
      'aplica_ventas': 1,
      'aplica_compras': 0,
      'activo': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final suffix = DateTime.now().microsecondsSinceEpoch;
    final productName = 'Producto ReteICA $suffix';
    final productId = await db.insert('productos', {
      'company_id': companyId,
      'nombre': productName,
      'unidad_base': 'unid.',
      'stock': 2,
      'costo': 400000,
      'precio': 1000000,
      'impuesto_pct': 0,
      'codigo_barras': 'RTEICA$suffix',
    });

    final result = await CreateSaleUseCase().execute(
      CreateSaleRequest(
        items: [
          SaleItemInput(
            productId: productId,
            productName: productName,
            quantity: 1,
            unitPrice: MoneyValue.fromMajorUnits('10000', currency: cop),
            unitCost: MoneyValue.fromMajorUnits('4000', currency: cop),
            subtotal: MoneyValue.fromMajorUnits('10000', currency: cop),
            taxRate: 0,
            taxTotal: MoneyValue(minorUnits: 0, currency: cop),
          ),
        ],
        paymentMethodId: 1,
        paymentMethodName: 'EFECTIVO',
        clientName: 'Cliente general',
        efectivo: MoneyValue(minorUnits: 0, currency: cop),
        transferencia: MoneyValue(minorUnits: 0, currency: cop),
        credito: MoneyValue(minorUnits: 0, currency: cop),
        retefuente: MoneyValue(minorUnits: 0, currency: cop),
        reteiva: MoneyValue(minorUnits: 0, currency: cop),
        reteica: MoneyValue(minorUnits: 0, currency: cop),
      ),
    );

    expect(result.total.toMajorUnitsString(), '9890.00');
    final saleRows = await db.query(
      'ventas',
      columns: ['reteica'],
      where: 'id = ? AND company_id = ?',
      whereArgs: [result.saleId, companyId],
    );
    expect(saleRows.single['reteica'], 11000);
  });

  tearDownAll(() async {
    CompanyConfigurationService.instance.resetForTests();
    await DatabaseHelper.resetForTests();
  });
}
