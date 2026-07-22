/// Esquema de base de datos para el módulo de Regalías y SGP
/// SGR (Sistema General de Regalías) + SGP + Bienios SGR + OCAD + SPGR + SICODIS
library;

import 'package:sqflite/sqflite.dart';

class SchemaRegalias {
  static Future<void> crearTablas(Database db) async {
    // 1. Tabla de estimaciones de Regalías
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

    // 2. Tabla de asignaciones del SGP (Sistema General de Participaciones)
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

    // 3. Tabla de Bienios Presupuestales SGR (Bienalidades 2 años: ej. 2025-2026)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bienios_sgr (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        codigo_bienio TEXT NOT NULL UNIQUE,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        monto_presupuestado_bienio REAL NOT NULL,
        monto_ejecutado_bienio REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'vigente',
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // 4. Tabla de Proyectos OCAD
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proyectos_ocad (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        proyecto_mga_id TEXT,
        bienio_id TEXT,
        codigo_bpin TEXT NOT NULL UNIQUE,
        nombre_proyecto TEXT NOT NULL,
        bienalidad TEXT NOT NULL,
        tipo_ocad TEXT NOT NULL,
        monto_aprobado REAL NOT NULL,
        monto_giro_spgr REAL NOT NULL DEFAULT 0,
        estado_ocad TEXT NOT NULL,
        fecha_aprobacion TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (proyecto_mga_id) REFERENCES proyectos_mga(id),
        FOREIGN KEY (bienio_id) REFERENCES bienios_sgr(id)
      )
    ''');

    // 5. Tabla de Reportes SPGR
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reportes_spgr (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        bienio_id TEXT,
        bienalidad TEXT NOT NULL,
        fecha_generacion TEXT NOT NULL,
        usuario_genero TEXT NOT NULL,
        datos TEXT NOT NULL,
        estado TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (bienio_id) REFERENCES bienios_sgr(id)
      )
    ''');

    // 6. Tabla de Certificaciones SICODIS SGP (Sistema de Información para la Captura de Datos de la Inversión Social - DNP)
    // FK: entidad_id -> entidades_territoriales(id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reportes_sicodis (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        sector_participacion TEXT NOT NULL,
        fecha_generacion TEXT NOT NULL,
        usuario_genero TEXT NOT NULL,
        datos TEXT NOT NULL,
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bienios_entidad ON bienios_sgr(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ocad_entidad ON proyectos_ocad(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ocad_mga ON proyectos_ocad(proyecto_mga_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ocad_bpin ON proyectos_ocad(codigo_bpin)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spgr_entidad ON reportes_spgr(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sicodis_entidad ON reportes_sicodis(entidad_id)');
  }
}
