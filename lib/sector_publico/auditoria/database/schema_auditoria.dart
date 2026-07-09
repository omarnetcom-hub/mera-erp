/// Esquema de base de datos para el módulo de Auditoría Forense
/// Tabla de reportes CHIP
library;

import 'package:sqflite/sqflite.dart';

class SchemaAuditoria {
  /// Crea las tablas adicionales para auditoría forense
  static Future<void> crearTablas(Database db) async {
    // Tabla de reportes CHIP
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reportes_chip (
        id TEXT PRIMARY KEY,
        entidad_id TEXT NOT NULL,
        tipo_formulario TEXT NOT NULL,
        vigencia TEXT NOT NULL,
        fecha_generacion TEXT NOT NULL,
        usuario_genero TEXT NOT NULL,
        datos TEXT NOT NULL,
        estado TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY (entidad_id) REFERENCES entidades_territoriales(id)
      )
    ''');

    // Índices para reportes CHIP
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reportes_chip_entidad 
      ON reportes_chip(entidad_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reportes_chip_vigencia 
      ON reportes_chip(vigencia)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reportes_chip_tipo 
      ON reportes_chip(tipo_formulario)
    ''');
  }
}
