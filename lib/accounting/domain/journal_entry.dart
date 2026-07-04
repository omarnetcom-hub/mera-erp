enum JournalEntryStatus { draft, posted, reversed }

class AccountingDimensionValue {
  const AccountingDimensionValue({
    this.companyId,
    this.branchId,
    this.warehouseId,
    this.costCenterId,
    this.thirdParty,
    this.currency = 'COP',
    this.exchangeRate = 1,
  });

  final int? companyId;
  final int? branchId;
  final int? warehouseId;
  final int? costCenterId;
  final String? thirdParty;
  final String currency;
  final double exchangeRate;

  Map<String, Object?> toMap() => {
    'company_id': companyId,
    'branch_id': branchId,
    'warehouse_id': warehouseId,
    'cost_center_id': costCenterId,
    'third_party': thirdParty,
    'currency': currency,
    'exchange_rate': exchangeRate,
  };
}

class JournalLine {
  const JournalLine({
    required this.accountCode,
    required this.description,
    required this.debit,
    required this.credit,
    this.dimension = const AccountingDimensionValue(),
  });

  final String accountCode;
  final String description;
  final double debit;
  final double credit;
  final AccountingDimensionValue dimension;

  double get localDebit => debit * dimension.exchangeRate;

  double get localCredit => credit * dimension.exchangeRate;

  JournalLine reversed() {
    return JournalLine(
      accountCode: accountCode,
      description: 'Reversion: $description',
      debit: credit,
      credit: debit,
      dimension: dimension,
    );
  }

  Map<String, Object?> toMap() => {
    'account_code': accountCode,
    'description': description,
    'debit': debit,
    'credit': credit,
    'local_debit': localDebit,
    'local_credit': localCredit,
    'dimension': dimension.toMap(),
  };
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.consecutive,
    required this.date,
    required this.concept,
    required this.reference,
    required this.origin,
    required this.lines,
    this.status = JournalEntryStatus.draft,
    this.reversedEntryId,
    this.correlationId,
  });

  final String id;
  final String consecutive;
  final DateTime date;
  final String concept;
  final String reference;
  final String origin;
  final List<JournalLine> lines;
  final JournalEntryStatus status;
  final String? reversedEntryId;
  final String? correlationId;

  double get totalDebit => lines.fold(0, (sum, line) => sum + line.localDebit);

  double get totalCredit =>
      lines.fold(0, (sum, line) => sum + line.localCredit);

  bool get balanced => (totalDebit - totalCredit).abs() <= 0.01;

  JournalEntry post() {
    if (status != JournalEntryStatus.draft) {
      throw StateError('Solo se pueden contabilizar asientos en borrador.');
    }
    if (lines.length < 2) {
      throw StateError('El asiento debe tener minimo dos lineas.');
    }
    if (!balanced) {
      throw StateError('El asiento no cumple partida doble.');
    }
    return _copy(status: JournalEntryStatus.posted);
  }

  JournalEntry reverse({
    required String reversalId,
    required String reversalConsecutive,
    required DateTime date,
  }) {
    if (status != JournalEntryStatus.posted) {
      throw StateError('Solo se pueden reversar asientos contabilizados.');
    }
    return JournalEntry(
      id: reversalId,
      consecutive: reversalConsecutive,
      date: date,
      concept: 'Reversion de $consecutive',
      reference: reference,
      origin: origin,
      lines: lines.map((line) => line.reversed()).toList(),
      status: JournalEntryStatus.posted,
      reversedEntryId: id,
      correlationId: correlationId,
    );
  }

  JournalEntry _copy({JournalEntryStatus? status}) {
    return JournalEntry(
      id: id,
      consecutive: consecutive,
      date: date,
      concept: concept,
      reference: reference,
      origin: origin,
      lines: lines,
      status: status ?? this.status,
      reversedEntryId: reversedEntryId,
      correlationId: correlationId,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'consecutive': consecutive,
    'date': date.toIso8601String(),
    'concept': concept,
    'reference': reference,
    'origin': origin,
    'status': status.name,
    'reversed_entry_id': reversedEntryId,
    'correlation_id': correlationId,
    'total_debit': totalDebit,
    'total_credit': totalCredit,
    'balanced': balanced,
    'lines': lines.map((line) => line.toMap()).toList(),
  };
}
