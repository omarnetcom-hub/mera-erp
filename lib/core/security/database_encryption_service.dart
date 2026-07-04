// ============================================================
// database_encryption_service.dart
// Servicio de cifrado de base de datos con SQLCipher
// ============================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/pointycastle.dart';

class DatabaseEncryptionService {
  static final DatabaseEncryptionService instance = DatabaseEncryptionService._internal();
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _encryptionKey = 'db_encryption_key';
  static const String _encryptionSalt = 'db_encryption_salt';
  static const int _keyIterations = 10000; // PBKDF2 iterations
  static const int _keyLength = 32; // 256 bits for AES-256
  
  DatabaseEncryptionService._internal();
  
  /// Deriva una clave de cifrado desde una contraseña usando PBKDF2
  String deriveKeyFromPassword(String password, {String? salt}) async {
    final effectiveSalt = salt ?? _generateSalt();
    
    final key = _pbkdf2(
      password,
      effectiveSalt,
      iterations: _keyIterations,
      keyLength: _keyLength,
    );
    
    // Guardar el salt para futuras derivaciones
    if (salt == null) {
      await _secureStorage.write(key: _encryptionSalt, value: effectiveSalt);
    }
    
    return key;
  }
  
  /// Genera un salt aleatorio
  String _generateSalt() {
    final random = SecureRandom('AES/CTR/AUTO-PRNG');
    final salt = random.nextBytes(16);
    return base64.encode(salt);
  }
  
  /// Implementación de PBKDF2
  String _pbkdf2(String password, String salt, {required int iterations, required int keyLength}) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64.decode(salt);
    
    final key = _pbkdf2Core(passwordBytes, saltBytes, iterations, keyLength);
    return base64.encode(key);
  }
  
  /// Core PBKDF2-HMAC-SHA256
  Uint8List _pbkdf2Core(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final u1 = hmac.convert(salt).bytes;
    final dk = <int>[];
    
    var result = u1;
    for (int i = 1; i < iterations; i++) {
      result = hmac.convert(result).bytes;
      for (int j = 0; j < result.length; j++) {
        dk.add(u1[j] ^ result[j]);
      }
    }
    
    return Uint8List.fromList(dk.sublist(0, keyLength));
  }
  
  /// Verifica si la base de datos está cifrada
  Future<bool> isDatabaseEncrypted() async {
    final key = await _secureStorage.read(key: _encryptionKey);
    return key != null;
  }
  
  /// Obtiene la clave de cifrado almacenada
  Future<String?> getStoredKey() async {
    return await _secureStorage.read(key: _encryptionKey);
  }
  
  /// Guarda la clave de cifrado
  Future<void> storeKey(String key) async {
    await _secureStorage.write(key: _encryptionKey, value: key);
  }
  
  /// Elimina la clave de cifrado (descifrado)
  Future<void> removeKey() async {
    await _secureStorage.delete(key: _encryptionKey);
    await _secureStorage.delete(key: _encryptionSalt);
  }
  
  /// Inicializa el cifrado de la base de datos
  Future<String> initializeEncryption(String password) async {
    final existingKey = await getStoredKey();
    
    if (existingKey != null) {
      // Verificar que la contraseña coincide
      final testKey = await deriveKeyFromPassword(password);
      if (testKey != existingKey) {
        throw Exception('Contraseña incorrecta');
      }
      return existingKey;
    }
    
    // Nueva clave
    final newKey = await deriveKeyFromPassword(password);
    await storeKey(newKey);
    return newKey;
  }
  
  /// Cambia la contraseña de cifrado
  Future<String> changePassword(String oldPassword, String newPassword) async {
    final existingKey = await getStoredKey();
    if (existingKey == null) {
      throw Exception('No hay cifrado activo');
    }
    
    // Verificar contraseña antigua
    final testKey = await deriveKeyFromPassword(oldPassword);
    if (testKey != existingKey) {
      throw Exception('Contraseña antigua incorrecta');
    }
    
    // Generar nueva clave
    final newKey = await deriveKeyFromPassword(newPassword);
    await storeKey(newKey);
    
    return newKey;
  }
  
  /// Genera una clave aleatoria para cifrado automático
  Future<String> generateRandomKey() async {
    final random = SecureRandom('AES/CTR/AUTO-PRNG');
    final keyBytes = random.nextBytes(32);
    final key = base64.encode(keyBytes);
    await storeKey(key);
    return key;
  }
  
  /// Verifica la integridad de la clave
  Future<bool> verifyKeyIntegrity(String key) async {
    final storedKey = await getStoredKey();
    return storedKey == key;
  }
  
  /// Obtiene información sobre el estado del cifrado
  Future<Map<String, dynamic>> getEncryptionStatus() async {
    final isEncrypted = await isDatabaseEncrypted();
    final hasSalt = await _secureStorage.read(key: _encryptionSalt) != null;
    
    return {
      'encrypted': isEncrypted,
      'has_salt': hasSalt,
      'key_iterations': _keyIterations,
      'key_length': _keyLength,
      'algorithm': 'AES-256',
      'key_derivation': 'PBKDF2-HMAC-SHA256',
    };
  }
  
  /// Resetea el cifrado (peligroso - solo para desarrollo/testing)
  Future<void> resetEncryption() async {
    await removeKey();
  }
}
