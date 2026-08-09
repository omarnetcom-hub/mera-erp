import 'package:sqflite/sqflite.dart';

class SchemaMrp {
  const SchemaMrp._();

  static Future<void> crearTablas(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_workstations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        hour_rate INTEGER NOT NULL DEFAULT 0,
        production_capacity INTEGER NOT NULL DEFAULT 1,
        available_hours_per_day REAL,
        status TEXT NOT NULL DEFAULT 'produccion',
        warehouse_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_routings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        routing_id INTEGER NOT NULL,
        workstation_id INTEGER NOT NULL,
        operation_name TEXT NOT NULL,
        sequence_order INTEGER NOT NULL DEFAULT 1,
        time_minutes REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(routing_id) REFERENCES mrp_routings(id),
        FOREIGN KEY(workstation_id) REFERENCES mrp_workstations(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_boms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        uom TEXT NOT NULL DEFAULT 'UND',
        is_active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        routing_id INTEGER,
        raw_material_cost INTEGER NOT NULL DEFAULT 0,
        operating_cost INTEGER NOT NULL DEFAULT 0,
        total_cost INTEGER NOT NULL DEFAULT 0,
        entity_type TEXT NOT NULL DEFAULT 'comercial',
        FOREIGN KEY(item_id) REFERENCES productos(id),
        FOREIGN KEY(routing_id) REFERENCES mrp_routings(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_bom_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        bom_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        qty REAL NOT NULL,
        uom TEXT NOT NULL DEFAULT 'UND',
        rate INTEGER NOT NULL DEFAULT 0,
        amount INTEGER NOT NULL DEFAULT 0,
        source_warehouse_id INTEGER,
        is_sub_assembly_item INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(bom_id) REFERENCES mrp_boms(id),
        FOREIGN KEY(item_id) REFERENCES productos(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_work_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        production_item_id INTEGER NOT NULL,
        bom_id INTEGER NOT NULL,
        qty_planned REAL NOT NULL,
        qty_produced REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'borrador',
        wip_warehouse_id INTEGER NOT NULL,
        fg_warehouse_id INTEGER NOT NULL,
        planned_start_date TEXT,
        actual_start_date TEXT,
        planned_end_date TEXT,
        actual_end_date TEXT,
        planned_operating_cost INTEGER NOT NULL DEFAULT 0,
        actual_operating_cost INTEGER NOT NULL DEFAULT 0,
        raw_material_cost INTEGER NOT NULL DEFAULT 0,
        total_cost INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(production_item_id) REFERENCES productos(id),
        FOREIGN KEY(bom_id) REFERENCES mrp_boms(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_work_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        work_order_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        required_qty REAL NOT NULL,
        transferred_qty REAL NOT NULL DEFAULT 0,
        consumed_qty REAL NOT NULL DEFAULT 0,
        source_warehouse_id INTEGER,
        FOREIGN KEY(work_order_id) REFERENCES mrp_work_orders(id),
        FOREIGN KEY(item_id) REFERENCES productos(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mrp_bom_item ON mrp_boms(company_id, item_id, is_active)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mrp_work_order_status ON mrp_work_orders(company_id, status)',
    );
  }
}
