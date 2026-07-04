import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/app_bootstrap.dart';

void main() {
  group('AppBootstrap', () {
    test('debe continuar aunque un paso de arranque falle', () async {
      final result = await AppBootstrap.initialize(
        configureDatabase: () async {
          throw StateError('fallo simulado');
        },
        preloadTheme: () async {},
        startServices: () async {},
      );

      expect(result.ready, isTrue);
      expect(result.errors, isNotEmpty);
    });
  });
}
