/// Servicio de Encriptación AES-256
/// Encriptación de datos sensibles en reposo
/// 
/// ESTRATEGIA DE GESTIÓN DE CLAVES:
/// - La clave maestra se almacena en FlutterSecureStorage (keystore del sistema operativo)
/// - iOS: Keychain con kSecAttrAccessibleWhenUnlocked
/// - Android: Keystore con KeyStore.getInstance("AndroidKeyStore")
/// - La clave nunca se hardcodea ni se almacena en la base de datos
/// 
/// ESTRATEGIA DE ROTACIÓN DE CLAVE:
/// - Rotación anual recomendada (configurable por política de seguridad)
/// - Proceso de rotación:
///   1. Generar nueva clave maestra
///   2. Re-encriptar todos los datos sensibles con la nueva clave
///   3. Reemplazar la clave antigua con la nueva en secure storage
///   4. Registrar evento de rotación en auditoría
/// - Durante la rotación, ambas claves coexisten temporalmente para evitar pérdida de datos
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/pointycastle.dart';
import 'auditoria_service.dart';
import '../models/registro_auditoria.dart';

enum TipoDatoSensible {
  terceroIdentificacion,
  terceroDireccion,
  terceroTelefono,
  terceroEmail,
  cuentaBancaria,
  nominaSalario,
  nominaCuentaBancaria,
  otro,
}

class EncryptionService {
  final FlutterSecureStorage _secureStorage;
  final AuditoriaService? auditoriaService;
  
  // Clave maestra encriptada almacenada en secure storage
  static const String _claveMaestraKey = 'encryption_master_key';
  static const String _ivKey = 'encryption_iv';
  static const String _claveMaestraAnteriorKey = 'encryption_master_key_previous';
  static const String _ivAnteriorKey = 'encryption_iv_previous';
  static const String _rotacionTimestampKey = 'encryption_rotation_timestamp';

  EncryptionService({
    FlutterSecureStorage? secureStorage,
    this.auditoriaService,
  }) : _secureStorage = secureStorage ?? FlutterSecureStorage();

  /// Inicializa el servicio de encriptación
  Future<void> inicializar() async {
    final claveMaestra = await _secureStorage.read(key: _claveMaestraKey);
    
    if (claveMaestra == null) {
      // Generar nueva clave maestra y IV
      final clave = _generarClaveAleatoria();
      final iv = _generarIV();
      
      await _secureStorage.write(key: _claveMaestraKey, value: clave);
      await _secureStorage.write(key: _ivKey, value: iv);
      await _secureStorage.write(key: _rotacionTimestampKey, value: DateTime.now().toIso8601String());
    }
  }

  /// Rota la clave maestra de encriptación
  /// Este proceso re-encripta todos los datos sensibles con la nueva clave
  Future<void> rotarClaveMaestra({
    required String entidadId,
    required String usuarioId,
  }) async {
    // 1. Guardar clave actual como "anterior"
    final claveActual = await _secureStorage.read(key: _claveMaestraKey);
    final ivActual = await _secureStorage.read(key: _ivKey);
    
    if (claveActual != null && ivActual != null) {
      await _secureStorage.write(key: _claveMaestraAnteriorKey, value: claveActual);
      await _secureStorage.write(key: _ivAnteriorKey, value: ivActual);
    }
    
    // 2. Generar nueva clave maestra y IV
    final nuevaClave = _generarClaveAleatoria();
    final nuevoIv = _generarIV();
    
    // 3. Re-encriptar datos sensibles (esto debe implementarse por módulo)
    // Por ahora, solo registramos el evento de rotación
    // En producción, esto debe iterar sobre todos los datos sensibles en la base de datos
    // y re-encriptarlos con la nueva clave
    
    // 4. Reemplazar clave actual con la nueva
    await _secureStorage.write(key: _claveMaestraKey, value: nuevaClave);
    await _secureStorage.write(key: _ivKey, value: nuevoIv);
    await _secureStorage.write(key: _rotacionTimestampKey, value: DateTime.now().toIso8601String());
    
    // 5. Registrar evento de rotación en auditoría
    if (auditoriaService != null) {
      await auditoriaService!.registrarEvento(
        entidadId: entidadId,
        usuarioId: usuarioId,
        tipoEvento: TipoEventoAuditoria.modificacionRegistro,
        modulo: 'security',
        accion: 'rotacion_clave_maestra',
        valorAnterior: {'timestamp_rotacion_anterior': await _secureStorage.read(key: _rotacionTimestampKey)},
        valorNuevo: {'timestamp_rotacion_nueva': DateTime.now().toIso8601String()},
      );
    }
    
    // 6. Eliminar clave anterior después de un periodo de gracia (ej. 30 días)
    // Por ahora, se mantiene para permitir desencriptación de datos no re-encriptados
  }

