import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db_helper.dart';

enum SyncStatus {
  idle,
  syncing,
  offline,
  error,
  conflict
}

class SyncEvent {
  final String eventId;
  final String table;
  final String operation; // insert, update, delete
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool processed;

  SyncEvent({
    required this.eventId,
    required this.table,
    required this.operation,
    required this.data,
    required this.timestamp,
    this.processed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'table': table,
      'operation': operation,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'processed': processed ? 1 : 0,
    };
  }

  factory SyncEvent.fromMap(Map<String, dynamic> map) {
    return SyncEvent(
      eventId: map['eventId'] as String,
      table: map['table'] as String,
      operation: map['operation'] as String,
      data: jsonDecode(map['data'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      processed: (map['processed'] as int) == 1,
    );
  }
}

class SyncConflict {
  final int id;
  final String table;
  final String recordId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime createdAt;
  bool resolved;
  String? resolution;
  Map<String, dynamic>? resolvedData;

  SyncConflict({
    required this.id,
    required this.table,
    required this.recordId,
    required this.localData,
    required this.remoteData,
    required this.createdAt,
    this.resolved = false,
    this.resolution,
    this.resolvedData,
  });
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  SyncStatus _status = SyncStatus.idle;
  Timer? _syncTimer;
  DateTime? _lastSyncTimestamp;
  String? _serverEndpoint;
  String? _installationId;
  String? _userId;
  String? _authToken;

  SyncStatus get status => _status;
  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;
  bool get isOnline => _status != SyncStatus.offline && _status != SyncStatus.error;

  final List<void Function(SyncStatus)> _statusListeners = [];

  void addStatusListener(void Function(SyncStatus) listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(void Function(SyncStatus) listener) {
    _statusListeners.remove(listener);
  }

  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    for (final listener in _statusListeners) {
      listener(newStatus);
    }
  }

  Future<void> initialize() async {
    final db = await DatabaseHelper.instance.database;
    
    // Crear tabla de outbox de sincronización
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT UNIQUE NOT NULL,
        user_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        processed INTEGER DEFAULT 0,
        error TEXT
      )
    ''');

    // Crear tabla de inbox de sincronización
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_inbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT UNIQUE NOT NULL,
        user_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        applied INTEGER DEFAULT 0
      )
    ''');

    // Crear tabla de conflictos de sincronización
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        local_data TEXT NOT NULL,
        remote_data TEXT NOT NULL,
        resolved INTEGER DEFAULT 0,
        resolution TEXT,
        resolved_data TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Obtener configuración del servidor
    await _loadConfiguration();

    // Iniciar sincronización automática
    _startAutoSync();
  }

  Future<void> _loadConfiguration() async {
    final db = await DatabaseHelper.instance.database;
    
    // Obtener endpoint del servidor
    final endpointRows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['sync_server_endpoint'],
      limit: 1,
    );
    _serverEndpoint = endpointRows.isEmpty 
        ? 'https://merkaerp-control-center-backend.onrender.com' 
        : endpointRows.first['valor']?.toString();

