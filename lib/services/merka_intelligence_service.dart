import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/currency/currency.dart';
import '../core/currency/money_currency_resolver.dart';
import '../core/currency/money_value.dart';
import '../db_helper.dart';
import 'control_center_endpoint.dart';

class ProductLookupResult {
  const ProductLookupResult({
    required this.product,
    required this.matchedBy,
    required this.currency,
    this.lot,
    this.suggestions = const [],
  });

  final Map<String, dynamic> product;
  final String matchedBy;
  final Currency currency;
  final Map<String, dynamic>? lot;
  final List<Map<String, dynamic>> suggestions;

  String get name => product['nombre']?.toString() ?? 'Producto';
  double get stock => (product['stock'] as num?)?.toDouble() ?? 0;
  double get price => MoneyValue.fromSql(
    product['precio'],
    currency: currency,
    nullableAsZero: true,
  ).toMajorUnitsDoubleForDisplay();
  String get location {
    final code = product['ubicacion_codigo']?.toString().trim() ?? '';
    if (code.isNotEmpty) return code;
    final parts = [
      product['ubicacion_pasillo']?.toString() ?? '',
      product['ubicacion_estante']?.toString() ?? '',
      product['ubicacion_nivel']?.toString() ?? '',
    ].where((part) => part.trim().isNotEmpty).join('-');
    return parts;
  }
}

class OperationalAlert {
  const OperationalAlert({
    required this.title,
    required this.detail,
    required this.priority,
    required this.kind,
    this.entityId,
  });

  final String title;
  final String detail;
  final String priority;
  final String kind;
  final int? entityId;
}

class CopilotReply {
  const CopilotReply({
    required this.intent,
    required this.response,
    this.moduleId,
  });

  final String intent;
  final String response;
  final String? moduleId;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.salesToday,
    required this.criticalStock,
    required this.overdueReceivables,
    required this.cashFlow,
    required this.salesLast7Days,
    required this.incomeMonth,
    required this.expenseMonth,
  });

  final double salesToday;
  final int criticalStock;
  final double overdueReceivables;
  final double cashFlow;
  final List<double> salesLast7Days;
  final double incomeMonth;
  final double expenseMonth;
}

class MerkaIntelligenceService {
  MerkaIntelligenceService({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<ProductLookupResult?> findProduct(String query) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final rows = await db.query(
      'productos',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'nombre ASC',
    );
    Map<String, dynamic>? best;
    var matchedBy = 'nombre';
    for (final row in rows) {
      final barcode = _normalize(row['codigo_barras']);
      final reference = _normalize(row['referencia']);
      final name = _normalize(row['nombre']);
      final description = _normalize(row['descripcion']);
      if (barcode.isNotEmpty && barcode == normalized) {
        best = row;
        matchedBy = 'codigo_barras';
        break;
      }
      if (reference.isNotEmpty && reference == normalized) {
        best = row;
        matchedBy = 'referencia';
        break;
      }
      if (name.contains(normalized) || description.contains(normalized)) {
        best ??= row;
        matchedBy = name.contains(normalized) ? 'nombre' : 'descripcion';
      }
    }
    if (best == null) return null;
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: companyId,
    );
    final productId = (best['id'] as num).toInt();
    return ProductLookupResult(
      product: best,
      matchedBy: matchedBy,
      currency: currency,
      lot: await nextFifoLot(productId),
      suggestions: await crossSellSuggestions(productId),
    );
  }

