/// Esquema de base de datos para el módulo de Salud Pública
/// RIPS + EPS/ADRES + Facturación + Glosas
library;

import 'package:sqflite/sqflite.dart';

class SchemaSalud {
  static Future<void> crearTablas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rips (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        tipo_rips TEXT NOT NULL,
        codigo_prestador TEXT NOT NULL,
        nombre_prestador TEXT NOT NULL,
        numero_factura TEXT NOT NULL,
        fecha_factura TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        codigo_paciente TEXT NOT NULL,
        nombre_paciente TEXT NOT NULL,
        tipo_identificacion TEXT NOT NULL,
        numero_identificacion TEXT NOT NULL,
        codigo_servicio TEXT NOT NULL,
        nombre_servicio TEXT NOT NULL,
        valor_servicio REAL NOT NULL,
        valor_copago REAL NOT NULL DEFAULT 0,
        valor_modera REAL NOT NULL DEFAULT 0,
        valor_neto REAL NOT NULL,
        diagnostico_principal TEXT,
        diagnostico_relacionado TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS glosas (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_glosa TEXT NOT NULL UNIQUE,
        tipo_glosa TEXT NOT NULL,
        rips_id TEXT NOT NULL,
        numero_factura TEXT NOT NULL,
        eps TEXT NOT NULL,
        motivo TEXT NOT NULL,
        valor_glosado REAL NOT NULL,
        valor_aceptado REAL NOT NULL,
        valor_rechazado REAL NOT NULL,
        fecha_generacion TEXT NOT NULL,
        fecha_envio TEXT NOT NULL,
        fecha_respuesta TEXT,
        estado TEXT NOT NULL,
        justificacion_respuesta TEXT,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (rips_id) REFERENCES rips(id)
      )
    ''');

    // Tabla de Contratos EPS / ADRES
    // FK: entidad_id -> entidades_territoriales(id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contratos_eps_adres (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        numero_contrato TEXT NOT NULL UNIQUE,
        eps_adres_nombre TEXT NOT NULL,
        eps_adres_nit TEXT NOT NULL,
        regimen TEXT NOT NULL,
        monto_contrato REAL NOT NULL,
        monto_facturado REAL NOT NULL DEFAULT 0,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'activo',
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // Tabla de Facturas de Prestación de Servicios de Salud
    // FK: entidad_id -> entidades_territoriales(id)
    // FK: contrato_id -> contratos_eps_adres(id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS facturas_salud (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        contrato_id TEXT NOT NULL,
        numero_factura TEXT NOT NULL UNIQUE,
        periodo TEXT NOT NULL,
        monto_total REAL NOT NULL,
        monto_glosado REAL NOT NULL DEFAULT 0,
        monto_pagado REAL NOT NULL DEFAULT 0,
        fecha_emision TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'emitida',
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id),
        FOREIGN KEY (contrato_id) REFERENCES contratos_eps_adres(id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_rips_entidad ON rips(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rips_fecha ON rips(fecha_factura)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rips_paciente ON rips(numero_identificacion)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_glosas_entidad ON glosas(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_glosas_estado ON glosas(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_glosas_rips ON glosas(rips_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contratos_eps_entidad ON contratos_eps_adres(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_facturas_salud_contrato ON facturas_salud(contrato_id)');
  }
}
