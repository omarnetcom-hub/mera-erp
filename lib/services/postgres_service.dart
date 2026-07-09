import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../db_helper.dart';
import 'licencia_service.dart';
import 'control_center_endpoint.dart';

class PostgresService {
  static final PostgresService _instance = PostgresService._internal();
  factory PostgresService() => _instance;
  PostgresService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<void> get connection async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_endpoint'],
      limit: 1,
    );
    final endpoint = rows.isEmpty ? 'https://merkaerp-control-center-backend.onrender.com' : rows.first['valor']?.toString() ?? 'https://merkaerp-control-center-backend.onrender.com';
    
    // Check health of backend
    final response = await _dio.get('${ControlCenterEndpoint.normalize(endpoint)}/health');
    if (response.statusCode != 200) {
      throw Exception('Backend not available: ${response.statusCode}');
    }
  }

  Future<String?> _getAuthToken() async {
    final license = await LicenciaService.instance.obtenerLicencia();
    return license?.offlineToken;
  }

  Future<String> _getEndpoint() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_endpoint'],
      limit: 1,
    );
    final rawVal = rows.isEmpty ? null : rows.first['valor']?.toString();
    return ControlCenterEndpoint.normalize(rawVal);
  }

  Map<String, dynamic> _mapRemoteToLocal(String table, Map<String, dynamic> remote) {
    final local = Map<String, dynamic>.from(remote);
    
    if (table == 'productos') {
      local['codigo_barras'] = remote['codigo'];
      local['precio'] = remote['precio_venta'];
      local['unidad_base'] = remote['unidad_medida'];
      local['impuesto_pct'] = remote['iva'];
      
      // Remove remote-only keys to avoid SQLite column errors
      local.remove('codigo');
      local.remove('precio_venta');
      local.remove('unidad_medida');
      local.remove('iva');
      local.remove('categoria');
      local.remove('stock_minimo');
      local.remove('activo');
      local.remove('created_at');
      local.remove('updated_at');
      local.remove('sync_status');
      local.remove('last_sync');
    } else if (table == 'clientes') {
      local['documento'] = remote['identificacion'];
      local['fecha'] = remote['updated_at'] ?? remote['created_at'];
      local['estado'] = (remote['activo'] == 1 || remote['activo'] == true) ? 'activo' : 'inactivo';
      
      local.remove('identificacion');
      local.remove('ciudad');
      local.remove('tipo_cliente');
      local.remove('limite_credito');
      local.remove('saldo_actual');
      local.remove('activo');
      local.remove('created_at');
      local.remove('updated_at');
      local.remove('sync_status');
      local.remove('last_sync');
    } else if (table == 'ventas') {
      local['impuesto_total'] = remote['iva'];
      local['impuesto_pct'] = 19.0; // Default
      
      local.remove('numero_factura');
      local.remove('iva');
      local.remove('observaciones');
      local.remove('created_at');
      local.remove('updated_at');
      local.remove('sync_status');
      local.remove('last_sync');
    }
    
    return local;
  }

  Future<List<Map<String, dynamic>>> query(String sql, {Map<String, dynamic>? params}) async {
    // We expect query format like: 'SELECT * FROM $tableName ...' or with 'WHERE updated_at > @lastSync'
    // Let's parse the table name and the lastSync param.
    final match = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(sql);
    if (match == null) return [];
    final table = match.group(1)!;

    String? since;
    if (params != null && params.containsKey('lastSync')) {
      since = params['lastSync'] as String;
    } else {
      // Look for a timestamp parameter in SQL or params
      final sinceMatch = RegExp(r"updated_at\s*>\s*'([^']+)'", caseSensitive: false).firstMatch(sql);
      if (sinceMatch != null) {
        since = sinceMatch.group(1);
      }
    }

    final token = await _getAuthToken();
    if (token == null) {
      debugPrint('No auth token for pull sync, skipping query');
      return [];
    }

    final endpoint = await _getEndpoint();
    final url = '$endpoint/api/v1/data/pull';

    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          'table': table,
          'since': ?since,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final records = response.data['records'] as List;
        return records.map((r) {
          final mapped = Map<String, dynamic>.from(r as Map);
          return _mapRemoteToLocal(table, mapped);
        }).toList();
      }
    } catch (e) {
      debugPrint('Error in pull query REST API: $e');
    }
    return [];
  }

  Future<void> execute(String sql, {Map<String, dynamic>? params}) async {
    // execute is not directly used for push in HybridSyncService, but we keep it
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final token = await _getAuthToken();
    if (token == null) return 0;

    final endpoint = await _getEndpoint();
    final url = '$endpoint/api/v1/data/push';

    try {
      final response = await _dio.post(
        url,
        data: {
          'table': table,
          'records': [data],
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return 1;
      }
    } catch (e) {
      debugPrint('Error in insert REST API: $e');
      rethrow;
    }
    return 0;
  }

  Future<void> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    await insert(table, data);
  }

  Future<void> delete(String table, String where, List<dynamic> whereArgs) async {
    // deletes are not synchronized through this simple REST API for now
  }
}
