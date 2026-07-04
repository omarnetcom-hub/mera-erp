import '../../core/events/domain_event.dart';

enum LedgerSide { debit, credit }

enum PaymentStatus { scheduled, approved, paid, cancelled }

enum ReconciliationStatus { draft, matched, reconciled, exception }

enum AssetStatus { active, impaired, disposed, transferred }

enum CrmStage { lead, qualified, proposal, won, lost }

enum ReportFormat { pdf, excel, json }

class LedgerEntry {
  const LedgerEntry({
    required this.accountId,
    required this.partyId,
    required this.partyName,
    required this.documentId,
    required this.documentType,
    required this.side,
    required this.amount,
    required this.openAmount,
    required this.dueDate,
    required this.occurredAt,
    this.description = '',
  });

  final int accountId;
  final int partyId;
  final String partyName;
  final String documentId;
  final String documentType;
  final LedgerSide side;
  final double amount;
  final double openAmount;
  final DateTime dueDate;
  final DateTime occurredAt;
  final String description;

  bool get overdue => openAmount > 0 && DateTime.now().isAfter(dueDate);
  int get daysPastDue =>
      overdue ? DateTime.now().difference(dueDate).inDays : 0;

  Map<String, Object?> toMap() => {
    'account_id': accountId,
    'party_id': partyId,
    'party': partyName,
    'document_id': documentId,
    'document_type': documentType,
    'side': side.name,
    'amount': amount,
    'open_amount': openAmount,
    'due_date': dueDate.toIso8601String(),
    'occurred_at': occurredAt.toIso8601String(),
    'description': description,
    'overdue': overdue,
    'days_past_due': daysPastDue,
  };
}

class CreditRiskProfile {
  const CreditRiskProfile({
    required this.partyId,
    required this.limit,
    required this.balance,
    required this.riskScore,
    this.blocked = false,
  });

  final int partyId;
  final double limit;
  final double balance;
  final double riskScore;
  final bool blocked;

  bool get overLimit => limit > 0 && balance > limit;
  bool get shouldBlock => blocked || overLimit || riskScore >= 80;

  CreditRiskProfile collect(double amount) {
    return CreditRiskProfile(
      partyId: partyId,
      limit: limit,
      balance: (balance - amount).clamp(0, double.infinity).toDouble(),
      riskScore: riskScore,
      blocked: blocked && balance - amount > limit,
    );
  }

  CreditRiskProfile withBlock(bool value) {
    return CreditRiskProfile(
      partyId: partyId,
      limit: limit,
      balance: balance,
      riskScore: riskScore,
      blocked: value,
    );
  }

  Map<String, Object?> toMap() => {
    'party_id': partyId,
    'limit': limit,
    'balance': balance,
    'risk_score': riskScore,
    'blocked': blocked,
    'over_limit': overLimit,
    'should_block': shouldBlock,
  };
}

class PaymentSchedule {
  const PaymentSchedule({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.amount,
    required this.dueDate,
    this.status = PaymentStatus.scheduled,
    this.sourceDocumentId,
  });

  final String id;
  final int partyId;
  final String partyName;
  final double amount;
  final DateTime dueDate;
  final PaymentStatus status;
  final String? sourceDocumentId;

  PaymentSchedule approve() => _copy(status: PaymentStatus.approved);

  PaymentSchedule pay() => _copy(status: PaymentStatus.paid);

  PaymentSchedule _copy({PaymentStatus? status}) => PaymentSchedule(
    id: id,
    partyId: partyId,
    partyName: partyName,
    amount: amount,
    dueDate: dueDate,
    status: status ?? this.status,
    sourceDocumentId: sourceDocumentId,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'party_id': partyId,
    'party': partyName,
    'amount': amount,
    'due_date': dueDate.toIso8601String(),
    'status': status.name,
    'source_document_id': sourceDocumentId,
  };
}

class TreasuryTransfer {
  const TreasuryTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.requestedBy,
    required this.createdAt,
    this.approved = false,
  });

  final String id;
  final int fromAccountId;
  final int toAccountId;
  final double amount;
  final String requestedBy;
  final DateTime createdAt;
  final bool approved;

  TreasuryTransfer approve() => TreasuryTransfer(
    id: id,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amount: amount,
    requestedBy: requestedBy,
    createdAt: createdAt,
    approved: true,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'from_account_id': fromAccountId,
    'to_account_id': toAccountId,
    'amount': amount,
    'requested_by': requestedBy,
    'created_at': createdAt.toIso8601String(),
    'approved': approved,
  };
}

