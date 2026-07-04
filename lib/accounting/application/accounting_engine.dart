class AccountingLineDraft {
  const AccountingLineDraft({
    required this.accountCode,
    required this.debit,
    required this.credit,
    required this.description,
    this.thirdParty,
  });

  final String accountCode;
  final double debit;
  final double credit;
  final String description;
  final String? thirdParty;

  Map<String, dynamic> toLegacyMap() => {
    'codigo': accountCode,
    'debito': debit,
    'credito': credit,
    'descripcion': description,
    'tercero': thirdParty,
  };
}

class AccountingEntryDraft {
  const AccountingEntryDraft({
    required this.concept,
    required this.reference,
    required this.origin,
    required this.lines,
  });

  final String concept;
  final String reference;
  final String origin;
  final List<AccountingLineDraft> lines;

  List<Map<String, dynamic>> toLegacyLines() =>
      lines.map((line) => line.toLegacyMap()).toList();
}

class AccountingRuleSet {
  const AccountingRuleSet({
    this.cashAccount = '1105',
    this.bankAccount = '1110',
    this.accountsReceivableAccount = '1305',
    this.inventoryAccount = '1435',
    this.taxDeductibleAccount = '1355',
    this.accountsPayableAccount = '2205',
    this.taxPayableAccount = '2408',
    this.salesRevenueAccount = '4135',
    this.operationalExpenseAccount = '5135',
    this.costOfSalesAccount = '6135',
  });

  final String cashAccount;
  final String bankAccount;
  final String accountsReceivableAccount;
  final String inventoryAccount;
  final String taxDeductibleAccount;
  final String accountsPayableAccount;
  final String taxPayableAccount;
  final String salesRevenueAccount;
  final String operationalExpenseAccount;
  final String costOfSalesAccount;

  String moneyAccountForOrigin(String origin) {
    final normalized = origin.toLowerCase().trim();
    if (normalized == 'banco') return bankAccount;
    if (normalized == 'cartera') return accountsReceivableAccount;
    return cashAccount;
  }

  String moneyAccountForPaymentMethod(String method) {
    final normalized = method.toUpperCase().trim();
    if (normalized == 'TRANSFERENCIA' ||
        normalized == 'TARJETA' ||
        normalized == 'NEQUI' ||
        normalized == 'DAVIPLATA') {
      return bankAccount;
    }
    if (normalized == 'CREDITO') return accountsReceivableAccount;
    return cashAccount;
  }
}

class AccountingEngine {
  const AccountingEngine({this.rules = const AccountingRuleSet()});

  final AccountingRuleSet rules;

  AccountingEntryDraft sale({
    required int saleId,
    required double total,
    required double cashPayment,
    required double bankPayment,
    required double credit,
    double costOfSale = 0,
    double tax = 0,
    double retefuente = 0,
    double reteiva = 0,
    double reteica = 0,
    String? client,
  }) {
    final subtotal = total - tax;
    final lines = <AccountingLineDraft>[
      AccountingLineDraft(
        accountCode: rules.salesRevenueAccount,
        debit: 0,
        credit: subtotal,
        description: 'Ingreso por venta #$saleId',
        thirdParty: client,
      ),
    ];

    if (tax > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.taxPayableAccount,
          debit: 0,
          credit: tax,
          description: 'Impuesto generado venta #$saleId',
          thirdParty: client,
        ),
      );
    }

    if (retefuente > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: '135515',
          debit: retefuente,
          credit: 0,
          description: 'Anticipo Retefuente venta #$saleId',
          thirdParty: client,
        ),
      );
    }
    if (reteiva > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: '135517',
          debit: reteiva,
          credit: 0,
          description: 'Anticipo ReteIVA venta #$saleId',
          thirdParty: client,
        ),
      );
    }
    if (reteica > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: '135518',
          debit: reteica,
          credit: 0,
          description: 'Anticipo ReteICA venta #$saleId',
          thirdParty: client,
        ),
      );
    }

    if (cashPayment > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.cashAccount,
          debit: cashPayment,
          credit: 0,
          description: 'Cobro por caja venta #$saleId',
          thirdParty: client,
        ),
      );
    }
    if (bankPayment > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.bankAccount,
          debit: bankPayment,
          credit: 0,
          description: 'Cobro por banco venta #$saleId',
          thirdParty: client,
        ),
      );
    }
    if (credit > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.accountsReceivableAccount,
          debit: credit,
          credit: 0,
          description: 'Cuenta por cobrar venta #$saleId',
          thirdParty: client,
        ),
      );
    }

    if (costOfSale > 0) {
      lines.addAll([
        AccountingLineDraft(
          accountCode: rules.costOfSalesAccount,
          debit: costOfSale,
          credit: 0,
          description: 'Costo de venta #$saleId',
          thirdParty: client,
        ),
        AccountingLineDraft(
          accountCode: rules.inventoryAccount,
          debit: 0,
          credit: costOfSale,
          description: 'Salida de inventario por venta #$saleId',
          thirdParty: client,
        ),
      ]);
    }

    return AccountingEntryDraft(
      concept: 'Venta #$saleId',
      reference: 'VENTA-$saleId',
      origin: 'ventas',
      lines: lines,
    );
  }

  AccountingEntryDraft purchase({
    required int purchaseId,
    required double total,
    required double cashPayment,
    required double bankPayment,
    required double credit,
    String? supplier,
    double tax = 0,
    double retefuente = 0,
    double reteiva = 0,
    double reteica = 0,
  }) {
    final subtotal = total - tax;
    final lines = <AccountingLineDraft>[
      AccountingLineDraft(
        accountCode: rules.inventoryAccount,
        debit: subtotal,
        credit: 0,
        description: 'Compra de inventario #$purchaseId',
        thirdParty: supplier,
      ),
    ];

    if (tax > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.taxDeductibleAccount,
          debit: tax,
          credit: 0,
          description: 'Impuesto descontable compra #$purchaseId',
          thirdParty: supplier,
        ),
      );
    }

    if (retefuente > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: '2365',
          debit: 0,
          credit: retefuente,
          description: 'Retefuente practicada compra #$purchaseId',
          thirdParty: supplier,
        ),
      );
    }
    if (reteiva > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: '2367',
          debit: 0,
          credit: reteiva,
          description: 'ReteIVA practicado compra #$purchaseId',
          thirdParty: supplier,
        ),
      );
    }
    if (reteica > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: '2368',
          debit: 0,
          credit: reteica,
          description: 'ReteICA practicado compra #$purchaseId',
          thirdParty: supplier,
        ),
      );
    }

    if (cashPayment > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.cashAccount,
          debit: 0,
          credit: cashPayment,
          description: 'Pago de compra #$purchaseId por caja',
          thirdParty: supplier,
        ),
      );
    }
    if (bankPayment > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.bankAccount,
          debit: 0,
          credit: bankPayment,
          description: 'Pago de compra #$purchaseId por banco',
          thirdParty: supplier,
        ),
      );
    }
    if (credit > 0) {
      lines.add(
        AccountingLineDraft(
          accountCode: rules.accountsPayableAccount,
          debit: 0,
          credit: credit,
          description: 'Cuenta por pagar compra #$purchaseId',
          thirdParty: supplier,
        ),
      );
    }

    return AccountingEntryDraft(
      concept: 'Compra #$purchaseId',
      reference: 'COMPRA-$purchaseId',
      origin: 'compras',
      lines: lines,
    );
  }
}
