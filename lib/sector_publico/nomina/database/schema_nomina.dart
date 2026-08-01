/// Esquema de base de datos para el módulo de Nómina Pública
/// PILA + Retroactivos
library;

import 'package:sqflite/sqflite.dart';

class SchemaNomina {
  static Future<void> crearTablas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleados_sp (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_identificacion TEXT NOT NULL UNIQUE,
        nombre_completo TEXT NOT NULL,
        cargo TEXT NOT NULL,
        dependencia TEXT NOT NULL,
        tipo_contrato TEXT NOT NULL,
        tipo_vinculacion TEXT NOT NULL,
        regimen_nomina TEXT NOT NULL DEFAULT 'carreraAdministrativa',
        clase_riesgo_arl INTEGER NOT NULL DEFAULT 1,
        salario_basico REAL NOT NULL,
        fecha_ingreso TEXT NOT NULL,
        fecha_retiro TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        cuenta_bancaria TEXT,
        tipo_cuenta TEXT,
        banco TEXT,
        eps TEXT,
        fondo_pension TEXT,
        fondo_cesantias TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS liquidaciones_nomina (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_liquidacion TEXT NOT NULL UNIQUE,
        periodo TEXT NOT NULL,
        empleado_id TEXT NOT NULL,
        empleado_nombre TEXT NOT NULL,
        empleado_identificacion TEXT NOT NULL,
        dias_trabajados INTEGER NOT NULL,
        salario_basico REAL NOT NULL,
        salario_devengado REAL NOT NULL,
        auxilio_transporte REAL NOT NULL DEFAULT 0,
        auxilio_alimentacion REAL NOT NULL DEFAULT 0,
        horas_extra REAL NOT NULL DEFAULT 0,
        recargo_nocturno REAL NOT NULL DEFAULT 0,
        total_devengado REAL NOT NULL,
        salud REAL NOT NULL,
        pension REAL NOT NULL,
        fondo_solidaridad REAL NOT NULL,
        riesgos_laborales REAL NOT NULL,
        caja_compensacion REAL NOT NULL,
        sena REAL NOT NULL,
        icbf REAL NOT NULL,
        total_aportes REAL NOT NULL,
        neto_pagar REAL NOT NULL,
        estado TEXT NOT NULL,
        fecha_liquidacion TEXT NOT NULL,
        fecha_pago TEXT,
        pila_id TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (empleado_id) REFERENCES empleados_sp(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS retroactivos (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_retroactivo TEXT NOT NULL UNIQUE,
        empleado_id TEXT NOT NULL,
        empleado_nombre TEXT NOT NULL,
        empleado_identificacion TEXT NOT NULL,
        tipo_retroactivo TEXT NOT NULL,
        motivo TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        meses INTEGER NOT NULL,
        salario_anterior REAL NOT NULL,
        salario_nuevo REAL NOT NULL,
        diferencia_mensual REAL NOT NULL,
        valor_total REAL NOT NULL,
        valor_pagado REAL NOT NULL DEFAULT 0,
        saldo_pendiente REAL NOT NULL,
        estado TEXT NOT NULL,
        fecha_calculo TEXT NOT NULL,
        fecha_aprobacion TEXT,
        acto_administrativo TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (empleado_id) REFERENCES empleados_sp(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS horas_extra (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        empleado_id TEXT NOT NULL,
        tipo_hora TEXT NOT NULL,
        fecha TEXT NOT NULL,
        cantidad_horas REAL NOT NULL,
        salario_hora REAL NOT NULL,
        porcentaje_recargo REAL NOT NULL,
        valor_recargo REAL NOT NULL,
        valor_total REAL NOT NULL,
        motivo TEXT,
        aprobado_por TEXT,
        fecha_registro TEXT NOT NULL,
        estado TEXT NOT NULL,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (empleado_id) REFERENCES empleados_sp(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recargos (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        empleado_id TEXT NOT NULL,
        tipo_recargo TEXT NOT NULL,
        fecha TEXT NOT NULL,
        cantidad_horas REAL NOT NULL,
        salario_hora REAL NOT NULL,
        porcentaje_recargo REAL NOT NULL,
        valor_recargo REAL NOT NULL,
        motivo TEXT,
        fecha_registro TEXT NOT NULL,
        estado TEXT NOT NULL,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (empleado_id) REFERENCES empleados_sp(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_empleados_entidad ON empleados_sp(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_empleados_identificacion ON empleados_sp(numero_identificacion)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_liquidaciones_entidad ON liquidaciones_nomina(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_liquidaciones_periodo ON liquidaciones_nomina(periodo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_liquidaciones_empleado ON liquidaciones_nomina(empleado_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_retroactivos_entidad ON retroactivos(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_retroactivos_empleado ON retroactivos(empleado_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_horas_extra_entidad ON horas_extra(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_horas_extra_empleado ON horas_extra(empleado_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recargos_entidad ON recargos(entidad_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recargos_empleado ON recargos(empleado_id)',
    );
  }

  static Future<void> migrarRegimenesYAportes(Database db) async {
    await _agregarColumnaSiNoExiste(
      db,
      'empleados_sp',
      'regimen_nomina',
      "TEXT NOT NULL DEFAULT 'carreraAdministrativa'",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'empleados_sp',
      'clase_riesgo_arl',
      'INTEGER NOT NULL DEFAULT 1',
    );
  }

  static Future<void> _agregarColumnaSiNoExiste(
    Database db,
    String tabla,
    String columna,
    String definicion,
  ) async {
    final columnas = await db.rawQuery('PRAGMA table_info($tabla)');
    if (columnas.any((fila) => fila['name'] == columna)) return;
    await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $definicion');
  }
}