class TaxRule {
  const TaxRule({
    required this.code,
    required this.country,
    required this.documentType,
    required this.rate,
    this.retentionRate = 0,
    this.exempt = false,
    this.group = 'default',
  });

  final String code;
  final String country;
  final String documentType;
  final double rate;
  final double retentionRate;
  final bool exempt;
  final String group;

  double taxFor(double taxableBase) => exempt ? 0 : taxableBase * rate / 100;

  double retentionFor(double taxableBase) =>
      exempt ? 0 : taxableBase * retentionRate / 100;

  Map<String, Object?> toMap() => {
    'code': code,
    'country': country,
    'document_type': documentType,
    'rate': rate,
    'retention_rate': retentionRate,
    'exempt': exempt,
    'group': group,
  };
}

class TaxCalculation {
  const TaxCalculation({
    required this.documentType,
    required this.documentId,
    required this.taxableBase,
    required this.tax,
    required this.retention,
    required this.ruleCode,
  });

  final String documentType;
  final String documentId;
  final double taxableBase;
  final double tax;
  final double retention;
  final String ruleCode;

  double get total => taxableBase + tax - retention;

  Map<String, Object?> toMap() => {
    'document_type': documentType,
    'document_id': documentId,
    'taxable_base': taxableBase,
    'tax': tax,
    'retention': retention,
    'total': total,
    'rule_code': ruleCode,
  };
}

class FixedAsset {
  const FixedAsset({
    required this.id,
    required this.name,
    required this.cost,
    required this.usefulLifeMonths,
    required this.acquiredAt,
    this.accumulatedDepreciation = 0,
    this.fiscalDepreciation = 0,
    this.status = AssetStatus.active,
  });

  final String id;
  final String name;
  final double cost;
  final int usefulLifeMonths;
  final DateTime acquiredAt;
  final double accumulatedDepreciation;
  final double fiscalDepreciation;
  final AssetStatus status;

  double get monthlyDepreciation =>
      usefulLifeMonths <= 0 ? 0 : cost / usefulLifeMonths;

  double get bookValue => (cost - accumulatedDepreciation).clamp(0, cost);

  FixedAsset depreciate({int months = 1, double fiscalFactor = 1}) {
    final accounting = (accumulatedDepreciation + monthlyDepreciation * months)
        .clamp(0, cost)
        .toDouble();
    final fiscal =
        (fiscalDepreciation + monthlyDepreciation * fiscalFactor * months)
            .clamp(0, cost)
            .toDouble();
    return _copy(
      accumulatedDepreciation: accounting,
      fiscalDepreciation: fiscal,
    );
  }

  FixedAsset impair(double amount) => _copy(
    accumulatedDepreciation: (accumulatedDepreciation + amount)
        .clamp(0, cost)
        .toDouble(),
    status: AssetStatus.impaired,
  );

  FixedAsset dispose() => _copy(status: AssetStatus.disposed);

  FixedAsset transfer() => _copy(status: AssetStatus.transferred);

  FixedAsset _copy({
    double? accumulatedDepreciation,
    double? fiscalDepreciation,
    AssetStatus? status,
  }) => FixedAsset(
    id: id,
    name: name,
    cost: cost,
    usefulLifeMonths: usefulLifeMonths,
    acquiredAt: acquiredAt,
    accumulatedDepreciation:
        accumulatedDepreciation ?? this.accumulatedDepreciation,
    fiscalDepreciation: fiscalDepreciation ?? this.fiscalDepreciation,
    status: status ?? this.status,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'cost': cost,
    'useful_life_months': usefulLifeMonths,
    'acquired_at': acquiredAt.toIso8601String(),
    'monthly_depreciation': monthlyDepreciation,
    'accumulated_depreciation': accumulatedDepreciation,
    'fiscal_depreciation': fiscalDepreciation,
    'book_value': bookValue,
    'status': status.name,
  };
}

