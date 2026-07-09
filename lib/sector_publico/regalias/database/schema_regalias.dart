/// Esquema de base de datos para el módulo de Regalías
/// SGR + SGP
library;

import 'package:sqflite/sqflite.dart';

class SchemaRegalias {
  static Future<void> crearTablas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS regalias (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_regalia TEXT NOT NULL UNIQUE,
        tipo_regalia TEXT NOT NULL,
        proyecto TEXT NOT NULL,
        municipio TEXT NOT NULL,
        departamento TEXT NOT NULL,
        valor_estimado REAL NOT NULL,
        valor_recibido REAL NOT NULL DEFAULT 0,
        valor_distribuido REAL NOT NULL DEFAULT 0,
        valor_asignado REAL NOT NULL DEFAULT 0,
        valor_ejecutado REAL NOT NULL DEFAULT 0,
        vigencia TEXT NOT NULL,
        fecha_estimacion TEXT NOT NULL,
        fecha_recepcion TEXT,
        fecha_distribucion TEXT,
        estado TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sgp (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_sgp TEXT NOT NULL UNIQUE,
        tipo_participacion TEXT NOT NULL,
        programa TEXT NOT NULL,
        municipio TEXT NOT NULL,
        departamento TEXT NOT NULL,
        valor_asignado REAL NOT NULL,
        valor_transferido REAL NOT NULL DEFAULT 0,
        valor_recibido REAL NOT NULL DEFAULT 0,
        valor_ejecutado REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        vigencia TEXT NOT NULL,
        fecha_asignacion TEXT NOT NULL,
        fecha_transferencia TEXT,
        fecha_recepcion TEXT,
        estado TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_regalias_entidad ON regalias(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_regalias_estado ON regalias(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_regalias_vigencia ON regalias(vigencia)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sgp_entidad ON sgp(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sgp_estado ON sgp(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sgp_vigencia ON sgp(vigencia)');
  }
}
