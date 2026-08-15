import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:sqflite/sqflite.dart';

import '../db_helper.dart';

class LicenseSecureStore {
  LicenseSecureStore({
    FlutterSecureStorage? secureStorage,
    String? testKey,
  }) : _secureStorage = secureStorage,
       _testKey = testKey;

  static const encryptedConfigKey = 'licencia_info_encrypted_v1';
  static const legacyConfigKey = 'licencia_info';
  static const _secureKeyName = 'merka_license_store_key_v1';

  final FlutterSecureStorage? _secureStorage;
  final String? _testKey;

  Future<void> write(Map<String, Object?> value) async {
    final db = await DatabaseHelper.instance.database;
    final key = await _loadOrCreateKey();
    final encrypted = _encrypt(jsonEncode(value), key);
    await db.insert(
      'app_config',
      {'clave': encryptedConfigKey, 'valor': encrypted},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> read() async {
    final db = await DatabaseHelper.instance.database;
    final encrypted = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [encryptedConfigKey],
      limit: 1,
    );
    if (encrypted.isNotEmpty) {
      final key = await _loadOrCreateKey();
      final decrypted = _decrypt(encrypted.first['valor'] as String, key);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    }

    final legacy = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [legacyConfigKey],
      limit: 1,
    );
    if (legacy.isEmpty) return null;
    final decoded = jsonDecode(legacy.first['valor'] as String);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<void> delete() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'app_config',
      where: 'clave IN (?, ?)',
      whereArgs: [encryptedConfigKey, legacyConfigKey],
    );
  }

  Future<Uint8List> _loadOrCreateKey() async {
    if (_testKey != null) {
      return Uint8List.fromList(sha256.convert(utf8.encode(_testKey)).bytes);
    }

    const storage = FlutterSecureStorage();
    final effectiveStorage = _secureStorage ?? storage;
    try {
      final existing = await effectiveStorage.read(key: _secureKeyName);
      if (existing != null && existing.isNotEmpty) {
        return Uint8List.fromList(base64Decode(existing));
      }
      final generated = _randomBytes(32);
      await effectiveStorage.write(
        key: _secureKeyName,
        value: base64Encode(generated),
      );
      return generated;
    } on MissingPluginException catch (_) {
      return _fallbackDevelopmentKey();
    } catch (error) {
      debugPrint('License secure storage fallback: $error');
      return _fallbackDevelopmentKey();
    }
  }

  Uint8List _fallbackDevelopmentKey() {
    final material = [
      'merka-license-local-fallback',
      defaultTargetPlatform.name,
      DateTime.now().timeZoneName,
    ].join('|');
    return Uint8List.fromList(sha256.convert(utf8.encode(material)).bytes);
  }

  String _encrypt(String plainText, Uint8List key) {
    final iv = _randomBytes(16);
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
    return jsonEncode({
      'v': 1,
      'alg': 'AES-256-CBC',
      'iv': base64Encode(iv),
      'data': base64Encode(encrypted),
    });
  }

  String _decrypt(String encryptedJson, Uint8List key) {
    final envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;
    if (envelope['alg'] != 'AES-256-CBC') {
      throw StateError('Formato de licencia cifrada no soportado');
    }
    final iv = base64Decode(envelope['iv'] as String);
    final encrypted = base64Decode(envelope['data'] as String);
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        false,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return utf8.decode(cipher.process(Uint8List.fromList(encrypted)));
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
