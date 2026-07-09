// ============================================================
// mfa_service.dart
// Servicio de autenticación multifactor (MFA) con TOTP
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

class MFAService {
  static final MFAService instance = MFAService._internal();
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _mfaEnabledKey = 'mfa_enabled';
  static const String _mfaSecretKey = 'mfa_secret';
  static const String _mfaBackupCodesKey = 'mfa_backup_codes';
  static const String _mfaUserIdKey = 'mfa_user_id';
  
  MFAService._internal();
  
  /// Genera un secreto TOTP para un usuario
  String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }
  
  /// Genera códigos de respaldo (10 códigos de 8 dígitos)
  List<String> generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];
    
    for (int i = 0; i < 10; i++) {
      final code = List<int>.generate(8, (_) => random.nextInt(10)).join();
      codes.add(code);
    }
    
    return codes;
  }
  
  /// Habilita MFA para un usuario
  Future<bool> enableMFA(String userId) async {
    try {
      final secret = generateSecret();
      final backupCodes = generateBackupCodes();
      
      // Guardar configuración
      await _secureStorage.write(key: _mfaEnabledKey, value: 'true');
      await _secureStorage.write(key: _mfaSecretKey, value: secret);
      await _secureStorage.write(key: _mfaUserIdKey, value: userId);
      await _secureStorage.write(
        key: _mfaBackupCodesKey,
        value: jsonEncode(backupCodes),
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Deshabilita MFA para un usuario
  Future<void> disableMFA() async {
    try {
      await _secureStorage.delete(key: _mfaEnabledKey);
      await _secureStorage.delete(key: _mfaSecretKey);
      await _secureStorage.delete(key: _mfaBackupCodesKey);
      await _secureStorage.delete(key: _mfaUserIdKey);
    } catch (e) {
      // Silenciar error
    }
  }
  
  /// Verifica si MFA está habilitado
  Future<bool> isMFAEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _mfaEnabledKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }
  
  /// Verifica un código TOTP
  Future<bool> verifyTOTP(String code) async {
    try {
      final secret = await _secureStorage.read(key: _mfaSecretKey);
      if (secret == null) return false;
      
      final time = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
      final otp = OTP.generateTOTPCode(
        secret,
        time,
        algorithm: Algorithm.SHA1,
      );
      
      return otp == code;
    } catch (e) {
      return false;
    }
  }
  
  /// Verifica un código de respaldo
  Future<bool> verifyBackupCode(String code) async {
    try {
      final backupCodesJson = await _secureStorage.read(key: _mfaBackupCodesKey);
      if (backupCodesJson == null) return false;
      
      final backupCodes = List<String>.from(jsonDecode(backupCodesJson));
      
      if (backupCodes.contains(code)) {
        // Remover código usado
        backupCodes.remove(code);
        await _secureStorage.write(
          key: _mfaBackupCodesKey,
          value: jsonEncode(backupCodes),
        );
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Obtiene los códigos de respaldo restantes
  Future<List<String>> getRemainingBackupCodes() async {
    try {
      final backupCodesJson = await _secureStorage.read(key: _mfaBackupCodesKey);
      if (backupCodesJson == null) return [];
      
      return List<String>.from(jsonDecode(backupCodesJson));
    } catch (e) {
      return [];
    }
  }
  
  /// Regenera códigos de respaldo
  Future<bool> regenerateBackupCodes() async {
    try {
      final newBackupCodes = generateBackupCodes();
      await _secureStorage.write(
        key: _mfaBackupCodesKey,
        value: jsonEncode(newBackupCodes),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Obtiene el secreto TOTP (para configuración inicial)
  Future<String?> getSecret() async {
    try {
      return await _secureStorage.read(key: _mfaSecretKey);
    } catch (e) {
      return null;
    }
  }
  
  /// Genera URI para Google Authenticator
  String generateAuthenticatorURI(String secret, String issuer, String account) {
    final encodedSecret = base64Encode(base64Decode(secret));
    return 'otpauth://totp/$issuer:$account?secret=$encodedSecret&issuer=$issuer';
  }
  
  /// Verifica si el usuario tiene MFA configurado
  Future<bool> hasMFAConfigured(String userId) async {
    try {
      final enabled = await isMFAEnabled();
      if (!enabled) return false;
      
      final mfaUserId = await _secureStorage.read(key: _mfaUserIdKey);
      return mfaUserId == userId;
    } catch (e) {
      return false;
    }
  }
}
