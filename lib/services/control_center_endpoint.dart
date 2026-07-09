class ControlCenterEndpoint {
  const ControlCenterEndpoint._();

  static const String apiVersion = 'api/v1';

  static String normalize(String? value) {
    var endpoint = (value ?? '').trim();
    if (endpoint.isEmpty) {
      return 'https://merkaerp-control-center-backend.onrender.com';
    }

    endpoint = endpoint.replaceAll(RegExp(r'\s+'), '');
    endpoint = endpoint.replaceFirst(RegExp(r'/+$'), '');

    if (endpoint.toLowerCase().endsWith('/$apiVersion')) {
      endpoint = endpoint.substring(0, endpoint.length - apiVersion.length - 1);
    }

    if (endpoint.toLowerCase().endsWith('/api')) {
      endpoint = endpoint.substring(0, endpoint.length - 4);
    }

    return endpoint;
  }

  static String buildUrl(String? endpoint, String path) {
    final base = normalize(endpoint);
    final cleanPath = path.replaceFirst(RegExp(r'^/'), '');
    return '$base/$apiVersion/$cleanPath';
  }

  static String activationUrl(String? endpoint) {
    return buildUrl(endpoint, 'licenses/activate');
  }
}
