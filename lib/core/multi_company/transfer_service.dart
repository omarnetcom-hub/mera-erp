// ============================================================
// transfer_service.dart
// Servicio de gestión de transferencias entre empresas
// ============================================================

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'company_transfer.dart';

class CompanyTransferService {
  static final CompanyTransferService instance = CompanyTransferService._internal();
  
  CompanyTransferService._internal();
  
  /// Crea las tablas necesarias para transferencias
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_company_id INTEGER NOT NULL,
        to_company_id INTEGER NOT NULL,
        transfer_number TEXT NOT NULL UNIQUE,
        transfer_type TEXT NOT NULL,
        items TEXT NOT NULL,
        total_value REAL NOT NULL,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        requested_by TEXT,
        approved_by TEXT,
        requested_at TEXT NOT NULL,
        approved_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Índices
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_from ON company_transfers(from_company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_to ON company_transfers(to_company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_status ON company_transfers(status)');
  }
  
  /// Genera un número de transferencia único
  Future<String> generateTransferNumber(Database db) async {
    final year = DateTime.now().year;
    final prefix = 'TRF-$year-';
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM company_transfers 
      WHERE transfer_number LIKE ?
    ''', ['$prefix%']);
    
    final count = Sqflite.firstIntValue(result) ?? 0;
    final sequence = (count + 1).toString().padLeft(5, '0');
    
    return '$prefix$sequence';
  }
  
  /// Crea una solicitud de transferencia
  Future<int> createTransfer(Database db, CompanyTransfer transfer) async {
    final id = await db.insert('company_transfers', {
      'from_company_id': transfer.fromCompanyId,
      'to_company_id': transfer.toCompanyId,
      'transfer_number': transfer.transferNumber,
      'transfer_type': transfer.transferType,
      'items': jsonEncode(transfer.items),
      'total_value': transfer.totalValue,
      'status': transfer.status,
      'notes': transfer.notes,
      'requested_by': transfer.requestedBy,
      'requested_at': transfer.requestedAt.toIso8601String(),
      'created_at': transfer.createdAt.toIso8601String(),
    });
    
    return id;
  }
  
  /// Aprueba una transferencia
  Future<void> approveTransfer(Database db, int transferId, String approvedBy) async {
    await db.update(
      'company_transfers',
      {
        'status': 'approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }
  
  /// Rechaza una transferencia
  Future<void> rejectTransfer(Database db, int transferId, String reason) async {
    await db.update(
      'company_transfers',
      {
        'status': 'rejected',
        'notes': reason,
      },
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }
  
  /// Completa una transferencia
  Future<void> completeTransfer(Database db, int transferId) async {
    final transfer = await getTransferById(db, transferId);
    if (transfer == null) return;
    
    // Ejecutar la transferencia según el tipo
    switch (transfer.transferType) {
      case 'inventory':
        await _executeInventoryTransfer(db, transfer);
        break;
      case 'funds':
        await _executeFundsTransfer(db, transfer);
        break;
      case 'products':
        await _executeProductsTransfer(db, transfer);
        break;
    }
    
    // Actualizar estado
    await db.update(
      'company_transfers',
      {
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }
  
  /// Ejecuta transferencia de inventario
  Future<void> _executeInventoryTransfer(Database db, CompanyTransfer transfer) async {
    final items = transfer.items as Map<String, dynamic>;
    
    for (final entry in items.entries) {
      final productId = int.tryParse(entry.key);
      final quantity = (entry.value as num).toDouble();
      
      if (productId != null && quantity > 0) {
        // Reducir stock en empresa origen
        await db.rawQuery('''
          UPDATE productos 
          SET stock = stock - ? 
          WHERE id = ? AND company_id = ?
        ''', [quantity, productId, transfer.fromCompanyId]);
        
        // Aumentar stock en empresa destino
        await db.rawQuery('''
          UPDATE productos 
          SET stock = stock + ? 
          WHERE id = ? AND company_id = ?
        ''', [quantity, productId, transfer.toCompanyId]);
      }
    }
  }
  
  /// Ejecuta transferencia de fondos
  Future<void> _executeFundsTransfer(Database db, CompanyTransfer transfer) async {
    // Registrar movimiento de salida en empresa origen
    await db.insert('movimientos_caja', {
      'company_id': transfer.fromCompanyId,
      'tipo': 'egreso',
      'monto': transfer.totalValue,
      'concepto': 'Transferencia a empresa ${transfer.toCompanyId}',
      'referencia': transfer.transferNumber,
      'fecha': DateTime.now().toIso8601String(),
    });
    
    // Registrar movimiento de entrada en empresa destino
    await db.insert('movimientos_caja', {
      'company_id': transfer.toCompanyId,
      'tipo': 'ingreso',
      'monto': transfer.totalValue,
      'concepto': 'Transferencia desde empresa ${transfer.fromCompanyId}',
      'referencia': transfer.transferNumber,
      'fecha': DateTime.now().toIso8601String(),
    });
  }
  
  /// Ejecuta transferencia de productos completos
  Future<void> _executeProductsTransfer(Database db, CompanyTransfer transfer) async {
    final items = transfer.items as Map<String, dynamic>;
    
    for (final entry in items.entries) {
      final productId = int.tryParse(entry.key);
      final quantity = (entry.value as num).toDouble();
      
      if (productId != null && quantity > 0) {
        // Similar a inventario pero con lógica específica para productos
        await _executeInventoryTransfer(db, transfer);
      }
    }
  }
  
  /// Cancela una transferencia
  Future<void> cancelTransfer(Database db, int transferId) async {
    await db.update(
      'company_transfers',
      {
        'status': 'cancelled',
      },
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }
  
  /// Obtiene una transferencia por ID
  Future<CompanyTransfer?> getTransferById(Database db, int transferId) async {
    final maps = await db.query(
      'company_transfers',
      where: 'id = ?',
      whereArgs: [transferId],
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return CompanyTransfer.fromMap({
      ...map,
      'items': jsonDecode(map['items'] as String),
    });
  }
  
  /// Obtiene transferencias de una empresa (origen)
  Future<List<CompanyTransfer>> getTransfersFromCompany(Database db, int companyId) async {
    final maps = await db.query(
      'company_transfers',
      where: 'from_company_id = ?',
      whereArgs: [companyId],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => CompanyTransfer.fromMap({
      ...map,
      'items': jsonDecode(map['items'] as String),
    })).toList();
  }
  
  /// Obtiene transferencias hacia una empresa (destino)
  Future<List<CompanyTransfer>> getTransfersToCompany(Database db, int companyId) async {
    final maps = await db.query(
      'company_transfers',
      where: 'to_company_id = ?',
      whereArgs: [companyId],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => CompanyTransfer.fromMap({
      ...map,
      'items': jsonDecode(map['items'] as String),
    })).toList();
  }
  
  /// Obtiene transferencias por estado
  Future<List<CompanyTransfer>> getTransfersByStatus(Database db, String status) async {
    final maps = await db.query(
      'company_transfers',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => CompanyTransfer.fromMap({
      ...map,
      'items': jsonDecode(map['items'] as String),
    })).toList();
  }
  
  /// Obtiene transferencias pendientes de aprobación
  Future<List<CompanyTransfer>> getPendingTransfers(Database db) async {
    return await getTransfersByStatus(db, 'pending');
  }
  
  /// Obtiene estadísticas de transferencias
  Future<Map<String, dynamic>> getTransferStatistics(Database db, int companyId) async {
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(total_value) as total
      FROM company_transfers
      WHERE from_company_id = ? OR to_company_id = ?
    ''', [companyId, companyId]);
    
    final pendingResult = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(total_value) as total
      FROM company_transfers
      WHERE (from_company_id = ? OR to_company_id = ?) AND status = 'pending'
    ''', [companyId, companyId]);
    
    final completedResult = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(total_value) as total
      FROM company_transfers
      WHERE (from_company_id = ? OR to_company_id = ?) AND status = 'completed'
    ''', [companyId, companyId]);
    
    return {
      'total_transfers': Sqflite.firstIntValue(totalResult.first['count']) ?? 0,
      'total_value': (totalResult.first['total'] as num?)?.toDouble() ?? 0,
      'pending_transfers': Sqflite.firstIntValue(pendingResult.first['count']) ?? 0,
      'pending_value': (pendingResult.first['total'] as num?)?.toDouble() ?? 0,
      'completed_transfers': Sqflite.firstIntValue(completedResult.first['count']) ?? 0,
      'completed_value': (completedResult.first['total'] as num?)?.toDouble() ?? 0,
    };
  }
  
  /// Obtiene historial de transferencias entre dos empresas
  Future<List<CompanyTransfer>> getTransferHistory(
    Database db,
    int companyA,
    int companyB,
  ) async {
    final maps = await db.query(
      'company_transfers',
      where: '(from_company_id = ? AND to_company_id = ?) OR (from_company_id = ? AND to_company_id = ?)',
      whereArgs: [companyA, companyB, companyB, companyA],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => CompanyTransfer.fromMap({
      ...map,
      'items': jsonDecode(map['items'] as String),
    })).toList();
  }
}
