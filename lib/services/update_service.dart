import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import 'control_center_endpoint.dart';

enum CanalActualizacion { stable, beta, hotfix }

enum EstadoDescarga { pendiente, descargando, completado, error, pausado }

class InfoVersion {
  const InfoVersion({
    required this.version,
    required this.canal,
    required this.fechaPublicacion,
    required this.urlDescarga,
    required this.tamanoBytes,
    required this.sha256,
    this.notas,
    this.obligatoria = false,
  });

  final String version;
  final CanalActualizacion canal;
  final DateTime fechaPublicacion;
  final String urlDescarga;
  final int tamanoBytes;
  final String sha256;
  final String? notas;
  final bool obligatoria;

  bool esMayorQue(String versionActual) {
    final actual = versionActual.split('.').map(int.parse).toList();
    final nueva = version.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      final a = i < actual.length ? actual[i] : 0;
      final n = i < nueva.length ? nueva[i] : 0;
      if (n > a) return true;
      if (n < a) return false;
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'canal': canal.name,
      'fecha_publicacion': fechaPublicacion.toIso8601String(),
      'url_descarga': urlDescarga,
      'tamano_bytes': tamanoBytes,
      'sha256': sha256,
      'notas': notas,
      'obligatoria': obligatoria,
    };
  }

  static InfoVersion fromJson(Map<String, dynamic> json) {
    return InfoVersion(
      version: json['version'] as String,
      canal: CanalActualizacion.values.firstWhere(
        (e) => e.name == json['canal'],
        orElse: () => CanalActualizacion.stable,
      ),
      fechaPublicacion: DateTime.parse(json['fecha_publicacion'] as String),
      urlDescarga: json['url_descarga'] as String,
      tamanoBytes: json['tamano_bytes'] as int,
      sha256: json['sha256'] as String,
      notas: json['notas'] as String?,
      obligatoria: json['obligatoria'] as bool? ?? false,
    );
  }
}

class ProgresoDescarga {
  const ProgresoDescarga({
    required this.estado,
    this.bytesDescargados = 0,
    this.totalBytes = 0,
    this.porcentaje = 0.0,
    this.velocidadKbps = 0.0,
    this.error,
  });

  final EstadoDescarga estado;
  final int bytesDescargados;
  final int totalBytes;
  final double porcentaje;
  final double velocidadKbps;
  final String? error;

