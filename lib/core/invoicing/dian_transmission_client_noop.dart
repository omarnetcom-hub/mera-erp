import 'dian_transmission_client.dart';
import '../../db_helper.dart';

/// No-op implementation of DianTransmissionClient. Reads local DB config
/// and returns honest, simulated responses without performing network I/O.
class NoOpDianTransmissionClient implements DianTransmissionClient {
  /// Optional configuration reader function for testing/injection.
  /// If not provided, falls back to DatabaseHelper.instance.obtenerDianConfig().
  final Future<Map<String, String>> Function()? _configReader;

  NoOpDianTransmissionClient({Future<Map<String, String>> Function()? configReader}) : _configReader = configReader;

  Future<Map<String, String>> _readConfig() async {
    if (_configReader != null) return await _configReader();
    try {
      final cfg = await DatabaseHelper.instance.obtenerDianConfig();
      return cfg;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<ConfigStatus> checkConfiguration() async {
    final cfg = await _readConfig();
    final hasTechKey = (cfg['dian_tech_key'] ?? '').isNotEmpty;
    final hasPin = (cfg['dian_pin'] ?? '').isNotEmpty;
    final hasSoftwareId = (cfg['dian_software_id'] ?? '').isNotEmpty;

    if (hasTechKey && hasPin && hasSoftwareId) return ConfigStatus.configuredComplete;
    if (hasTechKey || hasPin || hasSoftwareId) return ConfigStatus.configuredPartial;
    return ConfigStatus.notConfigured;
  }

  @override
  Future<ConnectionCheckResult> checkConnectivity() async {
    final cfgStatus = await checkConfiguration();
    if (cfgStatus == ConfigStatus.notConfigured) {
      return ConnectionCheckResult(
        status: ConnectivityStatus.notConfigured,
        message: 'Sin configuración DIAN. Guarde configuración en Centro de Facturación.',
      );
    }

    // NoOp cannot establish real connections. Return honest simulated state.
    return ConnectionCheckResult(
      status: ConnectivityStatus.notConnected,
      message: 'NoOp: cliente configurado pero sin conexión real (modo local). Configure proveedor tecnológico autorizado para enviar.',
    );
  }

  @override
  Future<TransmissionResult> transmitInvoice({
    required int ventaId,
    required String xml,
    required String cufe,
    Map<String, dynamic>? metadata,
  }) async {
    final cfgStatus = await checkConfiguration();
    if (cfgStatus == ConfigStatus.notConfigured) {
      return TransmissionResult(
        status: TransmissionStatus.notConfigured,
        message: 'No se ha guardado la configuración DIAN. Guarde la Resolución/ PIN antes de emitir.',
        details: {'ventaId': ventaId},
      );
    }

    // Simulate a transmission record for local testing without contacting PTA.
    return TransmissionResult(
      status: TransmissionStatus.simulated,
      message: 'NoOp: transmisión simulada — no enviada a DIAN. Use un PTA real para transmisión.',
      details: {'ventaId': ventaId, 'cufe': cufe},
    );
  }

  @override
  Future<EnablementResult> sendEnablementPackage({required String packageContent, Map<String, dynamic>? metadata}) async {
    return EnablementResult(
      status: EnablementStatus.notImplemented,
      message: 'NoOp: envío de paquete de habilitación no implementado en NoOp.',
    );
  }
}
