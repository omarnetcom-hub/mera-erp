import 'package:sqflite/sqflite.dart';

import '../../core/currency/currency.dart';
import '../../core/currency/money_currency_resolver.dart';
import '../../core/currency/money_value.dart';
import '../../db_helper.dart';
import '../database/schema_impact.dart';
import '../domain/impact_scenario.dart';

class ImpactSimulatorService {
  ImpactSimulatorService({
    DatabaseExecutor? executor,
    int? companyId,
    Currency? currency,
    DateTime Function()? clock,
  }) : _executor = executor,
       _companyId = companyId,
       _currency = currency,
       _clock = clock ?? DateTime.now;

  final DatabaseExecutor? _executor;
  final int? _companyId;
  final Currency? _currency;
  final DateTime Function() _clock;

  Future<DatabaseExecutor> _db() async =>
      _executor ?? await DatabaseHelper.instance.database;

  Future<int> _company(DatabaseExecutor db) async =>
      _companyId ?? await DatabaseHelper.instance.obtenerEmpresaActivaId(db);

  Future<Currency> _resolvedCurrency(
    DatabaseExecutor db,
    int companyId,
  ) async =>
      _currency ?? MoneyCurrencyResolver.resolve(db, companyId: companyId);

  Future<ImpactSnapshot> snapshot() async {
    final db = await _db();
    final companyId = await _company(db);
    final currency = await _resolvedCurrency(db, companyId);
    final opportunities = await db.rawQuery(
      '''
      SELECT id,
             COALESCE(amount, value, 0) AS amount_minor_units,
             COALESCE(NULLIF(sales_stage, ''), stage, 'prospecting') AS sales_stage
      FROM crm_opportunities
      WHERE company_id = ?
    ''',
      [companyId],
    );
    final won = opportunities.where(
      (row) => row['sales_stage']?.toString() == 'closed_won',
    );
    final closedWonValue = won.fold<int>(
      0,
      (sum, row) => sum + _integer(row['amount_minor_units']),
    );
    final employees = await db.rawQuery(
      '''
      SELECT id, cargo, salario_base
      FROM empleados
      WHERE company_id = ? AND activo = 1
    ''',
      [companyId],
    );
    final workstations = await db.query(
      'mrp_workstations',
      columns: [
        'id',
        'name',
        'production_capacity',
        'available_hours_per_day',
        'status',
      ],
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
    final productionWorkstations = workstations
        .where((row) => row['status']?.toString() == 'produccion')
        .toList();
    final configuredWorkstations = productionWorkstations.where((row) {
      final hours = (row['available_hours_per_day'] as num?)?.toDouble();
      return hours != null && hours > 0;
    }).toList();
    final availableHoursPerDay = configuredWorkstations.fold<double>(
      0,
      (sum, row) =>
          sum + ((row['available_hours_per_day'] as num?)?.toDouble() ?? 0),
    );
    final capacityConfigured =
        productionWorkstations.isNotEmpty &&
        configuredWorkstations.length == productionWorkstations.length;
    return ImpactSnapshot(
      companyId: companyId,
      currency: currency,
      closedWonValue: MoneyValue(
        minorUnits: closedWonValue,
        currency: currency,
      ),
      closedWonCount: won.length,
      activeHeadcount: employees.length,
      activeBasePayroll: MoneyValue(
        minorUnits: employees.fold<int>(
          0,
          (sum, row) => sum + _integer(row['salario_base']),
        ),
        currency: currency,
      ),
      workstationCount: workstations.length,
      configuredWorkstationCount: configuredWorkstations.length,
      availableHoursPerDay: availableHoursPerDay,
      capacityConfigured: capacityConfigured,
      capacityNote: capacityConfigured
          ? 'Capacidad configurada: ${availableHoursPerDay.toStringAsFixed(2)} horas por dia '
                'en ${configuredWorkstations.length} workstations de produccion.'
          : configuredWorkstations.isEmpty
          ? 'Capacidad temporal no configurada. production_capacity no representa horas disponibles.'
          : 'Capacidad parcial: ${availableHoursPerDay.toStringAsFixed(2)} horas por dia '
                'en ${configuredWorkstations.length} de ${productionWorkstations.length} workstations de produccion.',
    );
  }

  ImpactResult calculate({
    required ImpactSnapshot snapshot,
    required int upliftPercent,
  }) => ImpactCalculator.calculate(
    snapshot: snapshot,
    upliftPercent: upliftPercent,
  );

  Future<ImpactScenario> saveScenario({
    required String name,
    required ImpactSnapshot snapshot,
    required ImpactResult result,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('El escenario requiere un nombre.');
    }
    final db = await _db();
    await SchemaImpact.crearTablas(db);
    final scenario = ImpactScenario.create(
      companyId: snapshot.companyId,
      name: name.trim(),
      createdAt: _clock(),
      snapshot: snapshot,
      result: result,
    );
    final id = await db.insert('impact_scenarios', scenario.toInsertMap());
    return ImpactScenario(
      id: id,
      companyId: scenario.companyId,
      name: scenario.name,
      createdAt: scenario.createdAt,
      upliftPercent: scenario.upliftPercent,
      snapshot: scenario.snapshot,
      result: scenario.result,
      integritySha256: scenario.integritySha256,
    );
  }

  Future<List<ImpactScenario>> listScenarios() async {
    final db = await _db();
    final companyId = await _company(db);
    final currency = await _resolvedCurrency(db, companyId);
    await SchemaImpact.crearTablas(db);
    final rows = await db.query(
      'impact_scenarios',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows
        .map((row) => ImpactScenario.fromRow(row, currency: currency))
        .toList();
  }

  int _integer(Object? value) => (value as num?)?.toInt() ?? 0;
}
