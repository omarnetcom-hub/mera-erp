import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/sector_publico/auditoria/services/chip_reporter_service.dart';
import 'package:merka_erp/sector_publico/auditoria/database/schema_auditoria.dart';
import 'package:merka_erp/sector_publico/contabilidad/database/schema_contabilidad.dart';
import 'package:merka_erp/sector_publico/database/schema_multi_tenant.dart';
import 'package:merka_erp/sector_publico/security/auditoria_service.dart';

Future<void> insertarFuncionario(
  Database db, {
  required String id,
  required String cargo,
  String? usuarioId,
  required String nombre,
  required String identificacion,
  required String tarjeta,
  required String telefono,
  required String email,
  required String direccion,
}) {
  return db.insert('funcionarios_entidad', {
    'id': id,
    'entidad_id': 'ENT-CHIP',
    'usuario_id': usuarioId,
    'cargo_clave': cargo,
    'nombre_completo': nombre,
    'identificacion': identificacion,
    'tarjeta_profesional': tarjeta,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
  });
}

Future<void> insertarSaldo(
  Database db,
  String codigo,
  String nombre,
  double debito,
  double credito,
) {
  return db.insert('saldos_cuentas', {
    'id': 'SALDO-$codigo',
    'entidad_id': 'ENT-CHIP',
    'cuenta_codigo': codigo,
    'cuenta_nombre': nombre,
    'saldo_deudor': debito,
    'saldo_acreedor': credito,
    'saldo_neto': debito - credito,
    'fecha_ultimo_movimiento': '2026-12-31T00:00:00.000',
    'vigencia': '2026',
  });
}

void main() {
  late Database db;
  late CHIPReporterService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
    await SchemaMultiTenant.crearTablas(db);
    await SchemaContabilidad.crearTablas(db);
    await SchemaAuditoria.crearTablas(db);

    await db.insert('entidades_territoriales', {
      'id': 'ENT-CHIP',
      'nit': '900123456',
      'razon_social': 'Municipio de Prueba',
      'tipo_entidad': 'municipio',
      'departamento': 'Cundinamarca',
      'municipio': 'Prueba',
      'fecha_creacion': '2026-01-01T00:00:00.000',
      'plan_cuentas_cgc': '{}',
      'configuracion_normativa': '{}',
    });

    await insertarFuncionario(
      db,
      id: 'FUNC-AUDITOR',
      cargo: 'jefeControlInterno',
      usuarioId: 'USR-AUDITOR',
      nombre: 'Auditor Interno',
      identificacion: '100',
      tarjeta: '',
      telefono: '3000000000',
      email: 'auditor@prueba.gov.co',
      direccion: 'Calle 1',
    );
    await insertarFuncionario(
      db,
      id: 'FUNC-REP',
      cargo: 'representante_legal',
      nombre: 'Alcaldesa Prueba',
      identificacion: '101',
      tarjeta: '',
      telefono: '3000000001',
      email: 'alcaldesa@prueba.gov.co',
      direccion: 'Calle 1',
    );
    await insertarFuncionario(
      db,
      id: 'FUNC-ORD',
      cargo: 'ordenador_gasto',
      nombre: 'Ordenador Prueba',
      identificacion: '102',
      tarjeta: '',
      telefono: '3000000002',
      email: 'ordenador@prueba.gov.co',
      direccion: 'Calle 1',
    );
    await insertarFuncionario(
      db,
      id: 'FUNC-CONT',
      cargo: 'contador',
      nombre: 'Contadora Prueba',
      identificacion: '103',
      tarjeta: 'TP-123',
      telefono: '3000000003',
      email: 'contadora@prueba.gov.co',
      direccion: 'Calle 1',
    );
    await insertarFuncionario(
      db,
      id: 'FUNC-CONTACTO',
      cargo: 'contacto_entidad',
      nombre: 'Contacto Prueba',
      identificacion: '104',
      tarjeta: '',
      telefono: '3000000004',
      email: 'contacto@prueba.gov.co',
      direccion: 'Carrera 2',
    );

    await insertarSaldo(db, '1110', 'Efectivo', 1100, 0);
    await insertarSaldo(db, '2401', 'Cuentas por pagar', 0, 400);
    await insertarSaldo(db, '3105', 'Capital fiscal', 0, 300);
    await insertarSaldo(db, '4111', 'Impuesto predial', 0, 600);
    await insertarSaldo(db, '4401', 'Transferencias SGP', 0, 100);
    await insertarSaldo(db, '5101', 'Servicios personales', 250, 0);
    await insertarSaldo(db, '5111', 'Gastos generales', 50, 0);

    service = CHIPReporterService(
      db: db,
      auditoriaService: AuditoriaService(db),
    );
  });

  tearDown(() async => db.close());

  test('CGN 2015_001 a 003 reflejan fuentes persistidas del sistema', () async {
    final reportes = await service.generarReportesDesdeDatosSistema(
      entidadId: 'ENT-CHIP',
      usuarioId: 'USR-AUDITOR',
      vigencia: '2026',
    );

    expect(
      reportes.keys,
      containsAll(['cgn2015_001', 'cgn2015_002', 'cgn2015_003']),
    );
    expect(reportes, isNot(contains('cgn2015_004')));

    final entidad = reportes['cgn2015_001']!.datos;
    expect(entidad['nit'], '900123456');
    expect(entidad['razon_social'], 'Municipio de Prueba');
    expect(entidad['contador'], 'Contadora Prueba');
    expect(entidad['tarjeta_profesional_contador'], 'TP-123');

    final resultado = reportes['cgn2015_002']!.datos;
    expect(resultado['ingresos_tributarios'], 600.0);
    expect(resultado['transferencias_sgp'], 100.0);
    expect(resultado['total_ingresos'], 700.0);
    expect(resultado['gastos_personal'], 250.0);
    expect(resultado['gastos_generales'], 50.0);
    expect(resultado['total_gastos'], 300.0);
    expect(resultado['resultado_operacional'], 400.0);

    final situacion = reportes['cgn2015_003']!.datos;
    expect(situacion['total_activo'], 1100.0);
    expect(situacion['total_pasivo'], 400.0);
    expect(situacion['patrimonio'], 700.0);
    expect(situacion['total_pasivo_patrimonio'], 1100.0);

    final guardados = await db.query('reportes_chip');
    expect(guardados, hasLength(3));
    final recuperado = await service.obtenerReporte(
      reportes['cgn2015_002']!.id,
    );
    expect(recuperado!.datos['resultado_operacional'], 400.0);
  });
}
