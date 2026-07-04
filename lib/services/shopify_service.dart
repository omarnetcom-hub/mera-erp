import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

enum ShopifySyncStatus { pendiente, sincronizando, exitoso, error }

class ShopifyConfig {
  const ShopifyConfig({
    required this.shopDomain,
    required this.accessToken,
    required this.apiVersion,
    this.activo = true,
  });

  final String shopDomain;
  final String accessToken;
  final String apiVersion;
  final bool activo;

  String get baseUrl => 'https://$shopDomain.myshopify.com/admin/api/$apiVersion';
}

class ShopifyProduct {
  const ShopifyProduct({
    required this.id,
    required this.title,
    required this.inventoryItemId,
    required this.variants,
  });

  final int id;
  final String title;
  final int inventoryItemId;
  final List<ShopifyVariant> variants;
}

class ShopifyVariant {
  const ShopifyVariant({
    required this.id,
    required this.inventoryQuantity,
    required this.price,
    this.sku,
  });

  final int id;
  final int inventoryQuantity;
  final String price;
  final String? sku;
}

class ShopifyOrder {
  const ShopifyOrder({
    required this.id,
    required this.orderNumber,
    required this.totalPrice,
    required this.createdAt,
    required this.financialStatus,
    this.customerId,
    this.lineItems = const [],
  });

  final int id;
  final String orderNumber;
  final String totalPrice;
  final DateTime createdAt;
  final String financialStatus;
  final int? customerId;
  final List<ShopifyLineItem> lineItems;
}

class ShopifyLineItem {
  const ShopifyLineItem({
    required this.productId,
    required this.quantity,
    required this.price,
  });

  final int productId;
  final int quantity;
  final String price;
}

class ShopifyService {
  ShopifyService._();

