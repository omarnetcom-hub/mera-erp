import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/features/company_configuration_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late final Directory dbDir;
  late final Database db;
  late final int companyId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.resetForTests();
    CompanyConfigurationService.instance.resetForTests();
    dbDir = await Directory.systemTemp.createTemp(
      'merkaerp_fiscal_payroll_db_',
    );
    await databaseFactory.setDatabasesPath(dbDir.path);
    db = await DatabaseHelper.instance.database;
    companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
  });

  tearDownAll(() async {
    CompanyConfigurationService.instance.resetForTests();
    await DatabaseHelper.resetForTests();
    await dbDir.delete(recursive: true);
  });

  test(
    'obtenerReporteFiscal suma neto_pagar de una liquidacion real',
    () async {
      final now = DateTime.now();
      await db.insert('payroll_parameters', {
        'company_id': companyId,
        'year': now.year,
        'smmlv': 1423500,
        'uvt': 52374,
        'transportation_allowance': 0,
        'created_at': now.toIso8601String(),
      });

      for (final account in const [
        ('510506', 'Sueldos', 'gasto', 'debito'),
        ('237005', 'Aportes salud', 'pasivo', 'credito'),
        ('238030', 'Aportes pension', 'pasivo', 'credito'),
        ('110505', 'Caja general', 'activo', 'debito'),
      ]) {
        await db.insert('cuentas_contables', {
          'company_id': companyId,
          'codigo': account.$1,
          'nombre': account.$2,
          'tipo': account.$3,
          'naturaleza': account.$4,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final employeeId = await DatabaseHelper.instance.guardarEmpleado(
        nombre: 'Empleado reporte fiscal',
        salarioBase: 1000000,
      );
      final payrollId = await DatabaseHelper.instance.liquidarNomina(
        empleadoId: employeeId,
        anio: now.year,
        mes: now.month,
      );

      final payrollRows = await db.query(
        'nomina_liquidaciones',
        columns: ['neto_pagar'],
        where: 'id = ?',
        whereArgs: [payrollId],
      );
      expect((payrollRows.single['neto_pagar'] as num).toDouble(), 920000);

      final report = await DatabaseHelper.instance.obtenerReporteFiscal(
        anio: now.year,
        mes: now.month,
      );
      expect(report['nomina'], 920000);

      final payrollHistory = await DatabaseHelper.instance.obtenerNomina();
      expect(
        payrollHistory.single['periodo'],
        '${now.year}-${now.month.toString().padLeft(2, '0')}',
      );
      expect(
        (payrollHistory.single['total_devengado'] as num).toDouble(),
        1000000,
      );
      expect(
        (payrollHistory.single['total_deducciones'] as num).toDouble(),
        80000,
      );
      expect((payrollHistory.single['neto_pagar'] as num).toDouble(), 920000);
    },
  );
}
