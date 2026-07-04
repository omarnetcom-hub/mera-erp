import '../db_helper.dart';

class EnterpriseOperationsService {
  EnterpriseOperationsService({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> abrirCaja({
    required String usuario,
    required double montoInicial,
    int? sucursalId,
  }) async {
    final db = await _db.database;
    return db.insert('caja_sesiones', {
      'company_id': await _db.obtenerEmpresaActivaId(),
      'usuario': usuario,
      'sucursal_id': sucursalId,
      'monto_inicial': montoInicial,
      'estado': 'abierta',
      'abierta_en': DateTime.now().toIso8601String(),
    });
  }

  Future<void> cerrarCaja({
    required int sesionId,
    required double montoContado,
    required String justificacion,
  }) async {
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final ventas = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM ventas WHERE company_id = ? AND COALESCE(estado, 'emitida') != 'anulada'",
      [companyId],
    );
    final ingresos = await db.rawQuery(
      "SELECT COALESCE(SUM(monto), 0) AS total FROM movimientos_caja WHERE company_id = ? AND tipo = 'ingreso'",
      [companyId],
    );
    final egresos = await db.rawQuery(
      "SELECT COALESCE(SUM(monto), 0) AS total FROM movimientos_caja WHERE company_id = ? AND tipo = 'egreso'",
      [companyId],
    );
    final totalVentas = (ventas.first['total'] as num?)?.toDouble() ?? 0;
    final totalIngresos = (ingresos.first['total'] as num?)?.toDouble() ?? 0;
    final totalEgresos = (egresos.first['total'] as num?)?.toDouble() ?? 0;
    final esperado = totalVentas + totalIngresos - totalEgresos;
    final diferencia = montoContado - esperado;
    if (diferencia.abs() > 0.01 && justificacion.trim().isEmpty) {
      throw StateError('La diferencia de caja requiere justificacion.');
    }
    await db.update(
      'caja_sesiones',
      {
        'total_ventas': totalVentas,
        'total_ingresos': totalIngresos,
        'total_egresos': totalEgresos,
        'monto_contado': montoContado,
        'diferencia': diferencia,
        'justificacion': justificacion,
        'estado': 'cerrada',
        'cerrada_en': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sesionId],
    );
  }

  Future<int> trasladarBodega({
    required int productoId,
    required int origenId,
    required int destinoId,
    required double cantidad,
    String usuario = 'local',
    String observacion = '',
  }) async {
    if (cantidad <= 0) throw ArgumentError('La cantidad debe ser positiva.');
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    return db.transaction((txn) async {
      await txn.rawUpdate(
        '''
        UPDATE stock_bodega
        SET cantidad = cantidad - ?, actualizado_en = ?
        WHERE producto_id = ? AND bodega_id = ? AND cantidad >= ?
        ''',
        [
          cantidad,
          DateTime.now().toIso8601String(),
          productoId,
          origenId,
          cantidad,
        ],
      );
      await txn.rawInsert(
        '''
        INSERT INTO stock_bodega(company_id, producto_id, bodega_id, cantidad, costo, actualizado_en)
        VALUES(?, ?, ?, ?, 0, ?)
        ON CONFLICT(producto_id, bodega_id)
        DO UPDATE SET cantidad = cantidad + excluded.cantidad,
                      actualizado_en = excluded.actualizado_en
        ''',
        [
          companyId,
          productoId,
          destinoId,
          cantidad,
          DateTime.now().toIso8601String(),
        ],
      );
      return txn.insert('traslados_bodega', {
        'company_id': companyId,
        'producto_id': productoId,
        'bodega_origen_id': origenId,
        'bodega_destino_id': destinoId,
        'cantidad': cantidad,
        'estado': 'registrado',
        'observacion': observacion,
        'usuario': usuario,
        'fecha': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<int> registrarCambioPrecio({
    required int productoId,
    required double precioAnterior,
    required double precioNuevo,
    required String usuario,
  }) async {
    final db = await _db.database;
    await db.update(
      'productos',
      {'precio': precioNuevo},
      where: 'id = ?',
      whereArgs: [productoId],
    );
    return db.insert('historial_precios', {
      'company_id': await _db.obtenerEmpresaActivaId(),
      'producto_id': productoId,
      'precio_anterior': precioAnterior,
      'precio_nuevo': precioNuevo,
      'usuario': usuario,
      'fecha': DateTime.now().toIso8601String(),
    });
  }
}
