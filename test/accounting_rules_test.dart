import 'package:merka_erp/accounting/application/accounting_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountingEngine configurable', () {
    test('usa cuentas configuradas para venta', () {
      final engine = AccountingEngine(
        rules: const AccountingRuleSet(
          cashAccount: '110505',
          salesRevenueAccount: '413595',
          taxPayableAccount: '240805',
          costOfSalesAccount: '613595',
          inventoryAccount: '143595',
        ),
      );

      final entry = engine.sale(
        saleId: 1,
        total: 119,
        cashPayment: 119,
        bankPayment: 0,
        credit: 0,
        tax: 19,
        costOfSale: 60,
      );

      expect(entry.lines.map((line) => line.accountCode), contains('110505'));
      expect(entry.lines.map((line) => line.accountCode), contains('413595'));
      expect(entry.lines.map((line) => line.accountCode), contains('240805'));
      expect(entry.lines.map((line) => line.accountCode), contains('613595'));
      expect(entry.lines.map((line) => line.accountCode), contains('143595'));
    });

    test('usa cuentas configuradas para compra', () {
      final engine = AccountingEngine(
        rules: const AccountingRuleSet(
          cashAccount: '110505',
          bankAccount: '111005',
          inventoryAccount: '143595',
          taxDeductibleAccount: '135595',
          accountsPayableAccount: '220595',
        ),
      );

      final entry = engine.purchase(
        purchaseId: 2,
        total: 119,
        cashPayment: 50,
        bankPayment: 0,
        credit: 69,
        tax: 19,
      );

      expect(entry.lines.map((line) => line.accountCode), contains('143595'));
      expect(entry.lines.map((line) => line.accountCode), contains('135595'));
      expect(entry.lines.map((line) => line.accountCode), contains('110505'));
      expect(entry.lines.map((line) => line.accountCode), contains('220595'));
    });
  });
}
