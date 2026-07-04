// ============================================================
// order_service.dart
// Servicio de gestión de pedidos/pre-ventas
// ============================================================

import 'package:sqflite/sqflite.dart';
import '../domain/order.dart';
import '../domain/order_line.dart';

class OrderService {
  static final OrderService instance = OrderService._internal();
  
  OrderService._internal();
  
  /// Crea las tablas necesarias para pedidos
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        order_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        order_date TEXT NOT NULL,
        estimated_delivery_date TEXT,
        actual_delivery_date TEXT,
        subtotal REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        delivery_address TEXT,
        contact_phone TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_percentage REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        subtotal REAL NOT NULL,
        total REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES sales_orders(id),
        FOREIGN KEY (product_id) REFERENCES productos(id)
      )
    ''');
    
    // Índices
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_company ON sales_orders(company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_customer ON sales_orders(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON sales_orders(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_date ON sales_orders(order_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_lines_order ON order_lines(order_id)');
  }
  
  /// Genera un número de pedido único
  Future<String> generateOrderNumber(Database db, int companyId) async {
    final year = DateTime.now().year;
    final prefix = 'ORD-$year-';
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_orders 
      WHERE company_id = ? AND order_number LIKE ?
    ''', [companyId, '$prefix%']);
    
    final count = Sqflite.firstIntValue(result) ?? 0;
    final sequence = (count + 1).toString().padLeft(5, '0');
    
    return '$prefix$sequence';
  }
  
  /// Crea un nuevo pedido
  Future<int> createOrder(Database db, SalesOrder order) async {
    final id = await db.insert('sales_orders', order.toMap());
    return id;
  }
  
  /// Agrega una línea a un pedido
  Future<int> addOrderLine(Database db, OrderLine line) async {
    final id = await db.insert('order_lines', line.toMap());
    
    // Actualizar totales del pedido
    await _updateOrderTotals(db, line.orderId);
    
    return id;
  }
  
  /// Actualiza los totales de un pedido
  Future<void> _updateOrderTotals(Database db, int orderId) async {
    final linesResult = await db.query(
      'order_lines',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    
    double subtotal = 0;
    double taxAmount = 0;
    double discountAmount = 0;
    
    for (final lineMap in linesResult) {
      final line = OrderLine.fromMap(lineMap);
      subtotal += line.subtotal;
      taxAmount += line.taxAmount;
      discountAmount += line.discountAmount;
    }
    
    final total = subtotal - discountAmount + taxAmount;
    
    await db.update(
      'sales_orders',
      {
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'discount_amount': discountAmount,
        'total': total,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
  
  /// Obtiene un pedido por ID
  Future<SalesOrder?> getOrderById(Database db, int orderId) async {
    final maps = await db.query(
      'sales_orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
    
    if (maps.isEmpty) return null;
    return SalesOrder.fromMap(maps.first);
  }
  
  /// Obtiene las líneas de un pedido
  Future<List<OrderLine>> getOrderLines(Database db, int orderId) async {
    final maps = await db.query(
      'order_lines',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
    
    return maps.map((map) => OrderLine.fromMap(map)).toList();
  }
  
  /// Obtiene pedidos por cliente
  Future<List<SalesOrder>> getOrdersByCustomer(Database db, int customerId, int companyId) async {
    final maps = await db.query(
      'sales_orders',
      where: 'customer_id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      orderBy: 'order_date DESC',
    );
    
    return maps.map((map) => SalesOrder.fromMap(map)).toList();
  }
  
  /// Obtiene pedidos por estado
  Future<List<SalesOrder>> getOrdersByStatus(Database db, String status, int companyId) async {
    final maps = await db.query(
      'sales_orders',
      where: 'status = ? AND company_id = ?',
      whereArgs: [status, companyId],
      orderBy: 'order_date DESC',
    );
    
    return maps.map((map) => SalesOrder.fromMap(map)).toList();
  }
  
  /// Obtiene pedidos pendientes de entrega
  Future<List<SalesOrder>> getPendingDeliveryOrders(Database db, int companyId) async {
    final maps = await db.query(
      'sales_orders',
      where: 'status IN (?, ?) AND company_id = ?',
      whereArgs: ['confirmed', 'sent', companyId],
      orderBy: 'estimated_delivery_date ASC',
    );
    
    return maps.map((map) => SalesOrder.fromMap(map)).toList();
  }
  
  /// Obtiene pedidos vencidos (no entregados en fecha estimada)
  Future<List<SalesOrder>> getOverdueOrders(Database db, int companyId) async {
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'sales_orders',
      where: 'status NOT IN (?, ?, ?) AND company_id = ? AND estimated_delivery_date < ?',
      whereArgs: ['delivered', 'cancelled', 'pending', companyId, now],
      orderBy: 'estimated_delivery_date ASC',
    );
    
    return maps.map((map) => SalesOrder.fromMap(map)).toList();
  }
  
  /// Actualiza el estado de un pedido
  Future<void> updateOrderStatus(Database db, int orderId, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (status == 'delivered') {
      updates['actual_delivery_date'] = DateTime.now().toIso8601String();
    }
    
    await db.update(
      'sales_orders',
      updates,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
  
  /// Reserva stock para un pedido confirmado
  Future<bool> reserveStockForOrder(Database db, int orderId) async {
    final order = await getOrderById(db, orderId);
    if (order == null) return false;
    
    final lines = await getOrderLines(db, orderId);
    
    for (final line in lines) {
      // Verificar stock disponible
      final productResult = await db.query(
        'productos',
        columns: ['stock'],
        where: 'id = ?',
        whereArgs: [line.productId],
      );
      
      if (productResult.isEmpty) return false;
      
      final currentStock = (productResult.first['stock'] as num).toDouble();
      
      if (currentStock < line.quantity) {
        return false; // Stock insuficiente
      }
      
      // Reservar stock (actualizar tabla de reservas si existe)
      // Por ahora, solo verificamos disponibilidad
    }
    
    return true;
  }
  
  /// Convierte un pedido en venta
  Future<int?> convertOrderToSale(Database db, int orderId) async {
    final order = await getOrderById(db, orderId);
    if (order == null || order.status != 'confirmed') return null;
    
    // Crear venta
    final saleId = await db.insert('ventas', {
      'company_id': order.companyId,
      'producto': 'Pedido ${order.orderNumber}',
      'cantidad': 1,
      'precio_unitario': order.total,
      'subtotal': order.subtotal,
      'impuesto_pct': (order.taxAmount / order.subtotal) * 100,
      'impuesto_total': order.taxAmount,
      'total': order.total,
      'fecha': DateTime.now().toIso8601String(),
      'estado': 'emitida',
      'metodo_pago_id': 1,
    });
    
    // Actualizar estado del pedido
    await updateOrderStatus(db, orderId, 'delivered');
    
    return saleId;
  }
  
  /// Cancela un pedido
  Future<void> cancelOrder(Database db, int orderId, String? reason) async {
    await db.update(
      'sales_orders',
      {
        'status': 'cancelled',
        'notes': reason,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
  
  /// Elimina una línea de pedido
  Future<void> removeOrderLine(Database db, int lineId) async {
    final line = OrderLine.fromMap(
      (await db.query('order_lines', where: 'id = ?', whereArgs: [lineId])).first,
    );
    
    await db.delete('order_lines', where: 'id = ?', whereArgs: [lineId]);
    await _updateOrderTotals(db, line.orderId);
  }
  
  /// Obtiene estadísticas de pedidos
  Future<Map<String, dynamic>> getOrderStatistics(Database db, int companyId) async {
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as total 
      FROM sales_orders 
      WHERE company_id = ?
    ''', [companyId]);
    
    final pendingResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_orders 
      WHERE company_id = ? AND status = 'pending'
    ''', [companyId]);
    
    final confirmedResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_orders 
      WHERE company_id = ? AND status = 'confirmed'
    ''', [companyId]);
    
    final deliveredResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_orders 
      WHERE company_id = ? AND status = 'delivered'
    ''', [companyId]);
    
    final totalValueResult = await db.rawQuery('''
      SELECT SUM(total) as value 
      FROM sales_orders 
      WHERE company_id = ? AND status != 'cancelled'
    ''', [companyId]);
    
    return {
      'total_orders': Sqflite.firstIntValue(totalResult) ?? 0,
      'pending_orders': Sqflite.firstIntValue(pendingResult) ?? 0,
      'confirmed_orders': Sqflite.firstIntValue(confirmedResult) ?? 0,
      'delivered_orders': Sqflite.firstIntValue(deliveredResult) ?? 0,
      'total_value': (totalValueResult.first['value'] as num?)?.toDouble() ?? 0,
    };
  }
}
