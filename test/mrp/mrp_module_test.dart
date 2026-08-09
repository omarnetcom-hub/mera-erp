import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/core/currency/currency.dart';
import 'package:merka_erp/core/currency/money_value.dart';
import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/mrp/application/mrp_services.dart';
import 'package:merka_erp/mrp/database/schema_mrp.dart';
import 'package:merka_erp/mrp/domain/mrp_bom.dart';
import 'package:merka_erp/mrp/domain/mrp_bom_item.dart';
import 'package:merka_erp/mrp/domain/mrp_operation.dart';
import 'package:merka_erp/mrp/domain/mrp_routing.dart';
import 'package:merka_erp/mrp/domain/mrp_work_order.dart';
import 'package:merka_erp/mrp/domain/mrp_workstation.dart';

void main() {
  late Directory dir;
  late Database db;
  late int companyId;
  late Currency cop;
  late int rawProductId;
  late int finishedProductId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.resetForTests();
    dir = await Directory.systemTemp.createTemp('merkaerp_mrp_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = await DatabaseHelper.instance.database;
    companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    cop = Currency(
      code: 'COP',
      name: 'Peso colombiano',
      symbol: r'$',
      decimalPlaces: 2,
    );
    await SchemaMrp.crearTablas(db);
    rawProductId = await db.insert('productos', {
      'company_id': companyId,
      'nombre': 'Acero MRP',
      'unidad_base': 'KG',
      'stock': 10,
      'costo': 1000,
      'precio': 1000,
      'impuesto_pct': 0,
    });
    finishedProductId = await db.insert('productos', {
      'company_id': companyId,
      'nombre': 'Producto terminado MRP',
      'unidad_base': 'UND',
      'stock': 0,
      'costo': 0,
      'precio': 5000,
      'impuesto_pct': 0,
    });
    for (final warehouseId in [1, 2, 3]) {
      await db.insert('stock_bodega', {
        'company_id': companyId,
        'producto_id': rawProductId,
        'bodega_id': warehouseId,
        'cantidad': warehouseId == 1 ? 10 : 0,
        'costo': 1000,
        'actualizado_en': DateTime.now().toIso8601String(),
      });
      await db.insert('stock_bodega', {
        'company_id': companyId,
        'producto_id': finishedProductId,
        'bodega_id': warehouseId,
        'cantidad': 0,
        'costo': 0,
        'actualizado_en': DateTime.now().toIso8601String(),
      });
    }
  });

  tearDownAll(() async {
    await DatabaseHelper.resetForTests();
    await dir.delete(recursive: true);
  });

  test('MRP crea entidades, calcula costos, explota BOM y mueve stock', () async {
    final workstationId = await MrpWorkstationService().create(
      MrpWorkstation(
        companyId: companyId,
        name: 'Corte',
        hourRate: MoneyValue.fromMajorUnits('10', currency: cop),
        warehouseId: 2,
      ),
    );
    final routingId = await MrpRoutingService().create(
      MrpRouting(companyId: companyId, name: 'Ruta corte'),
    );
    await MrpOperationService().create(
      MrpOperation(
        companyId: companyId,
        routingId: routingId,
        workstationId: workstationId,
        operationName: 'Corte',
        timeMinutes: 60,
      ),
    );
    final bomId = await MrpBomService().create(
      MrpBom(
        companyId: companyId,
        itemId: finishedProductId,
        rawMaterialCost: MoneyValue(minorUnits: 0, currency: cop),
        operatingCost: MoneyValue(minorUnits: 0, currency: cop),
        totalCost: MoneyValue(minorUnits: 0, currency: cop),
        routingId: routingId,
      ),
    );
    await MrpBomService().addItem(
      MrpBomItem(
        companyId: companyId,
        bomId: bomId,
        itemId: rawProductId,
        qty: 2,
        rate: MoneyValue.fromMajorUnits('10', currency: cop),
        amount: MoneyValue.fromMajorUnits('20', currency: cop),
        sourceWarehouseId: 1,
      ),
    );
    final bom = await MrpBomService().recalculate(bomId);
    expect(bom.rawMaterialCost.minorUnits, 2000);
    expect(bom.operatingCost.minorUnits, 1000);
    expect(bom.totalCost.minorUnits, 3000);

    final orderId = await MrpWorkOrderService().create(
      draft: MrpWorkOrder(
        companyId: companyId,
        productionItemId: finishedProductId,
        bomId: bomId,
        qtyPlanned: 1,
        wipWarehouseId: 2,
        fgWarehouseId: 3,
        plannedOperatingCost: bom.operatingCost,
        actualOperatingCost: MoneyValue(minorUnits: 0, currency: cop),
        rawMaterialCost: bom.rawMaterialCost,
        totalCost: bom.totalCost,
      ),
    );
    final orderItems = await MrpWorkOrderService().items(orderId);
    expect(orderItems.single.requiredQty, 2);
    await MrpWorkOrderService().transition(
      orderId,
      MrpWorkOrderStatus.noIniciada,
    );
    await MrpWorkOrderService().transition(
      orderId,
      MrpWorkOrderStatus.enProceso,
    );
    await MrpWorkOrderService().transition(
      orderId,
      MrpWorkOrderStatus.completada,
    );

    final rawAtSource = await db.query(
      'stock_bodega',
      where: 'producto_id = ? AND bodega_id = ?',
      whereArgs: [rawProductId, 1],
    );
    final finishedAtFg = await db.query(
      'stock_bodega',
      where: 'producto_id = ? AND bodega_id = ?',
      whereArgs: [finishedProductId, 3],
    );
    final movementCount = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM movimientos_inventario WHERE motivo LIKE 'MRP WO#%' OR motivo LIKE 'TRASLADO #%'",
    );
    final transferCount = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM traslados_bodega WHERE observacion LIKE 'MRP WO#%'",
    );
    final order = (await MrpWorkOrderService().list()).single;
    expect(rawAtSource.single['cantidad'], 8);
    expect(finishedAtFg.single['cantidad'], 1);
    expect(movementCount.single['total'], 5);
    expect(transferCount.single['total'], 2);
    expect(order.status, MrpWorkOrderStatus.completada);
    expect(order.qtyProduced, 1);
  });

  test('MRP rechaza transiciones de orden no permitidas', () async {
    final boms = await MrpBomService().list();
    final bom = boms.single;
    final orderId = await MrpWorkOrderService().create(
      draft: MrpWorkOrder(
        companyId: companyId,
        productionItemId: finishedProductId,
        bomId: bom.id!,
        qtyPlanned: 1,
        wipWarehouseId: 2,
        fgWarehouseId: 3,
        plannedOperatingCost: bom.operatingCost,
        actualOperatingCost: MoneyValue(minorUnits: 0, currency: cop),
        rawMaterialCost: bom.rawMaterialCost,
        totalCost: bom.totalCost,
      ),
    );
    await expectLater(
      () => MrpWorkOrderService().transition(
        orderId,
        MrpWorkOrderStatus.completada,
      ),
      throwsStateError,
    );
  });
}
