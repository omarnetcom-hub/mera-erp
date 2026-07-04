import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import 'hardware_fingerprint_service.dart';
import 'license_validation_service.dart';

enum TipoPlan { basico, profesional, enterprise, trial }

enum EstadoLicencia { activa, expirada, suspendida, trial }

enum TipoLicencia { suscripcion, perpetua }

class LicenciaInfo {
  const LicenciaInfo({
    required this.uuid,
    required this.plan,
    required this.estado,
    required this.fechaExpiracion,
    required this.modulosHabilitados,
    this.limiteDbMb,
    this.alertaVencimientoDias = 30,
    this.tipoLicencia = TipoLicencia.suscripcion,
    this.hardwareFingerprint,
    this.offlineToken,
  });

  final String uuid;
  final TipoPlan plan;
  final EstadoLicencia estado;
  final DateTime fechaExpiracion;
  final List<String> modulosHabilitados;
  final int? limiteDbMb;
  final int alertaVencimientoDias;
  final TipoLicencia tipoLicencia;
  final String? hardwareFingerprint;
  final String? offlineToken;

  bool get esValida => estado == EstadoLicencia.activa || estado == EstadoLicencia.trial;

  bool get estaPorVencer {
    // Licencias perpetuas no vencen
    if (tipoLicencia == TipoLicencia.perpetua) return false;
    
    final diasRestantes = fechaExpiracion.difference(DateTime.now()).inDays;
    return diasRestantes <= alertaVencimientoDias && diasRestantes > 0;
  }

  bool get estaExpirada {
    // Licencias perpetuas no expiran
    if (tipoLicencia == TipoLicencia.perpetua) return false;
    return DateTime.now().isAfter(fechaExpiracion);
  }

  bool tieneModulo(String modulo) => modulosHabilitados.contains(modulo);

  bool get requiereValidacionOnline => tipoLicencia == TipoLicencia.suscripcion;

  Map<String, Object?> toMap() {
    return {
      'uuid': uuid,
      'plan': plan.name,
      'estado': estado.name,
      'fecha_expiracion': fechaExpiracion.toIso8601String(),
      'modulos_habilitados': jsonEncode(modulosHabilitados),
      'limite_db_mb': limiteDbMb,
      'alerta_vencimiento_dias': alertaVencimientoDias,
      'tipo_licencia': tipoLicencia.name,
      'hardware_fingerprint': hardwareFingerprint,
      'offline_token': offlineToken,
    };
  }

  static LicenciaInfo fromMap(Map<String, dynamic> map) {
    return LicenciaInfo(
      uuid: map['uuid'] as String,
      plan: TipoPlan.values.firstWhere(
        (e) => e.name == map['plan'],
        orElse: () => TipoPlan.basico,
      ),
      estado: EstadoLicencia.values.firstWhere(
        (e) => e.name == map['estado'],
        orElse: () => EstadoLicencia.trial,
      ),
      fechaExpiracion: DateTime.parse(map['fecha_expiracion'] as String),
      modulosHabilitados: (jsonDecode(map['modulos_habilitados'] as String) as List)
          .map((e) => e.toString())
          .toList(),
      limiteDbMb: map['limite_db_mb'] as int?,
      alertaVencimientoDias: map['alerta_vencimiento_dias'] as int? ?? 30,
      tipoLicencia: TipoLicencia.values.firstWhere(
        (e) => e.name == map['tipo_licencia'],
        orElse: () => TipoLicencia.suscripcion,
      ),
      hardwareFingerprint: map['hardware_fingerprint'] as String?,
      offlineToken: map['offline_token'] as String?,
    );
  }
}

class LicenciaService {
  LicenciaService._();

  static final LicenciaService instance = LicenciaService._();

  LicenciaInfo? _licenciaCache;
  static const String _claveConfig = 'licencia_info';

  Future<LicenciaInfo?> obtenerLicencia() async {
    if (_licenciaCache != null) return _licenciaCache;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [_claveConfig],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    try {
      _licenciaCache = LicenciaInfo.fromMap(rows.first);
      return _licenciaCache;
    } catch (e) {
      debugPrint('Error al parsear licencia: $e');
      return null;
    }
  }

