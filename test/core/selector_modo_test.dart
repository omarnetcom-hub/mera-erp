import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/app_session.dart';
import 'package:merka_erp/core/workspace/selector_modo_screen.dart';
import 'package:merka_erp/sector_publico/security/roles_permisos_service.dart';
import 'package:merka_erp/sector_publico/database/schema_multi_tenant.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.instance.setDatabaseForTesting(db);
    AppSession.cerrar();

    // Crear tablas necesarias
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_config (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_settings (
        company_id INTEGER NOT NULL,
        setting_key TEXT NOT NULL,
        setting_value TEXT,
        PRIMARY KEY (company_id, setting_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        usuario TEXT NOT NULL UNIQUE,
        rol TEXT NOT NULL,
        pin TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha TEXT NOT NULL
      )
    ''');

    await SchemaMultiTenant.crearTablas(db);

    // Datos semilla
    await db.insert('app_config', {'clave': 'company_active_id', 'valor': '1'});

    // 1. Entidad Territorial
    await db.insert('entidades_territoriales', {
      'id': 'ENT-999',
      'nit': '900000000-1',
      'razon_social': 'Municipio de Prueba',
      'tipo_entidad': 'municipio',
      'fecha_creacion': DateTime.now().toIso8601String(),
      'plan_cuentas_cgc': '{}',
      'configuracion_normativa': '{}',
    });

    // 2. Funcionario con Autoridad (Alcalde)
    await db.insert('funcionarios_entidad', {
      'id': 'FUNC-ALCALDE',
      'entidad_id': 'ENT-999',
      'usuario_id': 'USR-ALCALDE',
      'cargo_clave': 'alcaldeRepresentanteLegal',
      'nombre_completo': 'Alcalde Municipal',
      'identificacion': '10000001',
      'telefono': '3000000000',
      'email': 'alcalde@prueba.gov.co',
      'direccion': 'Alcaldía',
    });

    // 3. Funcionario con Autoridad Financiera (Secretario de Hacienda)
    await db.insert('funcionarios_entidad', {
      'id': 'FUNC-HACIENDA',
      'entidad_id': 'ENT-999',
      'usuario_id': 'USR-HACIENDA',
      'cargo_clave': 'secretarioHacienda',
      'nombre_completo': 'Secretario Hacienda',
      'identificacion': '10000003',
      'telefono': '3000000003',
      'email': 'hacienda@prueba.gov.co',
      'direccion': 'Alcaldía',
    });

    // 4. Funcionario SIN Autoridad de Reconfiguración (Tesorero)
    await db.insert('funcionarios_entidad', {
      'id': 'FUNC-TESORERO',
      'entidad_id': 'ENT-999',
      'usuario_id': 'USR-TESORERO',
      'cargo_clave': 'tesorero',
      'nombre_completo': 'Tesorero Prueba',
      'identificacion': '10000002',
      'telefono': '3000000001',
      'email': 'tesorero@prueba.gov.co',
      'direccion': 'Alcaldía',
    });

    // 5. Usuario Comercial Administrador
    await db.insert('usuarios', {
      'id': 100,
      'company_id': 1,
      'nombre': 'Admin Comercial',
      'usuario': 'admin_comercial',
      'rol': 'administrador',
      'fecha': DateTime.now().toIso8601String(),
    });

    // 6. Usuario Comercial Operador (Sin Autoridad)
    await db.insert('usuarios', {
      'id': 101,
      'company_id': 1,
      'nombre': 'Operador Comercial',
      'usuario': 'operador_comercial',
      'rol': 'operador',
      'fecha': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Defensa en Profundidad & Resolucion de Sesion Estricta', () {
    test('1. Sin sesión activa, AppSession.usuarioId retorna null', () {
      expect(AppSession.usuarioId, isNull);
    });

    test('2. Sin usuarioId (null), tieneAutoridadReconfiguracion retorna FALSE (Fail-Closed)', () async {
      final auth = await SelectorModoService.tieneAutoridadReconfiguracion(
        db: db,
        entidadId: 'ENT-999',
        usuarioId: null,
      );
      expect(auth, isFalse);
    });

    test('3. Sin usuarioId (null), obtenerRolUsuarioEnEntidad retorna NULL (Fail-Closed)', () async {
      final rol = await RolesPermisosService.obtenerRolUsuarioEnEntidad(
        db: db,
        entidadId: 'ENT-999',
        usuarioId: null,
      );
      expect(rol, isNull);
    });

    test('4. Con sesión activa explícita, resuelve id/usuario sin ambigüedad ni fallbacks fijos', () async {
      AppSession.iniciar({
        'id': 'USR-ALCALDE',
        'usuario': 'alcalde_muni',
        'nombre': 'Dr. Alcalde',
        'rol': 'alcaldeRepresentanteLegal',
      });
      AppSession.establecerEntidadActiva('ENT-999');

      expect(AppSession.usuarioId, equals('USR-ALCALDE'));

      final auth = await SelectorModoService.tieneAutoridadReconfiguracion(
        db: db,
        entidadId: AppSession.entidadId,
        usuarioId: AppSession.usuarioId,
      );
      expect(auth, isTrue);
    });
  });
}
