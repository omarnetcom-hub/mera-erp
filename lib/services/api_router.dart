import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../core/currency/money_currency_resolver.dart';
import '../core/currency/money_value.dart';
import '../db_helper.dart';
import 'api_auth_service.dart';

class ApiRouter {
  ApiRouter._();

  static final ApiRouter instance = ApiRouter._();

  Future<Router> crearRouter() async {
    final router = Router();

    // Health check
    router.get('/api/v1/health', _healthCheckHandler);

    // Productos
    router.get('/api/v1/products', _listarProductosHandler);
    router.get('/api/v1/products/<id>', _obtenerProductoHandler);
    router.get('/api/v1/products/<id>/stock', _consultarStockHandler);
    router.patch('/api/v1/products/<id>/stock', _actualizarStockHandler);

    // Clientes
    router.get('/api/v1/customers', _listarClientesHandler);
    router.post('/api/v1/customers', _crearClienteHandler);
    router.get('/api/v1/customers/<id>', _obtenerClienteHandler);

    // Órdenes/Ventas
    router.post('/api/v1/orders', _crearOrdenHandler);
    router.get('/api/v1/orders/<id>', _obtenerOrdenHandler);

    // Facturas
    router.get('/api/v1/invoices/<id>', _obtenerFacturaHandler);

    // Pagos
    router.post('/api/v1/payments', _registrarPagoHandler);

    // Webhooks
    router.post('/api/v1/webhooks', _procesarWebhookHandler);

    return router;
  }