    // Obtener installation ID
    final installationRows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_installation_id'],
      limit: 1,
    );
    _installationId = installationRows.isEmpty 
        ? null 
        : installationRows.first['valor']?.toString();

    // Obtener user_id y auth_token
    final userIdRows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['sync_user_id'],
      limit: 1,
    );
    _userId = userIdRows.isEmpty ? null : userIdRows.first['valor']?.toString();

    final tokenRows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['sync_auth_token'],
      limit: 1,
    );
    _authToken = tokenRows.isEmpty ? null : tokenRows.first['valor']?.toString();

    // Obtener último timestamp de sincronización
    final lastSyncRows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['last_sync_timestamp'],
      limit: 1,
    );
    if (lastSyncRows.isNotEmpty) {
      _lastSyncTimestamp = DateTime.tryParse(lastSyncRows.first['valor']?.toString() ?? '');
    }
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    // Solo iniciar sincronización automática si hay usuario autenticado
    if (_userId != null && _authToken != null) {
      _syncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => sync(),
      );
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        '$_serverEndpoint/api/v1/auth/login',
        data: {
          'username': username,
          'password': password,
          'deviceInfo': 'MerkaERP Desktop',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _authToken = data['token'] as String;
        _userId = data['user']['id'] as String;

        // Guardar en base de datos
        final db = await DatabaseHelper.instance.database;
        await db.insert('app_config', {
          'clave': 'sync_user_id',
          'valor': _userId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('app_config', {
          'clave': 'sync_auth_token',
          'valor': _authToken,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        _startAutoSync();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_authToken != null) {
        final dio = Dio();
        await dio.post(
          '$_serverEndpoint/api/v1/auth/logout',
          data: {'token': _authToken},
          options: Options(
            headers: {'Content-Type': 'application/json'},
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    // Limpiar datos locales
    _userId = null;
    _authToken = null;
    stopAutoSync();

    final db = await DatabaseHelper.instance.database;
    await db.delete('app_config', where: 'clave = ?', whereArgs: ['sync_user_id']);
    await db.delete('app_config', where: 'clave = ?', whereArgs: ['sync_auth_token']);
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
  }

  Future<void> sync() async {
    if (_status == SyncStatus.syncing) return;
    
    _setStatus(SyncStatus.syncing);
    
    try {
      // 1. Push cambios locales al servidor
      await _pushChanges();
      
      // 2. Pull cambios del servidor
      await _pullChanges();
      
      // 3. Actualizar timestamp de última sincronización
      _lastSyncTimestamp = DateTime.now();
      await _saveLastSyncTimestamp();
      
      _setStatus(SyncStatus.idle);
      
      debugPrint('Sync completed successfully');
    } catch (e) {
      debugPrint('Sync error: $e');
      _setStatus(SyncStatus.error);
      
      // Si es error de conexión, marcar como offline
      if (e is SocketException || e is HttpException) {
        _setStatus(SyncStatus.offline);
      }
    }
  }

  Future<void> _pushChanges() async {
    if (_serverEndpoint == null || _installationId == null || _userId == null || _authToken == null) {
      throw Exception('Sync not configured or not authenticated');
    }

    final db = await DatabaseHelper.instance.database;
    
    // Obtener eventos no procesados
    final pendingEvents = await db.query(
      'sync_outbox',
      where: 'processed = 0',
      orderBy: 'timestamp ASC',
    );

    if (pendingEvents.isEmpty) return;

    final events = pendingEvents.map((row) => {
      'eventId': row['event_id'] as String,
      'table': row['table_name'] as String,
      'operation': row['operation'] as String,
      'data': jsonDecode(row['data'] as String),
      'timestamp': row['timestamp'] as String,
    }).toList();

    // Enviar al servidor con autenticación
    final dio = Dio();
    final response = await dio.post(
      '$_serverEndpoint/api/v1/installations/sync/push',
      data: {
        'installationId': _installationId,
        'events': events,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      // Marcar eventos como procesados
      for (final event in pendingEvents) {
        await db.update(
          'sync_outbox',
          {'processed': 1},
          where: 'id = ?',
          whereArgs: [event['id']],
        );
      }
      
      debugPrint('Pushed ${events.length} events to server');
    } else {
      throw Exception('Push failed: ${response.statusCode}');
    }
  }

  Future<void> _pullChanges() async {
    if (_serverEndpoint == null || _installationId == null || _userId == null || _authToken == null) {
      throw Exception('Sync not configured or not authenticated');
    }

    final lastSync = _lastSyncTimestamp?.toIso8601String() ?? 
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

    // Solicitar cambios del servidor con autenticación
    final dio = Dio();
    final response = await dio.get(
      '$_serverEndpoint/api/v1/installations/sync/pull',
      queryParameters: {
        'installationId': _installationId,
        'lastSyncTimestamp': lastSync,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final events = data['events'] as List<dynamic>;
      
      if (events.isEmpty) return;

      final db = await DatabaseHelper.instance.database;
      
      for (final event in events) {
        final eventData = event as Map<String, dynamic>;
        final eventId = eventData['eventId'] as String;
        
        // Verificar si ya fue aplicado
        final existing = await db.query(
          'sync_inbox',
          where: 'event_id = ?',
          whereArgs: [eventId],
          limit: 1,
        );
        
        if (existing.isNotEmpty) continue;
        
        // Aplicar cambio localmente
        await _applyRemoteChange(eventData);
        
        // Guardar en inbox
        await db.insert('sync_inbox', {
          'event_id': eventId,
          'user_id': _userId,
          'table_name': eventData['table'] as String,
          'operation': eventData['operation'] as String,
          'data': jsonEncode(eventData['data']),
          'timestamp': eventData['timestamp'] as String,
          'applied': 1,
        });
      }
      
      _lastSyncTimestamp = DateTime.parse(data['lastSyncTimestamp'] as String);
      debugPrint('Pulled ${events.length} events from server');
    } else {
      throw Exception('Pull failed: ${response.statusCode}');
    }
  }

  Future<void> _applyRemoteChange(Map<String, dynamic> event) async {
    final db = await DatabaseHelper.instance.database;
    final table = event['table'] as String;
    final operation = event['operation'] as String;
    final data = event['data'] as Map<String, dynamic>;

    switch (operation) {
      case 'insert':
        await db.insert(table, data);
        break;
      case 'update':
        final id = data['id'];
        await db.update(table, data, where: 'id = ?', whereArgs: [id]);
        break;
      case 'delete':
        final id = data['id'];
        await db.delete(table, where: 'id = ?', whereArgs: [id]);
        break;
    }
  }

  Future<void> queueEvent(String table, String operation, Map<String, dynamic> data) async {
    if (_userId == null) {
      debugPrint('Cannot queue event: user not authenticated');
      return;
    }
    
    final db = await DatabaseHelper.instance.database;
    final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}_${table}_${operation}';
    
    await db.insert('sync_outbox', {
      'event_id': eventId,
      'user_id': _userId,
      'table_name': table,
      'operation': operation,
      'data': jsonEncode(data),
      'timestamp': DateTime.now().toIso8601String(),
      'processed': 0,
    });
    
    debugPrint('Queued sync event: $table $operation');
  }

  Future<void> _saveLastSyncTimestamp() async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {
        'clave': 'last_sync_timestamp',
        'valor': _lastSyncTimestamp?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncConflict>> getConflicts() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sync_conflicts',
      where: 'resolved = 0',
      orderBy: 'created_at DESC',
    );
    
    return rows.map((row) => SyncConflict(
      id: row['id'] as int,
      table: row['table_name'] as String,
      recordId: row['record_id'] as String,
      localData: jsonDecode(row['local_data'] as String),
      remoteData: jsonDecode(row['remote_data'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      resolved: (row['resolved'] as int) == 1,
      resolution: row['resolution']?.toString(),
      resolvedData: row['resolved_data'] != null 
          ? jsonDecode(row['resolved_data'] as String) 
          : null,
    )).toList();
  }

  Future<void> resolveConflict(int conflictId, String resolution, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    
    await db.update(
      'sync_conflicts',
      {
        'resolved': 1,
        'resolution': resolution,
        'resolved_data': jsonEncode(data),
      },
      where: 'id = ?',
      whereArgs: [conflictId],
    );
    
    // Aplicar la resolución según la elección
    if (resolution == 'remote') {
      // Aplicar datos remotos
      final conflict = await db.query(
        'sync_conflicts',
        where: 'id = ?',
        whereArgs: [conflictId],
        limit: 1,
      );
      
      if (conflict.isNotEmpty) {
        final table = conflict.first['table_name'] as String;
        final remoteData = jsonDecode(conflict.first['remote_data'] as String);
        await _applyRemoteChange({
          'table': table,
          'operation': 'update',
          'data': remoteData,
        });
      }
    }
  }

  Future<void> setServerEndpoint(String endpoint) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_config',
      {'clave': 'sync_server_endpoint', 'valor': endpoint},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _serverEndpoint = endpoint;
  }
}
