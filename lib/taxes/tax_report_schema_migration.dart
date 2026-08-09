import 'package:sqflite/sqflite.dart';

class TaxReportSchemaMigration {
  const TaxReportSchemaMigration._();

  static Future<void> migrateV88(DatabaseExecutor db) async {
    await _addColumnIfMissing(
      db,
      'ventas_detalle',
      'impuesto_pct',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'ventas_detalle',
      'impuesto_total',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'compras_detalle',
      'impuesto_pct',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'compras_detalle',
      'impuesto_total',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    if (rows.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
