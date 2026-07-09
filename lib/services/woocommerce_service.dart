import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

enum WooCommerceSyncStatus { pendiente, sincronizando, exitoso, error }

class WooCommerceConfig {
  const WooCommerceConfig({
    required this.url,
    required this.consumerKey,
    required this.consumerSecret,
    this.activo = true,
  });

  final String url;
  final String consumerKey;
  final String consumerSecret;
  final bool activo;

  String generarAuthUrl(String endpoint) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = timestamp.toString();
    
    final params = {
      'oauth_consumer_key': consumerKey,
      'oauth_nonce': nonce,
      'oauth_signature_method': 'HMAC-SHA256',
      'oauth_timestamp': timestamp.toString(),
      'oauth_version': '1.0',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    return '$endpoint?$queryString';
  }
}

class WooCommerceProduct {
  const WooCommerceProduct({
    required this.id,
    required this.name,
    required this.stockQuantity,
    required this.regularPrice,
    this.sku,
    this.manageStock = true,
  });

  final int id;
  final String name;
  final int stockQuantity;
  final String regularPrice;
  final String? sku;
  final bool manageStock;

  static WooCommerceProduct fromJson(Map<String, dynamic> json) {
    return WooCommerceProduct(
      id: json['id'] as int,
      name: json['name'] as String,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      regularPrice: json['regular_price'] as String? ?? '0',
      sku: json['sku'] as String?,
      manageStock: json['manage_stock'] as bool? ?? true,
    );
  }
}

class WooCommerceOrder {
  const WooCommerceOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.dateCreated,
    this.customerId,
    this.paymentMethod,
    this.lineItems = const [],
  });

  final int id;
  final String status;
  final String total;
  final DateTime dateCreated;
  final int? customerId;
  final String? paymentMethod;
  final List<WooCommerceLineItem> lineItems;
}

class WooCommerceLineItem {
  const WooCommerceLineItem({
    required this.productId,
    required this.quantity,
    required this.total,
  });

  final int productId;
  final int quantity;
  final String total;
}

class WooCommerceService {
  WooCommerceService._();

  static final WooCommerceService instance = WooCommerceService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<WooCommerceConfig?> obtenerConfiguracion() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    
    final rows = await db.query(
      'integraciones',
      where: 'company_id = ? AND tipo = ? AND activo = ?',
      whereArgs: [companyId, 'woocommerce', 1],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final configJson = rows.first['config'] as String?;
    if (configJson == null) return null;

    final config = jsonDecode(configJson) as Map<String, dynamic>;
    return WooCommerceConfig(
      url: config['url'] as String,
      consumerKey: config['consumer_key'] as String,
      consumerSecret: config['consumer_secret'] as String,
      activo: (rows.first['activo'] as int) == 1,
    );
  }

  Future<void> guardarConfiguracion(WooCommerceConfig config) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final configJson = jsonEncode({
      'url': config.url,
      'consumer_key': config.consumerKey,
      'consumer_secret': config.consumerSecret,
    });

    await db.insert(
      'integraciones',
      {
        'company_id': companyId,
        'tipo': 'woocommerce',
        'nombre': 'WooCommerce',
        'config': configJson,
        'activo': config.activo ? 1 : 0,
        'creado_en': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'WOOCOMMERCE_CONFIG_GUARDADA',
      entidad: 'integraciones',
      detalle: 'URL: ${config.url}',
    );
  }

