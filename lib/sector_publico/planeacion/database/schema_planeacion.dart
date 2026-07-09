/// Esquema de base de datos para el módulo de Planeación
/// Banco de Proyectos MGA + PDT
library;

import 'package:sqflite/sqflite.dart';

class SchemaPlaneacion {
  static Future<void> crearTablas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proyectos_mga (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        codigo_bpin TEXT NOT NULL UNIQUE,
        nombre_proyecto TEXT NOT NULL,
        tipo_proyecto TEXT NOT NULL,
        sector TEXT NOT NULL,
        programa TEXT NOT NULL,
        subprograma TEXT NOT NULL,
        valor_total REAL NOT NULL,
        valor_ejecutado REAL NOT NULL DEFAULT 0,
        saldo_por_ejecutar REAL NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        responsable TEXT NOT NULL,
        dependencia TEXT NOT NULL,
        estado TEXT NOT NULL,
        codigo_cdp TEXT,
        codigo_rp TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pdt (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        vigencia TEXT NOT NULL UNIQUE,
        nombre_pdt TEXT NOT NULL,
        vision TEXT NOT NULL,
        mision TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        estado TEXT NOT NULL,
        acto_administrativo TEXT,
        fecha_aprobacion TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_proyectos_entidad ON proyectos_mga(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_proyectos_estado ON proyectos_mga(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_proyectos_bpin ON proyectos_mga(codigo_bpin)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pdt_entidad ON pdt(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pdt_vigencia ON pdt(vigencia)');
  }
}
