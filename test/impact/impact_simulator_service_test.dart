import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/core/currency/currency.dart';
import 'package:merka_erp/core/currency/money_value.dart';
import 'package:merka_erp/impact/application/impact_simulator_service.dart';
import 'package:merka_erp/impact/database/schema_impact.dart';
import 'package:merka_erp/impact/domain/impact_scenario.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const companyId = 7;
  final currency = Currency(
    code: 'COP',
    name: 'Peso colombiano',
    symbol: r'$',
    decimalPlaces: 2,
  );
  late Database db;
  late ImpactSimulatorService service;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE crm_opportunities (
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        value INTEGER NOT NULL DEFAULT 0,
        amount INTEGER,
        stage TEXT,
        sales_stage TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE empleados (
        id INTEGER PRIMARY KEY,
        company_id INTEGER NOT NULL,
        cargo TEXT,
        salario_base INTEGER,
        activo INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mrp_workstations (
        id INTEGER PRIMARY KEY,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        production_capacity INTEGER NOT NULL,
        hour_rate INTEGER NOT NULL
      )
    ''');
    await SchemaImpact.crearTablas(db);
    await db.insert('crm_opportunities', {
      'id': 'OP-WON',
      'company_id': companyId,
      'value': 100000,
      'amount': 100000,
      'stage': 'closed_won',
      'sales_stage': 'closed_won',
    });
    await db.insert('crm_opportunities', {
      'id': 'OP-OPEN',
      'company_id': companyId,
      'value': 50000,
      'amount': 50000,
      'stage': 'prospecting',
      'sales_stage': 'prospecting',
    });
    await db.insert('empleados', {
      'id': 1,
      'company_id': companyId,
      'cargo': 'Operario',
      'salario_base': 200000,
      'activo': 1,
    });
    await db.insert('empleados', {
      'id': 2,
      'company_id': companyId,
      'cargo': 'Retirado',
      'salario_base': 900000,
      'activo': 0,
    });
    await db.insert('mrp_workstations', {
      'id': 1,
      'company_id': companyId,
      'name': 'Linea A',
      'production_capacity': 4,
      'hour_rate': 5000,
    });
    service = ImpactSimulatorService(
      executor: db,
      companyId: companyId,
      currency: currency,
      clock: () => DateTime.utc(2026, 8, 9, 12),
    );
  });

  tearDown(() => db.close());

  test('calcula el impacto con unidades menores y formula explicita', () async {
    final snapshot = await service.snapshot();
    final result = service.calculate(snapshot: snapshot, upliftPercent: 20);

    expect(snapshot.closedWonValue.minorUnits, 100000);
    expect(snapshot.closedWonCount, 1);
    expect(snapshot.activeHeadcount, 1);
    expect(snapshot.activeBasePayroll.minorUnits, 200000);
    expect(snapshot.workstationCount, 1);
    expect(result.projectedClosedWonValue.minorUnits, 120000);
    expect(result.incrementalDemandProxy.minorUnits, 20000);
    expect(result.capacityStatus, 'capacidad_no_configurada');
    expect(result.formula, contains('valor_ganado_actual'));
    expect(result.warnings, contains(contains('Capacidad no configurada')));
  });

  test('guardar escenario no modifica tablas operativas', () async {
    final beforeOpportunities = await db.query(
      'crm_opportunities',
      orderBy: 'id',
    );
    final beforeEmployees = await db.query('empleados', orderBy: 'id');
    final beforeWorkstations = await db.query(
      'mrp_workstations',
      orderBy: 'id',
    );
    final snapshot = await service.snapshot();
    final result = service.calculate(snapshot: snapshot, upliftPercent: 20);

    final saved = await service.saveScenario(
      name: 'Demanda de agosto',
      snapshot: snapshot,
      result: result,
    );

    expect(saved.id, isNotNull);
    expect(
      await db.query('crm_opportunities', orderBy: 'id'),
      beforeOpportunities,
    );
    expect(await db.query('empleados', orderBy: 'id'), beforeEmployees);
    expect(
      await db.query('mrp_workstations', orderBy: 'id'),
      beforeWorkstations,
    );
    expect((await db.query('impact_scenarios')).length, 1);
  });

  test('el libro conserva formula, snapshot y hash de integridad', () async {
    final snapshot = await service.snapshot();
    final result = service.calculate(snapshot: snapshot, upliftPercent: 20);
    final saved = await service.saveScenario(
      name: 'Escenario reproducible',
      snapshot: snapshot,
      result: result,
    );

    final listed = await service.listScenarios();
    expect(listed, hasLength(1));
    expect(listed.single.id, saved.id);
    expect(listed.single.snapshot.closedWonValue.minorUnits, 100000);
    expect(listed.single.result.projectedClosedWonValue.minorUnits, 120000);
    expect(listed.single.result.formula, saved.result.formula);
    expect(listed.single.integritySha256, hasLength(64));
  });

  test(
    'dos escenarios con el mismo instante y snapshot tienen el mismo hash',
    () async {
      final snapshot = await service.snapshot();
      final result = service.calculate(snapshot: snapshot, upliftPercent: 20);
      final first = ImpactScenario.create(
        companyId: companyId,
        name: 'Mismo escenario',
        createdAt: DateTime.utc(2026, 8, 9, 12),
        snapshot: snapshot,
        result: result,
      );
      final second = ImpactScenario.create(
        companyId: companyId,
        name: 'Mismo escenario',
        createdAt: DateTime.utc(2026, 8, 9, 12),
        snapshot: snapshot,
        result: result,
      );

      expect(second.integritySha256, first.integritySha256);
    },
  );

  test('el calculador rechaza incrementos fuera del rango del control', () {
    final snapshot = ImpactSnapshot(
      companyId: companyId,
      currency: currency,
      closedWonValue: MoneyValue(minorUnits: 100000, currency: currency),
      closedWonCount: 1,
      activeHeadcount: 1,
      activeBasePayroll: MoneyValue(minorUnits: 200000, currency: currency),
      workstationCount: 1,
      capacityConfigured: false,
      capacityNote: 'No configurada',
    );

    expect(
      () => ImpactCalculator.calculate(snapshot: snapshot, upliftPercent: 101),
      throwsArgumentError,
    );
  });
}
