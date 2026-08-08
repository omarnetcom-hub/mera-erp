/// Esquema de base de datos para el módulo de Contratación Pública
/// Ley 80 de 1993 + SECOP II
library;

import 'package:sqflite/sqflite.dart';

class SchemaContratacion {
  /// Crea todas las tablas necesarias para el módulo de contratación
  static Future<void> crearTablas(Database db) async {
    // Tabla de procesos de contratación
    await db.execute('''
      CREATE TABLE IF NOT EXISTS procesos_contratacion (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_proceso TEXT NOT NULL UNIQUE,
        objeto_contrato TEXT NOT NULL,
        modalidad TEXT NOT NULL,
        valor_estimado INTEGER NOT NULL,
        tipo_contrato TEXT NOT NULL,
        dependencia_solicitante TEXT NOT NULL,
        responsable_proceso TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_publicacion TEXT,
        fecha_cierre TEXT,
        estado TEXT NOT NULL,
        cdp_id TEXT,
        numero_cdp TEXT,
        secop_id TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (cdp_id) REFERENCES cdps(id)
      )
    ''');

    // Tabla de contratos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contratos (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_contrato TEXT NOT NULL UNIQUE,
        proceso_id TEXT NOT NULL,
        numero_proceso TEXT NOT NULL,
        objeto_contrato TEXT NOT NULL,
        tipo_contrato TEXT NOT NULL,
        valor_contrato INTEGER NOT NULL,
        contratista_id TEXT NOT NULL,
        contratista_nombre TEXT NOT NULL,
        contratista_identificacion TEXT NOT NULL,
        cdp_id TEXT NOT NULL,
        numero_cdp TEXT NOT NULL,
        rp_id TEXT,
        numero_rp TEXT,
        fecha_firma TEXT NOT NULL,
        fecha_inicio_ejecucion TEXT NOT NULL,
        fecha_fin_ejecucion TEXT NOT NULL,
        duracion_dias INTEGER NOT NULL,
        estado TEXT NOT NULL,
        fecha_legalizacion TEXT,
        fecha_terminacion TEXT,
        fecha_liquidacion TEXT,
        supervisor_id TEXT,
        supervisor_nombre TEXT,
        interventor_id TEXT,
        interventor_nombre TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (proceso_id) REFERENCES procesos_contratacion(id),
        FOREIGN KEY (cdp_id) REFERENCES cdps(id),
        FOREIGN KEY (rp_id) REFERENCES rps(id)
      )
    ''');

    // Tabla de pólizas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS polizas (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        contrato_id TEXT NOT NULL,
        numero_contrato TEXT NOT NULL,
        numero_poliza TEXT NOT NULL UNIQUE,
        tipo_poliza TEXT NOT NULL,
        aseguradora TEXT NOT NULL,
        valor_asegurado INTEGER NOT NULL,
        fecha_emision TEXT NOT NULL,
        fecha_inicio_vigencia TEXT NOT NULL,
        fecha_fin_vigencia TEXT NOT NULL,
        estado TEXT NOT NULL,
        fecha_reclamacion TEXT,
        fecha_pago TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (contrato_id) REFERENCES contratos(id)
      )
    ''');

    // Índices para optimización
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_procesos_entidad 
      ON procesos_contratacion(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_procesos_estado 
      ON procesos_contratacion(estado)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_procesos_cdp 
      ON procesos_contratacion(cdp_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_contratos_entidad 
      ON contratos(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_contratos_proceso 
      ON contratos(proceso_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_contratos_estado 
      ON contratos(estado)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_contratos_contratista 
      ON contratos(contratista_identificacion)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_polizas_contrato 
      ON polizas(contrato_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_polizas_estado 
      ON polizas(estado)
    ''');
  }

  /// Migra contratos heredados para permitir la firma antes de expedir el RP.
  /// SQLite no permite quitar NOT NULL con ALTER TABLE, por lo que preserva
  /// explícitamente cada columna de contratos y pólizas al reconstruirlas.
  static Future<void> migrarContratosConRPOpcional(Database db) async {
    final columnas = await db.rawQuery('PRAGMA table_info(contratos)');
    final rpIdObligatorio = columnas.any(
      (columna) => columna['name'] == 'rp_id' && columna['notnull'] == 1,
    );
    final numeroRpObligatorio = columnas.any(
      (columna) => columna['name'] == 'numero_rp' && columna['notnull'] == 1,
    );
    if (columnas.isEmpty || (!rpIdObligatorio && !numeroRpObligatorio)) return;

    await db.execute('ALTER TABLE polizas RENAME TO polizas_legacy_v68');
    await db.execute('ALTER TABLE contratos RENAME TO contratos_legacy_v68');
    await crearTablas(db);

    const columnasContrato = '''
      id, entidad_id, numero_contrato, proceso_id, numero_proceso,
      objeto_contrato, tipo_contrato, valor_contrato, contratista_id,
      contratista_nombre, contratista_identificacion, cdp_id, numero_cdp,
      rp_id, numero_rp, fecha_firma, fecha_inicio_ejecucion,
      fecha_fin_ejecucion, duracion_dias, estado, fecha_legalizacion,
      fecha_terminacion, fecha_liquidacion, supervisor_id, supervisor_nombre,
      interventor_id, interventor_nombre, observaciones
    ''';
    await db.execute('''
      INSERT INTO contratos ($columnasContrato)
      SELECT $columnasContrato FROM contratos_legacy_v68
    ''');

    const columnasPoliza = '''
      id, entidad_id, contrato_id, numero_contrato, numero_poliza,
      tipo_poliza, aseguradora, valor_asegurado, fecha_emision,
      fecha_inicio_vigencia, fecha_fin_vigencia, estado, fecha_reclamacion,
      fecha_pago, observaciones
    ''';
    await db.execute('''
      INSERT INTO polizas ($columnasPoliza)
      SELECT $columnasPoliza FROM polizas_legacy_v68
    ''');

    await db.execute('DROP TABLE polizas_legacy_v68');
    await db.execute('DROP TABLE contratos_legacy_v68');
    await crearTablas(db);
  }
}
