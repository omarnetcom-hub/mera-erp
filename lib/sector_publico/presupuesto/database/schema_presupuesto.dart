/// Esquema de base de datos para el módulo de Presupuesto Público
/// Implementa el flujo: APROPIACIÓN → CDP → RP → OBLIGACIÓN → PAGO
library;

import 'package:sqflite/sqflite.dart';

class SchemaPresupuesto {
  /// Crea todas las tablas necesarias para el módulo de presupuesto
  static Future<void> crearTablas(Database db) async {
    // Tabla de apropiaciones presupuestales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS apropiaciones (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        codigo_rubro TEXT NOT NULL,
        nombre_rubro TEXT NOT NULL,
        valor_inicial REAL NOT NULL,
        valor_apropiado REAL NOT NULL,
        valor_cdp REAL NOT NULL DEFAULT 0,
        valor_rp REAL NOT NULL DEFAULT 0,
        valor_obligado REAL NOT NULL DEFAULT 0,
        valor_pagado REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        fuente_financiacion TEXT NOT NULL,
        sector TEXT NOT NULL,
        programa TEXT NOT NULL,
        subprograma TEXT NOT NULL,
        proyecto TEXT NOT NULL,
        actividad TEXT NOT NULL,
        objeto_gasto TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        fecha_aprobacion_concejo TEXT NOT NULL,
        acto_administrativo TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        UNIQUE(entidad_id, vigencia, codigo_rubro)
      )
    ''');

    // Tabla de CDPs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cdps (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_cdp TEXT NOT NULL UNIQUE,
        vigencia TEXT NOT NULL,
        apropiacion_id TEXT NOT NULL,
        codigo_rubro TEXT NOT NULL,
        valor_cdp REAL NOT NULL,
        valor_comprometido_rp REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        fecha_expedicion TEXT NOT NULL,
        fecha_vigencia TEXT NOT NULL,
        funcionario_expedidor TEXT NOT NULL,
        funcionario_solicitante TEXT NOT NULL,
        objeto_gasto TEXT NOT NULL,
        contrato_numero TEXT,
        estado TEXT NOT NULL,
        acto_administrativo_modificacion TEXT,
        fecha_modificacion TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (apropiacion_id) REFERENCES apropiaciones(id)
      )
    ''');

    // Tabla de RPs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rps (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_rp TEXT NOT NULL UNIQUE,
        vigencia TEXT NOT NULL,
        cdp_id TEXT NOT NULL,
        numero_cdp TEXT NOT NULL,
        contrato_id TEXT NOT NULL,
        contrato_numero TEXT NOT NULL,
        codigo_rubro TEXT NOT NULL,
        valor_rp REAL NOT NULL,
        valor_obligado REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        fecha_expedicion TEXT NOT NULL,
        fecha_vigencia TEXT NOT NULL,
        funcionario_expedidor TEXT NOT NULL,
        funcionario_solicitante TEXT NOT NULL,
        objeto_gasto TEXT NOT NULL,
        estado TEXT NOT NULL,
        acto_administrativo_modificacion TEXT,
        fecha_modificacion TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (cdp_id) REFERENCES cdps(id)
      )
    ''');

    // Tabla de obligaciones
    await db.execute('''
      CREATE TABLE IF NOT EXISTS obligaciones (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_obligacion TEXT NOT NULL UNIQUE,
        vigencia TEXT NOT NULL,
        rp_id TEXT NOT NULL,
        numero_rp TEXT NOT NULL,
        contrato_id TEXT NOT NULL,
        contrato_numero TEXT NOT NULL,
        tercero_id TEXT NOT NULL,
        tercero_nombre TEXT NOT NULL,
        codigo_rubro TEXT NOT NULL,
        valor_obligacion REAL NOT NULL,
        valor_pagado REAL NOT NULL DEFAULT 0,
        saldo_pendiente REAL NOT NULL,
        fecha_reconocimiento TEXT NOT NULL,
        funcionario_reconocio TEXT NOT NULL,
        objeto_gasto TEXT NOT NULL,
        acta_recibo_numero TEXT,
        acta_recibo_fecha TEXT,
        factura_numero TEXT,
        factura_fecha TEXT,
        estado TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (rp_id) REFERENCES rps(id),
        FOREIGN KEY (tercero_id) REFERENCES terceros_sector_publico(id)
      )
    ''');

    // Tabla de pagos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pagos (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_pago TEXT NOT NULL UNIQUE,
        vigencia TEXT NOT NULL,
        obligacion_id TEXT NOT NULL,
        numero_obligacion TEXT NOT NULL,
        rp_id TEXT NOT NULL,
        numero_rp TEXT NOT NULL,
        tercero_id TEXT NOT NULL,
        tercero_nombre TEXT NOT NULL,
        banco_destino TEXT NOT NULL,
        cuenta_destino TEXT NOT NULL,
        tipo_cuenta TEXT NOT NULL,
        valor_pago REAL NOT NULL,
        fecha_programacion TEXT NOT NULL,
        fecha_aprobacion TEXT,
        fecha_ejecucion TEXT,
        funcionario_aprobo TEXT NOT NULL,
        funcionario_programo TEXT NOT NULL,
        tipo_pago TEXT NOT NULL,
        estado TEXT NOT NULL,
        numero_cheque TEXT,
        numero_referencia TEXT,
        observaciones TEXT,
        rechazo_motivo TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (obligacion_id) REFERENCES obligaciones(id),
        FOREIGN KEY (tercero_id) REFERENCES terceros_sector_publico(id)
      )
    ''');

    // Tabla de PAC
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pac (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        mes INTEGER NOT NULL,
        codigo_rubro TEXT NOT NULL,
        valor_programado REAL NOT NULL,
        valor_ejecutado REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        fecha_creacion TEXT NOT NULL,
        fecha_aprobacion TEXT,
        funcionario_aprobo TEXT,
        estado TEXT NOT NULL,
        acto_administrativo TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        UNIQUE(entidad_id, vigencia, mes, codigo_rubro)
      )
    ''');

    // Tabla de embargos judiciales (informativo)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS embargos_judiciales (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_proceso TEXT NOT NULL,
        juzgado TEXT NOT NULL,
        tercero_id TEXT,
        tercero_nombre TEXT NOT NULL,
        valor_embargo REAL NOT NULL,
        fecha_registro TEXT NOT NULL,
        fecha_levantamiento TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (tercero_id) REFERENCES terceros_sector_publico(id)
      )
    ''');

    // Tabla de estampillas parafiscales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS estampillas_parafiscales (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        nombre_estampilla TEXT NOT NULL,
        tarifa REAL NOT NULL,
        base_legal TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // Índices para optimización
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_apropiaciones_entidad 
      ON apropiaciones(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_apropiaciones_vigencia 
      ON apropiaciones(vigencia)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cdps_entidad 
      ON cdps(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cdps_apropiacion 
      ON cdps(apropiacion_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rps_entidad 
      ON rps(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rps_cdp 
      ON rps(cdp_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_obligaciones_entidad 
      ON obligaciones(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_obligaciones_rp 
      ON obligaciones(rp_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pagos_entidad 
      ON pagos(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pagos_obligacion 
      ON pagos(obligacion_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pac_entidad 
      ON pac(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pac_vigencia_mes 
      ON pac(vigencia, mes)
    ''');
  }
}
