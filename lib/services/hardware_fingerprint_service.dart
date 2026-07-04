import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareFingerprintService {
  static final HardwareFingerprintService _instance = HardwareFingerprintService._internal();
  factory HardwareFingerprintService() => _instance;
  HardwareFingerprintService._internal();

  String? _cachedFingerprint;

  /// Genera el fingerprint del hardware actual
  Future<String> generateFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String fingerprintData = '';

      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        fingerprintData = _generateWindowsFingerprint(windowsInfo);
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprintData = _generateAndroidFingerprint(androidInfo);
      } else {
        // Fallback para otras plataformas
        fingerprintData = _generateGenericFingerprint();
      }

      // Generar hash SHA-256 del fingerprint
      final bytes = utf8.encode(fingerprintData);
      final hash = sha256.convert(bytes);
      
      _cachedFingerprint = hash.toString();
      return _cachedFingerprint!;
    } catch (e) {
      // Fallback en caso de error
      return _generateFallbackFingerprint();
    }
  }

  /// Genera fingerprint específico para Windows
  String _generateWindowsFingerprint(WindowsDeviceInfo windowsInfo) {
    // Combinar múltiples identificadores de hardware
    final components = [
      windowsInfo.computerName,
      windowsInfo.numberOfCores.toString(),
      windowsInfo.systemMemoryInMegabytes.toString(),
      // En producción, agregar más identificadores específicos de hardware
      // como MAC address, serial del disco, etc.
    ];

    return components.join('|');
  }

  /// Genera fingerprint específico para Android
  String _generateAndroidFingerprint(AndroidDeviceInfo androidInfo) {
    final components = [
      androidInfo.id,
      androidInfo.brand,
      androidInfo.model,
      androidInfo.board,
    ];

    return components.join('|');
  }

  /// Genera fingerprint genérico para otras plataformas
  String _generateGenericFingerprint() {
    final components = [
      Platform.localHostname,
      Platform.numberOfProcessors.toString(),
      DateTime.now().millisecondsSinceEpoch.toString(),
    ];

    return components.join('|');
  }

  /// Genera fingerprint de fallback en caso de error
  String _generateFallbackFingerprint() {
    final components = [
      Platform.localHostname,
      Platform.numberOfProcessors.toString(),
      DateTime.now().toIso8601String(),
    ];

    final bytes = utf8.encode(components.join('|'));
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Valida si el fingerprint actual coincide con uno almacenado
  Future<bool> validateFingerprint(String storedFingerprint) async {
    final currentFingerprint = await generateFingerprint();
    return currentFingerprint == storedFingerprint;
  }

  /// Genera un UUID basado en el fingerprint (para compatibilidad con sistemas existentes)
  Future<String> generateUUID() async {
    final fingerprint = await generateFingerprint();
    // Convertir el hash a formato UUID-like
    final hash = fingerprint.substring(0, 32);
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}'.toUpperCase();
  }

  /// Obtiene información del hardware para debugging
  Future<Map<String, dynamic>> getHardwareInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return {
        'platform': 'Windows',
        'computerName': windowsInfo.computerName,
        'numberOfCores': windowsInfo.numberOfCores,
        'systemMemoryInMegabytes': windowsInfo.systemMemoryInMegabytes,
        'productName': windowsInfo.productName,
        'userName': windowsInfo.userName,
      };
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'platform': 'Android',
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'board': androidInfo.board,
        'bootloader': androidInfo.bootloader,
      };
    } else {
      return {
        'platform': Platform.operatingSystem,
        'hostname': Platform.localHostname,
        'numberOfProcessors': Platform.numberOfProcessors,
      };
    }
  }
}
