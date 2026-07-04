import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

enum NequiTransactionStatus { pendiente, procesando, exitoso, fallido, expirado }

class NequiConfig {
  const NequiConfig({
    required this.apiKey,
    required this.clientId,
    required this.clientSecret,
    required this.endpoint,
    this.activo = true,
  });

  final String apiKey;
  final String clientId;
  final String clientSecret;
  final String endpoint;
  final bool activo;
}

class NequiTransaction {
  const NequiTransaction({
    required this.transactionId,
    required this.phoneNumber,
    required this.amount,
    required this.reference,
    required this.status,
    required this.createdAt,
    this.expirationMinutes = 30,
    this.processedAt,
  });

  final String transactionId;
  final String phoneNumber;
  final double amount;
  final String reference;
  final NequiTransactionStatus status;
  final DateTime createdAt;
  final int expirationMinutes;
  final DateTime? processedAt;

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'phone_number': phoneNumber,
      'amount': amount,
      'reference': reference,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'expiration_minutes': expirationMinutes,
      'processed_at': processedAt?.toIso8601String(),
    };
  }

  static NequiTransaction fromMap(Map<String, dynamic> map) {
    return NequiTransaction(
      transactionId: map['transaction_id'] as String,
      phoneNumber: map['phone_number'] as String,
      amount: (map['amount'] as num).toDouble(),
      reference: map['reference'] as String,
      status: NequiTransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => NequiTransactionStatus.pendiente,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      expirationMinutes: map['expiration_minutes'] as int? ?? 30,
      processedAt: map['processed_at'] != null 
          ? DateTime.parse(map['processed_at'] as String) 
          : null,
    );
  }

  bool get isExpired {
    final expiration = createdAt.add(Duration(minutes: expirationMinutes));
    return DateTime.now().isAfter(expiration);
  }
}

class NequiService {
  NequiService._();

  static final NequiService instance = NequiService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  Future<NequiConfig?> obtenerConfiguracion() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    
    final rows = await db.query(
      'integraciones',
      where: 'company_id = ? AND tipo = ? AND activo = ?',
      whereArgs: [companyId, 'nequi', 1],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final configJson = rows.first['config'] as String?;
    if (configJson == null) return null;

    final config = jsonDecode(configJson) as Map<String, dynamic>;
    return NequiConfig(
      apiKey: config['api_key'] as String,
      clientId: config['client_id'] as String,
      clientSecret: config['client_secret'] as String,
      endpoint: config['endpoint'] as String,
      activo: (rows.first['activo'] as int) == 1,
    );
  }

  Future<void> guardarConfiguracion(NequiConfig config) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final configJson = jsonEncode({
      'api_key': config.apiKey,
      'client_id': config.clientId,
      'client_secret': config.clientSecret,
      'endpoint': config.endpoint,
    });

    await db.insert(
      'integraciones',
      {
        'company_id': companyId,
        'tipo': 'nequi',
        'nombre': 'Nequi',
        'config': configJson,
        'activo': config.activo ? 1 : 0,
        'creado_en': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'NEQUI_CONFIG_GUARDADA',
      entidad: 'integraciones',
      detalle: 'Client ID: ${config.clientId}',
    );
  }

