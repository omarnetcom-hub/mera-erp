class TrialBalanceAccount {
  const TrialBalanceAccount({
    required this.accountId,
    required this.code,
    required this.name,
    required this.type,
    required this.nature,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final int accountId;
  final String code;
  final String name;
  final String type;
  final String nature;
  final double debit;
  final double credit;
  final double balance;

  factory TrialBalanceAccount.fromMap(Map<String, dynamic> map) {
    return TrialBalanceAccount(
      accountId: (map['id'] as num?)?.toInt() ?? 0,
      code: map['codigo']?.toString() ?? '',
      name: map['nombre']?.toString() ?? '',
      type: map['tipo']?.toString() ?? '',
      nature: map['naturaleza']?.toString() ?? '',
      debit: (map['debito'] as num?)?.toDouble() ?? 0,
      credit: (map['credito'] as num?)?.toDouble() ?? 0,
      balance: (map['saldo'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, Object?> toMap() => {
    'account_id': accountId,
    'code': code,
    'name': name,
    'type': type,
    'nature': nature,
    'debit': debit,
    'credit': credit,
    'balance': balance,
  };
}

class TrialBalance {
  const TrialBalance({required this.accounts});

  final List<TrialBalanceAccount> accounts;

  double get totalDebit =>
      accounts.fold(0, (sum, account) => sum + account.debit);

  double get totalCredit =>
      accounts.fold(0, (sum, account) => sum + account.credit);

  double get difference => totalDebit - totalCredit;

  bool get balanced => difference.abs() < 0.01;

  Map<String, Object?> toMap() => {
    'accounts': accounts.map((account) => account.toMap()).toList(),
    'summary': {
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'difference': difference,
      'balanced': balanced,
    },
  };
}
