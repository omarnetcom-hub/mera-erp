import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/features/company_configuration_service.dart';
import 'package:merka_erp/services/enterprise_operations_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dbDir;
  late Database db;
  late int companyId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.resetForTests();
    CompanyConfigurationService.instance.resetForTests();
    dbDir = await Directory.systemTemp.createTemp('merka_ops_db_');
    await databaseFactory.setDatabasesPath(dbDir.path);
    db = await DatabaseHelper.instance.database;
    companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
  });

  tearDownAll(() async {
    CompanyConfigurationService.instance.resetForTests();
    await DatabaseHelper.resetForTests();
    if (await dbDir.exists()) {
      await dbDir.delete(recursive: true);
    }
  });

  test(
    'apertura y cierre de caja exige justificacion para diferencias',
    () async {
      final service = EnterpriseOperationsService();
      final sessionId = await service.abrirCaja(
        usuario: 'admin',
        montoInicial: 0,
      );
      await db.insert('movimientos_caja', {
        'company_id': companyId,
        'tipo': 'ingreso',
        'concepto': 'Prueba',
        'monto': 100,
        'fecha': DateTime.now().toIso8601String(),
        'origen': 'caja',
      });

      expect(
        () => service.cerrarCaja(
          sesionId: sessionId,
          montoContado: 90,
          justificacion: '',
        ),
        throwsStateError,
      );

      await service.cerrarCaja(
        sesionId: sessionId,
        montoContado: 90,
        justificacion: 'Diferencia de prueba',
      );
      final rows = await db.query(
        'caja_sesiones',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      expect(rows.first['estado'], 'cerrada');
    },
  );

  test('traslado entre bodegas y cambio de precio quedan auditables', () async {
    final service = EnterpriseOperationsService();
    final productId = await db.insert('productos', {
      'company_id': companyId,
      'nombre': 'Producto bodega QA',
      'unidad_base': 'unid.',
      'stock': 10,
      'costo': 50,
      'precio': 100,
      'impuesto_pct': 0,
      'codigo_barras': 'BOD-QA',
    });
    await db.insert('bodegas', {
      'company_id': companyId,
      'codigo': 'B1',
      'nombre': 'Bodega 1',
      'activa': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('bodegas', {
      'company_id': companyId,
      'codigo': 'B2',
      'nombre': 'Bodega 2',
      'activa': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('stock_bodega', {
      'company_id': companyId,
      'producto_id': productId,
      'bodega_id': 1,
      'cantidad': 10,
      'costo': 50,
      'actualizado_en': DateTime.now().toIso8601String(),
    });

    final transferId = await service.trasladarBodega(
      productoId: productId,
      origenId: 1,
      destinoId: 2,
      cantidad: 3,
    );
    expect(transferId, greaterThan(0));

    final priceId = await service.registrarCambioPrecio(
      productoId: productId,
      precioAnterior: 100,
      precioNuevo: 120,
      usuario: 'admin',
    );
    expect(priceId, greaterThan(0));
  });
}
