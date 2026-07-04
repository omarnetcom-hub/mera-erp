import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/features/company_configuration_service.dart';
import 'package:merka_erp/sales/application/create_sale_use_case.dart';

void main() {
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
        'costo': 1000,
        'precio': 2500,
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
              unitPrice: 2500,
              unitCost: 1000,
              subtotal: 5000,
              taxRate: 0,
              taxTotal: 0,
            ),
          ],
          paymentMethodId: 1,
          paymentMethodName: 'EFECTIVO',
          clientName: 'Cliente general',
        ),
      );

      expect(result.total, 5000);

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

  tearDownAll(() async {
    CompanyConfigurationService.instance.resetForTests();
    await DatabaseHelper.resetForTests();
  });
}
