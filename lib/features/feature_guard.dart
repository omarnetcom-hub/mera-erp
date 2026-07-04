import '../app_session.dart';
import 'company_configuration_service.dart';

class FeatureGuard {
  const FeatureGuard._();

  static bool canOpen({
    required String permissionLabel,
    String? featureKey,
    bool requiresAdmin = false,
  }) {
    if (requiresAdmin && !AppSession.puedeAdministrar()) return false;
    if (!AppSession.puedeAbrir(permissionLabel)) return false;
    if (featureKey == null) return true;
    return CompanyConfigurationService.instance.featureEnabledSync(featureKey);
  }

  static Future<void> requireFeature(String featureKey) async {
    final enabled = await CompanyConfigurationService.instance.featureEnabled(
      featureKey,
    );
    if (!enabled) {
      throw Exception(
        'Esta funcion no esta habilitada para la empresa activa.',
      );
    }
  }
}
