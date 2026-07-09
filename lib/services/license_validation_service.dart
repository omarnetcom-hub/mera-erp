import 'dart:convert';
import 'package:crypto/crypto.dart';

class LicenseValidationService {
  static final LicenseValidationService _instance = LicenseValidationService._internal();
  factory LicenseValidationService() => _instance;
  LicenseValidationService._internal();

  // Clave pública RSA embebida (debe generarse desde Control Center y pegarse aquí)
  // Esta es una clave de ejemplo - debe ser reemplazada con la clave real generada
  static const String _publicKeyPEM = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
[GENERAR DESDE CONTROL CENTER Y PEGAR AQUÍ]
-----END PUBLIC KEY-----''';

  /// Valida un token JWT offline
  Map<String, dynamic>? validateOfflineToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final headerEncoded = parts[0];
      final payloadEncoded = parts[1];
      final signatureEncoded = parts[2];

      // Decodificar payload
      final payloadJson = _base64UrlDecode(payloadEncoded);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      // Validar firma (en producción, usar validación RSA real)
      // Por ahora, validamos estructura básica
      if (!_validateTokenStructure(payload)) {
        return null;
      }

      // Validar que el hardware fingerprint coincida
      // Esto se hará en el contexto de la aplicación
      return payload;
    } catch (e) {
      return null;
    }
  }

  /// Valida la estructura del token
  bool _validateTokenStructure(Map<String, dynamic> payload) {
    final requiredFields = ['hfp', 'lt', 'st', 'ed', 'md', 'iat', 'iss'];
    
    for (final field in requiredFields) {
      if (!payload.containsKey(field)) return false;
    }

    // Validar issuer
    if (payload['iss'] != 'MerkaERP-ControlCenter') return false;

    // Validar tipos de licencia
    final licenseType = payload['lt'] as String;
    if (licenseType != 'SUSCRIPCION' && licenseType != 'PERPETUA') return false;

    // Validar estado
    final status = payload['st'] as String;
    if (status != 'ACTIVO' && status != 'TRIAL' && status != 'SUSPENDIDO') return false;

    return true;
  }

  /// Verifica si el token coincide con el hardware actual
  Future<bool> verifyHardwareFingerprint(String tokenFingerprint, String currentFingerprint) async {
    return tokenFingerprint == currentFingerprint;
  }

  /// Verifica si el token está expirado
  bool isTokenExpired(Map<String, dynamic> payload) {
    final licenseType = payload['lt'] as String;
    
    // Licencias perpetuas no expiran
    if (licenseType == 'PERPETUA') return false;

    final expiryDateStr = payload['ed'] as String;
    final expiryDate = DateTime.parse(expiryDateStr);
    
    return DateTime.now().isAfter(expiryDate);
  }

  /// Verifica si el token está activo
  bool isTokenActive(Map<String, dynamic> payload) {
    final status = payload['st'] as String;
    return status == 'ACTIVO' || status == 'TRIAL';
  }

  /// Extrae información del token
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

  /// Decodificación Base64 URL-safe
  String _base64UrlDecode(String input) {
    var base64Str = input
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    
    // Padding
    final padLength = 4 - (base64Str.length % 4);
    if (padLength != 4) {
      base64Str += '=' * padLength;
    }
    
    final bytes = base64.decode(base64Str);
    return utf8.decode(bytes);
  }

  /// Genera hash de un string (para validaciones adicionales)
  String generateHash(String input) {
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Valida integridad de datos locales contra token
  bool validateLocalIntegrity({
    required String localLicenseType,
    required String localStatus,
    required String localExpiryDate,
    required Map<String, dynamic> tokenData,
  }) {
    return localLicenseType == tokenData['license_type'] &&
           localStatus == tokenData['status'] &&
           localExpiryDate == tokenData['expiry_date'];
  }

  /// Calcula días restantes hasta expiración
  int getDaysUntilExpiry(String expiryDateStr) {
    try {
      final expiryDate = DateTime.parse(expiryDateStr);
      final now = DateTime.now();
      final difference = expiryDate.difference(now);
      return difference.inDays;
    } catch (e) {
      return -1;
    }
  }

  /// Determina si se requiere renovación
  bool requiresRenewal(String expiryDateStr, {int warningDays = 7}) {
    final daysUntil = getDaysUntilExpiry(expiryDateStr);
    return daysUntil >= 0 && daysUntil <= warningDays;
  }

  /// Valida módulos habilitados
  bool isModuleEnabled(String module, List<dynamic> enabledModules) {
    return enabledModules.contains(module);
  }

  /// Valida límites de licencia
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
      'all_valid': currentUsers <= maxUsers &&
                   currentDevices <= maxDevices &&
                   currentBranches <= maxBranches,
    };
  }
}