  Future<NequiTransaction> generarReferenciaCobro({
    required String phoneNumber,
    required double amount,
    required String reference,
    String? description,
    int expirationMinutes = 30,
  }) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('Nequi no configurado o inactivo');
    }

    try {
      _dio.options.headers['Authorization'] = 'Bearer ${config.apiKey}';
      
      final response = await _dio.post(
        '${config.endpoint}/payments',
        data: {
          'client_id': config.clientId,
          'phone_number': _formatearTelefono(phoneNumber),
          'amount': amount,
          'currency': 'COP',
          'reference': reference,
          'description': description ?? 'Pago Nequi MerkaERP',
          'expiration_minutes': expirationMinutes,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final transaction = NequiTransaction(
          transactionId: data['transaction_id'] as String,
          phoneNumber: phoneNumber,
          amount: amount,
          reference: reference,
          status: NequiTransactionStatus.pendiente,
          createdAt: DateTime.now(),
          expirationMinutes: expirationMinutes,
        );

        await _guardarTransaccion(transaction);
        
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'NEQUI_REFERENCIA_GENERADA',
          entidad: 'pagos',
          detalle: 'Phone: $phoneNumber, Amount: $amount, Reference: $reference',
        );

        return transaction;
      }

      throw Exception('Error al generar referencia: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error en Nequi: $e');
    }
  }

  Future<NequiTransactionStatus> consultarEstado(String transactionId) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('Nequi no configurado o inactivo');
    }

    try {
      _dio.options.headers['Authorization'] = 'Bearer ${config.apiKey}';
      
      final response = await _dio.get(
        '${config.endpoint}/payments/$transactionId',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final statusStr = data['status'] as String;
        
        final status = NequiTransactionStatus.values.firstWhere(
          (e) => e.name == statusStr.toLowerCase(),
          orElse: () => NequiTransactionStatus.pendiente,
        );

        // Actualizar estado en BD
        await _actualizarEstadoTransaccion(transactionId, status);

        return status;
      }

      throw Exception('Error al consultar estado: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error en Nequi: $e');
    }
  }

  Future<void> procesarWebhook(Map<String, dynamic> webhookData) async {
    final transactionId = webhookData['transaction_id'] as String?;
    final statusStr = webhookData['status'] as String?;

    if (transactionId == null || statusStr == null) {
      throw Exception('Webhook inválido: faltan datos requeridos');
    }

    final status = NequiTransactionStatus.values.firstWhere(
      (e) => e.name == statusStr.toLowerCase(),
      orElse: () => NequiTransactionStatus.pendiente,
    );

    await _actualizarEstadoTransaccion(transactionId, status);

    // Si el pago fue exitoso, procesar el pago en el sistema
    if (status == NequiTransactionStatus.exitoso) {
      final transaccion = await _obtenerTransaccion(transactionId);
      if (transaccion != null) {
        await _procesarPagoExitoso(transaccion);
      }
    }

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'NEQUI_WEBHOOK_PROCESADO',
      entidad: 'pagos',
      detalle: 'Transaction ID: $transactionId, Status: $statusStr',
    );
  }

  Future<void> _guardarTransaccion(NequiTransaction transaction) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    await db.insert('nequi_transacciones', {
      'company_id': companyId,
      ...transaction.toMap(),
    });
  }

  Future<void> _actualizarEstadoTransaccion(String transactionId, NequiTransactionStatus status) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'nequi_transacciones',
      {
        'status': status.name,
        'processed_at': DateTime.now().toIso8601String(),
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<NequiTransaction?> _obtenerTransaccion(String transactionId) async {
    final db = await DatabaseHelper.instance.database;
    
    final rows = await db.query(
      'nequi_transacciones',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return NequiTransaction.fromMap(rows.first);
  }

  Future<void> _procesarPagoExitoso(NequiTransaction transaction) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    // Registrar movimiento de caja
    await db.insert('movimientos_caja', {
      'company_id': companyId,
      'tipo': 'ingreso',
      'concepto': 'Pago Nequi - Ref: ${transaction.reference}',
      'monto': transaction.amount,
      'fecha': DateTime.now().toIso8601String(),
      'origen': 'nequi',
    });

    // Si la referencia corresponde a una factura, actualizarla
    final facturas = await db.query(
      'cuentas_por_cobrar',
      where: 'descripcion LIKE ?',
      whereArgs: ['%${transaction.reference}%'],
    );

    for (final factura in facturas) {
      await db.insert('abonos_cxc', {
        'company_id': companyId,
        'cuenta_id': factura['id'],
        'monto': transaction.amount,
        'metodo_pago': 'NEQUI',
        'observacion': 'Transacción Nequi: ${transaction.transactionId}',
        'fecha': DateTime.now().toIso8601String(),
      });
    }

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'NEQUI_PAGO_PROCESADO',
      entidad: 'pagos',
      detalle: 'Transaction ID: ${transaction.transactionId}, Amount: ${transaction.amount}',
    );
  }

  String _formatearTelefono(String phoneNumber) {
    // Formatear número de teléfono colombiano: 57XXXXXXXXXX
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('57')) {
      return digits;
    }
    if (digits.startsWith('3') && digits.length == 10) {
      return '57$digits';
    }
    return digits;
  }

  Future<void> probarConexion() async {
    final config = await obtenerConfiguracion();
    if (config == null) {
      throw Exception('Nequi no configurado');
    }

    try {
      _dio.options.headers['Authorization'] = 'Bearer ${config.apiKey}';
      
      final response = await _dio.get(
        '${config.endpoint}/health',
      );

      if (response.statusCode != 200) {
        throw Exception('Conexión fallida: ${response.statusCode}');
      }

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'NEQUI_CONEXION_EXITOSA',
        entidad: 'integraciones',
        detalle: 'Client ID: ${config.clientId}',
      );
    } catch (e) {
      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'NEQUI_CONEXION_FALLIDA',
        entidad: 'integraciones',
        detalle: 'Error: $e',
      );
      rethrow;
    }
  }

  Future<List<NequiTransaction>> obtenerTransaccionesPendientes() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    
    final rows = await db.query(
      'nequi_transacciones',
      where: 'company_id = ? AND status = ?',
      whereArgs: [companyId, 'pendiente'],
      orderBy: 'created_at DESC',
    );

    return rows.map((row) => NequiTransaction.fromMap(row)).toList();
  }

  Future<void> verificarTransaccionesExpiradas() async {
    final pendientes = await obtenerTransaccionesPendientes();
    
    for (final transaccion in pendientes) {
      if (transaccion.isExpired) {
        await _actualizarEstadoTransaccion(
          transaccion.transactionId,
          NequiTransactionStatus.expirado,
        );
        
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'NEQUI_TRANSACCION_EXPIRADA',
          entidad: 'pagos',
          detalle: 'Transaction ID: ${transaccion.transactionId}',
        );
      }
    }
  }
}
