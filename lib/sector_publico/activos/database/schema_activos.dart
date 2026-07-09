/// Esquema de base de datos para el módulo de Activos del Estado
/// NICSP 17 + FUT
library;

import 'package:sqflite/sqflite.dart';

class SchemaActivos {
  static Future<void> crearTablas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activos_estado (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_inventario TEXT NOT NULL UNIQUE,
        nombre_activo TEXT NOT NULL,
        tipo_activo TEXT NOT NULL,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        serie TEXT NOT NULL,
        valor_adquisicion REAL NOT NULL,
        valor_libros REAL NOT NULL,
        valor_neto REAL NOT NULL,
        fecha_adquisicion TEXT NOT NULL,
        fecha_puesta_en_marcha TEXT NOT NULL,
        vida_util_anios INTEGER NOT NULL,
        valor_residual REAL NOT NULL,
        depreciacion_acumulada REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL,
        ubicacion TEXT,
        responsable TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fut (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_fut TEXT NOT NULL UNIQUE,
        nombre_fut TEXT NOT NULL,
        tipo_fut TEXT NOT NULL,
        numero_contrato TEXT,
        numero_convenio TEXT,
        tercero_id TEXT NOT NULL,
        tercero_nombre TEXT NOT NULL,
        tercero_identificacion TEXT NOT NULL,
        valor_inicial REAL NOT NULL,
        valor_ejecutado REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        fecha_apertura TEXT NOT NULL,
        fecha_cierre TEXT,
        estado TEXT NOT NULL,
        responsable TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_activos_entidad ON activos_estado(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activos_estado ON activos_estado(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activos_tipo ON activos_estado(tipo_activo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fut_entidad ON fut(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fut_estado ON fut(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fut_tercero ON fut(tercero_id)');
  }
}
