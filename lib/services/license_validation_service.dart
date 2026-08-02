import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

class LicenseValidationService {
  static const String _expectedIssuer = 'MerkaERP-ControlCenter';

  // PENDIENTE: pegar merka_license_public.pem aqui. Mientras este vacia,
  // toda activacion offline se rechaza de forma cerrada.
  static const String _productionPublicKeyPem = '';

  static final LicenseValidationService _instance = LicenseValidationService._(
    _productionPublicKeyPem,
  );

  factory LicenseValidationService() => _instance;

  LicenseValidationService.withPublicKey(String publicKeyPem)
    : _publicKeyPem = publicKeyPem;

  LicenseValidationService._(this._publicKeyPem);

  final String _publicKeyPem;

  bool get hasConfiguredPublicKey => _publicKeyPem.trim().isNotEmpty;

  /// Verifica primero cabecera y firma RS256. Solo despues procesa claims.
  Map<String, dynamic>? validateOfflineToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3 || !hasConfiguredPublicKey) return null;

      final header = _decodeJsonObject(parts[0]);
      if (header == null ||
          header['alg'] != 'RS256' ||
          header['typ'] != 'JWT') {
        return null;
      }

      final publicKey = CryptoUtils.rsaPublicKeyFromPem(_publicKeyPem);
      final verifier = Signer('SHA-256/RSA')
        ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      final signature = RSASignature(_base64UrlDecodeBytes(parts[2]));
      final signingInput = Uint8List.fromList(
        ascii.encode('${parts[0]}.${parts[1]}'),
      );

      if (!verifier.verifySignature(signingInput, signature)) return null;

      final payload = _decodeJsonObject(parts[1]);
      if (payload == null || !_validateTokenStructure(payload)) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Aplica las validaciones de negocio requeridas para usar el token.
  Future<Map<String, dynamic>?> validateOfflineTokenForDevice(
    String token,
    String currentFingerprint,
  ) async {
    final payload = validateOfflineToken(token);
    if (payload == null || isTokenExpired(payload) || !isTokenActive(payload)) {
      return null;
    }
    final tokenFingerprint = payload['hfp'] as String;
    if (!await verifyHardwareFingerprint(
      tokenFingerprint,
      currentFingerprint,
    )) {
      return null;
    }
    return payload;
  }

  Map<String, dynamic>? _decodeJsonObject(String encoded) {
    final decoded = utf8.decode(_base64UrlDecodeBytes(encoded));
    final value = jsonDecode(decoded);
    if (value is! Map<String, dynamic>) return null;
    return value;
  }

  bool _validateTokenStructure(Map<String, dynamic> payload) {
    const requiredFields = ['hfp', 'lt', 'st', 'ed', 'md', 'iat', 'iss'];
    if (requiredFields.any((field) => !payload.containsKey(field))) {
      return false;
    }

    if (payload['iss'] != _expectedIssuer) return false;

    final fingerprint = payload['hfp'];
    if (fingerprint is! String || fingerprint.trim().isEmpty) return false;

    final licenseType = payload['lt'];
    if (licenseType != 'SUSCRIPCION' && licenseType != 'PERPETUA') {
      return false;
    }

    final status = payload['st'];
    if (status != 'ACTIVO' && status != 'TRIAL' && status != 'SUSPENDIDO') {
      return false;
    }

    final expiry = payload['ed'];
    if (expiry is! String || DateTime.tryParse(expiry) == null) return false;

    final modules = payload['md'];
    if (modules is! List || modules.any((module) => module is! String)) {
      return false;
    }

    final issuedAt = payload['iat'];
    final validIssuedAt =
        (issuedAt is int && issuedAt > 0) ||
        (issuedAt is String && DateTime.tryParse(issuedAt) != null);
    return validIssuedAt;
  }

  Future<bool> verifyHardwareFingerprint(
    String tokenFingerprint,
    String currentFingerprint,
  ) async {
    return tokenFingerprint == currentFingerprint;
  }

  bool isTokenExpired(Map<String, dynamic> payload) {
    if (payload['lt'] == 'PERPETUA') return false;
    final expiry = payload['ed'];
    if (expiry is! String) return true;
    final expiryDate = DateTime.tryParse(expiry);
    return expiryDate == null || DateTime.now().isAfter(expiryDate);
  }

  bool isTokenActive(Map<String, dynamic> payload) {
    final status = payload['st'];
    return status == 'ACTIVO' || status == 'TRIAL';
  }

  Map<String, dynamic> extractLicenseInfo(String token) {
    final payload = validateOfflineToken(token);
    if (payload == null) return {};

    return {
      'license_type': payload['lt'],
      'status': payload['st'],
      'expiry_date': payload['ed'],
      'modules': payload['md'],
      'hardware_fingerprint': payload['hfp'],
      'issued_at': payload['iat'],
      'issuer': payload['iss'],
    };
  }

  Uint8List _base64UrlDecodeBytes(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder != 0) normalized += '=' * (4 - remainder);
    return Uint8List.fromList(base64.decode(normalized));
  }

  String generateHash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  bool validateLocalIntegrity({
    required String localLicenseType,
    required String localStatus,
    required String localExpiryDate,
    required Map<String, dynamic> tokenData,
  }) {
    return localLicenseType == (tokenData['license_type'] ?? tokenData['lt']) &&
        localStatus == (tokenData['status'] ?? tokenData['st']) &&
        localExpiryDate == (tokenData['expiry_date'] ?? tokenData['ed']);
  }

  int getDaysUntilExpiry(String expiryDateStr) {
    final expiryDate = DateTime.tryParse(expiryDateStr);
    if (expiryDate == null) return -1;
    return expiryDate.difference(DateTime.now()).inDays;
  }

  bool requiresRenewal(String expiryDateStr, {int warningDays = 7}) {
    final daysUntil = getDaysUntilExpiry(expiryDateStr);
    return daysUntil >= 0 && daysUntil <= warningDays;
  }

  bool isModuleEnabled(String module, List<dynamic> enabledModules) {
    return enabledModules.contains(module);
  }

  Map<String, bool> validateLicenseLimits({
    required int currentUsers,
    required int maxUsers,
    required int currentDevices,
    required int maxDevices,
    required int currentBranches,
    required int maxBranches,
  }) {
    return {
      'users_valid': currentUsers <= maxUsers,
      'devices_valid': currentDevices <= maxDevices,
      'branches_valid': currentBranches <= maxBranches,
      'all_valid':
          currentUsers <= maxUsers &&
          currentDevices <= maxDevices &&
          currentBranches <= maxBranches,
    };
  }
}
