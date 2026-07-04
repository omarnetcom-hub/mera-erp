// ============================================================
// quote_service.dart
// Servicio de gestión de presupuestos y cotizaciones
// ============================================================

import 'package:sqflite/sqflite.dart';
import '../domain/quote.dart';

class QuoteService {
  static final QuoteService instance = QuoteService._internal();
  
  QuoteService._internal();
  
  /// Crea las tablas necesarias para cotizaciones
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        quote_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        quote_date TEXT NOT NULL,
        valid_until TEXT,
        accepted_date TEXT,
        rejected_date TEXT,
        subtotal REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'draft',
        notes TEXT,
        terms TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        quote_id INTEGER NOT NULL,
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
        FOREIGN KEY (quote_id) REFERENCES sales_quotes(id),
        FOREIGN KEY (product_id) REFERENCES productos(id)
      )
    ''');
    
    // Índices
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quotes_company ON sales_quotes(company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quotes_customer ON sales_quotes(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quotes_status ON sales_quotes(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quotes_date ON sales_quotes(quote_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quote_lines_quote ON quote_lines(quote_id)');
  }
  
  /// Genera un número de cotización único
  Future<String> generateQuoteNumber(Database db, int companyId) async {
    final year = DateTime.now().year;
    final prefix = 'COT-$year-';
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_quotes 
      WHERE company_id = ? AND quote_number LIKE ?
    ''', [companyId, '$prefix%']);
    
    final count = Sqflite.firstIntValue(result) ?? 0;
    final sequence = (count + 1).toString().padLeft(5, '0');
    
    return '$prefix$sequence';
  }
  
  /// Crea una nueva cotización
  Future<int> createQuote(Database db, SalesQuote quote) async {
    final id = await db.insert('sales_quotes', quote.toMap());
    return id;
  }
  
  /// Obtiene una cotización por ID
  Future<SalesQuote?> getQuoteById(Database db, int quoteId) async {
    final maps = await db.query(
      'sales_quotes',
      where: 'id = ?',
      whereArgs: [quoteId],
    );
    
    if (maps.isEmpty) return null;
    return SalesQuote.fromMap(maps.first);
  }
  
  /// Obtiene cotizaciones por cliente
  Future<List<SalesQuote>> getQuotesByCustomer(Database db, int customerId, int companyId) async {
    final maps = await db.query(
      'sales_quotes',
      where: 'customer_id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      orderBy: 'quote_date DESC',
    );
    
    return maps.map((map) => SalesQuote.fromMap(map)).toList();
  }
  
  /// Obtiene cotizaciones por estado
  Future<List<SalesQuote>> getQuotesByStatus(Database db, String status, int companyId) async {
    final maps = await db.query(
      'sales_quotes',
      where: 'status = ? AND company_id = ?',
      whereArgs: [status, companyId],
      orderBy: 'quote_date DESC',
    );
    
    return maps.map((map) => SalesQuote.fromMap(map)).toList();
  }
  
  /// Obtiene cotizaciones expiradas
  Future<List<SalesQuote>> getExpiredQuotes(Database db, int companyId) async {
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'sales_quotes',
      where: 'company_id = ? AND valid_until < ? AND status NOT IN (?, ?, ?)',
      whereArgs: [companyId, now, 'accepted', 'rejected', 'expired'],
      orderBy: 'valid_until ASC',
    );
    
    return maps.map((map) => SalesQuote.fromMap(map)).toList();
  }
  
  /// Obtiene cotizaciones próximas a vencer
  Future<List<SalesQuote>> getQuotesNearExpiration(Database db, int companyId, {int days = 7}) async {
    final futureDate = DateTime.now().add(Duration(days: days));
    final maps = await db.query(
      'sales_quotes',
      where: 'company_id = ? AND valid_until <= ? AND valid_until > ? AND status NOT IN (?, ?, ?)',
      whereArgs: [companyId, futureDate.toIso8601String(), DateTime.now().toIso8601String(), 'accepted', 'rejected', 'expired'],
      orderBy: 'valid_until ASC',
    );
    
    return maps.map((map) => SalesQuote.fromMap(map)).toList();
  }
  
  /// Actualiza el estado de una cotización
  Future<void> updateQuoteStatus(Database db, int quoteId, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (status == 'accepted') {
      updates['accepted_date'] = DateTime.now().toIso8601String();
    } else if (status == 'rejected') {
      updates['rejected_date'] = DateTime.now().toIso8601String();
    } else if (status == 'expired') {
      // No requiere fecha específica
    }
    
    await db.update(
      'sales_quotes',
      updates,
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }
  
  /// Convierte una cotización aceptada en venta
  Future<int?> convertQuoteToSale(Database db, int quoteId) async {
    final quote = await getQuoteById(db, quoteId);
    if (quote == null || quote.status != 'accepted') return null;
    
    // Crear venta
    final saleId = await db.insert('ventas', {
      'company_id': quote.companyId,
      'producto': 'Cotización ${quote.quoteNumber}',
      'cantidad': 1,
      'precio_unitario': quote.total,
      'subtotal': quote.subtotal,
      'impuesto_pct': (quote.taxAmount / quote.subtotal) * 100,
      'impuesto_total': quote.taxAmount,
      'total': quote.total,
      'fecha': DateTime.now().toIso8601String(),
      'estado': 'emitida',
      'metodo_pago_id': 1,
    });
    
    return saleId;
  }
  
  /// Marca cotizaciones expiradas automáticamente
  Future<int> markExpiredQuotes(Database db, int companyId) async {
    final now = DateTime.now().toIso8601String();
    
    final result = await db.update(
      'sales_quotes',
      {
        'status': 'expired',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'company_id = ? AND valid_until < ? AND status NOT IN (?, ?, ?)',
      whereArgs: [companyId, now, 'accepted', 'rejected', 'expired'],
    );
    
    return result;
  }
  
  /// Obtiene historial de cotizaciones por cliente
  Future<List<Map<String, dynamic>>> getQuoteHistoryByCustomer(
    Database db,
    int customerId,
    int companyId,
  ) async {
    final maps = await db.rawQuery('''
      SELECT 
        sq.*,
        COUNT(DISTINCT ql.id) as line_count
      FROM sales_quotes sq
      LEFT JOIN quote_lines ql ON sq.id = ql.quote_id
      WHERE sq.customer_id = ? AND sq.company_id = ?
      GROUP BY sq.id
      ORDER BY sq.quote_date DESC
    ''', [customerId, companyId]);
    
    return maps;
  }
  
  /// Obtiene estadísticas de cotizaciones
  Future<Map<String, dynamic>> getQuoteStatistics(Database db, int companyId) async {
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as total 
      FROM sales_quotes 
      WHERE company_id = ?
    ''', [companyId]);
    
    final draftResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_quotes 
      WHERE company_id = ? AND status = 'draft'
    ''', [companyId]);
    
    final sentResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_quotes 
      WHERE company_id = ? AND status = 'sent'
    ''', [companyId]);
    
    final acceptedResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM sales_quotes 
      WHERE company_id = ? AND status = 'accepted'
    ''', [companyId]);
    
    final totalValueResult = await db.rawQuery('''
      SELECT SUM(total) as value 
      FROM sales_quotes 
      WHERE company_id = ? AND status = 'accepted'
    ''', [companyId]);
    
    final conversionRateResult = await db.rawQuery('''
      SELECT 
        CAST(COUNT(CASE WHEN status = 'accepted' THEN 1 END) AS FLOAT) / 
        CAST(COUNT(CASE WHEN status IN ('sent', 'accepted', 'rejected') THEN 1 END) AS FLOAT) * 100 as rate
      FROM sales_quotes 
      WHERE company_id = ?
    ''', [companyId]);
    
    return {
      'total_quotes': Sqflite.firstIntValue(totalResult) ?? 0,
      'draft_quotes': Sqflite.firstIntValue(draftResult) ?? 0,
      'sent_quotes': Sqflite.firstIntValue(sentResult) ?? 0,
      'accepted_quotes': Sqflite.firstIntValue(acceptedResult) ?? 0,
      'total_accepted_value': (totalValueResult.first['value'] as num?)?.toDouble() ?? 0,
      'conversion_rate': (conversionRateResult.first['rate'] as num?)?.toDouble() ?? 0.0,
    };
  }
  
  /// Elimina una cotización
  Future<void> deleteQuote(Database db, int quoteId) async {
    // Primero eliminar líneas
    await db.delete('quote_lines', where: 'quote_id = ?', whereArgs: [quoteId]);
    // Luego eliminar cotización
    await db.delete('sales_quotes', where: 'id = ?', whereArgs: [quoteId]);
  }
}
