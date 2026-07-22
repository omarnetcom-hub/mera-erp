/// Servicio MFA (Multi-Factor Authentication)
/// Implementación TOTP para roles de aprobación
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:otp/otp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'roles_permisos_service.dart';

class MFAService {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  // Roles que requieren MFA obligatorio
  static const Set<RolSectorPublico> _rolesRequierenMFA = {
    RolSectorPublico.tesorero,
    RolSectorPublico.secretarioHacienda,
    RolSectorPublico.alcaldeRepresentanteLegal,
    RolSectorPublico.contador,
  };

  MFAService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Verifica si un rol del sector público requiere MFA
  static bool requiereMFA(RolSectorPublico rol) {
    return _rolesRequierenMFA.contains(rol);
  }

  /// Genera un secreto TOTP para un usuario
  Future<String> generarSecretoTOTP(String usuarioId) async {
    final secreto = _generarSecretoAleatorio();
    final clave = 'mfa_secreto_$usuarioId';
    await _secureStorage.write(key: clave, value: secreto);
    return secreto;
  }

  /// Obtiene el secreto TOTP de un usuario
  Future<String?> obtenerSecretoTOTP(String usuarioId) async {
    final clave = 'mfa_secreto_$usuarioId';
    return await _secureStorage.read(key: clave);
  }

  /// Genera un código TOTP actual
  Future<String> generarCodigoTOTP(String usuarioId) async {
    final secreto = await obtenerSecretoTOTP(usuarioId);
    if (secreto == null) {
      throw Exception('MFA no configurado para este usuario');
    }

    final now = DateTime.now();
    return OTP.generateTOTPCodeString(
      secreto,
      now.millisecondsSinceEpoch,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  /// Verifica un código TOTP ingresado por el usuario
  Future<bool> verificarCodigoTOTP(String usuarioId, String codigoIngresado) async {
    try {
      final secreto = await obtenerSecretoTOTP(usuarioId);
      if (secreto == null) return false;

      final now = DateTime.now();
      
      // Probar código actual
      final codigoActual = OTP.generateTOTPCodeString(
        secreto,
        now.millisecondsSinceEpoch,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      if (codigoActual == codigoIngresado) return true;

      // Probar código anterior (ventana de tolerancia de 30 segundos)
      final codigoAnterior = OTP.generateTOTPCodeString(
        secreto,
        now.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      return codigoAnterior == codigoIngresado;
    } catch (e) {
      return false;
    }
  }

  /// Registra un código de recuperación
  Future<List<String>> generarCodigosRecuperacion(String usuarioId) async {
    final codigos = <String>[];
    for (int i = 0; i < 5; i++) {
      final codigo = _uuid.v4().substring(0, 8).toUpperCase();
      codigos.add(codigo);
    }

    final clave = 'mfa_recovery_$usuarioId';
    await _secureStorage.write(key: clave, value: jsonEncode(codigos));
    return codigos;
  }

  /// Genera un secreto aleatorio de 16 caracteres Base32
  String _generarSecretoAleatorio() {
    final randomBytes = List<int>.generate(10, (i) => DateTime.now().microsecondsSinceEpoch % 256);
    final bytes = utf8.encode(randomBytes.toString());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16).toUpperCase();
  }
}
