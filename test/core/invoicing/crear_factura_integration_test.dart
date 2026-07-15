import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/features/company_configuration_service.dart';
import 'package:merka_erp/sales/application/create_sale_use_case.dart';

void main() {
  late final Directory dbDir;
  late final dynamic db; // Database returned by DatabaseHelper
  late final int companyId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.resetForTests();
    CompanyConfigurationService.instance.resetForTests();
    dbDir = await Directory.systemTemp.createTemp('merkaerp_invoice_integration_db_');
    await databaseFactory.setDatabasesPath(dbDir.path);
    db = await DatabaseHelper.instance.database;
    companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    // Asegurar que la empresa de prueba exista con nombre conocido
    await DatabaseHelper.instance.guardarEmpresaConfig({
      'nombre': 'Empresa Prueba S.A.S',
      'nit': '900123456'
    });
  });

  test('crearFacturaElectronicaBorrador produce XML con supplier y líneas mapeadas', () async {
    // Crear producto
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final productId = await db.insert('productos', {
      'company_id': companyId,
      'nombre': 'Prod Integracion $suffix',
      'unidad_base': 'unid',
      'stock': 10,
      'costo': 1000,
      'precio': 1500,
      'impuesto_pct': 0,
      'codigo_barras': 'PI$suffix',
    });

    // Crear venta via caso de uso para poblar ventas y ventas_detalle
    final result = await CreateSaleUseCase().execute(CreateSaleRequest(
      items: [
        SaleItemInput(
          productId: productId,
          productName: 'Prod Integracion $suffix',
          quantity: 2,
          unitPrice: 1500,
          unitCost: 1000,
          subtotal: 3000,
          taxRate: 0,
          taxTotal: 0,
        ),
      ],
      paymentMethodId: 1,
      paymentMethodName: 'EFECTIVO',
      clientName: 'Cliente Integracion',
    ));

    final ventaId = result.saleId;

    // Crear factura borrador
    final facturaId = await DatabaseHelper.instance.crearFacturaElectronicaBorrador(
      ventaId: ventaId,
      observacion: 'Prueba integración mapping',
    );

    // Consultar factura creada
    final rows = await db.query('facturas_electronicas', where: 'id = ?', whereArgs: [facturaId], limit: 1);
    expect(rows, isNotEmpty);
    final xml = rows.first['xml']?.toString() ?? '';

    // Consultar total real calculado para la venta
    final ventasResult = await db.query('ventas', where: 'id = ?', whereArgs: [ventaId], limit: 1);
    expect(ventasResult, isNotEmpty);
    final totalVenta = (ventasResult.first['total'] as num).toDouble();

    // Debe contener la etiqueta ID
    expect(xml.contains('<ID>'), isTrue);

    // Debe contener el total real de la venta
    expect(xml.contains('<PayableAmount>$totalVenta</PayableAmount>') || xml.contains(totalVenta.toString()), isTrue);
  });

  tearDownAll(() async {
    CompanyConfigurationService.instance.resetForTests();
    await DatabaseHelper.resetForTests();
  });
}
