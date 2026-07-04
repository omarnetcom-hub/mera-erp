import 'accounting_engine.dart';

enum AccountingBasis { accrual }

class AccountingDimension {
  const AccountingDimension({
    this.costCenter,
    this.branch,
    this.project,
    this.thirdParty,
  });

  final String? costCenter;
  final String? branch;
  final String? project;
  final String? thirdParty;

  bool get hasOperationalDimension =>
      (costCenter?.trim().isNotEmpty ?? false) ||
      (branch?.trim().isNotEmpty ?? false) ||
      (project?.trim().isNotEmpty ?? false);

  Map<String, Object?> toMap() => {
    'cost_center': costCenter,
    'branch': branch,
    'project': project,
    'third_party': thirdParty,
  };
}

class AccountingPolicyFinding {
  const AccountingPolicyFinding({
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final String code;
  final String message;
  final bool blocking;

  Map<String, Object?> toMap() => {
    'code': code,
    'message': message,
    'blocking': blocking,
  };
}

class AccountingPolicyValidation {
  const AccountingPolicyValidation(this.findings);

  final List<AccountingPolicyFinding> findings;

  bool get valid => findings.where((finding) => finding.blocking).isEmpty;

  Map<String, Object?> toMap() => {
    'valid': valid,
    'findings': findings.map((finding) => finding.toMap()).toList(),
  };
}

class EnterpriseAccountingPolicy {
  const EnterpriseAccountingPolicy({
    this.basis = AccountingBasis.accrual,
    this.requireBalancedEntries = true,
    this.requireThirdPartyForReceivablesAndPayables = true,
    this.recommendOperationalDimensions = true,
  });

  final AccountingBasis basis;
  final bool requireBalancedEntries;
  final bool requireThirdPartyForReceivablesAndPayables;
  final bool recommendOperationalDimensions;

  AccountingPolicyValidation validateEntry(
    AccountingEntryDraft entry, {
    AccountingDimension dimension = const AccountingDimension(),
  }) {
    final findings = <AccountingPolicyFinding>[];
    final debit = entry.lines.fold<double>(0, (sum, line) => sum + line.debit);
    final credit = entry.lines.fold<double>(
      0,
      (sum, line) => sum + line.credit,
    );

    if (entry.lines.length < 2) {
      findings.add(
        const AccountingPolicyFinding(
          code: 'entry_minimum_lines',
          message: 'Un asiento empresarial debe tener al menos dos lineas.',
        ),
      );
    }
    if (requireBalancedEntries && (debit - credit).abs() > 0.01) {
      findings.add(
        AccountingPolicyFinding(
          code: 'entry_unbalanced',
          message:
              'El asiento no cuadra: debito $debit contra credito $credit.',
        ),
      );
    }

    for (final line in entry.lines) {
      if (line.debit < 0 || line.credit < 0) {
        findings.add(
          AccountingPolicyFinding(
            code: 'negative_line',
            message:
                'La cuenta ${line.accountCode} tiene debitos o creditos negativos.',
          ),
        );
      }
      if (line.debit == 0 && line.credit == 0) {
        findings.add(
          AccountingPolicyFinding(
            code: 'empty_line',
            message: 'La cuenta ${line.accountCode} no tiene movimiento.',
          ),
        );
      }
      if (_requiresThirdParty(line.accountCode) &&
          requireThirdPartyForReceivablesAndPayables &&
          ((line.thirdParty ?? dimension.thirdParty)?.trim().isEmpty ?? true)) {
        findings.add(
          AccountingPolicyFinding(
            code: 'third_party_required',
            message:
                'La cuenta ${line.accountCode} requiere tercero para trazabilidad NIIF.',
          ),
        );
      }
    }

    if (recommendOperationalDimensions && !dimension.hasOperationalDimension) {
      findings.add(
        const AccountingPolicyFinding(
          code: 'dimension_recommended',
          message:
              'Agrega centro de costo, sede o proyecto para analitica empresarial.',
          blocking: false,
        ),
      );
    }

    return AccountingPolicyValidation(findings);
  }

  Map<String, Object?> toMap() => {
    'basis': basis.name,
    'require_balanced_entries': requireBalancedEntries,
    'require_third_party_receivable_payable':
        requireThirdPartyForReceivablesAndPayables,
    'recommend_operational_dimensions': recommendOperationalDimensions,
  };

  bool _requiresThirdParty(String accountCode) {
    return accountCode.startsWith('13') ||
        accountCode.startsWith('22') ||
        accountCode.startsWith('23') ||
        accountCode.startsWith('24');
  }
}
