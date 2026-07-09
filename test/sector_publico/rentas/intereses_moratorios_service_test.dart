/// Pruebas unitarias del camino normativo duro - Fase 4: Rentas (Intereses Moratorios)
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/sector_publico/rentas/services/intereses_moratorios_service.dart';

void main() {
  late InteresesMoratoriosService interesesService;

  setUp(() {
    interesesService = InteresesMoratoriosService();
  });

  group('Validaciones Normativas Duras - Fase 4', () {
    test('Cálculo de intereses según fórmula I = K × T × t', () {
      // Arrange
      final capital = 1000000; // $1,000,000
      final tasaMora = 0.24; // 24% anual
      final tiempo = 30; // 30 días

      // Act
      final intereses = interesesService.calcularIntereses(
        capital: capital,
        tasaMora: tasaMora,
        diasMora: tiempo,
      );

      // Assert - I = 1,000,000 × 0.24 × (30/365) = 19,726.03
      final esperado = capital * tasaMora * (tiempo / 365);
      expect(intereses, closeTo(esperado, 0.01));
    });

    test('NO debe permitir tope de incremento de avalúo > 50% (general)', () {
      // Arrange
      final avaluoAnterior = 100000000; // $100,000,000
      final avaluoNuevo = 160000000; // $160,000,000 (60% incremento)

      // Act & Assert
      expect(
        () => interesesService.validarTopeIncremento(
          avaluoAnterior: avaluoAnterior,
          avaluoNuevo: avaluoNuevo,
          estrato: 3, // Estrato medio
          zona: 'urbana',
          areaHectareas: 0.5, // Menos de 100ha
        ),
        throwsException,
      );
    });

    test('NO debe permitir tope de incremento de avalúo > 135 SMMLV (estratos 1-2)', () {
      // Arrange
      final smmlv = 908526; // SMMLV 2024
      final avaluoAnterior = 100000000;
      final avaluoNuevo = avaluoAnterior + (135 * smmlv) + 1000; // Excede tope

      // Act & Assert
      expect(
        () => interesesService.validarTopeIncremento(
          avaluoAnterior: avaluoAnterior,
          avaluoNuevo: avaluoNuevo,
          estrato: 1, // Estrato bajo
          zona: 'urbana',
          areaHectareas: 0.5,
        ),
        throwsException,
      );
    });

    test('NO debe permitir tope de incremento de avalúo > 2× año anterior (rural ≥100ha)', () {
      // Arrange
      final avaluoAnterior = 100000000;
      final avaluoNuevo = avaluoAnterior * 2.1; // 210% del año anterior

      // Act & Assert
      expect(
        () => interesesService.validarTopeIncremento(
          avaluoAnterior: avaluoAnterior,
          avaluoNuevo: avaluoNuevo,
          estrato: 0, // Rural
          zona: 'rural',
          areaHectareas: 150, // Más de 100ha
        ),
        throwsException,
      );
    });

    test('Debe permitir descuento por pronto pago hasta 10% en primer trimestre', () {
      // Arrange
      final valorImpuesto = 1000000;
      final fechaLiquidacion = DateTime(2024, 2, 15); // Febrero (primer trimestre)

      // Act
      final descuento = interesesService.calcularDescuentoProntoPago(
        valorImpuesto: valorImpuesto,
        fechaLiquidacion: fechaLiquidacion,
      );

      // Assert - Máximo 10%
      expect(descuento, lessThanOrEqualTo(valorImpuesto * 0.1));
    });

    test('NO debe aplicar descuento por pronto pago fuera del primer trimestre', () {
      // Arrange
      final valorImpuesto = 1000000;
      final fechaLiquidacion = DateTime(2024, 5, 15); // Mayo (segundo trimestre)

      // Act
      final descuento = interesesService.calcularDescuentoProntoPago(
        valorImpuesto: valorImpuesto,
        fechaLiquidacion: fechaLiquidacion,
      );

      // Assert - Sin descuento
      expect(descuento, equals(0));
    });
  });
}
