// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/sector_publico/siif/services/siif_service.dart';
import 'package:merka_erp/sector_publico/siif/database/schema_siif.dart';
import 'package:merka_erp/sector_publico/presupuesto/database/schema_presupuesto.dart';
import 'package:merka_erp/sector_publico/security/auditoria_service.dart';

void main() {
  late Database db;
  late SIIFService siifService;
  late AuditoriaService auditoriaService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS entidades_territoriales (
            id TEXT PRIMARY KEY,
            nit TEXT NOT NULL,
            razon_social TEXT NOT NULL,
            tipo_entidad TEXT NOT NULL,
            fecha_creacion TEXT NOT NULL,
            plan_cuentas_cgc TEXT NOT NULL,
            configuracion_normativa TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS registro_auditoria (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            usuario_id TEXT NOT NULL,
            tipo_evento TEXT NOT NULL,
            modulo TEXT NOT NULL,
            accion TEXT NOT NULL,
            fecha_hora TEXT NOT NULL,
            valor_anterior TEXT NOT NULL,
            valor_nuevo TEXT NOT NULL,
            referencia_id TEXT NOT NULL,
            hash_integridad TEXT NOT NULL
          )
        ''');
        await SchemaPresupuesto.crearTablas(db);
        await SchemaSIIF.crearTablas(db);
      },
    );
    auditoriaService = AuditoriaService(db);
    siifService = SIIFService(db: db, auditoriaService: auditoriaService);
  });

  tearDown(() async {
    await db.close();
  });

  test('SIIFService genera reporte presupuestal mensual y exporta a plano', () async {
    final rep = await siifService.generarReportePresupuestoMensual(
      entidadId: 'ENT-SIIF-TEST',
      usuarioId: 'USR-SIIF-01',
      vigencia: '2026',
      mes: 1,
    );

    expect(rep.id, isNotEmpty);
    expect(rep.vigencia, equals('2026'));
    expect(rep.mes, equals(1));

    final plano = await siifService.exportarAPlano(rep.id);
    expect(plano, contains('HDR|SIIF_NACION|ENT-SIIF-TEST|2026|01|presupuestoMensual'));
  });
}
