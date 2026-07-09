/// Pruebas unitarias del camino normativo duro - Fase 4: Rentas (Intereses Moratorios)
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/sector_publico/rentas/services/intereses_moratorios_service.dart';

void main() {
  late InteresesMoratoriosService interesesService;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'SOCRATA_APP_TOKEN=token\nSOCRATA_AUTH_HEADER=header');
  });

  setUp(() {
    interesesService = InteresesMoratoriosService();
  });

  group('Validaciones Normativas Duras - Fase 4', () {
    test('Cálculo de intereses de mora según fórmula I = K × T × t', () {
      final capital = 1000000.0;
      final diasMora = 30;

      final intereses = interesesService.calcularInteresesMora(
        capital: capital,
        diasMora: diasMora,
      );

      final tasaMoraDiaria = interesesService.tasaMoraMensual / 30;
      final esperado = capital * tasaMoraDiaria * diasMora;

      expect(intereses, closeTo(esperado, 0.01));
    });

    test('Debe calcular intereses de mora con fecha de vencimiento específica', () {
      final capital = 1000000.0;
      final fechaVencimiento = DateTime(2024, 1, 1);
      final fechaCalculo = DateTime(2024, 1, 31);

      final intereses = interesesService.calcularInteresesMoraConFecha(
        capital: capital,
        fechaVencimiento: fechaVencimiento,
        fechaCalculo: fechaCalculo,
      );

      final diasMora = fechaCalculo.difference(fechaVencimiento).inDays;
      final tasaMoraDiaria = interesesService.tasaMoraMensual / 30;
      final esperado = capital * tasaMoraDiaria * diasMora;

      expect(intereses, closeTo(esperado, 0.01));
    });
  });
}
