/// Esquema de base de datos para el módulo de Activos del Estado
/// NICSP 17 + Fondo de Unidad de Tesorería (FUT Local) + Actas de Responsabilidad de Cuentadantes
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
        valor_adquisicion INTEGER NOT NULL,
        valor_libros INTEGER NOT NULL,
        valor_neto INTEGER NOT NULL,
        fecha_adquisicion TEXT NOT NULL,
        fecha_puesta_en_marcha TEXT NOT NULL,
        vida_util_anios INTEGER NOT NULL,
        valor_residual INTEGER NOT NULL,
        depreciacion_acumulada INTEGER NOT NULL DEFAULT 0,
        estado TEXT NOT NULL,
        ubicacion TEXT,
        responsable TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fondo_unidad_tesoreria (
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
        valor_inicial INTEGER NOT NULL,
        valor_ejecutado INTEGER NOT NULL DEFAULT 0,
        saldo_disponible INTEGER NOT NULL,
        fecha_apertura TEXT NOT NULL,
        fecha_cierre TEXT,
        estado TEXT NOT NULL,
        responsable TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion_depreciacion_unidades (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        activo_id TEXT NOT NULL,
        numero_inventario TEXT NOT NULL,
        unidades_totales_estimadas REAL NOT NULL,
        valor_adquisicion INTEGER NOT NULL,
        valor_residual INTEGER NOT NULL,
        costo_depreciable INTEGER NOT NULL,
        costo_por_unidad INTEGER NOT NULL,
        fecha_inicio TEXT NOT NULL,
        unidades_producidas_acumuladas REAL NOT NULL DEFAULT 0,
        depreciacion_acumulada INTEGER NOT NULL DEFAULT 0,
        observaciones TEXT,
        fecha_registro TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'activo',
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (activo_id) REFERENCES activos_estado(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS registros_produccion (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        configuracion_id TEXT NOT NULL,
        activo_id TEXT NOT NULL,
        unidades_producidas REAL NOT NULL,
        costo_por_unidad INTEGER NOT NULL,
        depreciacion_periodo INTEGER NOT NULL,
        fecha_produccion TEXT NOT NULL,
        observaciones TEXT,
        fecha_registro TEXT NOT NULL,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (configuracion_id) REFERENCES configuracion_depreciacion_unidades(id),
        FOREIGN KEY (activo_id) REFERENCES activos_estado(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS revalorizaciones (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        activo_id TEXT NOT NULL,
        numero_inventario TEXT NOT NULL,
        metodo TEXT NOT NULL,
        valor_anterior INTEGER NOT NULL,
        valor_nuevo INTEGER NOT NULL,
        incremento INTEGER NOT NULL,
        porcentaje_incremento REAL NOT NULL,
        fecha_revalorizacion TEXT NOT NULL,
        perito_avaluo TEXT NOT NULL,
        numero_dictamen TEXT NOT NULL,
        motivo TEXT NOT NULL,
        observaciones TEXT,
        fecha_registro TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'aprobado',
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (activo_id) REFERENCES activos_estado(id)
      )
    ''');

    // Tabla de Actas de Responsabilidad y Cuentadantes de Bienes del Estado
    // FK: entidad_id -> entidades_territoriales(id)
    // FK: activo_id -> activos_estado(id)
    // FK: funcionario_id -> empleados_sp(id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS actas_responsabilidad (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_acta TEXT NOT NULL UNIQUE,
        activo_id TEXT NOT NULL,
        funcionario_id TEXT NOT NULL,
        funcionario_nombre TEXT NOT NULL,
        funcionario_identificacion TEXT NOT NULL,
        dependencia TEXT NOT NULL,
        ubicacion_fisica TEXT NOT NULL,
        fecha_asignacion TEXT NOT NULL,
        fecha_devolucion TEXT,
        estado_acta TEXT NOT NULL DEFAULT 'activa',
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (activo_id) REFERENCES activos_estado(id),
        FOREIGN KEY (funcionario_id) REFERENCES empleados_sp(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activos_entidad ON activos_estado(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activos_estado ON activos_estado(estado)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activos_tipo ON activos_estado(tipo_activo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fondo_unidad_tesoreria_entidad ON fondo_unidad_tesoreria(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fondo_unidad_tesoreria_estado ON fondo_unidad_tesoreria(estado)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fondo_unidad_tesoreria_tercero ON fondo_unidad_tesoreria(tercero_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_config_deprec_activo ON configuracion_depreciacion_unidades(activo_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_registros_prod_config ON registros_produccion(configuracion_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_revalorizaciones_activo ON revalorizaciones(activo_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_actas_entidad ON actas_responsabilidad(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_actas_activo ON actas_responsabilidad(activo_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_actas_funcionario ON actas_responsabilidad(funcionario_id)',
    );
  }
}
