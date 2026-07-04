import 'dart:async';

class AppBootstrapResult {
  const AppBootstrapResult({required this.ready, required this.errors});

  final bool ready;
  final List<String> errors;
}

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppBootstrapResult> initialize({
    Future<void> Function()? configureDatabase,
    Future<void> Function()? preloadTheme,
    Future<void> Function()? startServices,
  }) async {
    final errors = <String>[];

    try {
      await configureDatabase?.call();
    } catch (error) {
      errors.add('database:$error');
    }

    try {
      await preloadTheme?.call();
    } catch (error) {
      errors.add('theme:$error');
    }

    try {
      await startServices?.call();
    } catch (error) {
      errors.add('services:$error');
    }

    return AppBootstrapResult(ready: true, errors: errors);
  }
}
