import 'dian_transmission_client.dart';
import 'dian_transmission_client_noop.dart';

/// Simple registry/factory for the global DianTransmissionClient instance.
///
/// Use `DianTransmissionClientRegistry.instance` to obtain the client.
/// Assign a different implementation via `DianTransmissionClientRegistry.instance = ...` for tests or real clients.
// Global singleton instance for DianTransmissionClient. Tests and app startup
// can replace this with a real implementation by assigning to this variable.
DianTransmissionClient dianTransmissionClientInstance = NoOpDianTransmissionClient();
