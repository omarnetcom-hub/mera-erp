import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import 'licencia_service.dart';
import 'update_service.dart';
import 'health_reporter.dart';

enum TipoComando {
  forzar_respaldo,
  reiniciar_sesiones,
  actualizar_modulos,
  enviar_log,
  mensaje_admin,
  bloquear_instalacion,
  activar_instalacion,
  forzar_actualizacion,
  rollback_actualizacion,
}

enum EstadoComando { pendiente, procesando, completado, fallido }

class ComandoRemoto {
  const ComandoRemoto({
    required this.id,
    required this.tipo,
    required this.parametros,
    required this.timestamp,
    this.firmaHmac,
    this.estado = EstadoComando.pendiente,
    this.resultado,
    this.error,
  });

  final String id;
  final TipoComando tipo;
  final Map<String, dynamic> parametros;
  final DateTime timestamp;
  final String? firmaHmac;
  final EstadoComando estado;
  final Map<String, dynamic>? resultado;
  final String? error;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo.name,
      'parametros': parametros,
      'timestamp': timestamp.toIso8601String(),
      'firma_hmac': firmaHmac,
      'estado': estado.name,
      'resultado': resultado,
      'error': error,
    };
  }

  static ComandoRemoto fromJson(Map<String, dynamic> json) {
    return ComandoRemoto(
      id: json['id'] as String,
      tipo: TipoComando.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoComando.mensaje_admin,
      ),
      parametros: (json['parametros'] as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
      firmaHmac: json['firma_hmac'] as String?,
      estado: EstadoComando.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoComando.pendiente,
      ),
      resultado: json['resultado'] as Map<String, dynamic>?,
      error: json['error'] as String?,
    );
  }

  String _generarPayloadParaFirma() {
    final data = {
      'id': id,
      'tipo': tipo.name,
      'timestamp': timestamp.toIso8601String(),
      'parametros': parametros,
    };
    return jsonEncode(data);
  }

  bool validarFirma(String secretKey) {
    if (firmaHmac == null) return false;

    final payload = _generarPayloadParaFirma();
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString() == firmaHmac;
  }
}

class ResultadoComando {
  const ResultadoComando({
    required this.exito,
    required this.mensaje,
    this.datos,
  });

  final bool exito;
  final String mensaje;
  final Map<String, dynamic>? datos;

  Map<String, dynamic> toJson() {
    return {
      'exito': exito,
      'mensaje': mensaje,
      'datos': datos,
    };
  }
}

class CCCommandsProcessor {
  CCCommandsProcessor._();

  static final CCCommandsProcessor instance = CCCommandsProcessor._();

  static const String _claveSecretHmac = 'control_center_hmac_secret';
  static const String _claveComandosPendientes = 'comandos_pendientes';

