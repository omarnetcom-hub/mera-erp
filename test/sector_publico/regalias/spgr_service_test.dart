// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/sector_publico/regalias/services/spgr_service.dart';
import 'package:merka_erp/sector_publico/regalias/database/schema_regalias.dart';
import 'package:merka_erp/sector_publico/planeacion/database/schema_planeacion.dart';
import 'package:merka_erp/sector_publico/regalias/models/proyecto_ocad.dart';
import 'package:merka_erp/sector_publico/security/auditoria_service.dart';

void main() {
  late Database db;
  late SPGRService spgrService;
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
        await SchemaPlaneacion.crearTablas(db);
        await SchemaRegalias.crearTablas(db);
      },
    );
    auditoriaService = AuditoriaService(db);
    spgrService = SPGRService(db: db, auditoriaService: auditoriaService);
  });

  tearDown(() async {
    await db.close();
  });

  test('SPGRService crea Bienio SGR, proyecto OCAD vinculado a MGA y genera reporte SPGR', () async {
    final bienio = await spgrService.crearBienioSGR(
      entidadId: 'ENT-SPGR-TEST',
      usuarioId: 'USR-SPGR-01',
      codigoBienio: '2025-2026',
      fechaInicio: DateTime(2025, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      montoPresupuestado: 1000000000.0,
    );

    expect(bienio.id, isNotEmpty);
    expect(bienio.codigoBienio, equals('2025-2026'));

    final proy = await spgrService.crearProyectoOCAD(
      entidadId: 'ENT-SPGR-TEST',
      usuarioId: 'USR-SPGR-01',
      bienioId: bienio.id,
      codigoBPIN: 'BPIN-2025-0099',
      nombreProyecto: 'Construcción Vía Rural SGR',
      bienalidad: '2025-2026',
      tipoOCAD: TipoOCAD.municipal,
      montoAprobado: 300000000.0,
      fechaAprobacion: DateTime.now(),
    );

    expect(proy.id, isNotEmpty);
    expect(proy.bienioId, equals(bienio.id));
    expect(proy.montoGiroSPGR, equals(0.0));

    final proyGirado = await spgrService.registrarGiroSPGR(
      entidadId: 'ENT-SPGR-TEST',
      usuarioId: 'USR-SPGR-01',
      proyectoId: proy.id,
      montoGiro: 100000000.0,
    );

    expect(proyGirado.montoGiroSPGR, equals(100000000.0));

    final rep = await spgrService.generarReporteSPGR(
      entidadId: 'ENT-SPGR-TEST',
      usuarioId: 'USR-SPGR-01',
      bienalidad: '2025-2026',
    );

    expect(rep.id, isNotEmpty);

    final plano = await spgrService.exportarAPlano(rep.id);
    expect(plano, contains('SPGR_MHCP_HEADER|ENT-SPGR-TEST|2025-2026'));
  });
}