class CrmOpportunity {
  const CrmOpportunity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.value,
    required this.stage,
    required this.nextFollowUpAt,
    this.owner = 'local',
  });

  final String id;
  final int customerId;
  final String customerName;
  final double value;
  final CrmStage stage;
  final DateTime nextFollowUpAt;
  final String owner;

  CrmOpportunity moveTo(CrmStage next) => CrmOpportunity(
    id: id,
    customerId: customerId,
    customerName: customerName,
    value: value,
    stage: next,
    nextFollowUpAt: nextFollowUpAt,
    owner: owner,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'customer_id': customerId,
    'customer': customerName,
    'value': value,
    'stage': stage.name,
    'next_follow_up_at': nextFollowUpAt.toIso8601String(),
    'owner': owner,
  };
}

class EnterpriseReportDefinition {
  const EnterpriseReportDefinition({
    required this.id,
    required this.name,
    required this.dataset,
    this.filters = const {},
    this.formats = const [ReportFormat.json],
  });

  final String id;
  final String name;
  final String dataset;
  final Map<String, Object?> filters;
  final List<ReportFormat> formats;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'dataset': dataset,
    'filters': filters,
    'formats': formats.map((format) => format.name).toList(),
  };
}

class InvoicePaidEvent extends IntegrationEvent {
  InvoicePaidEvent({
    required int customerId,
    required double amount,
    required int companyId,
    required int branchId,
    String? correlationId,
  }) : super(
         name: 'InvoicePaidEvent',
         payload: {
           'aggregate_type': 'accounts_receivable',
           'aggregate_id': customerId.toString(),
           'customer_id': customerId,
           'amount': amount,
           'company_id': companyId,
           'branch_id': branchId,
           'correlation_id': correlationId,
         },
       );
}

class CustomerBlockedEvent extends IntegrationEvent {
  CustomerBlockedEvent({
    required int customerId,
    required double balance,
    required int companyId,
    required int branchId,
    String? reason,
  }) : super(
         name: 'CustomerBlockedEvent',
         payload: {
           'aggregate_type': 'customer_credit',
           'aggregate_id': customerId.toString(),
           'customer_id': customerId,
           'balance': balance,
           'company_id': companyId,
           'branch_id': branchId,
           'reason': reason,
         },
       );
}

class TreasuryTransferCreatedEvent extends IntegrationEvent {
  TreasuryTransferCreatedEvent({
    required String transferId,
    required double amount,
    required int companyId,
    required int branchId,
    String? correlationId,
  }) : super(
         name: 'TreasuryTransferCreatedEvent',
         payload: {
           'aggregate_type': 'treasury_transfer',
           'aggregate_id': transferId,
           'transfer_id': transferId,
           'amount': amount,
           'company_id': companyId,
           'branch_id': branchId,
           'correlation_id': correlationId,
         },
       );
}

class BankReconciledEvent extends IntegrationEvent {
  BankReconciledEvent({
    required String reconciliationId,
    required int matched,
    required int companyId,
    required int branchId,
  }) : super(
         name: 'BankReconciledEvent',
         payload: {
           'aggregate_type': 'bank_reconciliation',
           'aggregate_id': reconciliationId,
           'reconciliation_id': reconciliationId,
           'matched': matched,
           'company_id': companyId,
           'branch_id': branchId,
         },
       );
}

class AssetDepreciatedEvent extends IntegrationEvent {
  AssetDepreciatedEvent({
    required String assetId,
    required double depreciation,
    required int companyId,
    required int branchId,
  }) : super(
         name: 'AssetDepreciatedEvent',
         payload: {
           'aggregate_type': 'fixed_asset',
           'aggregate_id': assetId,
           'asset_id': assetId,
           'depreciation': depreciation,
           'company_id': companyId,
           'branch_id': branchId,
         },
       );
}

class ReportGeneratedEvent extends IntegrationEvent {
  ReportGeneratedEvent({
    required String reportRunId,
    required String definitionId,
    required int companyId,
    required int branchId,
  }) : super(
         name: 'ReportGeneratedEvent',
         payload: {
           'aggregate_type': 'report_run',
           'aggregate_id': reportRunId,
           'report_run_id': reportRunId,
           'definition_id': definitionId,
           'company_id': companyId,
           'branch_id': branchId,
         },
       );
}
