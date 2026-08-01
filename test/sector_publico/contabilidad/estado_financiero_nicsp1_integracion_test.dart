import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/sector_publico/contabilidad/database/schema_contabilidad.dart';
import 'package:merka_erp/sector_publico/contabilidad/services/cierre_vigencia_service.dart';
import 'package:merka_erp/sector_publico/contabilidad/services/contabilidad_nicsp_service.dart';
import 'package:merka_erp/sector_publico/security/auditoria_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _entidadId = 'ENT-NICSP1-001';
const _vigencia = '2026';

late Database db;
late CierreVigenciaService cierreService;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SchemaContabilidad.crearTablas(db);
    final auditoria = AuditoriaService(db);
    cierreService = CierreVigenciaService(
      db: db,
      contabilidadService: ContabilidadNICSPService(
        db: db,
        auditoriaService: auditoria,
      ),
      auditoriaService: auditoria,
    );
  });

  tearDown(() async => db.close());

  test(
    'NICSP 1 presenta creditos positivos e integra resultado al patrimonio',
    () async {
      await _insertarSaldo('1110', 'Efectivo', deudor: 1000, acreedor: 0);
      await _insertarSaldo(
        '2401',
        'Cuentas por pagar',
        deudor: 0,
        acreedor: 400,
      );
      await _insertarSaldo('3105', 'Capital fiscal', deudor: 0, acreedor: 300);
      await _insertarSaldo(
        '4111',
        'Ingresos tributarios',
        deudor: 0,
        acreedor: 500,
      );
      await _insertarSaldo(
        '5111',
        'Gastos generales',
        deudor: 200,
        acreedor: 0,
      );

      final situacion = await cierreService.generarEstadoSituacionFinanciera(
        entidadId: _entidadId,
        vigencia: _vigencia,
        fechaCorte: DateTime(2026, 12, 31),
      );
      final resultado = await cierreService.generarEstadoResultado(
        entidadId: _entidadId,
        vigencia: _vigencia,
        fechaInicio: DateTime(2026, 1, 1),
        fechaFin: DateTime(2026, 12, 31),
      );

      expect(situacion.totalActivo, 1000.0);
      expect(situacion.totalPasivo, 400.0);
      expect(situacion.totalPatrimonio, 600.0);
      expect(situacion.totalPasivoPatrimonio, 1000.0);
      expect(situacion.estaCuadrado(), isTrue);
      expect(resultado.totalIngresos, 500.0);
      expect(resultado.totalGastos, 200.0);
      expect(resultado.resultadoOperacional, 300.0);
      expect(
        situacion.patrimonio
            .where((r) => r.codigoCuenta == 'RESULTADO-PERIODO')
            .single
            .valor,
        300.0,
      );
    },
  );
}

Future<void> _insertarSaldo(
  String codigo,
  String nombre, {
  required double deudor,
  required double acreedor,
}) {
  return db.insert('saldos_cuentas', {
    'id': 'SALDO-$codigo',
    'entidad_id': _entidadId,
    'cuenta_codigo': codigo,
    'cuenta_nombre': nombre,
    'saldo_deudor': deudor,
    'saldo_acreedor': acreedor,
    'saldo_neto': deudor - acreedor,
    'fecha_ultimo_movimiento': DateTime(2026, 12, 31).toIso8601String(),
    'vigencia': _vigencia,
  });
}
