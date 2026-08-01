/// Esquema de base de datos para el módulo de Contabilidad NICSP
/// Implementa Resolución 533/2015 CGN y NICSP
library;

import 'package:sqflite/sqflite.dart';

class SchemaContabilidad {
  /// Crea todas las tablas necesarias para el módulo de contabilidad
  static Future<void> crearTablas(Database db) async {
    // Tabla de asientos contables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS asientos_contables_sp (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_asiento TEXT NOT NULL UNIQUE,
        fecha_asiento TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        tipo_asiento TEXT NOT NULL,
        estado TEXT NOT NULL,
        total_debito REAL NOT NULL,
        total_credito REAL NOT NULL,
        usuario_creo TEXT NOT NULL,
        usuario_reviso TEXT,
        fecha_revision TEXT,
        referencia_origen TEXT,
        tipo_documento_origen TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // Tabla de detalles de asientos contables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS detalles_asientos (
        id TEXT PRIMARY KEY,
        asiento_id TEXT NOT NULL,
        cuenta_codigo TEXT NOT NULL,
        cuenta_nombre TEXT NOT NULL,
        debito REAL NOT NULL,
        credito REAL NOT NULL,
        referencia_id TEXT,
        FOREIGN KEY (asiento_id) REFERENCES asientos_contables_sp(id) ON DELETE CASCADE
      )
    ''');

    // Tabla de saldos de cuentas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saldos_cuentas (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        cuenta_codigo TEXT NOT NULL,
        cuenta_nombre TEXT NOT NULL,
        saldo_deudor REAL NOT NULL DEFAULT 0,
        saldo_acreedor REAL NOT NULL DEFAULT 0,
        saldo_neto REAL NOT NULL DEFAULT 0,
        fecha_ultimo_movimiento TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        UNIQUE(entidad_id, cuenta_codigo, vigencia)
      )
    ''');

    // Tabla de configuración de depreciación (NICSP 17)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion_depreciacion (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        tipo_activo TEXT NOT NULL,
        vida_util_anios INTEGER NOT NULL,
        metodo_depreciacion TEXT NOT NULL,
        porcentaje_depreciacion REAL NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // Tabla de provisiones (NICSP 19)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS provisiones (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        tipo_provision TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        valor_provision REAL NOT NULL,
        valor_utilizado REAL NOT NULL DEFAULT 0,
        saldo_disponible REAL NOT NULL,
        fecha_creacion TEXT NOT NULL,
        fecha_vencimiento TEXT,
        estado TEXT NOT NULL,
        referencia_documento TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // Tabla de asientos de cierre de vigencia
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cierres_vigencia (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        fecha_cierre TEXT NOT NULL,
        asiento_cierre_id TEXT NOT NULL,
        asiento_apertura_id TEXT,
        usuario_cerro TEXT NOT NULL,
        estado TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (asiento_cierre_id) REFERENCES asientos_contables_sp(id),
        UNIQUE(entidad_id, vigencia)
      )
    ''');

    // Índices para optimización
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_asientos_entidad 
      ON asientos_contables_sp(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_asientos_fecha 
      ON asientos_contables_sp(fecha_asiento)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_asientos_tipo 
      ON asientos_contables_sp(tipo_asiento)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_detalles_asiento 
      ON detalles_asientos(asiento_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_detalles_cuenta 
      ON detalles_asientos(cuenta_codigo)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_saldos_entidad 
      ON saldos_cuentas(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_saldos_vigencia 
      ON saldos_cuentas(vigencia)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cierres_entidad 
      ON cierres_vigencia(entidad_id)
    ''');

    await crearTablasConciliacionesReciprocas(db);
  }

  /// Crea la capa de eliminacion NICSP 40 sin alterar los asientos fuente.
  static Future<void> crearTablasConciliacionesReciprocas(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conciliaciones_reciprocas (
        id TEXT PRIMARY KEY,
        entidad_consolidadora_id TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        monto_conciliado REAL NOT NULL CHECK (monto_conciliado > 0),
        tolerancia_monto REAL NOT NULL DEFAULT 0 CHECK (tolerancia_monto >= 0),
        tolerancia_dias INTEGER NOT NULL DEFAULT 0 CHECK (tolerancia_dias >= 0),
        diferencia_monto_validada REAL NOT NULL,
        diferencia_dias_validada INTEGER NOT NULL,
        aprobado_por TEXT NOT NULL,
        fecha_aprobacion TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'aprobada' CHECK (estado = 'aprobada'),
        observaciones TEXT,
        FOREIGN KEY (entidad_consolidadora_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS conciliaciones_reciprocas_partidas (
        id TEXT PRIMARY KEY,
        conciliacion_id TEXT NOT NULL,
        entidad_id TEXT NOT NULL,
        asiento_id TEXT NOT NULL,
        detalle_asiento_id TEXT NOT NULL,
        lado TEXT NOT NULL CHECK (lado IN ('debito', 'credito')),
        monto_eliminar REAL NOT NULL CHECK (monto_eliminar > 0),
        FOREIGN KEY (conciliacion_id) REFERENCES conciliaciones_reciprocas(id),
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (asiento_id) REFERENCES asientos_contables_sp(id),
        FOREIGN KEY (detalle_asiento_id) REFERENCES detalles_asientos(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_conciliaciones_reciprocas_consolidadora
      ON conciliaciones_reciprocas(entidad_consolidadora_id, vigencia, estado)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_conciliaciones_reciprocas_partidas
      ON conciliaciones_reciprocas_partidas(conciliacion_id, asiento_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_conciliaciones_reciprocas_detalle
      ON conciliaciones_reciprocas_partidas(detalle_asiento_id)
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_conciliacion_reciproca_no_sobreeliminar
      BEFORE INSERT ON conciliaciones_reciprocas_partidas
      FOR EACH ROW
      WHEN NEW.monto_eliminar + COALESCE((
        SELECT SUM(p.monto_eliminar)
        FROM conciliaciones_reciprocas_partidas p
        INNER JOIN conciliaciones_reciprocas c ON c.id = p.conciliacion_id
        WHERE p.detalle_asiento_id = NEW.detalle_asiento_id
          AND c.estado = 'aprobada'
      ), 0) > COALESCE((
        SELECT CASE WHEN d.debito > 0 THEN d.debito ELSE d.credito END
        FROM detalles_asientos d
        WHERE d.id = NEW.detalle_asiento_id
      ), 0)
      BEGIN
        SELECT RAISE(ABORT, 'La conciliacion excede el saldo de la partida');
      END
    ''');
  }

  /// Migracion incremental v73 para instalaciones existentes.
  static Future<void> migrarConciliacionesReciprocas(Database db) async {
    await crearTablasConciliacionesReciprocas(db);
  }

  /// Inserta configuración inicial de depreciación según tablas NICSP 17
  static Future<void> insertarConfiguracionDepreciacion(
    Database db,
    String entidadId,
  ) async {
    final configuraciones = [
      ['Edificios', 50, 'linea_recta', 2.0],
      ['Maquinaria y equipo', 10, 'linea_recta', 10.0],
      ['Equipo de transporte', 5, 'linea_recta', 20.0],
      ['Equipo de cómputo', 3, 'linea_recta', 33.33],
      ['Mobiliario', 10, 'linea_recta', 10.0],
      ['Mejoras a propiedades', 10, 'linea_recta', 10.0],
    ];

    final batch = db.batch();
    for (final config in configuraciones) {
      batch.insert('configuracion_depreciacion', {
        'id':
            DateTime.now().millisecondsSinceEpoch.toString() +
            (config[0] as String),
        'entidad_id': entidadId,
        'tipo_activo': config[0],
        'vida_util_anios': config[1],
        'metodo_depreciacion': config[2],
        'porcentaje_depreciacion': config[3],
        'activo': 1,
      });
    }
    await batch.commit(noResult: true);
  }
}