  Future<String?> _obtenerSecretHmac() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [_claveSecretHmac],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['valor']?.toString();
  }

  Future<void> configurarSecretHmac(String secret) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {'clave': _claveSecretHmac, 'valor': secret},
      conflictAlgorithm: ConflictAlgorithm.replace
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CC_HMAC_SECRET_CONFIGURADO',
      entidad: 'control_center',
      detalle: 'Secret HMAC configurado',
    );
  }

  Future<bool> validarComando(ComandoRemoto comando) async {
    final secret = await _obtenerSecretHmac();
    if (secret == null || secret.isEmpty) {
      debugPrint('Secret HMAC no configurado');
      return false;
    }

    return comando.validarFirma(secret);
  }

  Future<ResultadoComando> procesarComando(ComandoRemoto comando) async {
    if (!await validarComando(comando)) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Firma HMAC inválida',
      );
    }

    try {
      switch (comando.tipo) {
        case TipoComando.forzar_respaldo:
          return await _ejecutarForzarRespaldo(comando);
        case TipoComando.reiniciar_sesiones:
          return await _ejecutarReiniciarSesiones(comando);
        case TipoComando.actualizar_modulos:
          return await _ejecutarActualizarModulos(comando);
        case TipoComando.enviar_log:
          return await _ejecutarEnviarLog(comando);
        case TipoComando.mensaje_admin:
          return await _ejecutarMensajeAdmin(comando);
        case TipoComando.bloquear_instalacion:
          return await _ejecutarBloquearInstalacion(comando);
        case TipoComando.activar_instalacion:
          return await _ejecutarActivarInstalacion(comando);
        case TipoComando.forzar_actualizacion:
          return await _ejecutarForzarActualizacion(comando);
        case TipoComando.rollback_actualizacion:
          return await _ejecutarRollbackActualizacion(comando);
      }
    } catch (e) {
      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'CC_COMANDO_ERROR',
        entidad: 'control_center',
        detalle: '${comando.tipo.name}: $e',
      );

      return ResultadoComando(
        exito: false,
        mensaje: 'Error al procesar comando: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarForzarRespaldo(ComandoRemoto comando) async {
    try {
      final archivo = await DatabaseHelper.instance.crearRespaldo();
      
      return ResultadoComando(
        exito: true,
        mensaje: 'Respaldo generado exitosamente',
        datos: {
          'ruta': archivo.path,
          'tamaño': await archivo.length(),
          'fecha': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al generar respaldo: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarReiniciarSesiones(ComandoRemoto comando) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Marcar todas las sesiones como cerradas
      await db.update(
        'caja_sesiones',
        {'estado': 'cerrada', 'cerrada_en': DateTime.now().toIso8601String()},
        where: 'estado = ?',
        whereArgs: ['abierta'],
      );

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'CC_COMANDO_REINICIAR_SESIONES',
        entidad: 'control_center',
        detalle: 'Todas las sesiones fueron cerradas',
      );

      return ResultadoComando(
        exito: true,
        mensaje: 'Todas las sesiones activas fueron cerradas',
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al reiniciar sesiones: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarActualizarModulos(ComandoRemoto comando) async {
    try {
      final modulos = comando.parametros['modulos'] as List?;
      if (modulos == null) {
        return ResultadoComando(
          exito: false,
          mensaje: 'No se especificaron módulos',
        );
      }

      final licencia = await LicenciaService.instance.obtenerLicencia();
      if (licencia == null) {
        return ResultadoComando(
          exito: false,
          mensaje: 'No hay licencia configurada',
        );
      }

      final modulosActualizados = (modulos).map((e) => e.toString()).toList();
      final licenciaActualizada = LicenciaInfo(
        uuid: licencia.uuid,
        plan: licencia.plan,
        estado: licencia.estado,
        fechaExpiracion: licencia.fechaExpiracion,
        modulosHabilitados: modulosActualizados,
        limiteDbMb: licencia.limiteDbMb,
      );

      await LicenciaService.instance.guardarLicencia(licenciaActualizada);

      return ResultadoComando(
        exito: true,
        mensaje: 'Módulos actualizados exitosamente',
        datos: {'modulos': modulosActualizados},
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al actualizar módulos: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarEnviarLog(ComandoRemoto comando) async {
    try {
      final periodoInicio = comando.parametros['periodo_inicio'] as String?;
      final periodoFin = comando.parametros['periodo_fin'] as String?;

      if (periodoInicio == null || periodoFin == null) {
        return ResultadoComando(
          exito: false,
          mensaje: 'Se requieren periodo_inicio y periodo_fin',
        );
      }

      final db = await DatabaseHelper.instance.database;
      final inicio = DateTime.parse(periodoInicio);
      final fin = DateTime.parse(periodoFin);

      final logs = await db.query(
        'auditoria',
        where: 'creada_en BETWEEN ? AND ?',
        whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
        orderBy: 'creada_en DESC',
        limit: 1000,
      );

      return ResultadoComando(
        exito: true,
        mensaje: 'Log de auditoría generado',
        datos: {
          'periodo': '$periodoInicio - $periodoFin',
          'total_registros': logs.length,
          'logs': logs,
        },
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al generar log: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarMensajeAdmin(ComandoRemoto comando) async {
    try {
      final titulo = comando.parametros['titulo'] as String?;
      final detalle = comando.parametros['detalle'] as String?;
      final prioridad = comando.parametros['prioridad'] as String? ?? 'info';

      if (titulo == null) {
        return ResultadoComando(
          exito: false,
          mensaje: 'Se requiere título del mensaje',
        );
      }

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      await db.insert('notificaciones', {
        'company_id': companyId,
        'tipo': 'control_center',
        'prioridad': prioridad,
        'titulo': titulo,
        'detalle': detalle ?? '',
        'entidad': 'remote_command',
        'entidad_id': null,
        'leida': 0,
        'creada_en': DateTime.now().toIso8601String(),
      });

      return ResultadoComando(
        exito: true,
        mensaje: 'Mensaje enviado al administrador',
        datos: {'titulo': titulo},
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al enviar mensaje: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarBloquearInstalacion(ComandoRemoto comando) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.execute(
        "INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('instalacion_bloqueada', '1')",
      );

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'CC_COMANDO_BLOQUEAR_INSTALACION',
        entidad: 'control_center',
        detalle: jsonEncode(comando.parametros),
      );

      return ResultadoComando(
        exito: true,
        mensaje: 'Instalación bloqueada',
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al bloquear instalación: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarActivarInstalacion(ComandoRemoto comando) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.execute(
        "INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('instalacion_bloqueada', '0')",
      );

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'CC_COMANDO_ACTIVAR_INSTALACION',
        entidad: 'control_center',
        detalle: jsonEncode(comando.parametros),
      );

      return ResultadoComando(
        exito: true,
        mensaje: 'Instalación activada',
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al activar instalación: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarForzarActualizacion(ComandoRemoto comando) async {
    try {
      final version = comando.parametros['version'] as String?;
      if (version == null) {
        return ResultadoComando(
          exito: false,
          mensaje: 'Se requiere versión a actualizar',
        );
      }

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'CC_COMANDO_FORZAR_ACTUALIZACION',
        entidad: 'control_center',
        detalle: 'Versión objetivo: $version',
      );

      return ResultadoComando(
        exito: true,
        mensaje: 'Actualización forzada registrada',
        datos: {'version': version},
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al forzar actualización: $e',
      );
    }
  }

  Future<ResultadoComando> _ejecutarRollbackActualizacion(ComandoRemoto comando) async {
    try {
      await UpdateService.instance.rollbackForzado();

      return ResultadoComando(
        exito: true,
        mensaje: 'Rollback solicitado al Control Center',
      );
    } catch (e) {
      return ResultadoComando(
        exito: false,
        mensaje: 'Error al solicitar rollback: $e',
      );
    }
  }

  Future<bool> verificarInstalacionBloqueada() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['instalacion_bloqueada'],
      limit: 1,
    );
    
    if (rows.isEmpty) return false;
    final valor = rows.first['valor']?.toString();
    return valor == '1';
  }
}
