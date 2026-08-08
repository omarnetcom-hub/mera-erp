import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core/currency/money_currency_resolver.dart';
import 'core/currency/money_value.dart';
import 'db_helper.dart';
import 'services/enterprise_feature_service.dart';

class PublicApiServer {
  PublicApiServer._();

  static HttpServer? _server;

  static Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      unawaited(_server!.listen(_handle).asFuture<void>());
    } catch (_) {
      _server = null;
    }
  }

  static Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json(request, {'ok': true, 'service': 'merkaerp-public-api'});
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/openapi.json') {
        await _json(request, _openApi());
        return;
      }
      if (!await _authorized(request)) {
        request.response.statusCode = HttpStatus.unauthorized;
        await _json(request, {'ok': false, 'error': 'unauthorized'});
        return;
      }
      final db = await DatabaseHelper.instance.database;
      final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
      if (request.method == 'GET' && request.uri.path == '/api/v1/productos') {
        await _json(request, {
          'ok': true,
          'data': await db.query(
            'productos',
            where: 'company_id = ?',
            whereArgs: [companyId],
            limit: _limit(request),
          ),
        });
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/api/v1/clientes') {
        await _json(request, {
          'ok': true,
          'data': await db.query(
            'clientes',
            where: 'company_id = ?',
            whereArgs: [companyId],
            limit: _limit(request),
          ),
        });
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/api/v1/ventas') {
        await _json(request, {
          'ok': true,
          'data': await db.query(
            'ventas',
            where: 'company_id = ?',
            whereArgs: [companyId],
            orderBy: 'fecha DESC',
            limit: _limit(request),
          ),
        });
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/api/v1/inventario') {
        await _json(request, {
          'ok': true,
          'data': await db.rawQuery(
            '''
            SELECT id, nombre, stock, costo, precio, codigo_barras,
                   ubicacion_codigo, ubicacion_pasillo, ubicacion_estante,
                   ubicacion_nivel
            FROM productos
            WHERE company_id = ?
            ORDER BY nombre ASC
            LIMIT ?
            ''',
            [companyId, _limit(request)],
          ),
        });
        return;
      }
      if (request.method == 'GET' &&
          request.uri.path == '/api/v1/cotizaciones') {
        await _json(request, {
          'ok': true,
          'data': await db.query(
            'cotizaciones',
            where: 'company_id = ?',
            whereArgs: [companyId],
            orderBy: 'fecha DESC',
            limit: _limit(request),
          ),
        });
        return;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/api/v1/cotizaciones') {
        final body = await _body(request);
        final id = await EnterpriseFeatureService().crearCotizacion(
          clienteId: (body['cliente_id'] as num?)?.toInt(),
          cliente: body['cliente']?.toString() ?? 'Consumidor final',
          items: await _lineItems(body['items']),
          observacion: body['observacion']?.toString() ?? '',
        );
        await _json(request, {
          'ok': true,
          'id': id,
        }, status: HttpStatus.created);
        return;
      }
      final pedidoMatch = RegExp(
        r'^/api/v1/cotizaciones/(\d+)/pedido$',
      ).firstMatch(request.uri.path);
      if (request.method == 'POST' && pedidoMatch != null) {
        final id = await EnterpriseFeatureService().convertirCotizacionAPedido(
          int.parse(pedidoMatch.group(1)!),
        );
        await _json(request, {
          'ok': true,
          'id': id,
        }, status: HttpStatus.created);
        return;
      }
      final facturaMatch = RegExp(
        r'^/api/v1/pedidos/(\d+)/factura$',
      ).firstMatch(request.uri.path);
      if (request.method == 'POST' && facturaMatch != null) {
        final body = await _body(request);
        final id = await EnterpriseFeatureService().facturarPedido(
          int.parse(facturaMatch.group(1)!),
          metodoPagoId: (body['metodo_pago_id'] as num?)?.toInt() ?? 1,
          bodegaId: (body['bodega_id'] as num?)?.toInt(),
        );
        await _json(request, {
          'ok': true,
          'id': id,
        }, status: HttpStatus.created);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/api/v1/webhooks') {
        final body = await _body(request);
        final id = await EnterpriseFeatureService().registrarWebhook(
          evento: body['evento']?.toString() ?? '',
          url: body['url']?.toString() ?? '',
        );
        await _json(request, {
          'ok': true,
          'id': id,
        }, status: HttpStatus.created);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/api/v1/tokens') {
        final token = await _issueJwt();
        await _json(request, {'ok': true, 'token': token});
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await _json(request, {'ok': false, 'error': 'not_found'});
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      await _json(request, {'ok': false, 'error': error.toString()});
    }
  }

  static Future<bool> _authorized(HttpRequest request) async {
    final expected = await _apiToken();
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (header == 'Bearer $expected') return true;
    if (!header.startsWith('Bearer ')) return false;
    return _verifyLocalJwt(header.substring(7), expected);
  }

  static Future<String> _apiToken() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['public_api_token'],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['valor']?.toString() ?? '';
    const token = 'merka-local-dev-token';
    await db.insert('app_config', {
      'clave': 'public_api_token',
      'valor': token,
    });
    return token;
  }

  static int _limit(HttpRequest request) {
    final value =
        int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 100;
    return value.clamp(1, 500).toInt();
  }

  static Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('JSON body must be an object.');
  }

  static Future<List<EnterpriseLineItem>> _lineItems(Object? raw) async {
    if (raw is! List) throw const FormatException('items must be a list.');
    final db = await DatabaseHelper.instance.database;
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: await DatabaseHelper.instance.obtenerEmpresaActivaId(),
    );
    return raw.map((item) {
      if (item is! Map) throw const FormatException('invalid line item.');
      return EnterpriseLineItem(
        productoId: (item['producto_id'] as num).toInt(),
        producto: item['producto']?.toString() ?? '',
        cantidad: (item['cantidad'] as num).toDouble(),
        precioUnitario: MoneyValue.fromMajorUnits(
          item['precio_unitario'].toString(),
          currency: currency,
        ),
      );
    }).toList();
  }

  static Future<void> _json(
    HttpRequest request,
    Object body, {
    int status = HttpStatus.ok,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  static Future<String> _issueJwt() async {
    final secret = await _apiToken();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = _b64(jsonEncode({'alg': 'MERKA-LOCAL', 'typ': 'JWT'}));
    final payload = _b64(
      jsonEncode({
        'iss': 'MerkaERP',
        'aud': 'integrations',
        'iat': now,
        'exp': now + 3600 * 12,
        'scope': ['read', 'write'],
      }),
    );
    final signature = _b64('$header.$payload.$secret');
    return '$header.$payload.$signature';
  }

  static bool _verifyLocalJwt(String token, String secret) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    if (parts[2] != _b64('${parts[0]}.${parts[1]}.$secret')) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = (payload['exp'] as num?)?.toInt() ?? 0;
      return exp > DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return false;
    }
  }

  static String _b64(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  static Map<String, Object?> _openApi() {
    return {
      'openapi': '3.0.0',
      'info': {'title': 'MerkaERP Public API', 'version': '1.0.0'},
      'servers': [
        {'url': 'http://127.0.0.1:8080'},
      ],
      'components': {
        'securitySchemes': {
          'bearerAuth': {'type': 'http', 'scheme': 'bearer'},
        },
      },
      'security': [
        {'bearerAuth': <String>[]},
      ],
      'paths': {
        '/api/v1/productos': {'get': _path('Lista productos')},
        '/api/v1/clientes': {'get': _path('Lista clientes')},
        '/api/v1/ventas': {'get': _path('Lista ventas')},
        '/api/v1/inventario': {'get': _path('Estado de inventario')},
        '/api/v1/cotizaciones': {
          'get': _path('Lista cotizaciones'),
          'post': _path('Crea cotizacion'),
        },
        '/api/v1/cotizaciones/{id}/pedido': {
          'post': _path('Convierte cotizacion en pedido'),
        },
        '/api/v1/pedidos/{id}/factura': {'post': _path('Factura pedido')},
        '/api/v1/webhooks': {'post': _path('Registra webhook')},
        '/api/v1/tokens': {'post': _path('Emite JWT local')},
      },
    };
  }

  static Map<String, Object?> _path(String summary) {
    return {
      'summary': summary,
      'responses': {
        '200': {'description': 'OK'},
        '401': {'description': 'Unauthorized'},
      },
    };
  }
}