  Future<void> guardarLicencia(LicenciaInfo licencia) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {
        'clave': _claveConfig,
        'valor': jsonEncode(licencia.toMap()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace
    );
    _licenciaCache = licencia;

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'LICENCIA_ACTUALIZADA',
      entidad: 'licencia',
      detalle: 'Plan: ${licencia.plan.name}, Estado: ${licencia.estado.name}',
    );
  }

  Future<void> generarLicenciaInicial() async {
    final existente = await obtenerLicencia();
    if (existente != null) return;

    final uuid = _generarUuid();
    final licenciaInicial = LicenciaInfo(
      uuid: uuid,
      plan: TipoPlan.trial,
      estado: EstadoLicencia.trial,
      fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
      modulosHabilitados: _modulosPorPlan(TipoPlan.trial),
      limiteDbMb: 100,
    );

    await guardarLicencia(licenciaInicial);
  }

  Future<bool> validarModulo(String modulo) async {
    final licencia = await obtenerLicencia();
    if (licencia == null) {
      await generarLicenciaInicial();
      return (await obtenerLicencia())?.tieneModulo(modulo) ?? false;
    }

    if (!licencia.esValida) return false;
    return licencia.tieneModulo(modulo);
  }

  Future<bool> verificarLimiteDb(int tamanoMbActual) async {
    final licencia = await obtenerLicencia();
    if (licencia == null || licencia.limiteDbMb == null) return true;

    return tamanoMbActual <= licencia.limiteDbMb!;
  }

  Future<void> actualizarEstadoDesdeControlCenter(Map<String, dynamic> datos) async {
    final licenciaActual = await obtenerLicencia();
    if (licenciaActual == null) return;

    final nuevoEstado = EstadoLicencia.values.firstWhere(
      (e) => e.name == datos['estado'],
      orElse: () => licenciaActual.estado,
    );

    final nuevoPlan = TipoPlan.values.firstWhere(
      (e) => e.name == datos['plan'],
      orElse: () => licenciaActual.plan,
    );

    DateTime? nuevaExpiracion = licenciaActual.fechaExpiracion;
    if (datos['fecha_expiracion'] != null) {
      nuevaExpiracion = DateTime.parse(datos['fecha_expiracion'] as String);
    }

    final licenciaActualizada = LicenciaInfo(
      uuid: licenciaActual.uuid,
      plan: nuevoPlan,
      estado: nuevoEstado,
      fechaExpiracion: nuevaExpiracion,
      modulosHabilitados: datos['modulos'] != null
          ? (datos['modulos'] as List).map((e) => e.toString()).toList()
          : licenciaActual.modulosHabilitados,
      limiteDbMb: datos['limite_db_mb'] as int? ?? licenciaActual.limiteDbMb,
      tipoLicencia: licenciaActual.tipoLicencia,
      hardwareFingerprint: licenciaActual.hardwareFingerprint,
      offlineToken: licenciaActual.offlineToken,
    );

    await guardarLicencia(licenciaActualizada);
  }

  /// Activar licencia desde token offline
  Future<bool> activarDesdeTokenOffline(String token) async {
    final validationService = LicenseValidationService();
    final fingerprintService = HardwareFingerprintService();
    
    // Validar token
    final tokenData = validationService.validateOfflineToken(token);
    if (tokenData == null) {
      debugPrint('Token inválido');
      return false;
    }
    
    // Verificar hardware fingerprint
    final currentFingerprint = await fingerprintService.generateFingerprint();
    final tokenFingerprint = tokenData['hfp'] as String;
    
    if (!await fingerprintService.validateFingerprint(tokenFingerprint)) {
      debugPrint('Hardware fingerprint no coincide');
      return false;
    }
    
    // Verificar expiración
    if (validationService.isTokenExpired(tokenData)) {
      debugPrint('Token expirado');
      return false;
    }
    
    // Verificar estado
    if (!validationService.isTokenActive(tokenData)) {
      debugPrint('Token inactivo');
      return false;
    }
    
    // Crear licencia desde token
    final tipoLicencia = tokenData['lt'] == 'PERPETUA' 
        ? TipoLicencia.perpetua 
        : TipoLicencia.suscripcion;
    
    final estado = tokenData['st'] == 'ACTIVO' 
        ? EstadoLicencia.activa 
        : EstadoLicencia.trial;
    
    final plan = _determinarPlanDesdeModulos(tokenData['md'] as List);
    
    final licencia = LicenciaInfo(
      uuid: await fingerprintService.generateUUID(),
      plan: plan,
      estado: estado,
      fechaExpiracion: DateTime.parse(tokenData['ed'] as String),
      modulosHabilitados: (tokenData['md'] as List).map((e) => e.toString()).toList(),
      tipoLicencia: tipoLicencia,
      hardwareFingerprint: currentFingerprint,
      offlineToken: token,
    );
    
    await guardarLicencia(licencia);
    return true;
  }

  /// Validar licencia local (para uso offline)
  Future<bool> validarLicenciaLocal() async {
    final licencia = await obtenerLicencia();
    if (licencia == null) return false;
    
    // Si es perpetua, solo validar que esté activa
    if (licencia.tipoLicencia == TipoLicencia.perpetua) {
      return licencia.esValida;
    }
    
    // Si es suscripción, validar expiración
    return licencia.esValida && !licencia.estaExpirada;
  }

  /// Validar hardware fingerprint actual contra licencia
  Future<bool> validarHardwareFingerprint() async {
    final licencia = await obtenerLicencia();
    if (licencia == null || licencia.hardwareFingerprint == null) return false;
    
    final fingerprintService = HardwareFingerprintService();
    final currentFingerprint = await fingerprintService.generateFingerprint();
    
    return await fingerprintService.validateFingerprint(licencia.hardwareFingerprint!);
  }

  /// Verificar si se requiere reactivación (cambio de hardware)
  Future<bool> requiereReactivacion() async {
    final licencia = await obtenerLicencia();
    if (licencia == null) return true;
    
    if (licencia.hardwareFingerprint == null) return false;
    
    return !(await validarHardwareFingerprint());
  }

  /// Obtener días de gracia restantes para suscripciones
  int getDiasGraciaRestantes() {
    // Implementar lógica de gracia si es necesario
    return 0;
  }

  TipoPlan _determinarPlanDesdeModulos(List<dynamic> modulos) {
    final modulosSet = modulos.map((e) => e.toString()).toSet();
    
    if (modulosSet.contains('nomina') || modulosSet.contains('activos_fijos')) {
      return TipoPlan.enterprise;
    } else if (modulosSet.contains('contabilidad') || modulosSet.contains('cartera')) {
      return TipoPlan.profesional;
    } else {
      return TipoPlan.basico;
    }
  }

  List<String> _modulosPorPlan(TipoPlan plan) {
    switch (plan) {
      case TipoPlan.basico:
        return [
          'ventas',
          'inventario',
          'caja',
          'reportes_basicos',
        ];
      case TipoPlan.profesional:
        return [
          'ventas',
          'inventario',
          'caja',
          'bancos',
          'cartera',
          'contabilidad',
          'reportes_basicos',
          'reportes_avanzados',
        ];
      case TipoPlan.enterprise:
        return [
          'ventas',
          'inventario',
          'caja',
          'bancos',
          'cartera',
          'contabilidad',
          'nomina',
          'activos_fijos',
          'conciliacion',
          'auditoria',
          'reportes_basicos',
          'reportes_avanzados',
          'crm',
          'produccion',
          'api_publica',
          'ecommerce_sync',
          'portal_clientes',
        ];
      case TipoPlan.trial:
        return [
          'ventas',
          'inventario',
          'caja',
          'reportes_basicos',
        ];
    }
  }

  String _generarUuid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final data = '$timestamp-$random';
    final digest = sha256.convert(utf8.encode(data));
    return 'MERKA-${digest.toString().substring(0, 32).toUpperCase()}';
  }

  Future<void> limpiarCache() {
    _licenciaCache = null;
    return Future.value();
  }
}
