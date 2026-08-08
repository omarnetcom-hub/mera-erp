// ============================================================
// payment_service.dart
// Servicio de integración con pasarelas de pago
// ============================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/currency/money_value.dart';
import '../../core/currency/money_currency_resolver.dart';
import 'payment_gateway.dart';

class PaymentService {
  static final PaymentService instance = PaymentService._internal();

  final Dio _dio = Dio();

  PaymentService._internal();

  /// Crea las tablas necesarias para pasarelas de pago
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_gateways (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        config TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        gateway_id INTEGER NOT NULL,
        transaction_id TEXT,
        amount INTEGER NOT NULL,
        currency TEXT DEFAULT 'USD',
        status TEXT DEFAULT 'pending',
        payment_method TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (gateway_id) REFERENCES payment_gateways(id)
      )
    ''');

    // Índices
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gateways_company ON payment_gateways(company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_company ON payment_transactions(company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_status ON payment_transactions(status)',
    );
  }

  /// Registra una pasarela de pago
  Future<int> registerGateway(Database db, PaymentGateway gateway) async {
    final id = await db.insert('payment_gateways', {
      'company_id': gateway.companyId,
      'type': gateway.type.name,
      'name': gateway.name,
      'config': jsonEncode(gateway.config),
      'is_active': gateway.isActive ? 1 : 0,
      'is_default': gateway.isDefault ? 1 : 0,
      'created_at': gateway.createdAt.toIso8601String(),
      'updated_at': gateway.updatedAt?.toIso8601String(),
    });

    return id;
  }

  /// Obtiene la pasarela de pago por defecto
  Future<PaymentGateway?> getDefaultGateway(Database db, int companyId) async {
    final maps = await db.query(
      'payment_gateways',
      where: 'company_id = ? AND is_default = 1 AND is_active = 1',
      whereArgs: [companyId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return PaymentGateway(
      id: map['id'] as int?,
      companyId: map['company_id'] as int,
      type: PaymentGatewayType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PaymentGatewayType.local,
      ),
      name: map['name'] as String,
      config: jsonDecode(map['config'] as String) as Map<String, dynamic>,
      isActive: (map['is_active'] as int) == 1,
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Obtiene todas las pasarelas activas de una empresa
  Future<List<PaymentGateway>> getActiveGateways(
    Database db,
    int companyId,
  ) async {
    final maps = await db.query(
      'payment_gateways',
      where: 'company_id = ? AND is_active = 1',
      whereArgs: [companyId],
    );

    return maps
        .map(
          (map) => PaymentGateway(
            id: map['id'] as int?,
            companyId: map['company_id'] as int,
            type: PaymentGatewayType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => PaymentGatewayType.local,
            ),
            name: map['name'] as String,
            config: jsonDecode(map['config'] as String) as Map<String, dynamic>,
            isActive: (map['is_active'] as int) == 1,
            isDefault: (map['is_default'] as int) == 1,
            createdAt: DateTime.parse(map['created_at'] as String),
            updatedAt: map['updated_at'] != null
                ? DateTime.parse(map['updated_at'] as String)
                : null,
          ),
        )
        .toList();
  }

  /// Procesa un pago
  Future<Map<String, dynamic>> processPayment(
    Database db,
    int companyId,
    MoneyValue amount,
    String currency,
    Map<String, dynamic> paymentData,
  ) async {
    final gateway = await getDefaultGateway(db, companyId);
    if (gateway == null) {
      throw Exception('No hay pasarela de pago configurada');
    }

    switch (gateway.type) {
      case PaymentGatewayType.stripe:
        return await _processStripePayment(
          gateway,
          amount,
          currency,
          paymentData,
        );
      case PaymentGatewayType.paypal:
        return await _processPayPalPayment(
          gateway,
          amount,
          currency,
          paymentData,
        );
      case PaymentGatewayType.mercadopago:
        return await _processMercadoPagoPayment(
          gateway,
          amount,
          currency,
          paymentData,
        );
      case PaymentGatewayType.local:
        return await _processLocalPayment(
          gateway,
          amount,
          currency,
          paymentData,
        );
      case PaymentGatewayType.custom:
        return await _processCustomPayment(
          gateway,
          amount,
          currency,
          paymentData,
        );
    }
  }

  /// Procesa pago con Stripe
  Future<Map<String, dynamic>> _processStripePayment(
    PaymentGateway gateway,
    MoneyValue amount,
    String currency,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final apiKey = gateway.config['api_key'] as String?;
      if (apiKey == null) {
        throw Exception('API Key de Stripe no configurada');
      }

      // TODO: Implementar integración real con Stripe
      // Por ahora, simulamos el proceso

      return {
        'success': true,
        'transaction_id': 'stripe_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'message': 'Pago procesado exitosamente',
      };
    } catch (e) {
      return {'success': false, 'status': 'failed', 'message': e.toString()};
    }
  }

  /// Procesa pago con PayPal
  Future<Map<String, dynamic>> _processPayPalPayment(
    PaymentGateway gateway,
    MoneyValue amount,
    String currency,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final clientId = gateway.config['client_id'] as String?;
      if (clientId == null) {
        throw Exception('Client ID de PayPal no configurado');
      }

      // TODO: Implementar integración real con PayPal

      return {
        'success': true,
        'transaction_id': 'paypal_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'message': 'Pago procesado exitosamente',
      };
    } catch (e) {
      return {'success': false, 'status': 'failed', 'message': e.toString()};
    }
  }

  /// Procesa pago con MercadoPago
  Future<Map<String, dynamic>> _processMercadoPagoPayment(
    PaymentGateway gateway,
    MoneyValue amount,
    String currency,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final accessToken = gateway.config['access_token'] as String?;
      if (accessToken == null) {
        throw Exception('Access Token de MercadoPago no configurado');
      }

      // TODO: Implementar integración real con MercadoPago

      return {
        'success': true,
        'transaction_id': 'mp_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'message': 'Pago procesado exitosamente',
      };
    } catch (e) {
      return {'success': false, 'status': 'failed', 'message': e.toString()};
    }
  }

  /// Procesa pago local (efectivo, transferencia, etc.)
  Future<Map<String, dynamic>> _processLocalPayment(
    PaymentGateway gateway,
    MoneyValue amount,
    String currency,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final paymentMethod = paymentData['payment_method'] as String? ?? 'cash';

      return {
        'success': true,
        'transaction_id': 'local_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'message': 'Pago local procesado',
        'payment_method': paymentMethod,
      };
    } catch (e) {
      return {'success': false, 'status': 'failed', 'message': e.toString()};
    }
  }

  /// Procesa pago con pasarela personalizada
  Future<Map<String, dynamic>> _processCustomPayment(
    PaymentGateway gateway,
    MoneyValue amount,
    String currency,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final endpoint = gateway.config['endpoint'] as String?;
      if (endpoint == null) {
        throw Exception('Endpoint de pasarela personalizada no configurado');
      }

      final response = await _dio.post(
        endpoint,
        data: {
          'amount': amount.toMajorUnitsString(),
          'currency': currency,
          ...paymentData,
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${gateway.config['api_key']}'},
        ),
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'status': 'failed', 'message': e.toString()};
    }
  }

  /// Registra una transacción de pago
  Future<int> recordTransaction(
    Database db,
    int companyId,
    int gatewayId,
    String transactionId,
    MoneyValue amount,
    String currency,
    String status, {
    String? paymentMethod,
    Map<String, dynamic>? metadata,
  }) async {
    final id = await db.insert('payment_transactions', {
      'company_id': companyId,
      'gateway_id': gatewayId,
      'transaction_id': transactionId,
      'amount': amount.toSql(),
      'currency': currency,
      'status': status,
      'payment_method': paymentMethod,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return id;
  }

  /// Obtiene transacciones de una empresa
  Future<List<Map<String, dynamic>>> getTransactions(
    Database db,
    int companyId, {
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String where = 'company_id = ?';
    final whereArgs = <Object>[companyId];

    if (status != null) {
      where += ' AND status = ?';
      whereArgs.add(status);
    }

    if (startDate != null) {
      where += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final maps = await db.query(
      'payment_transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps;
  }

  /// Actualiza el estado de una transacción
  Future<void> updateTransactionStatus(
    Database db,
    int transactionId,
    String status,
  ) async {
    await db.update(
      'payment_transactions',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Obtiene estadísticas de pagos
  Future<Map<String, dynamic>> getPaymentStatistics(
    Database db,
    int companyId,
  ) async {
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: companyId,
    );
    final totalResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, SUM(amount) as total
      FROM payment_transactions
      WHERE company_id = ? AND status = 'completed'
    ''',
      [companyId],
    );

    final pendingResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, SUM(amount) as total
      FROM payment_transactions
      WHERE company_id = ? AND status = 'pending'
    ''',
      [companyId],
    );

    final failedResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, SUM(amount) as total
      FROM payment_transactions
      WHERE company_id = ? AND status = 'failed'
    ''',
      [companyId],
    );

    return {
      'completed': {
        'count': (totalResult.first['count'] as int?) ?? 0,
        'total': MoneyValue.fromSql(
          totalResult.first['total'],
          currency: currency,
          nullableAsZero: true,
        ).toWireMap(),
      },
      'pending': {
        'count': (pendingResult.first['count'] as int?) ?? 0,
        'total': MoneyValue.fromSql(
          pendingResult.first['total'],
          currency: currency,
          nullableAsZero: true,
        ).toWireMap(),
      },
      'failed': {
        'count': (failedResult.first['count'] as int?) ?? 0,
        'total': MoneyValue.fromSql(
          failedResult.first['total'],
          currency: currency,
          nullableAsZero: true,
        ).toWireMap(),
      },
    };
  }
}
