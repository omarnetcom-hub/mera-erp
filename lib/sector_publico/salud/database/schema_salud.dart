/// Esquema de base de datos para el módulo de Salud Pública
/// RIPS + EPS + Glosas
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

    await db.execute('CREATE INDEX IF NOT EXISTS idx_rips_entidad ON rips(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rips_fecha ON rips(fecha_factura)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rips_paciente ON rips(numero_identificacion)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_glosas_entidad ON glosas(entidad_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_glosas_estado ON glosas(estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_glosas_rips ON glosas(rips_id)');
  }
}
