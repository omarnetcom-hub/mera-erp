/// Inicializador de Base de Datos - Sector Público
/// Conecta todos los esquemas de las 12 fases al motor SQLite
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'schema_multi_tenant.dart';
import '../presupuesto/database/schema_presupuesto.dart';
import '../contabilidad/database/schema_contabilidad.dart';
import '../auditoria/database/schema_auditoria.dart';
import '../rentas/database/schema_rentas.dart';
import '../contratacion/database/schema_contratacion.dart';
import '../nomina/database/schema_nomina.dart';
import '../planeacion/database/schema_planeacion.dart';
import '../activos/database/schema_activos.dart';
import '../salud/database/schema_salud.dart';
import '../regalias/database/schema_regalias.dart';
import '../transparencia/database/schema_transparencia.dart';

class DatabaseInitializer {
  static Database? _database;
  static const String _databaseName = 'merka_erp_sector_publico.db';
  static const int _databaseVersion = 1;

  /// Obtiene la instancia de la base de datos
  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  /// Crea todas las tablas al inicializar la base de datos
  static Future<void> _onCreate(Database db, int version) async {
    print('Inicializando base de datos del Sector Público...');
    
    // Fase 0: Multi-tenant y seguridad
    await SchemaMultiTenant.crearTablas(db);
    print('✓ Tablas multi-tenant creadas');
    
    // Fase 1: Presupuesto público + PAC
    await SchemaPresupuesto.crearTablas(db);
    print('✓ Tablas de presupuesto creadas');
    
    // Fase 2: Contabilidad NICSP
    await SchemaContabilidad.crearTablas(db);
    print('✓ Tablas de contabilidad NICSP creadas');
    
    // Fase 3: Auditoría forense + CHIP
    await SchemaAuditoria.crearTablas(db);
    print('✓ Tablas de auditoría creadas');
    
    // Fase 4: Rentas (Predial + ICA)
    await SchemaRentas.crearTablas(db);
    print('✓ Tablas de rentas creadas');
    
    // Fase 5: Contratación pública + SECOP II
    await SchemaContratacion.crearTablas(db);
    print('✓ Tablas de contratación creadas');
    
    // Fase 6: Nómina pública + PILA + Retroactivos
    await SchemaNomina.crearTablas(db);
    print('✓ Tablas de nómina creadas');
    
    // Fase 7: Planeación + Banco de Proyectos MGA + PDT
    await SchemaPlaneacion.crearTablas(db);
    print('✓ Tablas de planeación creadas');
    
    // Fase 8: Activos del Estado + FUT
    await SchemaActivos.crearTablas(db);
    print('✓ Tablas de activos creadas');
    
    // Fase 9: Salud pública (RIPS + EPS + Glosas)
    await SchemaSalud.crearTablas(db);
    print('✓ Tablas de salud creadas');
    
    // Fase 10: SGR (Regalías) + SGP
    await SchemaRegalias.crearTablas(db);
    print('✓ Tablas de regalías creadas');
    
    // Fase 11: Transparencia + Control Disciplinario + NICSP 40
    await SchemaTransparencia.crearTablas(db);
    print('✓ Tablas de transparencia creadas');
    
    print('Base de datos del Sector Público inicializada correctamente.');
  }

  /// Maneja upgrades de versión de base de datos
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Actualizando base de datos de versión $oldVersion a $newVersion...');
    
    // Aquí se implementarían migraciones incrementales si se cambia la versión
    // Por ahora, solo recrea las tablas (en producción esto debería ser más cuidadoso)
    if (oldVersion < newVersion) {
      // Implementar migraciones específicas según versión
    }
  }

  /// Cierra la conexión a la base de datos
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Elimina la base de datos (útil para pruebas)
  static Future<void> deleteDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