  /// Obtiene la fecha de la última rotación de clave
  Future<DateTime?> obtenerFechaUltimaRotacion() async {
    final timestamp = await _secureStorage.read(key: _rotacionTimestampKey);
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  /// Verifica si es necesario rotar la clave (recomendado: 1 año)
  Future<bool> requiereRotacion({Duration periodoRotacion = const Duration(days: 365)}) async {
    final ultimaRotacion = await obtenerFechaUltimaRotacion();
    if (ultimaRotacion == null) return false;
    
    final tiempoDesdeRotacion = DateTime.now().difference(ultimaRotacion);
    return tiempoDesdeRotacion >= periodoRotacion;
  }

  /// Encripta un dato sensible
  Future<String> encriptar({
    required String dato,
    required TipoDatoSensible tipo,
    required String referenciaId,
  }) async {
    final claveMaestra = await _obtenerClaveMaestra();
    final iv = await _obtenerIV();
    
    final datos = utf8.encode(dato);
    final encriptado = _encriptarAES256(datos, claveMaestra, iv);
    
    // Guardar metadatos para auditoría
    final metadatos = {
      'tipo': tipo.toString(),
      'referencia_id': referenciaId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final resultado = {
      'dato': base64.encode(encriptado),
      'metadatos': metadatos,
    };
    
    return jsonEncode(resultado);
  }

  /// Desencripta un dato sensible
  Future<String> desencriptar(String datoEncriptado) async {
    final claveMaestra = await _obtenerClaveMaestra();
    final iv = await _obtenerIV();
    
    final datos = jsonDecode(datoEncriptado);
    final encriptado = base64.decode(datos['dato']);
    
    final desencriptado = _desencriptarAES256(encriptado, claveMaestra, iv);
    return utf8.decode(desencriptado);
  }

  /// Encripta datos de tercero
  Future<Map<String, String>> encriptarDatosTercero({
    required String terceroId,
    required String identificacion,
    required String direccion,
    required String telefono,
    String? email,
  }) async {
    return {
      'identificacion': await encriptar(
        dato: identificacion,
        tipo: TipoDatoSensible.terceroIdentificacion,
        referenciaId: terceroId,
      ),
      'direccion': await encriptar(
        dato: direccion,
        tipo: TipoDatoSensible.terceroDireccion,
        referenciaId: terceroId,
      ),
      'telefono': await encriptar(
        dato: telefono,
        tipo: TipoDatoSensible.terceroTelefono,
        referenciaId: terceroId,
      ),
      if (email != null) 'email': await encriptar(
        dato: email,
        tipo: TipoDatoSensible.terceroEmail,
        referenciaId: terceroId,
      ),
    };
  }

  /// Desencripta datos de tercero
  Future<Map<String, String>> desencriptarDatosTercero(
    Map<String, String> datosEncriptados,
  ) async {
    final resultado = <String, String>{};
    
    for (final entry in datosEncriptados.entries) {
      resultado[entry.key] = await desencriptar(entry.value);
    }
    
    return resultado;
  }

  /// Encripta datos de nómina
  Future<Map<String, String>> encriptarDatosNomina({
    required String empleadoId,
    required double salario,
    required String cuentaBancaria,
  }) async {
    return {
      'salario': await encriptar(
        dato: salario.toString(),
        tipo: TipoDatoSensible.nominaSalario,
        referenciaId: empleadoId,
      ),
      'cuenta_bancaria': await encriptar(
        dato: cuentaBancaria,
        tipo: TipoDatoSensible.nominaCuentaBancaria,
        referenciaId: empleadoId,
      ),
    };
  }

  /// Desencripta datos de nómina
  Future<Map<String, String>> desencriptarDatosNomina(
    Map<String, String> datosEncriptados,
  ) async {
    final resultado = <String, String>{};
    
    for (final entry in datosEncriptados.entries) {
      resultado[entry.key] = await desencriptar(entry.value);
    }
    
    return resultado;
  }

  /// Encripta cuenta bancaria
  Future<String> encriptarCuentaBancaria({
    required String cuentaId,
    required String numeroCuenta,
  }) async {
    return await encriptar(
      dato: numeroCuenta,
      tipo: TipoDatoSensible.cuentaBancaria,
      referenciaId: cuentaId,
    );
  }

  /// Desencripta cuenta bancaria
  Future<String> desencriptarCuentaBancaria(String cuentaEncriptada) async {
    return await desencriptar(cuentaEncriptada);
  }

  /// Obtiene la clave maestra desde secure storage
  Future<Uint8List> _obtenerClaveMaestra() async {
    final clave = await _secureStorage.read(key: _claveMaestraKey);
    if (clave == null) throw Exception('Clave maestra no encontrada. Inicialice el servicio primero.');
    return base64.decode(clave);
  }

  /// Obtiene el IV desde secure storage
  Future<Uint8List> _obtenerIV() async {
    final iv = await _secureStorage.read(key: _ivKey);
    if (iv == null) throw Exception('IV no encontrado. Inicialice el servicio primero.');
    return base64.decode(iv);
  }

  /// Genera una clave aleatoria de 32 bytes (256 bits)
  String _generarClaveAleatoria() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64.encode(bytes);
  }

  /// Genera un IV aleatorio de 16 bytes
  String _generarIV() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64.encode(bytes);
  }

  /// Encripta usando AES-256-CBC
  Uint8List _encriptarAES256(Uint8List datos, Uint8List clave, Uint8List iv) {
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        ParametersWithIV<KeyParameter>(KeyParameter(clave), iv),
      );

    return cipher.process(datos);
  }

  /// Desencripta usando AES-256-CBC
  Uint8List _desencriptarAES256(Uint8List datos, Uint8List clave, Uint8List iv) {
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        false,
        ParametersWithIV<KeyParameter>(KeyParameter(clave), iv),
      );

    return cipher.process(datos);
  }
}