  Future<Map<String, dynamic>?> nextFifoLot(int productId) async {
    final db = await _db.database;
    final rows = await db.query(
      'lotes',
      where: 'producto_id = ? AND cantidad > 0',
      whereArgs: [productId],
      orderBy:
          "CASE WHEN fecha_vencimiento IS NULL OR fecha_vencimiento = '' THEN 1 ELSE 0 END, fecha_vencimiento ASC, id ASC",
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> crossSellSuggestions(int productId) async {
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: companyId,
    );
    final rows = await db.rawQuery(
      '''
      SELECT p.*, COUNT(*) AS score
      FROM ventas_detalle base
      INNER JOIN ventas_detalle rel ON rel.venta_id = base.venta_id
      INNER JOIN productos p ON p.id = rel.producto_id
      WHERE base.producto_id = ?
        AND rel.producto_id != ?
        AND p.company_id = ?
      GROUP BY p.id
      ORDER BY score DESC, p.nombre ASC
      LIMIT 3
      ''',
      [productId, productId, companyId],
    );
    if (rows.isNotEmpty) return rows;
    return db.query(
      'productos',
      where: 'company_id = ? AND id != ? AND stock > 0',
      whereArgs: [companyId, productId],
      orderBy: 'stock DESC, nombre ASC',
      limit: 3,
    );
  }

  Future<List<OperationalAlert>> operationalAlerts() async {
    if (DatabaseHelper.disableAutoLoadsForTests) {
      return const [];
    }
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: companyId,
    );
    final now = DateTime.now();
    final until = now.add(const Duration(days: 30)).toIso8601String();
    final expiringRows = await db.rawQuery(
      '''
      SELECT l.id, l.producto_id, l.codigo_lote, l.fecha_vencimiento, l.cantidad, p.nombre
      FROM lotes l
      INNER JOIN productos p ON p.id = l.producto_id
      WHERE COALESCE(l.company_id, ?) = ?
        AND l.cantidad > 0
        AND l.fecha_vencimiento IS NOT NULL
        AND l.fecha_vencimiento != ''
        AND l.fecha_vencimiento <= ?
      ORDER BY l.fecha_vencimiento ASC
      LIMIT 8
      ''',
      [companyId, companyId, until],
    );
    final stockRows = await db.query(
      'productos',
      where: 'company_id = ? AND stock <= 5',
      whereArgs: [companyId],
      orderBy: 'stock ASC',
      limit: 8,
    );
    final receivables = await db.rawQuery(
      '''
      SELECT cliente, saldo
      FROM cuentas_por_cobrar
      WHERE company_id = ? AND saldo > 0 AND estado != 'pagada'
      ORDER BY fecha ASC
      LIMIT 5
      ''',
      [companyId],
    );
    return [
      for (final row in expiringRows)
        OperationalAlert(
          title: '${row['nombre']} por vencer',
          detail:
              'Lote ${row['codigo_lote']} vence ${_shortDate(row['fecha_vencimiento'])}. Cantidad ${(row['cantidad'] as num?)?.toStringAsFixed(0) ?? '0'}.',
          priority: 'urgent',
          kind: 'expiring_product',
          entityId: (row['producto_id'] as num?)?.toInt(),
        ),
      for (final row in stockRows)
        OperationalAlert(
          title: 'Stock critico: ${row['nombre']}',
          detail:
              'Quedan ${(row['stock'] as num?)?.toStringAsFixed(0) ?? '0'} unidades. Revisa compra o traslado.',
          priority: 'warning',
          kind: 'critical_stock',
          entityId: (row['id'] as num?)?.toInt(),
        ),
      for (final row in receivables)
        OperationalAlert(
          title: 'Cobranza pendiente',
          detail:
              '${row['cliente'] ?? 'Cliente'} debe ${_money(MoneyValue.fromSql(row['saldo'], currency: currency, nullableAsZero: true).toMajorUnitsDoubleForDisplay())}.',
          priority: 'info',
          kind: 'receivable',
        ),
    ];
  }

