// ============================================================
// timestamp_service.dart
// Servicio de sello de tiempo criptográfico
// ============================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/pointycastle.dart';

class TimestampService {
  static final TimestampService instance = TimestampService._internal();
  
  String _privateKey = '';
  String _publicKey = '';
  
  TimestampService._internal();
  
  /// Genera un par de claves RSA para firmar timestamps
  Future<void> generateKeyPair() async {
    final keyParams = RSAKeyGeneratorParameters(
      BigInt.parse('65537'), // public exponent
      2048, // bit length
    );
    
    final random = SecureRandom('AES/CTR/AUTO-PRNG');
    final keyGenerator = KeyGenerator('RSA')..init(keyParams, random);
    
    final keyPair = keyGenerator.generateKeyPair();
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;
    
    _privateKey = _encodePrivateKey(privateKey);
    _publicKey = _encodePublicKey(publicKey);
  }
  
  /// Codifica clave privada
  String _encodePrivateKey(RSAPrivateKey privateKey) {
    // Simplificado - en producción usar formato PEM real
    return base64.encode(privateKey.modulus!.toUnsigned().toBytes());
  }
  
  /// Codifica clave pública
  String _encodePublicKey(RSAPublicKey publicKey) {
    // Simplificado - en producción usar formato PEM real
    return base64.encode(publicKey.modulus!.toUnsigned().toBytes());
  }
  
  /// Genera un sello de tiempo criptográfico
  Future<String> generateTimestamp(String data) async {
    final timestamp = DateTime.now().toIso8601String();
    final hash = _hashData('$data:$timestamp');
    
    // En producción, firmar con clave privada real
    final signature = _sign(hash);
    
    final timestampData = {
      'timestamp': timestamp,
      'hash': hash,
      'signature': signature,
      'public_key': _publicKey,
    };
    
    return base64.encode(utf8.encode(jsonEncode(timestampData)));
  }
  
  /// Genera hash de datos
  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Firma datos (simplificado)
  String _sign(String hash) {
    // En producción usar firma RSA real
    final signature = hash + ':' + DateTime.now().millisecondsSinceEpoch.toString();
    return base64.encode(utf8.encode(signature));
  }
  
  /// Verifica un sello de tiempo
  Future<bool> verifyTimestamp(String data, String timestampToken) async {
    try {
      final decoded = utf8.decode(base64.decode(timestampToken));
      final timestampData = jsonDecode(decoded) as Map<String, dynamic>;
      
      final timestamp = timestampData['timestamp'] as String;
      final hash = timestampData['hash'] as String;
      final signature = timestampData['signature'] as String;
      
      // Verificar que el hash coincide
      final expectedHash = _hashData('$data:$timestamp');
      if (hash != expectedHash) return false;
      
      // Verificar que el timestamp es reciente (dentro de 24 horas)
      final timestampDate = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (now.difference(timestampDate).inHours > 24) return false;
      
      // En producción, verificar firma con clave pública
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Genera un timestamp para un documento
  Future<String> timestampDocument(Map<String, dynamic> document) async {
    final documentString = jsonEncode(document);
    return await generateTimestamp(documentString);
  }
  
  /// Verifica el timestamp de un documento
  Future<bool> verifyDocumentTimestamp(
    Map<String, dynamic> document,
    String timestampToken,
  ) async {
    final documentString = jsonEncode(document);
    return await verifyTimestamp(documentString, timestampToken);
  }
  
  /// Obtiene información del timestamp
  Map<String, dynamic>? getTimestampInfo(String timestampToken) {
    try {
      final decoded = utf8.decode(base64.decode(timestampToken));
      final timestampData = jsonDecode(decoded) as Map<String, dynamic>;
      
      return {
        'timestamp': timestampData['timestamp'],
        'hash': timestampData['hash'],
        'has_signature': timestampData['signature'] != null,
      };
    } catch (e) {
      return null;
    }
  }
  
  /// Establece las claves (para configuración existente)
  void setKeys({required String privateKey, required String publicKey}) {
    _privateKey = privateKey;
    _publicKey = publicKey;
  }
  
  /// Obtiene la clave pública
  String get publicKey => _publicKey;
  
  /// Obtiene la clave privada
  String get privateKey => _privateKey;
  
  /// Genera un hash SHA-256
  static String sha256Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Genera un hash SHA-512
  static String sha512Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha512.convert(bytes);
    return digest.toString();
  }
}
