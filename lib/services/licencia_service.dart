import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../db_helper.dart';
import 'control_center_license_client.dart';
import 'hardware_fingerprint_service.dart';
import 'license_secure_store.dart';
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
    this.clientId,
    this.clientName,
    this.maxUsers,
    this.maxDevices,
    this.maxBranches,
    this.installationId,
    this.postgresCredentials,
    this.lastSuccessfulValidationAt,
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
  final String? clientId;
  final String? clientName;
  final int? maxUsers;
  final int? maxDevices;
  final int? maxBranches;
  final String? installationId;
  final Map<String, dynamic>? postgresCredentials;
  final DateTime? lastSuccessfulValidationAt;

  bool get esValida =>
      estado == EstadoLicencia.activa || estado == EstadoLicencia.trial;

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
      'client_id': clientId,
      'client_name': clientName,
      'max_users': maxUsers,
      'max_devices': maxDevices,
      'max_branches': maxBranches,
      'installation_id': installationId,
      'postgres_credentials': postgresCredentials,
      'last_successful_validation_at': lastSuccessfulValidationAt
          ?.toIso8601String(),
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
      modulosHabilitados:
          (jsonDecode(map['modulos_habilitados'] as String) as List)
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
      clientId: map['client_id'] as String?,
      clientName: map['client_name'] as String?,
      maxUsers: _toInt(map['max_users']),
      maxDevices: _toInt(map['max_devices']),
      maxBranches: _toInt(map['max_branches']),
      installationId: map['installation_id'] as String?,
      postgresCredentials: map['postgres_credentials'] is Map
          ? (map['postgres_credentials'] as Map).cast<String, dynamic>()
          : null,
      lastSuccessfulValidationAt:
          map['last_successful_validation_at'] is String
          ? DateTime.tryParse(map['last_successful_validation_at'] as String)
          : null,
    );
  }

  LicenciaInfo copyWith({
    EstadoLicencia? estado,
    DateTime? fechaExpiracion,
    List<String>? modulosHabilitados,
    int? limiteDbMb,
    String? offlineToken,
    String? clientId,
    String? clientName,
    int? maxUsers,
    int? maxDevices,
    int? maxBranches,
    String? installationId,
    Map<String, dynamic>? postgresCredentials,
    DateTime? lastSuccessfulValidationAt,
  }) {
    return LicenciaInfo(
      uuid: uuid,
      plan: plan,
      estado: estado ?? this.estado,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      modulosHabilitados: modulosHabilitados ?? this.modulosHabilitados,
      limiteDbMb: limiteDbMb ?? this.limiteDbMb,
      alertaVencimientoDias: alertaVencimientoDias,
      tipoLicencia: tipoLicencia,
      hardwareFingerprint: hardwareFingerprint,
      offlineToken: offlineToken ?? this.offlineToken,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      maxUsers: maxUsers ?? this.maxUsers,
      maxDevices: maxDevices ?? this.maxDevices,
      maxBranches: maxBranches ?? this.maxBranches,
      installationId: installationId ?? this.installationId,
      postgresCredentials: postgresCredentials ?? this.postgresCredentials,
      lastSuccessfulValidationAt:
          lastSuccessfulValidationAt ?? this.lastSuccessfulValidationAt,
    );
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class LicenciaService {
  LicenciaService._();

  static final LicenciaService instance = LicenciaService._();

  LicenciaInfo? _licenciaCache;
  static const Duration gracePeriod = Duration(days: 7);
  LicenseSecureStore _secureStore = LicenseSecureStore();

  void configureSecureStoreForTests(LicenseSecureStore store) {
    _secureStore = store;
    _licenciaCache = null;
  }

  Future<LicenciaInfo?> obtenerLicencia() async {
    if (_licenciaCache != null) return _licenciaCache;

    try {
      final map = await _secureStore.read();
      if (map == null) return null;
      _licenciaCache = LicenciaInfo.fromMap(map);
      return _licenciaCache;
    } catch (e) {
      debugPrint('Error al parsear licencia: $e');
      return null;
    }
  }

  Future<void> guardarLicencia(LicenciaInfo licencia) async {
    await _secureStore.write(licencia.toMap());
    _licenciaCache = licencia;

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'LICENCIA_ACTUALIZADA',
      entidad: 'licencia',
      detalle: 'Plan: ${licencia.plan.name}, Estado: ${licencia.estado.name}',
    );
  }

  Future<void> limpiarLicenciaDuplicada() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave IN (?, ?)',
      whereArgs: [
        LicenseSecureStore.legacyConfigKey,
        LicenseSecureStore.encryptedConfigKey,
      ],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final licencia = await obtenerLicencia();
    if (licencia == null) return;
    if (licencia.estado == EstadoLicencia.activa ||
        licencia.estado == EstadoLicencia.trial) {
      return;
    }

    await db.delete(
      'app_config',
      where: 'clave IN (?, ?)',
      whereArgs: [
        LicenseSecureStore.legacyConfigKey,
        LicenseSecureStore.encryptedConfigKey,
      ],
    );
    _licenciaCache = null;
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

  Future<void> actualizarEstadoDesdeControlCenter(
    Map<String, dynamic> datos,
  ) async {
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
      clientId: licenciaActual.clientId,
      clientName: licenciaActual.clientName,
      maxUsers: licenciaActual.maxUsers,
      maxDevices: licenciaActual.maxDevices,
      maxBranches: licenciaActual.maxBranches,
      installationId: licenciaActual.installationId,
      postgresCredentials: licenciaActual.postgresCredentials,
      lastSuccessfulValidationAt: DateTime.now().toUtc(),
    );

    await guardarLicencia(licenciaActualizada);
  }

  Future<bool> activarDesdeControlCenter({
    required String email,
    required String password,
    ControlCenterLicenseClient? client,
    LicenseValidationService? validationService,
    HardwareFingerprintService? fingerprintService,
    String? currentHardwareFingerprint,
  }) async {
    final hardwareService = fingerprintService ?? HardwareFingerprintService();
    final fingerprint =
        currentHardwareFingerprint ?? await hardwareService.generateFingerprint();
    final ccClient = client ?? const ControlCenterLicenseClient();
    final response = await ccClient.activate(
      email: email,
      password: password,
      hardwareFingerprint: fingerprint,
    );
    final token = _extractString(response, const [
      'license_token',
      'token',
      'jwt',
    ]);
    if (token == null || token.trim().isEmpty) return false;

    final validator = validationService ?? LicenseValidationService();
    final tokenData = await validator.validateOfflineTokenForDevice(
      token,
      fingerprint,
    );
    if (tokenData == null) return false;

    final licenseData = _extractMap(response, const ['license', 'data']);
    final metadata = licenseData ?? response;
    final modules = _extractModules(metadata, tokenData);
    final expiry = _extractDate(metadata, const ['expires_at', 'expiresAt']) ??
        DateTime.parse(tokenData['ed'] as String);
    final licenseType = _extractString(metadata, const [
          'license_type',
          'licenseType',
          'type',
        ]) ??
        tokenData['lt'] as String;
    final status = _extractString(metadata, const ['status', 'estado']) ??
        tokenData['st'] as String;

    final licencia = LicenciaInfo(
      uuid: await hardwareService.generateUUID(),
      plan: _determinarPlanDesdeModulos(modules),
      estado: _estadoDesdeControlCenter(status),
      fechaExpiracion: expiry,
      modulosHabilitados: modules,
      tipoLicencia: licenseType.toUpperCase() == 'PERPETUA'
          ? TipoLicencia.perpetua
          : TipoLicencia.suscripcion,
      hardwareFingerprint: fingerprint,
      offlineToken: token,
      clientId: _extractString(metadata, const ['client_id', 'clientId']),
      clientName: _extractString(metadata, const ['client_name', 'clientName']),
      maxUsers: _extractInt(metadata, const ['max_users', 'maxUsers']),
      maxDevices: _extractInt(metadata, const ['max_devices', 'maxDevices']),
      maxBranches: _extractInt(metadata, const ['max_branches', 'maxBranches']),
      installationId:
          _extractString(metadata, const ['installation_id', 'installationId']),
      postgresCredentials: _extractMap(metadata, const [
        'postgres_credentials',
        'postgresCredentials',
      ]),
      lastSuccessfulValidationAt: DateTime.now().toUtc(),
    );

    await guardarLicencia(licencia);
    return true;
  }

  Future<bool> validarConControlCenterOGracia({
    ControlCenterLicenseClient? client,
    LicenseValidationService? validationService,
    HardwareFingerprintService? fingerprintService,
    String? currentHardwareFingerprint,
    DateTime? now,
  }) async {
    final licencia = await obtenerLicencia();
    final token = licencia?.offlineToken;
    if (licencia == null || token == null || token.trim().isEmpty) {
      return false;
    }

    final effectiveNow = now ?? DateTime.now().toUtc();
    final hardwareService = fingerprintService ?? HardwareFingerprintService();
    final fingerprint =
        currentHardwareFingerprint ?? await hardwareService.generateFingerprint();
    final validator = validationService ?? LicenseValidationService();
    final tokenData = await validator.validateOfflineTokenForDevice(
      token,
      fingerprint,
    );
    if (tokenData == null) return false;

    final tokenExpiry = DateTime.parse(tokenData['ed'] as String).toUtc();
    if (licencia.tipoLicencia != TipoLicencia.perpetua &&
        effectiveNow.isAfter(tokenExpiry)) {
      return false;
    }

    try {
      final ccClient = client ?? const ControlCenterLicenseClient();
      final response = await ccClient.validate(
        licenseToken: token,
        hardwareFingerprint: fingerprint,
        installationId: licencia.installationId ?? licencia.uuid,
      );
      final valid = response['valid'] == true || response['success'] == true;
      if (!valid) return false;
      await guardarLicencia(
        licencia.copyWith(lastSuccessfulValidationAt: effectiveNow),
      );
      return true;
    } on ControlCenterNetworkException {
      return _validarModoGracia(licencia, tokenExpiry, effectiveNow);
    } on SocketException {
      return _validarModoGracia(licencia, tokenExpiry, effectiveNow);
    } on TimeoutException {
      return _validarModoGracia(licencia, tokenExpiry, effectiveNow);
    }
  }

  /// Activar licencia desde token offline
  Future<bool> activarDesdeTokenOffline(
    String token, {
    LicenseValidationService? validationService,
    HardwareFingerprintService? fingerprintService,
    String? currentHardwareFingerprint,
  }) async {
    final validator = validationService ?? LicenseValidationService();
    final hardwareService = fingerprintService ?? HardwareFingerprintService();

    final currentFingerprint =
        currentHardwareFingerprint ??
        await hardwareService.generateFingerprint();
    final tokenData = await validator.validateOfflineTokenForDevice(
      token,
      currentFingerprint,
    );
    if (tokenData == null) {
      debugPrint('Token inválido');
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
      uuid: await hardwareService.generateUUID(),
      plan: plan,
      estado: estado,
      fechaExpiracion: DateTime.parse(tokenData['ed'] as String),
      modulosHabilitados: (tokenData['md'] as List)
          .map((e) => e.toString())
          .toList(),
      tipoLicencia: tipoLicencia,
      hardwareFingerprint: currentFingerprint,
      offlineToken: token,
    );

    await guardarLicencia(licencia);
    return true;
  }

  /// Validar licencia local (para uso offline)
  Future<bool> validarLicenciaLocal({
    LicenseValidationService? validationService,
    HardwareFingerprintService? fingerprintService,
    String? currentHardwareFingerprint,
  }) async {
    final licencia = await obtenerLicencia();
    final token = licencia?.offlineToken;
    if (licencia == null || token == null || token.trim().isEmpty) return false;

    final validator = validationService ?? LicenseValidationService();
    final hardwareService = fingerprintService ?? HardwareFingerprintService();
    final currentFingerprint =
        currentHardwareFingerprint ??
        await hardwareService.generateFingerprint();
    final tokenData = await validator.validateOfflineTokenForDevice(
      token,
      currentFingerprint,
    );
    if (tokenData == null) return false;
    final tokenFingerprint = tokenData['hfp'] as String;

    final expectedType = tokenData['lt'] == 'PERPETUA'
        ? TipoLicencia.perpetua
        : TipoLicencia.suscripcion;
    final expectedStatus = tokenData['st'] == 'ACTIVO'
        ? EstadoLicencia.activa
        : EstadoLicencia.trial;
    final expectedExpiry = DateTime.parse(tokenData['ed'] as String);
    final expectedModules = (tokenData['md'] as List)
        .map((module) => module.toString())
        .toList();

    return licencia.tipoLicencia == expectedType &&
        licencia.estado == expectedStatus &&
        licencia.plan == _determinarPlanDesdeModulos(expectedModules) &&
        licencia.fechaExpiracion.toUtc().millisecondsSinceEpoch ==
            expectedExpiry.toUtc().millisecondsSinceEpoch &&
        licencia.hardwareFingerprint == tokenFingerprint &&
        _sameModules(licencia.modulosHabilitados, expectedModules);
  }

  /// Validar hardware fingerprint actual contra licencia
  Future<bool> validarHardwareFingerprint() async {
    final licencia = await obtenerLicencia();
    if (licencia == null || licencia.hardwareFingerprint == null) return false;

    final fingerprintService = HardwareFingerprintService();
    final currentFingerprint = await fingerprintService.generateFingerprint();

    return currentFingerprint == licencia.hardwareFingerprint;
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
    final licencia = _licenciaCache;
    final last = licencia?.lastSuccessfulValidationAt;
    if (last == null) return 0;
    final deadline = last.toUtc().add(gracePeriod);
    final remaining = deadline.difference(DateTime.now().toUtc()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool _validarModoGracia(
    LicenciaInfo licencia,
    DateTime tokenExpiry,
    DateTime now,
  ) {
    final last = licencia.lastSuccessfulValidationAt;
    if (last == null) return false;
    final graceDeadline = last.toUtc().add(gracePeriod);
    final effectiveDeadline = tokenExpiry.isBefore(graceDeadline)
        ? tokenExpiry
        : graceDeadline;
    return !now.isAfter(effectiveDeadline);
  }

  TipoPlan _determinarPlanDesdeModulos(List<dynamic> modulos) {
    final modulosSet = modulos.map((e) => e.toString()).toSet();

    if (modulosSet.contains('nomina') || modulosSet.contains('activos_fijos')) {
      return TipoPlan.enterprise;
    } else if (modulosSet.contains('contabilidad') ||
        modulosSet.contains('cartera')) {
      return TipoPlan.profesional;
    } else {
      return TipoPlan.basico;
    }
  }

  bool _sameModules(List<String> local, List<String> signed) {
    if (local.length != signed.length) return false;
    return local.toSet().containsAll(signed) &&
        signed.toSet().containsAll(local);
  }

  List<String> _modulosPorPlan(TipoPlan plan) {
    switch (plan) {
      case TipoPlan.basico:
        return ['ventas', 'inventario', 'caja', 'reportes_basicos'];
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
        return ['ventas', 'inventario', 'caja', 'reportes_basicos'];
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

  String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  int? _extractInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  DateTime? _extractDate(Map<String, dynamic> data, List<String> keys) {
    final value = _extractString(data, keys);
    return value == null ? null : DateTime.tryParse(value);
  }

  Map<String, dynamic>? _extractMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.cast<String, dynamic>();
    }
    return null;
  }

  List<String> _extractModules(
    Map<String, dynamic> metadata,
    Map<String, dynamic> tokenData,
  ) {
    final raw = metadata['modules'] ?? metadata['modulos'] ?? tokenData['md'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    return const [];
  }

  EstadoLicencia _estadoDesdeControlCenter(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVO':
      case 'ACTIVE':
        return EstadoLicencia.activa;
      case 'SUSPENDIDO':
      case 'SUSPENDED':
        return EstadoLicencia.suspendida;
      case 'EXPIRADO':
      case 'EXPIRED':
        return EstadoLicencia.expirada;
      case 'TRIAL':
      default:
        return EstadoLicencia.trial;
    }
  }
}
