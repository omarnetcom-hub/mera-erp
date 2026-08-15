import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'services/licencia_service.dart';
import 'services/update_service.dart';
import 'services/health_reporter.dart';
import 'services/cc_commands_processor.dart';
import 'services/hardware_fingerprint_service.dart';
import 'services/control_center_endpoint.dart';
import 'services/control_center_license_client.dart';

class ControlCenterAgent {
  const ControlCenterAgent._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const defaultEndpoint = ControlCenterEndpoint.defaultEndpoint;
  static Timer? _telemetryTimer;
  static Timer? _commandTimer;

  static void startBackground() {
    // Inicializar licencia si no existe
    LicenciaService.instance.generarLicenciaInicial();
    
    // Configurar endpoint por defecto si no está configurado
    _configureDefaultEndpoint();
    
    // Iniciar health reporter
    HealthReporter.instance.iniciar();
    
    // Buscar actualizaciones al inicio
    UpdateService.instance.buscarActualizacion();
    
    sendStartupHeartbeat();
    
    // Enviar heartbeat cada 5 minutos
    _telemetryTimer?.cancel();
    _commandTimer?.cancel();
    _telemetryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => sendStartupHeartbeat(),
    );
    _commandTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => pollRemoteCommands(),
    );
  }

  static Future<void> _configureDefaultEndpoint() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_config',
        where: 'clave = ?',
        whereArgs: ['control_center_endpoint'],
        limit: 1,
      );
      
      if (rows.isEmpty) {
        // Configurar endpoint por defecto si no existe
        await db.insert('app_config', {
          'clave': 'control_center_endpoint',
          'valor': defaultEndpoint,
        });
      } else {
        final val = rows.first['valor']?.toString();
        if (val == 'http://localhost:3000' || val == 'http://localhost:8787' || val == 'http://127.0.0.1:8787') {
          await db.update(
            'app_config',
            {'valor': defaultEndpoint},
            where: 'clave = ?',
            whereArgs: ['control_center_endpoint'],
          );
        }
      }
    } catch (error) {
      debugPrint('Error al configurar endpoint por defecto: $error');
    }
  }

  static Future<void> sendStartupHeartbeat() async {
    try {
      final endpoint = await _endpoint();
      final payload = await _heartbeatPayload();
      debugPrint('Control Center: Enviando heartbeat a $endpoint');
      debugPrint('Control Center: Payload: $payload');
      await ControlCenterLicenseClient(endpoint: endpoint).heartbeat(payload);
      debugPrint('Control Center: Heartbeat enviado exitosamente');
      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'CONTROL_CENTER_HEARTBEAT',
        entidad: 'control_center',
        detalle: endpoint,
      );
    } catch (error) {
      debugPrint('Control Center heartbeat skipped: $error');
    }
  }

  static Future<void> reportEvent({
    required String event,
    required String module,
    String severity = 'info',
  }) async {
    try {
      final endpoint = await _endpoint();
      final company = await DatabaseHelper.instance.obtenerEmpresaConfig();
      await _postJson(Uri.parse('$endpoint/api/v1/telemetry/events'), {
        'companyName': company['nombre']?.toString() ?? 'MerkaERP local',
        'taxId': company['nit']?.toString() ?? '',
        'event': event,
        'module': module,
        'severity': severity,
      });
    } catch (error) {
      debugPrint('Control Center telemetry skipped: $error');
    }
  }

  static Future<void> pollRemoteCommands() async {
    try {
      // Verificar si la instalación está bloqueada
      final bloqueada = await CCCommandsProcessor.instance.verificarInstalacionBloqueada();
      if (bloqueada) {
        debugPrint('Instalación bloqueada por Control Center');
        return;
      }

      final endpoint = await _endpoint();
      final installationId = await _installationId();
      final client = ControlCenterLicenseClient(endpoint: endpoint);
      final commands = await client.commands(installationId);
      for (final command in commands) {
        final id = command['id']?.toString() ?? command['commandId']?.toString();
        final result = await _executeRemoteCommand(command);
        if (id != null && id.isNotEmpty) {
          final ackStatus = result.datos?['ack_status']?.toString() ??
              (result.exito ? 'done' : 'failed');
          await client.ackCommand(
            commandId: id,
            installationId: installationId,
            status: ackStatus,
            message: result.mensaje,
          );
        }
      }
    } catch (error) {
      debugPrint('Control Center command polling skipped: $error');
    }
  }

  @visibleForTesting
  static Future<ResultadoComando> processCommandForTests(
    Map<String, Object?> command,
  ) {
    return _executeRemoteCommand(command);
  }

  static Future<String> _endpoint() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_endpoint'],
      limit: 1,
    );
    final value = rows.isEmpty ? null : rows.first['valor']?.toString().trim();
    return ControlCenterEndpoint.normalize(value ?? defaultEndpoint);
  }

  static Future<String?> _authToken() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['sync_auth_token'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['valor']?.toString();
  }

  static Future<Map<String, Object?>> _heartbeatPayload() async {
    final db = await DatabaseHelper.instance.database;
    final company = await DatabaseHelper.instance.obtenerEmpresaConfig();
    final sw = Stopwatch()..start();
    await db.rawQuery('SELECT 1');
    sw.stop();
    
    // Obtener métricas de salud del HealthReporter
    final healthMetrics = await HealthReporter.instance.recolectarMetricas();
    
    // Obtener información de licencia
    final licencia = await LicenciaService.instance.obtenerLicencia();
    
    // Obtener hardware fingerprint para validación dual
    final hardwareFingerprint = await HardwareFingerprintService().generateFingerprint();
    
    final syncRows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM sqlite_master WHERE type = 'table' AND name = 'sync_outbox'",
    );
    var syncStatus = 'not_configured';
    if (((syncRows.first['total'] as num?)?.toInt() ?? 0) > 0) {
      final pending = await db.rawQuery(
        "SELECT COUNT(*) AS total FROM sync_outbox WHERE status IN ('pending', 'failed')",
      );
      syncStatus = (((pending.first['total'] as num?)?.toInt() ?? 0) == 0)
          ? 'ok'
          : 'pending';
    }
    
    // Verificar si hay actualización disponible
    final actualizacionDisponible = await UpdateService.instance.buscarActualizacion();
    
    return {
      'installationId': await _installationId(),
      'hardwareFingerprint': hardwareFingerprint,
      'companyName': company['nombre']?.toString() ?? 'MerkaERP local',
      'taxId': company['nit']?.toString() ?? '',
      'version': '1.0.0',
      'os': Platform.operatingSystem,
      'licenseStatus': licencia?.estado.name ?? 'local',
      'licensePlan': licencia?.plan.name ?? 'unknown',
      'licenseExpiry': licencia?.fechaExpiracion.toIso8601String(),
      'licenseType': licencia?.tipoLicencia.name ?? 'SUSCRIPCION',
      'syncStatus': syncStatus,
      'databaseStatus': 'ok',
      'criticalErrors': healthMetrics.erroresCriticos,
      'updateAvailable': actualizacionDisponible != null,
      'updateVersion': actualizacionDisponible?.version,
      'metrics': {
        'dbResponseMs': healthMetrics.dbResponseMs,
        'memoryRssMb': healthMetrics.memoryRssMb,
        'dbSizeMb': healthMetrics.dbSizeMb,
        'lastBackup': healthMetrics.ultimoRespaldo?.toIso8601String(),
        'heartbeatOk': healthMetrics.heartbeatOk,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };
  }

  static Future<String> _installationId() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_installation_id'],
      limit: 1,
    );

    if (rows.isNotEmpty && rows.first['valor']?.toString().isNotEmpty == true) {
      return rows.first['valor']!.toString();
    }

    final hardwareFingerprint = await HardwareFingerprintService().generateFingerprint();
    final fallbackId = 'MERKA-${hardwareFingerprint.substring(0, 12).toUpperCase()}';

    await db.insert('app_config', {
      'clave': 'control_center_installation_id',
      'valor': fallbackId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return fallbackId;
  }

  static Future<void> _postJson(Uri uri, Map<String, Object?> payload) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      
      // Agregar token de autenticación si existe
      final authToken = await _authToken();
      if (authToken != null) {
        request.headers.add('Authorization', 'Bearer $authToken');
      }
      
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<Map<String, Object?>>> _getJsonList(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(uri);
      
      // Agregar token de autenticación si existe
      final authToken = await _authToken();
      if (authToken != null) {
        request.headers.add('Authorization', 'Bearer $authToken');
      }
      
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == 404) return const [];
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final decoded = jsonDecode(body);
      final list = decoded is Map ? decoded['commands'] : decoded;
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map) item.cast<String, Object?>(),
      ];
    } finally {
      client.close(force: true);
    }
  }

  static Future<ResultadoComando> _executeRemoteCommand(
    Map<String, Object?> command,
  ) async {
    final action = command['action']?.toString() ?? '';
    
    // Intentar procesar con el nuevo CCCommandsProcessor
    try {
      final comandoRemoto = ComandoRemoto(
        id: command['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: _mapearTipoComando(action),
        parametros: command,
        timestamp: DateTime.now(),
        firmaHmac: command['signature']?.toString(),
      );
      
      final resultado = await CCCommandsProcessor.instance.procesarComando(comandoRemoto);
      
      if (resultado.exito) {
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'CONTROL_CENTER_COMMAND_${action}_SUCCESS',
          entidad: 'control_center',
          detalle: resultado.mensaje,
        );
        return resultado;
      }
    } catch (e) {
      debugPrint('Error procesando comando con CCCommandsProcessor: $e');
    }
    
    // Fallback al método anterior para comandos no soportados
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    switch (action) {
      case 'enviar_notificacion':
        await db.insert('notificaciones', {
          'company_id': companyId,
          'tipo': 'control_center',
          'prioridad': command['priority']?.toString() ?? 'info',
          'titulo': command['title']?.toString() ?? 'Control Center',
          'detalle': command['detail']?.toString() ?? '',
          'entidad': 'remote_command',
          'entidad_id': null,
          'leida': 0,
          'creada_en': DateTime.now().toIso8601String(),
        });
        return const ResultadoComando(
          exito: true,
          mensaje: 'Notificacion local registrada',
        );
      case 'bloquear_cliente':
      case 'bloquear':
        await db.execute(
          "INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('cliente_bloqueado', '1')",
        );
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'CONTROL_CENTER_COMMAND_bloquear_cliente',
          entidad: 'control_center',
          detalle: jsonEncode(command),
        );
        return const ResultadoComando(
          exito: true,
          mensaje: 'Cliente bloqueado localmente',
        );
      case 'backup':
      case 'forzar_respaldo':
        final file = await DatabaseHelper.instance.crearRespaldo();
        return ResultadoComando(
          exito: true,
          mensaje: 'Backup generado',
          datos: {'path': file.path},
        );
      case 'actualizar':
      case 'forzar_actualizacion':
        final update = await UpdateService.instance.buscarActualizacion();
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'CONTROL_CENTER_COMMAND_$action',
          entidad: 'control_center',
          detalle: update == null
              ? 'No hay actualizacion disponible'
              : 'Actualizacion disponible: ${update.version}',
        );
        return ResultadoComando(
          exito: true,
          mensaje: update == null
              ? 'No hay actualizacion disponible'
              : 'Actualizacion disponible: ${update.version}',
        );
      case 'reiniciar_modulo':
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'CONTROL_CENTER_COMMAND_$action',
          entidad: 'control_center',
          detalle: jsonEncode(command),
        );
        return ResultadoComando(
          exito: true,
          mensaje: 'Comando $action registrado para ejecucion local',
        );
      case 'solicitar_acceso_remoto':
      case 'solicitar_asistencia_remota':
      case 'remote_access':
      case 'remote_access_request':
      case 'acceso_remoto':
        return await handleRemoteAccessConsent(command);
      default:
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'CONTROL_CENTER_COMMAND_UNKNOWN',
          entidad: 'control_center',
          detalle: jsonEncode(command),
        );
        return ResultadoComando(
          exito: false,
          mensaje: 'Comando no soportado: $action',
        );
    }
  }

  static Future<ResultadoComando> handleRemoteAccessConsent(
    Map<String, Object?> command,
  ) async {
    final context = navigatorKey.currentContext;
    bool approved = false;

    if (context != null && context.mounted) {
      approved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.display_settings, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('MERKA solicita acceso remoto'),
                ],
              ),
              content: const Text(
                'El equipo de soporte de Control Center solicita acceso remoto a este equipo para asistencia técnica.\n\n'
                'Nota: Aprobar esta solicitud registrará su consentimiento. No se iniciará captura de pantalla ni transmisión en vivo (Stub pendiente de la Fase RA).',
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Rechazar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Aprobar'),
                ),
              ],
            ),
          ) ??
          false;
    } else {
      await _registrarSolicitudAccesoRemotoStub(command);
      return const ResultadoComando(
        exito: true,
        mensaje:
            'Solicitud de acceso remoto registrada como stub sin UI activa (Fase RA pendiente).',
        datos: {'ack_status': 'done'},
      );
    }

    await _registrarSolicitudAccesoRemotoStub(
      command,
      consentimientoOtorgado: approved,
    );

    return ResultadoComando(
      exito: true,
      mensaje: approved
          ? 'Consentimiento otorgado por el usuario. Stub de acceso remoto (Fase RA pendiente, sin streaming real).'
          : 'Consentimiento denegado por el usuario.',
      datos: {'ack_status': approved ? 'approved' : 'rejected'},
    );
  }

  static Future<void> _registrarSolicitudAccesoRemotoStub(
    Map<String, Object?> command, {
    bool? consentimientoOtorgado,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    final detalleConsent = consentimientoOtorgado == null
        ? 'Stub pendiente Fase RA: no inicia captura ni streaming de pantalla.'
        : (consentimientoOtorgado
            ? 'Consentimiento OTORGADO por el usuario. Stub pendiente Fase RA: no inicia captura ni streaming.'
            : 'Consentimiento DENEGADO por el usuario.');

    await db.insert('notificaciones', {
      'company_id': companyId,
      'tipo': 'control_center',
      'prioridad': 'warning',
      'titulo': 'MERKA solicita acceso remoto',
      'detalle': detalleConsent,
      'entidad': 'remote_access_stub',
      'entidad_id': command['id']?.toString(),
      'leida': 0,
      'creada_en': DateTime.now().toIso8601String(),
    });
    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CONTROL_CENTER_REMOTE_ACCESS_STUB',
      entidad: 'control_center',
      detalle: '$detalleConsent | Command: ${jsonEncode(command)}',
    );
  }

  static TipoComando _mapearTipoComando(String action) {
    switch (action) {
      case 'forzar_respaldo':
        return TipoComando.forzar_respaldo;
      case 'reiniciar_sesiones':
        return TipoComando.reiniciar_sesiones;
      case 'actualizar_modulos':
        return TipoComando.actualizar_modulos;
      case 'enviar_log':
        return TipoComando.enviar_log;
      case 'mensaje_admin':
        return TipoComando.mensaje_admin;
      case 'bloquear_instalacion':
        return TipoComando.bloquear_instalacion;
      case 'activar_instalacion':
        return TipoComando.activar_instalacion;
      case 'forzar_actualizacion':
        return TipoComando.forzar_actualizacion;
      case 'rollback_actualizacion':
        return TipoComando.rollback_actualizacion;
      case 'reiniciar':
        return TipoComando.reiniciar;
      case 'forzar_sincronizacion':
        return TipoComando.forzar_sincronizacion;
      case 'actualizar_licencia':
        return TipoComando.actualizar_licencia;
      case 'solicitar_acceso_remoto':
      case 'solicitar_asistencia_remota':
      case 'remote_access':
      case 'remote_access_request':
      case 'acceso_remoto':
        return TipoComando.solicitar_acceso_remoto;
      default:
        return TipoComando.mensaje_admin;
    }
  }
}
