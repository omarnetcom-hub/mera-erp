import '../domain/journal_entry.dart';

class LedgerAccountBalance {
  const LedgerAccountBalance({
    required this.accountCode,
    required this.debit,
    required this.credit,
  });

  final String accountCode;
  final double debit;
  final double credit;

  double get balance => debit - credit;

  Map<String, Object?> toMap() => {
    'account_code': accountCode,
    'debit': debit,
    'credit': credit,
    'balance': balance,
  };
}

class LedgerTrialBalance {
  const LedgerTrialBalance(this.accounts);

  final List<LedgerAccountBalance> accounts;

  double get totalDebit =>
      accounts.fold(0, (sum, account) => sum + account.debit);

  double get totalCredit =>
      accounts.fold(0, (sum, account) => sum + account.credit);

  bool get balanced => (totalDebit - totalCredit).abs() <= 0.01;

  Map<String, Object?> toMap() => {
    'accounts': accounts.map((account) => account.toMap()).toList(),
    'summary': {
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'balanced': balanced,
    },
  };
}

class LedgerEngine {
  const LedgerEngine();

  JournalEntry post(JournalEntry entry) => entry.post();

  JournalEntry reverse(
    JournalEntry entry, {
    required String reversalId,
    required String reversalConsecutive,
    required DateTime date,
  }) {
    return entry.reverse(
      reversalId: reversalId,
      reversalConsecutive: reversalConsecutive,
      date: date,
    );
  }

  LedgerTrialBalance trialBalance(List<JournalEntry> entries) {
    final totals = <String, ({double debit, double credit})>{};
    for (final entry in entries.where(
      (entry) => entry.status == JournalEntryStatus.posted,
    )) {
      for (final line in entry.lines) {
        final current = totals[line.accountCode] ?? (debit: 0, credit: 0);
        totals[line.accountCode] = (
          debit: current.debit + line.localDebit,
          credit: current.credit + line.localCredit,
        );
      }
    }

    final accounts = [
      for (final entry in totals.entries)
        LedgerAccountBalance(
          accountCode: entry.key,
          debit: entry.value.debit,
          credit: entry.value.credit,
        ),
    ]..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    return LedgerTrialBalance(accounts);
  }
}
