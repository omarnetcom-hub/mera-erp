/// Pruebas unitarias del camino normativo duro - Fase 6: Nómina Pública + PILA + Retroactivos
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/sector_publico/nomina/services/nomina_service.dart';

void main() {
  late NominaService nominaService;

  setUp(() {
    nominaService = NominaService();
  });

  group('Validaciones Normativas Duras - Fase 6', () {
    test('Debe calcular aporte de Salud 8.5%', () {
      // Arrange
      final salario = 2000000; // $2,000,000

      // Act
      final aporteSalud = nominaService.calcularAporteSalud(salario: salario);

      // Assert - 8.5% del salario
      expect(aporteSalud, equals(salario * 0.085));
    });

    test('Debe calcular aporte de Pensión 12%', () {
      // Arrange
      final salario = 2000000; // $2,000,000

      // Act
      final aportePension = nominaService.calcularAportePension(salario: salario);

      // Assert - 12% del salario
      expect(aportePension, equals(salario * 0.12));
    });

    test('Debe calcular Fondo Solidaridad 1% para salarios ≥ 4 SMMLV', () {
      // Arrange
      final smmlv = 908526; // SMMLV 2024
      final salario = 4 * smmlv; // 4 SMMLV

      // Act
      final fondoSolidaridad = nominaService.calcularFondoSolidaridad(salario: salario, smmlv: smmlv);

      // Assert - 1% del salario
      expect(fondoSolidaridad, equals(salario * 0.01));
    });

    test('Debe calcular Fondo Solidaridad 2% para salarios ≥ 16 SMMLV', () {
      // Arrange
      final smmlv = 908526; // SMMLV 2024
      final salario = 16 * smmlv; // 16 SMMLV

      // Act
      final fondoSolidaridad = nominaService.calcularFondoSolidaridad(salario: salario, smmlv: smmlv);

      // Assert - 2% del salario
      expect(fondoSolidaridad, equals(salario * 0.02));
    });

    test('NO debe calcular Fondo Solidaridad para salarios < 4 SMMLV', () {
      // Arrange
      final smmlv = 908526; // SMMLV 2024
      final salario = 3 * smmlv; // 3 SMMLV

      // Act
      final fondoSolidaridad = nominaService.calcularFondoSolidaridad(salario: salario, smmlv: smmlv);

      // Assert - 0%
      expect(fondoSolidaridad, equals(0));
    });

    test('Debe calcular aporte Riesgos Laborales 0.522%', () {
      // Arrange
      final salario = 2000000; // $2,000,000

      // Act
      final aporteRiesgos = nominaService.calcularAporteRiesgos(salario: salario);

      // Assert - 0.522% del salario
      expect(aporteRiesgos, closeTo(salario * 0.00522, 0.01));
    });

    test('Debe calcular aporte Caja 4%', () {
      // Arrange
      final salario = 2000000; // $2,000,000

      // Act
      final aporteCaja = nominaService.calcularAporteCaja(salario: salario);

      // Assert - 4% del salario
      expect(aporteCaja, equals(salario * 0.04));
    });

    test('Debe calcular aporte SENA 2%', () {
      // Arrange
      final salario = 2000000; // $2,000,000

      // Act
      final aporteSena = nominaService.calcularAporteSena(salario: salario);

      // Assert - 2% del salario
      expect(aporteSena, equals(salario * 0.02));
    });

    test('Debe calcular aporte ICBF 3%', () {
      // Arrange
      final salario = 2000000; // $2,000,000

      // Act
      final aporteICBF = nominaService.calcularAporteICBF(salario: salario);

      // Assert - 3% del salario
      expect(aporteICBF, equals(salario * 0.03));
    });

    test('Debe calcular auxilio de transporte hasta 2 SMMLV', () {
      // Arrange
      final smmlv = 908526; // SMMLV 2024
      final salario = 1000000; // Menos de 2 SMMLV

      // Act
      final auxilioTransporte = nominaService.calcularAuxilioTransporte(
        salario: salario,
        smmlv: smmlv,
      );

      // Assert - Auxilio completo (2 SMMLV)
      expect(auxilioTransporte, equals(2 * smmlv));
    });

    test('NO debe pagar auxilio de transporte si salario ≥ 2 SMMLV', () {
      // Arrange
      final smmlv = 908526; // SMMLV 2024
      final salario = 3 * smmlv; // Más de 2 SMMLV

      // Act
      final auxilioTransporte = nominaService.calcularAuxilioTransporte(
        salario: salario,
        smmlv: smmlv,
      );

      // Assert - 0
      expect(auxilioTransporte, equals(0));
    });

    test('NO debe aprobar retroactivo sin acto administrativo', () {
      // Arrange
      final retroactivoId = 'retroactivo-001';
      final actoAdministrativo = null; // Sin acto administrativo

      // Act & Assert
      expect(
        () => nominaService.aprobarRetroactivo(
          retroactivoId: retroactivoId,
          actoAdministrativo: actoAdministrativo,
        ),
        throwsException,
      );
    });
  });
}
