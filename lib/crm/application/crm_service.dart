// ============================================================
// crm_service.dart
// Servicio de gestión de relaciones con clientes (CRM)
// ============================================================

import 'package:sqflite/sqflite.dart';
import '../domain/customer_interaction.dart';

class CRMService {
  static final CRMService instance = CRMService._internal();
  
  CRMService._internal();
  
  /// Crea las tablas necesarias para CRM
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        interaction_type TEXT NOT NULL,
        subject TEXT NOT NULL,
        description TEXT,
        interaction_date TEXT NOT NULL,
        outcome TEXT,
        next_action TEXT,
        follow_up_date TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES clientes(id)
      )
    ''');
    
    // Índices
    await db.execute('CREATE INDEX IF NOT EXISTS idx_interactions_customer ON customer_interactions(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_interactions_company ON customer_interactions(company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_interactions_date ON customer_interactions(interaction_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_interactions_followup ON customer_interactions(follow_up_date)');
  }
  
  /// Registra una interacción con un cliente
  Future<int> recordInteraction(Database db, CustomerInteraction interaction) async {
    final id = await db.insert('customer_interactions', interaction.toMap());
    return id;
  }
  
  /// Obtiene todas las interacciones de un cliente
  Future<List<CustomerInteraction>> getCustomerInteractions(Database db, int customerId) async {
    final maps = await db.query(
      'customer_interactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'interaction_date DESC',
    );
    
    return maps.map((map) => CustomerInteraction.fromMap(map)).toList();
  }
  
  /// Obtiene interacciones por tipo
  Future<List<CustomerInteraction>> getInteractionsByType(
    Database db,
    int companyId,
    String type,
  ) async {
    final maps = await db.query(
      'customer_interactions',
      where: 'company_id = ? AND interaction_type = ?',
      whereArgs: [companyId, type],
      orderBy: 'interaction_date DESC',
    );
    
    return maps.map((map) => CustomerInteraction.fromMap(map)).toList();
  }
  
  /// Obtiene seguimientos pendientes (vencidos o próximos)
  Future<List<CustomerInteraction>> getPendingFollowUps(
    Database db,
    int companyId, {
    int daysAhead = 7,
  }) async {
    final futureDate = DateTime.now().add(Duration(days: daysAhead));
    
    final maps = await db.query(
      'customer_interactions',
      where: 'company_id = ? AND follow_up_date IS NOT NULL AND follow_up_date <= ?',
      whereArgs: [companyId, futureDate.toIso8601String()],
      orderBy: 'follow_up_date ASC',
    );
    
    return maps.map((map) => CustomerInteraction.fromMap(map)).toList();
  }
  
  /// Obtiene seguimientos vencidos
  Future<List<CustomerInteraction>> getOverdueFollowUps(Database db, int companyId) async {
    final now = DateTime.now().toIso8601String();
    
    final maps = await db.query(
      'customer_interactions',
      where: 'company_id = ? AND follow_up_date < ?',
      whereArgs: [companyId, now],
      orderBy: 'follow_up_date ASC',
    );
    
    return maps.map((map) => CustomerInteraction.fromMap(map)).toList();
  }
  
  /// Actualiza una interacción
  Future<void> updateInteraction(Database db, CustomerInteraction interaction) async {
    await db.update(
      'customer_interactions',
      interaction.toMap(),
      where: 'id = ?',
      whereArgs: [interaction.id],
    );
  }
  
  /// Marca un seguimiento como completado
  Future<void> completeFollowUp(Database db, int interactionId, String outcome) async {
    await db.update(
      'customer_interactions',
      {
        'outcome': outcome,
        'follow_up_date': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [interactionId],
    );
  }
  
  /// Obtiene estadísticas de interacciones por cliente
  Future<Map<String, dynamic>> getCustomerInteractionStats(
    Database db,
    int customerId,
  ) async {
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as total 
      FROM customer_interactions 
      WHERE customer_id = ?
    ''', [customerId]);
    
    final typeResult = await db.rawQuery('''
      SELECT interaction_type, COUNT(*) as count 
      FROM customer_interactions 
      WHERE customer_id = ? 
      GROUP BY interaction_type
    ''', [customerId]);
    
    final typeStats = <String, int>{};
    for (final row in typeResult) {
      typeStats[row['interaction_type'] as String] = row['count'] as int;
    }
    
    return {
      'total_interactions': Sqflite.firstIntValue(totalResult) ?? 0,
      'by_type': typeStats,
    };
  }
  
  /// Segmenta clientes por frecuencia de interacción
  Future<List<Map<String, dynamic>>> segmentCustomersByActivity(
    Database db,
    int companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final maps = await db.rawQuery('''
      SELECT 
        c.id as customer_id,
        c.nombre as customer_name,
        COUNT(ci.id) as interaction_count,
        SUM(CASE WHEN ci.interaction_type = 'meeting' THEN 1 ELSE 0 END) as meetings_count,
        SUM(CASE WHEN ci.interaction_type = 'call' THEN 1 ELSE 0 END) as calls_count
      FROM clientes c
      LEFT JOIN customer_interactions ci ON c.id = ci.customer_id
        AND ci.interaction_date >= ? 
        AND ci.interaction_date <= ?
      WHERE c.company_id = ?
      GROUP BY c.id
      ORDER BY interaction_count DESC
    ''', [startDate.toIso8601String(), endDate.toIso8601String(), companyId]);
    
    return maps;
  }
  
  /// Obtiene clientes más activos (top N)
  Future<List<Map<String, dynamic>>> getMostActiveCustomers(
    Database db,
    int companyId, {
    int limit = 10,
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    final maps = await db.rawQuery('''
      SELECT 
        c.id as customer_id,
        c.nombre as customer_name,
        COUNT(ci.id) as interaction_count
      FROM clientes c
      INNER JOIN customer_interactions ci ON c.id = ci.customer_id
      WHERE c.company_id = ? AND ci.interaction_date >= ?
      GROUP BY c.id
      ORDER BY interaction_count DESC
      LIMIT ?
    ''', [companyId, startDate.toIso8601String(), limit]);
    
    return maps;
  }
  
  /// Elimina una interacción
  Future<void> deleteInteraction(Database db, int interactionId) async {
    await db.delete(
      'customer_interactions',
      where: 'id = ?',
      whereArgs: [interactionId],
    );
  }
}