  static final ShopifyService instance = ShopifyService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'X-Shopify-Access-Token': '',
    },
  ));

  Future<ShopifyConfig?> obtenerConfiguracion() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    
    final rows = await db.query(
      'integraciones',
      where: 'company_id = ? AND tipo = ? AND activo = ?',
      whereArgs: [companyId, 'shopify', 1],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final configJson = rows.first['config'] as String?;
    if (configJson == null) return null;

    final config = jsonDecode(configJson) as Map<String, dynamic>;
    return ShopifyConfig(
      shopDomain: config['shop_domain'] as String,
      accessToken: config['access_token'] as String,
      apiVersion: config['api_version'] as String? ?? '2024-01',
      activo: (rows.first['activo'] as int) == 1,
    );
  }

  Future<void> guardarConfiguracion(ShopifyConfig config) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final configJson = jsonEncode({
      'shop_domain': config.shopDomain,
      'access_token': config.accessToken,
      'api_version': config.apiVersion,
    });

    await db.insert(
      'integraciones',
      {
        'company_id': companyId,
        'tipo': 'shopify',
        'nombre': 'Shopify',
        'config': configJson,
        'activo': config.activo ? 1 : 0,
        'creado_en': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'SHOPIFY_CONFIG_GUARDADA',
      entidad: 'integraciones',
      detalle: 'Shop: ${config.shopDomain}',
    );
  }

  Future<List<ShopifyProduct>> obtenerProductos({int limit = 250}) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('Shopify no configurado o inactivo');
    }

    try {
      _dio.options.headers['X-Shopify-Access-Token'] = config.accessToken;
      
      final response = await _dio.get(
        '${config.baseUrl}/products.json',
        queryParameters: {
          'limit': limit,
          'status': 'active',
        },
      );

      if (response.statusCode == 200) {
        final products = (response.data['products'] as List)
            .map((json) => _parseProduct(json as Map<String, dynamic>))
            .toList();
        return products;
      }

      throw Exception('Error al obtener productos: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error en Shopify: $e');
    }
  }

  ShopifyProduct _parseProduct(Map<String, dynamic> json) {
    final variants = (json['variants'] as List?)
        ?.map((v) => ShopifyVariant(
              id: v['id'] as int,
              inventoryQuantity: (v['inventory_quantity'] as num?)?.toInt() ?? 0,
              price: v['price'] as String,
              sku: v['sku'] as String?,
            ))
        .toList() ?? [];

    return ShopifyProduct(
      id: json['id'] as int,
      title: json['title'] as String,
      inventoryItemId: (json['variants'] as List?)?.isNotEmpty == true
          ? (json['variants'][0]['inventory_item_id'] as int?) ?? 0
          : 0,
      variants: variants,
    );
  }

  Future<void> actualizarInventario(int inventoryItemId, int cantidad) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('Shopify no configurado o inactivo');
    }

    try {
      _dio.options.headers['X-Shopify-Access-Token'] = config.accessToken;
      
      final response = await _dio.post(
        '${config.baseUrl}/inventory_levels/set.json',
        data: {
          'location_id': await _obtenerLocationId(config),
          'inventory_item_id': inventoryItemId,
          'available': cantidad,
        },
      );

      if (response.statusCode == 200) {
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'SHOPIFY_INVENTARIO_ACTUALIZADO',
          entidad: 'integraciones',
          detalle: 'Inventory Item ID: $inventoryItemId, Cantidad: $cantidad',
        );
      }
    } catch (e) {
      throw Exception('Error al actualizar inventario: $e');
    }
  }

  Future<int> _obtenerLocationId(ShopifyConfig config) async {
    try {
      _dio.options.headers['X-Shopify-Access-Token'] = config.accessToken;
      
      final response = await _dio.get(
        '${config.baseUrl}/locations.json',
      );

      if (response.statusCode == 200 && response.data['locations'] != null) {
        final locations = response.data['locations'] as List;
        if (locations.isNotEmpty) {
          return locations[0]['id'] as int;
        }
      }

      throw Exception('No se encontraron ubicaciones');
    } catch (e) {
      throw Exception('Error al obtener location ID: $e');
    }
  }

  Future<List<ShopifyOrder>> obtenerOrdenes({
    String status = 'any',
    DateTime? createdAtMin,
    DateTime? createdAtMax,
  }) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('Shopify no configurado o inactivo');
    }

    try {
      _dio.options.headers['X-Shopify-Access-Token'] = config.accessToken;
      
      final queryParams = <String, dynamic>{
        'status': status,
        'limit': 250,
      };

      if (createdAtMin != null) {
        queryParams['created_at_min'] = createdAtMin.toIso8601String();
      }
      if (createdAtMax != null) {
        queryParams['created_at_max'] = createdAtMax.toIso8601String();
      }

      final response = await _dio.get(
        '${config.baseUrl}/orders.json',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final orders = (response.data['orders'] as List)
            .map((json) => _parseOrder(json as Map<String, dynamic>))
            .toList();
        return orders;
      }

      throw Exception('Error al obtener órdenes: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error en Shopify: $e');
    }
  }

  ShopifyOrder _parseOrder(Map<String, dynamic> json) {
    final lineItems = (json['line_items'] as List?)
        ?.map((item) => ShopifyLineItem(
              productId: item['product_id'] as int,
              quantity: (item['quantity'] as num).toInt(),
              price: item['price'] as String,
            ))
        .toList() ?? [];

    return ShopifyOrder(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      totalPrice: json['total_price'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      financialStatus: json['financial_status'] as String,
      customerId: json['customer']?['id'] as int?,
      lineItems: lineItems,
    );
  }

  Future<void> crearWebhook(String topic, String callbackUrl) async {
    final config = await obtenerConfiguracion();
    if (config == null || !config.activo) {
      throw Exception('Shopify no configurado o inactivo');
    }

    try {
      _dio.options.headers['X-Shopify-Access-Token'] = config.accessToken;
      
      final response = await _dio.post(
        '${config.baseUrl}/webhooks.json',
        data: {
          'webhook': {
            'topic': topic,
            'address': callbackUrl,
            'format': 'json',
          },
        },
      );

      if (response.statusCode == 201) {
        await DatabaseHelper.instance.registrarEventoAuditoria(
          accion: 'SHOPIFY_WEBHOOK_CREADO',
          entidad: 'integraciones',
          detalle: 'Topic: $topic, URL: $callbackUrl',
        );
      }
    } catch (e) {
      throw Exception('Error al crear webhook: $e');
    }
  }

  Future<void> probarConexion() async {
    final config = await obtenerConfiguracion();
    if (config == null) {
      throw Exception('Shopify no configurado');
    }

    try {
      _dio.options.headers['X-Shopify-Access-Token'] = config.accessToken;
      
      final response = await _dio.get(
        '${config.baseUrl}/shop.json',
      );

      if (response.statusCode != 200) {
        throw Exception('Conexión fallida: ${response.statusCode}');
      }

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'SHOPIFY_CONEXION_EXITOSA',
        entidad: 'integraciones',
        detalle: 'Shop: ${config.shopDomain}',
      );
    } catch (e) {
      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'SHOPIFY_CONEXION_FALLIDA',
        entidad: 'integraciones',
        detalle: 'Error: $e',
      );
      rethrow;
    }
  }
}
