import 'package:merka_erp/catalog/application/catalog_service.dart';
import 'package:merka_erp/catalog/domain/master_catalog.dart';
import 'package:merka_erp/commerce/application/payment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentPolicy', () {
    test('asigna compra en efectivo completamente a caja', () {
      final allocation = PaymentPolicy.allocatePurchase(
        total: 100,
        method: 'EFECTIVO',
      );

      expect(allocation.cash, 100);
      expect(allocation.bank, 0);
      expect(allocation.credit, 0);
    });

    test('completa pago mixto parcial con credito automatico', () {
      final allocation = PaymentPolicy.allocatePurchase(
        total: 100,
        method: 'PAGO MIXTO',
        manualCash: 30,
        manualBank: 20,
      );

      expect(allocation.cash, 30);
      expect(allocation.bank, 20);
      expect(allocation.credit, 50);
    });

    test('rechaza pago mixto mayor al total', () {
      expect(
        () => PaymentPolicy.allocatePurchase(
          total: 100,
          method: 'PAGO MIXTO',
          manualCash: 80,
          manualBank: 30,
        ),
        throwsException,
      );
    });
  });

  group('CatalogService', () {
    test('deshabilitar IVA deja solo impuesto exento', () {
      final taxes = CatalogService.instance.taxOptionsFromSettings({
        'vat_enabled': '0',
        'default_tax': '19',
      });

      expect(taxes, hasLength(1));
      expect(taxes.first.rate, 0);
    });

    test('prioriza impuesto por defecto de plantilla', () {
      final taxes = CatalogService.instance.taxOptionsFromSettings({
        'vat_enabled': '1',
        'default_tax': '8',
      });

      expect(taxes.first.rate, 8);
      expect(taxes.map((tax) => tax.rate), containsAll([0, 5, 8, 19]));
    });

    test('respeta catalogo persistente personalizado', () {
      final taxes = CatalogService.instance.taxOptionsFromSettings(
        {'vat_enabled': '1', 'default_tax': '12'},
        baseTaxes: const [
          TaxOption(code: 'EXEMPT', label: 'Exento', rate: 0),
          TaxOption(code: 'IVA_12', label: 'IVA 12%', rate: 12),
        ],
      );

      expect(taxes.first.rate, 12);
      expect(taxes, hasLength(2));
    });
  });
}
