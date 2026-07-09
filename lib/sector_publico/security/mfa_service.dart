/// Servicio MFA (Multi-Factor Authentication)
/// Implementación TOTP para roles de aprobación
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:otp/otp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

enum RolUsuario {
  tesorero,
  secretarioHacienda,
  alcaldeRepresentanteLegal,
  contador,
  otros,
}

class MFAService {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  // Roles que requieren MFA obligatorio
  static const Set<RolUsuario> _rolesRequierenMFA = {
    RolUsuario.tesorero,
    RolUsuario.secretarioHacienda,
    RolUsuario.alcaldeRepresentanteLegal,
    RolUsuario.contador,
  };

  MFAService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Verifica si un rol requiere MFA
  static bool requiereMFA(RolUsuario rol) {
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

  /// Genera código TOTP actual para un usuario
  Future<String?> generarCodigoTOTP(String usuarioId) async {
    final secreto = await obtenerSecretoTOTP(usuarioId);
    if (secreto == null) return null;

    return OTP.generateTOTPCodeString(
      secreto,
      DateTime.now().millisecondsSinceEpoch,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  /// Verifica un código TOTP
  Future<bool> verificarCodigoTOTP({
    required String usuarioId,
    required String codigo,
    int ventana = 1,
  }) async {
    final secreto = await obtenerSecretoTOTP(usuarioId);
    if (secreto == null) return false;

    // Verificar código actual y ventanas adyacentes (para tolerancia de reloj)
    for (int i = -ventana; i <= ventana; i++) {
      final fechaOffset = DateTime.now().add(Duration(seconds: i * 30));
      final codigoValido = OTP.generateTOTPCodeString(
        secreto,
        fechaOffset.millisecondsSinceEpoch,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (codigoValido == codigo) {
        return true;
      }
    }

    return false;
  }

  /// Genera URI para configurar app de autenticación (Google Authenticator, Authy)
  Future<String> generarURIOTP(String usuarioId, String nombreUsuario) async {
    final secreto = await obtenerSecretoTOTP(usuarioId);
    if (secreto == null) throw Exception('No existe secreto TOTP para el usuario');

    final issuer = 'MerkaERP%20Sector%20P%C3%BAblico';
    final usuarioEncoded = Uri.encodeComponent(nombreUsuario);
    return 'otpauth://totp/$issuer:$usuarioEncoded?secret=$secreto&issuer=$issuer&digits=6&period=30';
  }

  /// Activa MFA para un usuario
  Future<void> activarMFA(String usuarioId, String nombreUsuario) async {
    await generarSecretoTOTP(usuarioId);
    final claveActivado = 'mfa_activado_$usuarioId';
    await _secureStorage.write(key: claveActivado, value: 'true');
  }

  /// Verifica si MFA está activado para un usuario
  Future<bool> estaMFAActivado(String usuarioId) async {
    final claveActivado = 'mfa_activado_$usuarioId';
    final activado = await _secureStorage.read(key: claveActivado);
    return activado == 'true';
  }

  /// Desactiva MFA para un usuario
  Future<void> desactivarMFA(String usuarioId) async {
    final claveSecreto = 'mfa_secreto_$usuarioId';
    final claveActivado = 'mfa_activado_$usuarioId';
    
    await _secureStorage.delete(key: claveSecreto);
    await _secureStorage.delete(key: claveActivado);
  }

  /// Valida que un usuario con rol de aprobación tenga MFA activado
  Future<bool> validarMFAParaRolAprobacion({
    required String usuarioId,
    required RolUsuario rol,
  }) async {
    if (!requiereMFA(rol)) {
      return true; // No requiere MFA
    }

    final activado = await estaMFAActivado(usuarioId);
    return activado;
  }

  /// Genera un secreto aleatorio de 32 bytes (Base32)
  String _generarSecretoAleatorio() {
    final random = _uuid.v4();
    final bytes = utf8.encode(random);
    final hash = sha256.convert(bytes);
    return Base32.encode(hash.bytes);
  }

  /// Convierte bytes a Base32
  String base32Encode(List<int> bytes) {
    return Base32.encode(bytes);
  }
}

/// Codificación Base32
class Base32 {
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  
  static String encode(List<int> bytes) {
    final buffer = StringBuffer();
    int bits = 0;
    int bitCount = 0;

    for (final byte in bytes) {
      bits = (bits << 8) | byte;
      bitCount += 8;

      while (bitCount >= 5) {
        final index = (bits >> (bitCount - 5)) & 0x1F;
        buffer.write(_alphabet[index]);
        bitCount -= 5;
      }
    }

    if (bitCount > 0) {
      final index = (bits << (5 - bitCount)) & 0x1F;
      buffer.write(_alphabet[index]);
    }

    return buffer.toString();
  }
}