  Future<DashboardSnapshot> dashboardSnapshot() async {
    if (DatabaseHelper.disableAutoLoadsForTests) {
      return const DashboardSnapshot(
        salesToday: 0,
        criticalStock: 0,
        overdueReceivables: 0,
        cashFlow: 0,
        salesLast7Days: [0, 0, 0, 0, 0, 0, 0],
        incomeMonth: 0,
        expenseMonth: 0,
      );
    }
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: companyId,
    );
    final now = DateTime.now();
    final salesToday = await _sumSales(db, companyId, now, now, currency);
    final criticalRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM productos WHERE company_id = ? AND stock <= 5',
      [companyId],
    );
    final receivableRows = await db.rawQuery(
      "SELECT COALESCE(SUM(saldo), 0) AS total FROM cuentas_por_cobrar WHERE company_id = ? AND saldo > 0 AND estado != 'pagada'",
      [companyId],
    );
    final incomeRows = await db.rawQuery(
      "SELECT COALESCE(SUM(monto), 0) AS total FROM movimientos_caja WHERE company_id = ? AND tipo = 'ingreso'",
      [companyId],
    );
    final expenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(monto), 0) AS total FROM movimientos_caja WHERE company_id = ? AND tipo = 'egreso'",
      [companyId],
    );
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final monthEnd = DateTime(
      now.year,
      now.month + 1,
      0,
      23,
      59,
    ).toIso8601String();
    final monthIncomeRows = await db.rawQuery(
      "SELECT COALESCE(SUM(monto), 0) AS total FROM movimientos_caja WHERE company_id = ? AND tipo = 'ingreso' AND fecha BETWEEN ? AND ?",
      [companyId, monthStart, monthEnd],
    );
    final monthExpenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(monto), 0) AS total FROM movimientos_caja WHERE company_id = ? AND tipo = 'egreso' AND fecha BETWEEN ? AND ?",
      [companyId, monthStart, monthEnd],
    );
    final sales7 = <double>[];
    for (var i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      sales7.add(
        (await _sumSales(
          db,
          companyId,
          day,
          day,
          currency,
        )).toMajorUnitsDoubleForDisplay(),
      );
    }
    final income = MoneyValue.fromSql(
      incomeRows.first['total'],
      currency: currency,
    );
    final expense = MoneyValue.fromSql(
      expenseRows.first['total'],
      currency: currency,
    );
    final cashFlow = income - expense;
    return DashboardSnapshot(
      salesToday: salesToday.toMajorUnitsDoubleForDisplay(),
      criticalStock: (criticalRows.first['total'] as num?)?.toInt() ?? 0,
      overdueReceivables: MoneyValue.fromSql(
        receivableRows.first['total'],
        currency: currency,
      ).toMajorUnitsDoubleForDisplay(),
      cashFlow: cashFlow.toMajorUnitsDoubleForDisplay(),
      salesLast7Days: sales7,
      incomeMonth: MoneyValue.fromSql(
        monthIncomeRows.first['total'],
        currency: currency,
      ).toMajorUnitsDoubleForDisplay(),
      expenseMonth: MoneyValue.fromSql(
        monthExpenseRows.first['total'],
        currency: currency,
      ).toMajorUnitsDoubleForDisplay(),
    );
  }

  Future<CopilotReply> answer(
    String text, {
    String module = 'workspace',
    String role = 'local',
  }) async {
    final normalized = _normalize(text);
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final currency = await MoneyCurrencyResolver.resolve(
      db,
      companyId: companyId,
    );

    CopilotReply reply;
    if (_matches(normalized, [
      'ventas hoy',
      'vendi hoy',
      'vendí hoy',
      'ventas dia',
    ])) {
      final total = await _sumSales(
        db,
        companyId,
        DateTime.now(),
        DateTime.now(),
        currency,
      );
      reply = CopilotReply(
        intent: 'sales_today',
        moduleId: 'sales',
        response:
            'Hoy vas en ${_money(total.toMajorUnitsDoubleForDisplay())} en ventas emitidas. Puedo abrir Ventas para revisar el detalle o generar el reporte.',
      );
    } else if (_matches(normalized, [
      'ventas mes',
      'vendido mes',
      'ventas del mes',
    ])) {
      final now = DateTime.now();
      final total = await _sumSales(
        db,
        companyId,
        DateTime(now.year, now.month, 1),
        now,
        currency,
      );
      reply = CopilotReply(
        intent: 'sales_month',
        moduleId: 'reports',
        response:
            'Este mes llevas ${_money(total.toMajorUnitsDoubleForDisplay())} en ventas. Recomendacion: revisa top productos y cartera asociada.',
      );
    } else if (_matches(normalized, [
      'stock critico',
      'productos criticos',
      'bajo stock',
    ])) {
      final rows = await db.query(
        'productos',
        where: 'company_id = ? AND stock <= 5',
        whereArgs: [companyId],
        orderBy: 'stock ASC',
        limit: 5,
      );
      reply = CopilotReply(
        intent: 'critical_stock',
        moduleId: 'inventory',
        response: rows.isEmpty
            ? 'No veo productos con stock critico ahora mismo.'
            : 'Productos criticos: ${rows.map((r) => '${r['nombre']} (${r['stock']})').join(', ')}. Conviene crear compra o traslado.',
      );
    } else if (_matches(normalized, ['por vencer', 'vencimiento', 'vence'])) {
      final alerts = (await operationalAlerts())
          .where((item) => item.kind == 'expiring_product')
          .take(5)
          .toList();
      reply = CopilotReply(
        intent: 'expiring_products',
        moduleId: 'inventory',
        response: alerts.isEmpty
            ? 'No hay lotes por vencer en los proximos 30 dias.'
            : 'Estos productos requieren accion: ${alerts.map((a) => a.title).join(', ')}. Puedes venderlos primero por FIFO.',
      );
    } else if (_matches(normalized, [
      'cartera',
      'cobranza',
      'cobrar',
      'deuda',
    ])) {
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(saldo), 0) AS total FROM cuentas_por_cobrar WHERE company_id = ? AND saldo > 0',
        [companyId],
      );
      reply = CopilotReply(
        intent: 'receivables',
        moduleId: 'receivables',
        response:
            'La cartera pendiente registrada es ${_money(MoneyValue.fromSql(rows.first['total'], currency: currency, nullableAsZero: true).toMajorUnitsDoubleForDisplay())}. Puedo llevarte a Cuentas por cobrar.',
      );
    } else if (_matches(normalized, [
      'pagar',
      'cuentas por pagar',
      'proveedores',
    ])) {
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(saldo), 0) AS total FROM cuentas_por_pagar WHERE company_id = ? AND saldo > 0',
        [companyId],
      );
      reply = CopilotReply(
        intent: 'payables',
        moduleId: 'payables',
        response:
            'Tienes ${_money(MoneyValue.fromSql(rows.first['total'], currency: currency, nullableAsZero: true).toMajorUnitsDoubleForDisplay())} en cuentas por pagar. Revisa vencimientos antes de programar caja.',
      );
    } else if (_matches(normalized, [
      'crear compra',
      'orden de compra',
      'entrada mercancia',
    ])) {
      reply = const CopilotReply(
        intent: 'open_purchase',
        moduleId: 'purchases',
        response:
            'Listo. Abre Compras para registrar orden, recepcion o factura de proveedor. Si quieres, dime el proveedor y lo preparo en el siguiente paso.',
      );
    } else if (_matches(normalized, ['arqueo', 'cierre caja', 'cerrar caja'])) {
      reply = const CopilotReply(
        intent: 'cash_closing',
        moduleId: 'cash_closings',
        response:
            'Para cerrar caja debes registrar ventas, ingresos, egresos y justificar cualquier diferencia antes de confirmar el cierre.',
      );
    } else if (_matches(normalized, ['cotizacion', 'cotizacion', 'pedido'])) {
      reply = const CopilotReply(
        intent: 'quote_order',
        moduleId: 'sales',
        response:
            'El flujo comercial queda preparado como Cotizacion -> Pedido -> Factura. Abre Ventas para crear el documento inicial.',
      );
    } else if (_matches(normalized, [
      'factura electronica',
      'facturacion electronica',
      'dian',
      'cufe',
    ])) {
      reply = const CopilotReply(
        intent: 'electronic_invoice',
        moduleId: 'electronic_invoice',
        response:
            'El centro de Facturacion Electronica permite emitir documentos validados ante la DIAN, consultar el CUFE, gestionar resoluciones oficiales y configurar el proveedor tecnologico.',
      );
    } else if (_matches(normalized, [
      'licencia',
      'licencias',
      'activar licencia',
      'hwid',
      'plan',
    ])) {
      reply = const CopilotReply(
        intent: 'licensing',
        moduleId: 'licensing',
        response:
            'El modulo de Licencias te permite consultar tu plan activo, copiar tu Identificador de Dispositivo (HWID) y activar o renovar tu clave de suscripcion empresarial.',
      );
    } else if (_matches(normalized, ['instalaciones', 'control center'])) {
      reply = CopilotReply(
        intent: 'control_center_status',
        moduleId: 'erp_readiness',
        response: await controlCenterStatus(),
      );
    } else if (_matches(normalized, [
      'como funciona',
      'ayuda',
      'explicacion',
      'guia',
      'manual',
      'como hago',
      'como se',
      'que es',
    ])) {
      String manualResponse = 'Aquí tienes ayuda sobre el sistema:\n\n';
      if (_matches(normalized, [
        'caja',
        'cierre',
        'arqueo',
        'dinero',
        'billete',
        'moneda',
      ])) {
        manualResponse +=
            '• **Arqueo y Cierre de Caja**: Ahora puedes realizar el arqueo detallado utilizando la calculadora de Monedas y Billetes Colombianos (COP) en el diálogo de Cierre. Permite registrar billetes de \$100k a \$2k y monedas de \$1000 a \$50. El desglose se guarda en la observación del cierre y bloquea las operaciones para proteger el saldo.';
      } else if (_matches(normalized, [
        'lote',
        'vencimiento',
        'vence',
        'inventario',
        'caduca',
      ])) {
        manualResponse +=
            '• **Lotes y Vencimientos**: Al crear un nuevo producto con stock inicial, puedes indicar su código de lote y fecha de vencimiento. El sistema te alertará automáticamente si hay lotes a vencer en los próximos 30 días. Puedes ver los lotes de cada producto seleccionando "Ver lotes" en el listado de inventario.';
      } else if (_matches(normalized, [
        'factura',
        'dian',
        'electronica',
        'cufe',
        'xml',
        'ubl',
      ])) {
        manualResponse +=
            '• **Facturación Electrónica DIAN**: El sistema genera el XML en formato oficial UBL 2.1 con firma digital y cálculo de CUFE (SHA-384 + PIN). Gestiona resoluciones vigentes, rangos autorizados y simula la transmisión (HTTP 200) ante el webservice de la DIAN. Al pagar en el POS, se previsualiza el ticket térmico de 80mm de forma realista.';
      } else if (_matches(normalized, [
        'licencia',
        'activar',
        'suscripcion',
        'hwid',
        'plan',
      ])) {
        manualResponse +=
            '• **Licenciamiento Empresarial**: El software se valida offline u online firmando el Hardware ID (HWID) del PC del cliente. Puedes ver tu plan activo, copiar tu HWID o renovar ingresando tu clave de activación desde el módulo de Licencias.';
      } else if (_matches(normalized, [
        'puc',
        'contabilidad',
        'cuenta',
        'asiento',
      ])) {
        manualResponse +=
            '• **Plan de Cuentas (PUC)**: Se precarga el catálogo del Plan Único de Cuentas (PUC) comercial de Colombia con más de 80 cuentas jerárquicas operativas (Caja, Bancos, Cartera, IVA, Retenciones, etc.) integradas automáticamente con las ventas, compras y cobros.';
      } else {
        manualResponse +=
            'MerkaERP cuenta con manuales detallados de:\n'
            '1. **Caja y Arqueo Detallado (COP)**: calculadora física de denominaciones.\n'
            '2. **Inventario y Lotes**: control de fechas de vencimiento y lotes iniciales.\n'
            '3. **Facturación Electrónica DIAN**: XML UBL 2.1, CUFE y firma digital.\n'
            '4. **Licenciamiento y HWID**: control de suscripciones offline por Hardware ID.\n'
            '5. **Plan Único de Cuentas (PUC)**: catálogo contable oficial de Colombia.\n\n'
            'Pregúntame sobre cualquiera de estos temas para darte una explicación detallada.';
      }
      reply = CopilotReply(intent: 'manual_guide', response: manualResponse);
    } else {
      reply = const CopilotReply(
        intent: 'fallback',
        response:
            'Puedo ayudarte con ventas de hoy, ventas del mes, stock critico, productos por vencer, cartera, cuentas por pagar, facturacion electronica DIAN, licencias o estado de Control Center.',
      );
    }

    await db.insert('conversaciones_copilot', {
      'company_id': companyId,
      'usuario': 'local',
      'modulo': module,
      'rol': role,
      'mensaje_usuario': text,
      'respuesta': reply.response,
      'intent': reply.intent,
      'creada_en': DateTime.now().toIso8601String(),
    });
    return reply;
  }

  Future<String> controlCenterStatus() async {
    final endpoint = await _controlCenterEndpoint();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse('$endpoint/health'));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return 'Control Center responde correctamente en $endpoint. Estado: $body';
      }
      return 'Control Center respondio HTTP ${response.statusCode} en $endpoint.';
    } catch (_) {
      return 'No pude conectar con Control Center en $endpoint. Verifica que este abierto y que el puerto 8787 sea accesible.';
    } finally {
      client.close(force: true);
    }
  }

  Future<MoneyValue> _sumSales(
    dynamic db,
    int companyId,
    DateTime from,
    DateTime to,
    Currency currency,
  ) async {
    final start = DateTime(from.year, from.month, from.day).toIso8601String();
    final end = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS total
      FROM ventas
      WHERE company_id = ?
        AND fecha >= ?
        AND fecha <= ?
        AND COALESCE(estado, 'emitida') != 'anulada'
      ''',
      [companyId, start, end],
    );
    return MoneyValue.fromSql(rows.first['total'], currency: currency);
  }

  Future<String> _controlCenterEndpoint() async {
    final db = await _db.database;
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['control_center_endpoint'],
      limit: 1,
    );
    final value = rows.isEmpty
        ? ''
        : rows.first['valor']?.toString().trim() ?? '';
    return ControlCenterEndpoint.normalize(value.isEmpty ? null : value);
  }

  bool _matches(String text, List<String> patterns) {
    return patterns.any((pattern) => text.contains(_normalize(pattern)));
  }

  String _normalize(Object? value) {
    return (value?.toString() ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .trim();
  }

  String _shortDate(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _money(double value) {
    final text = value.toStringAsFixed(0);
    return '\$${text.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }
}
