// ============================================================
// webhook_service.dart
// Servicio de gestión y envío de webhooks
// ============================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'webhook.dart';

class WebhookService {
  static final WebhookService instance = WebhookService._internal();
  
  final Dio _dio = Dio();
  
  WebhookService._internal();
  
  /// Crea las tablas necesarias para webhooks
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS webhooks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        event TEXT NOT NULL,
        url TEXT NOT NULL,
        secret TEXT,
        is_active INTEGER DEFAULT 1,
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 3,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS webhook_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        webhook_id INTEGER NOT NULL,
        event TEXT NOT NULL,
        payload TEXT NOT NULL,
        response_code INTEGER,
        response_body TEXT,
        success INTEGER DEFAULT 0,
        attempt INTEGER DEFAULT 1,
        sent_at TEXT NOT NULL,
        FOREIGN KEY (webhook_id) REFERENCES webhooks(id)
      )
    ''');
    
    // Índices
    await db.execute('CREATE INDEX IF NOT EXISTS idx_webhooks_company ON webhooks(company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_webhooks_event ON webhooks(event)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_webhooks_active ON webhooks(is_active)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_webhook_logs_webhook ON webhook_logs(webhook_id)');
  }
  
  /// Registra un nuevo webhook
  Future<int> registerWebhook(Database db, Webhook webhook) async {
    final id = await db.insert('webhooks', webhook.toMap());
    return id;
  }
  
  /// Obtiene webhooks activos para un evento
  Future<List<Webhook>> getActiveWebhooksForEvent(Database db, int companyId, String event) async {
    final maps = await db.query(
      'webhooks',
      where: 'company_id = ? AND event = ? AND is_active = ?',
      whereArgs: [companyId, event, 1],
    );
    
    return maps.map((map) => Webhook.fromMap(map)).toList();
  }
  
  /// Obtiene todos los webhooks de una empresa
  Future<List<Webhook>> getWebhooksByCompany(Database db, int companyId) async {
    final maps = await db.query(
      'webhooks',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'event ASC',
    );
    
    return maps.map((map) => Webhook.fromMap(map)).toList();
  }
  
  /// Desactiva un webhook
  Future<void> deactivateWebhook(Database db, int webhookId) async {
    await db.update(
      'webhooks',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [webhookId],
    );
  }
  
  /// Activa un webhook
  Future<void> activateWebhook(Database db, int webhookId) async {
    await db.update(
      'webhooks',
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [webhookId],
    );
  }
  
  /// Elimina un webhook
  Future<void> deleteWebhook(Database db, int webhookId) async {
    await db.delete('webhooks', where: 'id = ?', whereArgs: [webhookId]);
  }
  
  /// Envía un evento a los webhooks registrados
  Future<void> triggerEvent(Database db, int companyId, String event, Map<String, dynamic> payload) async {
    final webhooks = await getActiveWebhooksForEvent(db, companyId, event);
    
    for (final webhook in webhooks) {
      await _sendWebhook(db, webhook, event, payload);
    }
  }
  
  /// Envía un webhook específico
  Future<void> _sendWebhook(
    Database db,
    Webhook webhook,
    String event,
    Map<String, dynamic> payload,
  ) async {
    final payloadJson = jsonEncode(payload);
    final attempt = webhook.retryCount + 1;
    
    try {
      // Generar firma HMAC si hay secreto
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Merka-Event': event,
        'X-Merka-Delivery': DateTime.now().toIso8601String(),
      };
      
      if (webhook.secret != null) {
        final signature = _generateHMAC(payloadJson, webhook.secret!);
        headers['X-Merka-Signature'] = 'sha256=$signature';
      }
      
      final response = await _dio.post(
        webhook.url,
        data: payload,
        options: Options(headers: headers),
      );
      
      // Registrar log exitoso
      await _logWebhookDelivery(
        db,
        webhook.id!,
        event,
        payloadJson,
        response.statusCode,
        response.data,
        true,
        attempt,
      );
      
      // Resetear contador de reintentos
      await db.update(
        'webhooks',
        {'retry_count': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [webhook.id],
      );
      
    } catch (e) {
      // Registrar log fallido
      await _logWebhookDelivery(
        db,
        webhook.id!,
        event,
        payloadJson,
        null,
        e.toString(),
        false,
        attempt,
      );
      
      // Incrementar contador de reintentos
      final newRetryCount = webhook.retryCount + 1;
      
      if (newRetryCount >= webhook.maxRetries) {
        // Desactivar webhook si supera el máximo de reintentos
        await deactivateWebhook(db, webhook.id!);
      } else {
        await db.update(
          'webhooks',
          {'retry_count': newRetryCount, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [webhook.id],
        );
      }
    }
  }
  
  /// Genera firma HMAC
  String _generateHMAC(String payload, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    return digest.toString();
  }
  
  /// Registra el envío de un webhook
  Future<void> _logWebhookDelivery(
    Database db,
    int webhookId,
    String event,
    String payload,
    int? responseCode,
    dynamic responseBody,
    bool success,
    int attempt,
  ) async {
    await db.insert('webhook_logs', {
      'webhook_id': webhookId,
      'event': event,
      'payload': payload,
      'response_code': responseCode,
      'response_body': responseBody?.toString(),
      'success': success ? 1 : 0,
      'attempt': attempt,
      'sent_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Obtiene logs de un webhook
  Future<List<Map<String, dynamic>>> getWebhookLogs(Database db, int webhookId) async {
    final maps = await db.query(
      'webhook_logs',
      where: 'webhook_id = ?',
      whereArgs: [webhookId],
      orderBy: 'sent_at DESC',
      limit: 50,
    );
    
    return maps;
  }
  
  /// Reintenta envíos fallidos
  Future<void> retryFailedWebhooks(Database db, int companyId) async {
    final failedWebhooks = await db.rawQuery('''
      SELECT DISTINCT w.* 
      FROM webhooks w
      INNER JOIN webhook_logs wl ON w.id = wl.webhook_id
      WHERE w.company_id = ? 
        AND w.is_active = 1 
        AND wl.success = 0 
        AND wl.attempt < w.max_retries
        AND wl.sent_at > datetime('now', '-1 hour')
    ''', [companyId]);
    
    for (final map in failedWebhooks) {
      final webhook = Webhook.fromMap(map);
      
      // Obtener el último payload fallido
      final lastLog = await db.query(
        'webhook_logs',
        where: 'webhook_id = ? AND success = 0',
        whereArgs: [webhook.id],
        orderBy: 'sent_at DESC',
        limit: 1,
      );
      
      if (lastLog.isNotEmpty) {
        final payload = jsonDecode(lastLog.first['payload'] as String) as Map<String, dynamic>;
        await _sendWebhook(db, webhook, webhook.event, payload);
      }
    }
  }
  
  /// Obtiene estadísticas de webhooks
  Future<Map<String, dynamic>> getWebhookStatistics(Database db, int companyId) async {
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as total 
      FROM webhooks 
      WHERE company_id = ?
    ''', [companyId]);
    
    final activeResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM webhooks 
      WHERE company_id = ? AND is_active = 1
    ''', [companyId]);
    
    final deliveriesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
        SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failed
      FROM webhook_logs wl
      INNER JOIN webhooks w ON wl.webhook_id = w.id
      WHERE w.company_id = ?
    ''', [companyId]);
    
    return {
      'total_webhooks': Sqflite.firstIntValue(totalResult) ?? 0,
      'active_webhooks': Sqflite.firstIntValue(activeResult) ?? 0,
      'total_deliveries': Sqflite.firstIntValue(deliveriesResult) ?? 0,
      'successful_deliveries': Sqflite.firstIntValue(deliveriesResult) ?? 0,
      'failed_deliveries': Sqflite.firstIntValue(deliveriesResult) ?? 0,
    };
  }
}
