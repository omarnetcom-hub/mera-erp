import 'package:sqflite/sqflite.dart';

/// Persists the legacy movement row and the canonical historical Kardex row
/// in the same transaction.
class InventoryMovementService {
  const InventoryMovementService._();

  static Future<void> record({
    required DatabaseExecutor db,
    required int companyId,
    required int productId,
    required String type,
    required double quantity,
    required double stockBefore,
    required double stockAfter,
    required String reason,
    required String date,
    int? warehouseId,
    int costBeforeMinor = 0,
    int costAfterMinor = 0,
    int? costTotalMinor,
    String? documentType,
    int? documentId,
    String createdBy = 'local',
  }) async {
    await db.insert('movimientos_inventario', {
      'company_id': companyId,
      'producto_id': productId,
      'tipo': type,
      'cantidad': quantity,
      'stock_anterior': stockBefore,
      'stock_nuevo': stockAfter,
      'costo_anterior': costBeforeMinor,
      'costo_nuevo': costAfterMinor,
      'motivo': reason,
      'fecha': date,
    });
    await db.insert('kardex_inventario', {
      'company_id': companyId,
      'producto_id': productId,
      'bodega_id': warehouseId,
      'tipo': type,
      'cantidad': quantity,
      'costo_unitario': costAfterMinor,
      'costo_total': costTotalMinor ?? 0,
      'stock_anterior': stockBefore,
      'stock_nuevo': stockAfter,
      'referencia': reason,
      'documento_tipo': documentType,
      'documento_id': documentId,
      'fecha': date,
      'created_by': createdBy,
    });
  }
}