  ProgresoDescarga copyWith({
    EstadoDescarga? estado,
    int? bytesDescargados,
    int? totalBytes,
    double? porcentaje,
    double? velocidadKbps,
    String? error,
  }) {
    return ProgresoDescarga(
      estado: estado ?? this.estado,
      bytesDescargados: bytesDescargados ?? this.bytesDescargados,
      totalBytes: totalBytes ?? this.totalBytes,
      porcentaje: porcentaje ?? this.porcentaje,
      velocidadKbps: velocidadKbps ?? this.velocidadKbps,
      error: error ?? this.error,
    );
  }
}

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  static const String _currentVersion = '1.0.0';
  static const String _claveConfigCanal = 'update_canal';
  static const String _claveConfigUltimaRevision = 'update_ultima_revision';
  static const String _claveConfigVersionIgnorada = 'update_version_ignorada';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  ProgresoDescarga? _progresoActual;
  CancelToken? _cancelToken;
  final List<void Function(ProgresoDescarga)> _listeners = [];

  CanalActualizacion get canal => CanalActualizacion.stable;

  ProgresoDescarga? get progresoActual => _progresoActual;

  Future<CanalActualizacion> obtenerCanalConfigurado() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [_claveConfigCanal],
      limit: 1,
    );

    if (rows.isEmpty) return CanalActualizacion.stable;

    final valor = rows.first['valor']?.toString();
    return CanalActualizacion.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => CanalActualizacion.stable,
    );
  }

  Future<void> configurarCanal(CanalActualizacion canal) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {'clave': _claveConfigCanal, 'valor': canal.name},
      conflictAlgorithm: ConflictAlgorithm.replace
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'UPDATE_CANAL_CONFIGURADO',
      entidad: 'update_service',
      detalle: 'Canal: ${canal.name}',
    );
  }

  Future<InfoVersion?> buscarActualizacion() async {
    try {
      // Comentado temporalmente para evitar error 404
      // final endpoint = await _obtenerEndpointControlCenter();
      // final canal = await obtenerCanalConfigurado();
      
      // final response = await _dio.get(
      //   '$endpoint/api/v1/updates/check',
      //   queryParameters: {
      //     'version': _currentVersion,
      //     'canal': canal.name,
      //     'os': Platform.operatingSystem,
      //   },
      // );

      // if (response.statusCode == 200 && response.data != null) {
      //   final data = response.data as Map<String, dynamic>;
      //   if (data['disponible'] == true) {
      //     final version = InfoVersion.fromJson(data['version'] as Map<String, dynamic>);
      //     
      //     await _registrarUltimaRevision();
      //     return version;
      //   }
      // }
      
      return null; // Temporalmente no verifica actualizaciones

      await _registrarUltimaRevision();
      return null;
    } catch (e) {
      debugPrint('Error al buscar actualización: $e');
      return null;
    }
  }

  Future<void> descargarActualizacion(
    InfoVersion version, {
    void Function(ProgresoDescarga)? onProgreso,
  }) async {
    if (_progresoActual?.estado == EstadoDescarga.descargando) {
      throw Exception('Ya hay una descarga en progreso');
    }

    if (onProgreso != null) {
      _listeners.add(onProgreso);
    }

    _cancelToken = CancelToken();
    _progresoActual = ProgresoDescarga(
      estado: EstadoDescarga.descargando,
      totalBytes: version.tamanoBytes,
    );

    try {
      final directorioDescargas = await _obtenerDirectorioDescargas();
      final archivoDestino = File(p.join(
        directorioDescargas.path,
        'merkaerp_update_${version.version}.exe',
      ));

      if (await archivoDestino.exists()) {
        await archivoDestino.delete();
      }

      await _dio.download(
        version.urlDescarga,
        archivoDestino.path,
        cancelToken: _cancelToken,
        onReceiveProgress: (recibidos, total) {
          final porcentaje = total > 0 ? (recibidos / total) * 100 : 0.0;
          _progresoActual = _progresoActual!.copyWith(
            bytesDescargados: recibidos,
            porcentaje: porcentaje,
          );
          _notificarListeners();
        },
      );

      if (await archivoDestino.exists()) {
        final hash = await _calcularSha256(archivoDestino);
        if (hash.toLowerCase() != version.sha256.toLowerCase()) {
          await archivoDestino.delete();
          throw Exception('Hash SHA256 no coincide. Descarga corrupta.');
        }

        _progresoActual = _progresoActual!.copyWith(
          estado: EstadoDescarga.completado,
          porcentaje: 100.0,
        );
        _notificarListeners();

        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'UPDATE_DESCARGA_COMPLETADA',
          entidad: 'update_service',
          detalle: 'Versión: ${version.version}',
        );
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _progresoActual = _progresoActual!.copyWith(
          estado: EstadoDescarga.pausado,
        );
      } else {
        _progresoActual = _progresoActual!.copyWith(
          estado: EstadoDescarga.error,
          error: e.toString(),
        );
      }
      _notificarListeners();
      rethrow;
    } finally {
      _cancelToken = null;
    }
  }

  Future<void> pausarDescarga() async {
    _cancelToken?.cancel();
  }

  Future<void> aplicarActualizacion(String rutaInstalador) async {
    final archivo = File(rutaInstalador);
    if (!await archivo.exists()) {
      throw Exception('El instalador no existe');
    }

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'UPDATE_APLICANDO',
      entidad: 'update_service',
      detalle: rutaInstalador,
    );

    final resultado = await Process.start(
      rutaInstalador,
      ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
    );

    await resultado.exitCode;
  }

  Future<void> ignorarVersion(String version) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {'clave': _claveConfigVersionIgnorada, 'valor': version},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> rollbackForzado() async {
    final endpoint = await _obtenerEndpointControlCenter();
    final installationId = await _obtenerInstallationId();

    try {
      await _dio.post(
        '$endpoint/api/v1/installations/$installationId/rollback',
      );

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'UPDATE_ROLLBACK_FORZADO',
        entidad: 'update_service',
        detalle: 'Solicitado desde Control Center',
      );
    } catch (e) {
      debugPrint('Error al solicitar rollback: $e');
    }
  }

  void agregarListener(void Function(ProgresoDescarga) listener) {
    _listeners.add(listener);
  }

  void removerListener(void Function(ProgresoDescarga) listener) {
    _listeners.remove(listener);
  }

  void _notificarListeners() {
    for (final listener in _listeners) {
      listener(_progresoActual!);
    }
  }

  Future<String> _obtenerEndpointControlCenter() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_endpoint'],
      limit: 1,
    );
    final value = rows.isEmpty ? null : rows.first['valor']?.toString().trim();
    return ControlCenterEndpoint.normalize(value ?? 'http://127.0.0.1:8787');
  }

  Future<String> _obtenerInstallationId() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_installation_id'],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['valor']?.toString() ?? '';
    return 'UNKNOWN';
  }

  Future<Directory> _obtenerDirectorioDescargas() async {
    final directorio = await getApplicationDocumentsDirectory();
    final dirDescargas = Directory(p.join(directorio.path, 'merkaerp', 'updates'));
    if (!await dirDescargas.exists()) {
      await dirDescargas.create(recursive: true);
    }
    return dirDescargas;
  }

  Future<String> _calcularSha256(File archivo) async {
    final bytes = await archivo.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _registrarUltimaRevision() async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {
        'clave': _claveConfigUltimaRevision,
        'valor': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> obtenerUltimaRevision() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [_claveConfigUltimaRevision],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final valor = rows.first['valor']?.toString();
    return valor != null ? DateTime.tryParse(valor) : null;
  }

  Future<void> limpiarDescargasAntiguas() async {
    try {
      final directorio = await _obtenerDirectorioDescargas();
      final archivos = directorio.listSync()
          .whereType<File>()
          .toList();

      final ahora = DateTime.now();
      for (final archivo in archivos) {
        final modificado = await archivo.lastModified();
        final dias = ahora.difference(modificado).inDays;
        if (dias > 7) {
          await archivo.delete();
        }
      }
    } catch (e) {
      debugPrint('Error al limpiar descargas antiguas: $e');
    }
  }
}
