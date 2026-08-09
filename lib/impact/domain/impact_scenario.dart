import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/currency/currency.dart';
import '../../core/currency/money_value.dart';

class ImpactSnapshot {
  const ImpactSnapshot({
    required this.companyId,
    required this.currency,
    required this.closedWonValue,
    required this.closedWonCount,
    required this.activeHeadcount,
    required this.activeBasePayroll,
    required this.workstationCount,
    required this.capacityConfigured,
    required this.capacityNote,
  });

  final int companyId;
  final Currency currency;
  final MoneyValue closedWonValue;
  final int closedWonCount;
  final int activeHeadcount;
  final MoneyValue activeBasePayroll;
  final int workstationCount;
  final bool capacityConfigured;
  final String capacityNote;

  Map<String, dynamic> toJson() => {
    'company_id': companyId,
    'currency': currency.code,
    'closed_won_value': closedWonValue.toWireMap(),
    'closed_won_count': closedWonCount,
    'active_headcount': activeHeadcount,
    'active_base_payroll': activeBasePayroll.toWireMap(),
    'workstation_count': workstationCount,
    'capacity_configured': capacityConfigured,
    'capacity_note': capacityNote,
  };
}

class ImpactResult {
  const ImpactResult({
    required this.upliftPercent,
    required this.baselineClosedWonValue,
    required this.projectedClosedWonValue,
    required this.incrementalDemandProxy,
    required this.capacityStatus,
    required this.formula,
    required this.warnings,
  });

  final int upliftPercent;
  final MoneyValue baselineClosedWonValue;
  final MoneyValue projectedClosedWonValue;
  final MoneyValue incrementalDemandProxy;
  final String capacityStatus;
  final String formula;
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'uplift_percent': upliftPercent,
    'baseline_closed_won_value': baselineClosedWonValue.toWireMap(),
    'projected_closed_won_value': projectedClosedWonValue.toWireMap(),
    'incremental_demand_proxy': incrementalDemandProxy.toWireMap(),
    'capacity_status': capacityStatus,
    'formula': formula,
    'warnings': warnings,
  };
}

class ImpactCalculator {
  const ImpactCalculator._();

  /// Uses exact minor-unit arithmetic. It deliberately does not convert
  /// revenue into production units because no opportunity-to-item/quantity
  /// relation exists in the current CRM schema.
  static ImpactResult calculate({
    required ImpactSnapshot snapshot,
    required int upliftPercent,
  }) {
    if (upliftPercent < 0 || upliftPercent > 100) {
      throw ArgumentError('El incremento debe estar entre 0% y 100%.');
    }
    final projected = snapshot.closedWonValue.multiplyRatio(
      numerator: 100 + upliftPercent,
      denominator: 100,
    );
    return ImpactResult(
      upliftPercent: upliftPercent,
      baselineClosedWonValue: snapshot.closedWonValue,
      projectedClosedWonValue: projected,
      incrementalDemandProxy: projected - snapshot.closedWonValue,
      capacityStatus: snapshot.capacityConfigured
          ? 'configurada_sin_modelo_de_demanda_por_unidad'
          : 'capacidad_no_configurada',
      formula:
          'valor_ganado_proyectado = valor_ganado_actual * '
          '(1 + uplift_percent / 100); demanda MRP = proxy monetaria; '
          'no se convierten ingresos a unidades sin producto/cantidad.',
      warnings: snapshot.capacityConfigured
          ? const [
              'La capacidad horaria existe, pero la demanda por unidad aún no está vinculada a CRM.',
            ]
          : const [
              'Capacidad no configurada: production_capacity no representa horas disponibles.',
              'No existe vínculo oportunidad-producto/cantidad para calcular unidades MRP.',
            ],
    );
  }
}

class ImpactScenario {
  const ImpactScenario({
    this.id,
    required this.companyId,
    required this.name,
    required this.createdAt,
    required this.upliftPercent,
    required this.snapshot,
    required this.result,
    required this.integritySha256,
  });

  final int? id;
  final int companyId;
  final String name;
  final DateTime createdAt;
  final int upliftPercent;
  final ImpactSnapshot snapshot;
  final ImpactResult result;
  final String integritySha256;

  factory ImpactScenario.create({
    required int companyId,
    required String name,
    required DateTime createdAt,
    required ImpactSnapshot snapshot,
    required ImpactResult result,
  }) {
    final base = {
      'company_id': companyId,
      'name': name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'uplift_percent': result.upliftPercent,
      'snapshot': snapshot.toJson(),
      'result': result.toJson(),
      'formula': result.formula,
    };
    final hash = sha256.convert(utf8.encode(jsonEncode(base))).toString();
    return ImpactScenario(
      companyId: companyId,
      name: name,
      createdAt: createdAt,
      upliftPercent: result.upliftPercent,
      snapshot: snapshot,
      result: result,
      integritySha256: hash,
    );
  }

  Map<String, Object?> toInsertMap() => {
    'company_id': companyId,
    'name': name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'uplift_percent': upliftPercent,
    'input_json': jsonEncode({'uplift_percent': upliftPercent}),
    'snapshot_json': jsonEncode(snapshot.toJson()),
    'result_json': jsonEncode(result.toJson()),
    'formula': result.formula,
    'integrity_sha256': integritySha256,
  };

  factory ImpactScenario.fromRow(
    Map<String, dynamic> row, {
    required Currency currency,
  }) {
    final snapshot = jsonDecode(row['snapshot_json'].toString());
    final result = jsonDecode(row['result_json'].toString());
    return ImpactScenario(
      id: (row['id'] as num?)?.toInt(),
      companyId: (row['company_id'] as num).toInt(),
      name: row['name'].toString(),
      createdAt: DateTime.parse(row['created_at'].toString()),
      upliftPercent: (row['uplift_percent'] as num).toInt(),
      snapshot: _snapshotFromJson(snapshot, currency),
      result: _resultFromJson(result, currency),
      integritySha256: row['integrity_sha256'].toString(),
    );
  }
}

ImpactSnapshot _snapshotFromJson(
  Map<String, dynamic> json,
  Currency currency,
) => ImpactSnapshot(
  companyId: (json['company_id'] as num).toInt(),
  currency: currency,
  closedWonValue: MoneyValue.fromSql(
    (json['closed_won_value']['minor_units'] as num).toInt(),
    currency: currency,
  ),
  closedWonCount: (json['closed_won_count'] as num).toInt(),
  activeHeadcount: (json['active_headcount'] as num).toInt(),
  activeBasePayroll: MoneyValue.fromSql(
    (json['active_base_payroll']['minor_units'] as num).toInt(),
    currency: currency,
  ),
  workstationCount: (json['workstation_count'] as num).toInt(),
  capacityConfigured: json['capacity_configured'] == true,
  capacityNote: json['capacity_note'].toString(),
);

ImpactResult _resultFromJson(Map<String, dynamic> json, Currency currency) =>
    ImpactResult(
      upliftPercent: (json['uplift_percent'] as num).toInt(),
      baselineClosedWonValue: MoneyValue.fromSql(
        (json['baseline_closed_won_value']['minor_units'] as num).toInt(),
        currency: currency,
      ),
      projectedClosedWonValue: MoneyValue.fromSql(
        (json['projected_closed_won_value']['minor_units'] as num).toInt(),
        currency: currency,
      ),
      incrementalDemandProxy: MoneyValue.fromSql(
        (json['incremental_demand_proxy']['minor_units'] as num).toInt(),
        currency: currency,
      ),
      capacityStatus: json['capacity_status'].toString(),
      formula: json['formula'].toString(),
      warnings: (json['warnings'] as List).cast<String>(),
    );
