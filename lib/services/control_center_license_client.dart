import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'control_center_endpoint.dart';

class ControlCenterNetworkException implements Exception {
  const ControlCenterNetworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ControlCenterLicenseClient {
  const ControlCenterLicenseClient({
    this.endpoint,
    ControlCenterHttpTransport? transport,
  }) : _transport = transport;

  final String? endpoint;
  final ControlCenterHttpTransport? _transport;

  ControlCenterHttpTransport get transport =>
      _transport ?? const DartIoControlCenterTransport();

  Future<Map<String, dynamic>> activate({
    required String email,
    required String password,
    required String hardwareFingerprint,
  }) {
    return transport.postJson(
      ControlCenterEndpoint.buildUrl(
        endpoint ?? ControlCenterEndpoint.defaultEndpoint,
        'licenses/activate',
      ),
      {
        'email': email,
        'password': password,
        'hardware_fingerprint': hardwareFingerprint,
      },
    );
  }

  Future<Map<String, dynamic>> validate({
    required String licenseToken,
    required String hardwareFingerprint,
    required String installationId,
  }) {
    return transport.postJson(
      ControlCenterEndpoint.buildUrl(
        endpoint ?? ControlCenterEndpoint.defaultEndpoint,
        'licenses/validate',
      ),
      {
        'license_token': licenseToken,
        'hardware_fingerprint': hardwareFingerprint,
        'installation_id': installationId,
      },
    );
  }

  Future<void> heartbeat(Map<String, Object?> payload) async {
    await transport.postJson(
      ControlCenterEndpoint.buildUrl(
        endpoint ?? ControlCenterEndpoint.defaultEndpoint,
        'installations/heartbeat',
      ),
      payload,
    );
  }

  Future<List<Map<String, dynamic>>> commands(String installationId) async {
    final response = await transport.getJson(
      ControlCenterEndpoint.buildUrl(
        endpoint ?? ControlCenterEndpoint.defaultEndpoint,
        'installations/$installationId/commands',
      ),
    );
    final raw = response['commands'] ?? response['data'] ?? response;
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) item.cast<String, dynamic>(),
    ];
  }

  Future<void> ackCommand({
    required String commandId,
    required String installationId,
    required String status,
    String? message,
  }) async {
    await transport.postJson(
      ControlCenterEndpoint.buildUrl(
        endpoint ?? ControlCenterEndpoint.defaultEndpoint,
        'commands/$commandId/ack',
      ),
      {
        'installation_id': installationId,
        'installationId': installationId,
        'status': status,
        if (message != null) 'message': message,
      },
    );
  }
}

abstract class ControlCenterHttpTransport {
  Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, Object?> payload,
  );

  Future<Map<String, dynamic>> getJson(String url);
}

class DartIoControlCenterTransport implements ControlCenterHttpTransport {
  const DartIoControlCenterTransport({
    this.connectionTimeout = const Duration(seconds: 5),
    this.responseTimeout = const Duration(seconds: 15),
  });

  final Duration connectionTimeout;
  final Duration responseTimeout;

  @override
  Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, Object?> payload,
  ) async {
    final client = HttpClient()..connectionTimeout = connectionTimeout;
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(responseTimeout);
      return _decodeResponse(response, url);
    } on SocketException catch (error) {
      throw ControlCenterNetworkException(error.message);
    } on TimeoutException catch (_) {
      throw const ControlCenterNetworkException('Tiempo de espera agotado');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> getJson(String url) async {
    final client = HttpClient()..connectionTimeout = connectionTimeout;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(responseTimeout);
      if (response.statusCode == 404) return {'commands': <Object?>[]};
      return _decodeResponse(response, url);
    } on SocketException catch (error) {
      throw ControlCenterNetworkException(error.message);
    } on TimeoutException catch (_) {
      throw const ControlCenterNetworkException('Tiempo de espera agotado');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _decodeResponse(
    HttpClientResponse response,
    String url,
  ) async {
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: $body', uri: Uri.parse(url));
    }
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return {'data': decoded};
  }
}