  Future<Response> _healthCheckHandler(Request request) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.rawQuery('SELECT 1');
      return Response.ok(
        jsonEncode({
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0.0',
        }),
      );
    } catch (e) {
      return Response(
        503,
        body: jsonEncode({'status': 'unhealthy', 'error': e.toString()}),
      );
    }
  }

  Future<Response> _listarProductosHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/products',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final productos = await db.query(
        'productos',
        where: 'company_id = ?',
        whereArgs: [companyId],
        columns: ['id', 'nombre', 'stock', 'precio', 'codigo_barras'],
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': productos,
          'count': productos.length,
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _obtenerProductoHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      final id = int.parse(request.params['id'] as String);
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/products/$id',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final productos = await db.query(
        'productos',
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );

      if (productos.isEmpty) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'error': 'Producto no encontrado',
          }),
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': productos.first}),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _consultarStockHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      final id = int.parse(request.params['id'] as String);
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/products/$id/stock',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final productos = await db.query(
        'productos',
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
        columns: ['id', 'nombre', 'stock'],
      );

      if (productos.isEmpty) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'error': 'Producto no encontrado',
          }),
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': productos.first['id'],
            'nombre': productos.first['nombre'],
            'stock': productos.first['stock'],
          },
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _actualizarStockHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      final id = int.parse(request.params['id'] as String);
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/products/$id/stock',
        'PATCH',
      );

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final nuevoStock = body['stock'] as num?;

      if (nuevoStock == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': 'Se requiere el campo stock',
          }),
        );
      }

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final count = await db.update(
        'productos',
        {'stock': nuevoStock.toDouble()},
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );

      if (count == 0) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'error': 'Producto no encontrado',
          }),
        );
      }

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'API_STOCK_ACTUALIZADO',
        entidad: 'productos',
        detalle: 'Producto ID: $id, Nuevo stock: $nuevoStock',
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'id': id, 'stock': nuevoStock},
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _listarClientesHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/customers',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final clientes = await db.query(
        'clientes',
        where: 'company_id = ?',
        whereArgs: [companyId],
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': clientes,
          'count': clientes.length,
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _crearClienteHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/customers',
        'POST',
      );

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final nombre = body['nombre'] as String?;
      final nit = body['nit'] as String?;
      final telefono = body['telefono'] as String?;
      final direccion = body['direccion'] as String?;
      final email = body['email'] as String?;

      if (nombre == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': 'Se requiere el campo nombre',
          }),
        );
      }

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final id = await db.insert('clientes', {
        'company_id': companyId,
        'nombre': nombre,
        'nit': nit ?? '',
        'telefono': telefono ?? '',
        'direccion': direccion ?? '',
        'email': email ?? '',
        'estado': 'activo',
        'fecha': DateTime.now().toIso8601String(),
      });

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'API_CLIENTE_CREADO',
        entidad: 'clientes',
        detalle: 'Cliente ID: $id, Nombre: $nombre',
      );

      return Response(
        201,
        body: jsonEncode({
          'success': true,
          'data': {'id': id, 'nombre': nombre},
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _obtenerClienteHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      final id = int.parse(request.params['id'] as String);
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/customers/$id',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final clientes = await db.query(
        'clientes',
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );

      if (clientes.isEmpty) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'error': 'Cliente no encontrado',
          }),
        );
      }

      return Response.ok(jsonEncode({'success': true, 'data': clientes.first}));
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _crearOrdenHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/orders',
        'POST',
      );

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final clienteId = body['cliente_id'] as int?;
      final items = body['items'] as List?;

      if (items == null || items.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': 'Se requiere al menos un item en la orden',
          }),
        );
      }

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      // Crear venta
      final ventaId = await db.insert('ventas', {
        'company_id': companyId,
        'cliente_id': clienteId,
        'fecha': DateTime.now().toIso8601String(),
        'estado': 'emitida',
        'total': 0.0, // Se calculará después
      });

      final currency = await MoneyCurrencyResolver.resolve(
        db,
        companyId: companyId,
      );
      var total = MoneyValue(minorUnits: 0, currency: currency);
      for (final item in items) {
        final productoId = item['producto_id'] as int;
        final cantidad = (item['cantidad'] as num).toDouble();
        final precio = MoneyValue.fromMajorUnits(
          item['precio'].toString(),
          currency: currency,
        );
        final subtotal = precio.multiplyDecimal(cantidad.toString());
        total += subtotal;

        await db.insert('ventas_detalle', {
          'company_id': companyId,
          'venta_id': ventaId,
          'producto_id': productoId,
          'cantidad': cantidad,
          'precio_unitario': precio.toSql(),
          'subtotal': subtotal.toSql(),
        });
      }

      await db.update(
        'ventas',
        {'total': total.toSql()},
        where: 'id = ?',
        whereArgs: [ventaId],
      );

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'API_ORDEN_CREADA',
        entidad: 'ventas',
        detalle: 'Venta ID: $ventaId, Total: ${total.format()}',
      );

      return Response(
        201,
        body: jsonEncode({
          'success': true,
          'data': {'id': ventaId, 'total': total.toWireMap()},
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _obtenerOrdenHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      final id = int.parse(request.params['id'] as String);
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/orders/$id',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final ventas = await db.query(
        'ventas',
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );

      if (ventas.isEmpty) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'error': 'Orden no encontrada'}),
        );
      }

      final detalles = await db.query(
        'ventas_detalle',
        where: 'venta_id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'venta': ventas.first, 'detalles': detalles},
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _obtenerFacturaHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      final id = int.parse(request.params['id'] as String);
      final formato = request.url.queryParameters['format'] ?? 'json';

      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/invoices/$id',
        'GET',
      );

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

      final ventas = await db.query(
        'ventas',
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );

      if (ventas.isEmpty) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'error': 'Factura no encontrada',
          }),
        );
      }

      if (formato == 'json') {
        return Response.ok(jsonEncode({'success': true, 'data': ventas.first}));
      }

      // Para PDF, se usaría el servicio existente de generación de PDF
      return Response(
        501,
        body: jsonEncode({
          'success': false,
          'error': 'Formato PDF no implementado aún',
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _registrarPagoHandler(Request request) async {
    try {
      final apiKey = request.context['apiKey'] as ApiKey;
      await ApiAuthService.instance.registrarAcceso(
        apiKey,
        '/api/v1/payments',
        'POST',
      );

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final facturaId = body['factura_id'] as int?;
      final metodo = body['metodo'] as String?;
      final referencia = body['referencia'] as String?;

      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
      final currency = await MoneyCurrencyResolver.resolve(
        db,
        companyId: companyId,
      );
      final monto = MoneyValue.fromMajorUnits(
        body['monto'].toString(),
        currency: currency,
      );
      if (facturaId == null || monto.minorUnits <= 0) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': 'Se requiere factura_id y monto válido',
          }),
        );
      }

      // Registrar movimiento de caja
      await db.insert('movimientos_caja', {
        'company_id': companyId,
        'tipo': 'ingreso',
        'concepto': 'Pago API - Factura $facturaId',
        'monto': monto.toSql(),
        'fecha': DateTime.now().toIso8601String(),
        'origen': 'api',
      });

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'API_PAGO_REGISTRADO',
        entidad: 'pagos',
        detalle: 'Factura: $facturaId, Monto: $monto, Método: $metodo',
      );

      return Response(
        201,
        body: jsonEncode({
          'success': true,
          'data': {
            'factura_id': facturaId,
            'monto': monto.toWireMap(),
            'referencia': referencia,
          },
        }),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  Future<Response> _procesarWebhookHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final evento = request.headers['X-Webhook-Event'];
      final signature = request.headers['X-Webhook-Signature'];

      // Aquí se validaría la firma HMAC con el webhook processor
      // Por ahora, solo registramos el evento

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'API_WEBHOOK_RECIBIDO',
        entidad: 'webhooks',
        detalle: 'Evento: $evento, Signature: $signature',
      );

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Webhook procesado'}),
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
}
