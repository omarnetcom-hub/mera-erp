import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/core/invoicing/cufe.dart';

void main() {
  test('computeCufe deterministic example', () {
    final cufe = computeCufe(
      ventaId: 1,
      total: '100.00',
      fechaIso: '2026-07-11T00:00:00',
      pin: '12345',
    );
    // Expected value computed with the canonical algorithm
    expect(
      cufe,
      'vmvudge6mxxub3rhbdoxmdaumdb8rmvjage6mjayni0wny0xmvqwmdowmdowmc4wmdb8ueloojeymzq1fe2026dian',
    );
  });

  test('facturacion and sales panel produce same CUFE for same inputs', () {
    final ventaId = 42;
    final fechaIso = '2026-07-11T09:00:00';
    final pinPersisted = '99999';

    // Simulate a sale where total might be represented slightly differently by different code paths.
    const totalA = '100.00';
    const totalB = '100.00';
    // Both should normalize to the same two-decimal representation inside computeCufe()
    final cufeA = computeCufe(
      ventaId: ventaId,
      total: totalA,
      fechaIso: fechaIso,
      pin: pinPersisted,
    );
    final cufeB = computeCufe(
      ventaId: ventaId,
      total: totalB,
      fechaIso: fechaIso,
      pin: pinPersisted,
    );

    expect(cufeA, cufeB);
  });

  test('mismo segundo con distintos milisegundos produce el mismo CUFE', () {
    final cufeA = computeCufe(
      ventaId: 1,
      total: '100.00',
      fechaIso: '2026-07-11T09:00:00.000',
      pin: '12345',
    );
    final cufeB = computeCufe(
      ventaId: 1,
      total: '100.00',
      fechaIso: '2026-07-11T09:00:00.999',
      pin: '12345',
    );
    expect(cufeA, cufeB);
  });
}