  Future<List<WooCommerceProduct>> obtenerProductos({int page = 1, int perPage = 100}) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('WooCommerce no configurado o inactivo');
    }

    try {
      final endpoint = config.generarAuthUrl('/wp-json/wc/v3/products');
      final response = await _dio.get(
        '${config.url}$endpoint',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'status': 'publish',
        },
      );

      if (response.statusCode == 200) {
        final products = (response.data as List)
            .map((json) => WooCommerceProduct.fromJson(json as Map<String, dynamic>))
            .toList();
        return products;
      }

      throw Exception('Error al obtener productos: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error en WooCommerce: $e');
    }
  }

  Future<void> sincronizarProducto(int productoId, int stock, double precio) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('WooCommerce no configurado o inactivo');
    }

    try {
      final endpoint = config.generarAuthUrl('/wp-json/wc/v3/products/$productoId');
      final response = await _dio.put(
        '${config.url}$endpoint',
        data: {
          'stock_quantity': stock,
          'regular_price': precio.toStringAsFixed(2),
          'manage_stock': true,
        },
      );

      if (response.statusCode == 200) {
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'WOOCOMMERCE_PRODUCTO_SINCRONIZADO',
          entidad: 'integraciones',
          detalle: 'Producto ID: $productoId, Stock: $stock',
        );
      }
    } catch (e) {
      throw Exception('Error al sincronizar producto: $e');
    }
  }

  Future<List<WooCommerceOrder>> obtenerOrdenes({
    String status = 'completed',
    DateTime? after,
    DateTime? before,
  }) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('WooCommerce no configurado o inactivo');
    }

    try {
      final endpoint = config.generarAuthUrl('/wp-json/wc/v3/orders');
      final queryParams = <String, dynamic>{
        'status': status,
        'per_page': 100,
      };

      if (after != null) {
        queryParams['after'] = after.toIso8601String();
      }
      if (before != null) {
        queryParams['before'] = before.toIso8601String();
      }

      final response = await _dio.get(
        '${config.url}$endpoint',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final orders = (response.data as List)
            .map((json) => _parseOrder(json as Map<String, dynamic>))
            .toList();
        return orders;
      }

      throw Exception('Error al obtener órdenes: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error en WooCommerce: $e');
    }
  }

  WooCommerceOrder _parseOrder(Map<String, dynamic> json) {
    final lineItems = (json['line_items'] as List?)
        ?.map((item) => WooCommerceLineItem(
              productId: item['product_id'] as int,
              quantity: (item['quantity'] as num).toInt(),
              total: item['total'] as String,
            ))
        .toList() ?? [];

    return WooCommerceOrder(
      id: json['id'] as int,
      status: json['status'] as String,
      total: json['total'] as String,
      dateCreated: DateTime.parse(json['date_created'] as String),
      customerId: json['customer_id'] as int?,
      paymentMethod: json['payment_method'] as String?,
      lineItems: lineItems,
    );
  }

  Future<void> crearOrdenDesdeVenta(int ventaId) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('WooCommerce no configurado o inactivo');
    }

    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    // Obtener venta y detalles
    final ventas = await db.query(
      'ventas',
      where: 'id = ? AND company_id = ?',
      whereArgs: [ventaId, companyId],
    );

    if (ventas.isEmpty) {
      throw Exception('Venta no encontrada');
    }

    final venta = ventas.first;
    final detalles = await db.query(
      'ventas_detalle',
      where: 'venta_id = ? AND company_id = ?',
      whereArgs: [ventaId, companyId],
    );

    final lineItems = detalles.map((detalle) {
      return {
        'product_id': detalle['producto_id'],
        'quantity': detalle['cantidad'],
        'total': detalle['subtotal'].toString(),
      };
    }).toList();

    try {
      final endpoint = config.generarAuthUrl('/wp-json/wc/v3/orders');
      final response = await _dio.post(
        '${config.url}$endpoint',
        data: {
          'payment_method': 'merkaerp',
          'payment_method_title': 'MerkaERP',
          'set_paid': true,
          'billing': {
            'first_name': venta['cliente']?.toString() ?? 'Cliente',
          },
          'line_items': lineItems,
        },
      );

      if (response.statusCode == 201) {
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'WOOCOMMERCE_ORDEN_CREADA',
          entidad: 'integraciones',
          detalle: 'Venta ID: $ventaId -> WooCommerce Order ID: ${response.data['id']}',
        );
      }
    } catch (e) {
      throw Exception('Error al crear orden en WooCommerce: $e');
    }
  }

  Future<void> probarConexion() async {
    final config = await obtenerConfiguracion();
    if (config == null) {
      throw Exception('WooCommerce no configurado');
    }

    try {
      final endpoint = config.generarAuthUrl('/wp-json/wc/v3/system_status');
      final response = await _dio.get('${config.url}$endpoint');

      if (response.statusCode != 200) {
        throw Exception('Conexión fallida: ${response.statusCode}');
      }

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'WOOCOMMERCE_CONEXION_EXITOSA',
        entidad: 'integraciones',
        detalle: 'URL: ${config.url}',
      );
    } catch (e) {
      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'WOOCOMMERCE_CONEXION_FALLIDA',
        entidad: 'integraciones',
        detalle: 'Error: $e',
      );
      rethrow;
    }
  }
}
