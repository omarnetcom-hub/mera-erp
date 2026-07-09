/// Pruebas unitarias del camino normativo duro - Fase 6: Nómina Pública + PILA + Retroactivos
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/sector_publico/nomina/models/liquidacion_nomina.dart';
import 'package:merka_erp/sector_publico/nomina/services/nomina_service.dart';
import 'package:merka_erp/sector_publico/security/auditoria_service.dart';

void main() {
  late Database db;
  late AuditoriaService auditoriaService;
  late NominaService nominaService;

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
          CREATE TABLE empleados (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_identificacion TEXT NOT NULL,
            nombre_completo TEXT NOT NULL,
            cargo TEXT NOT NULL,
            dependencia TEXT NOT NULL,
            tipo_contrato TEXT NOT NULL,
            tipo_vinculacion TEXT NOT NULL,
            salario_basico REAL NOT NULL,
            fecha_ingreso TEXT NOT NULL,
            fecha_retiro TEXT,
            activo INTEGER NOT NULL,
            cuenta_bancaria TEXT,
            tipo_cuenta TEXT,
            banco TEXT,
            eps TEXT,
            fondo_pension TEXT,
            fondo_cesantias TEXT,
            observaciones TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE liquidaciones_nomina (
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
            auxilio_transporte REAL NOT NULL,
            auxilio_alimentacion REAL NOT NULL,
            horas_extra REAL NOT NULL,
            recargo_nocturno REAL NOT NULL,
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
            observaciones TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE auditoria_registros (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            usuario_id TEXT NOT NULL,
            usuario_nombre TEXT,
            ip_direccion TEXT,
            fecha_hora TEXT NOT NULL,
            tipo_evento TEXT NOT NULL,
            modulo TEXT NOT NULL,
            accion TEXT NOT NULL,
            valor_anterior TEXT NOT NULL,
            valor_nuevo TEXT NOT NULL,
            hash_anterior TEXT,
            hash_actual TEXT NOT NULL,
            referencia_id TEXT,
            observaciones TEXT
          )
        ''');
      },
    );

    auditoriaService = AuditoriaService(db);
    nominaService = NominaService(db: db, auditoriaService: auditoriaService);

    await db.insert('empleados', {
      'id': 'empleado-001',
      'entidad_id': 'entidad-001',
      'numero_identificacion': '1234567890',
      'nombre_completo': 'Empleado Test',
      'cargo': 'Analista',
      'dependencia': 'Finanzas',
      'tipo_contrato': 'indefinido',
      'tipo_vinculacion': 'carrera',
      'salario_basico': 2000000,
      'fecha_ingreso': DateTime(2024, 1, 1).toIso8601String(),
      'fecha_retiro': null,
      'activo': 1,
      'cuenta_bancaria': '123456789',
      'tipo_cuenta': 'Ahorros',
      'banco': 'Banco Prueba',
      'eps': 'EPS Test',
      'fondo_pension': 'PENSION Test',
      'fondo_cesantias': 'CESANTIAS Test',
      'observaciones': 'Empleado para prueba',
    });

    await db.insert('empleados', {
      'id': 'empleado-002',
      'entidad_id': 'entidad-001',
      'numero_identificacion': '2345678901',
      'nombre_completo': 'Empleado Solidaridad 1%',
      'cargo': 'Analista',
      'dependencia': 'Finanzas',
      'tipo_contrato': 'indefinido',
      'tipo_vinculacion': 'carrera',
      'salario_basico': 4542630,
      'fecha_ingreso': DateTime(2024, 1, 1).toIso8601String(),
      'fecha_retiro': null,
      'activo': 1,
      'cuenta_bancaria': '123456780',
      'tipo_cuenta': 'Ahorros',
      'banco': 'Banco Prueba',
      'eps': 'EPS Test',
      'fondo_pension': 'PENSION Test',
      'fondo_cesantias': 'CESANTIAS Test',
      'observaciones': 'Empleado para prueba 1% fondo solidaridad',
    });

    await db.insert('empleados', {
      'id': 'empleado-003',
      'entidad_id': 'entidad-001',
      'numero_identificacion': '3456789012',
      'nombre_completo': 'Empleado Solidaridad 2%',
      'cargo': 'Analista',
      'dependencia': 'Finanzas',
      'tipo_contrato': 'indefinido',
      'tipo_vinculacion': 'carrera',
      'salario_basico': 16353468,
      'fecha_ingreso': DateTime(2024, 1, 1).toIso8601String(),
      'fecha_retiro': null,
      'activo': 1,
      'cuenta_bancaria': '123456781',
      'tipo_cuenta': 'Ahorros',
      'banco': 'Banco Prueba',
      'eps': 'EPS Test',
      'fondo_pension': 'PENSION Test',
      'fondo_cesantias': 'CESANTIAS Test',
      'observaciones': 'Empleado para prueba 2% fondo solidaridad',
    });

    await db.insert('empleados', {
      'id': 'empleado-004',
      'entidad_id': 'entidad-001',
      'numero_identificacion': '4567890123',
      'nombre_completo': 'Empleado Auxilio Transporte',
      'cargo': 'Analista',
      'dependencia': 'Finanzas',
      'tipo_contrato': 'indefinido',
      'tipo_vinculacion': 'carrera',
      'salario_basico': 1817052,
      'fecha_ingreso': DateTime(2024, 1, 1).toIso8601String(),
      'fecha_retiro': null,
      'activo': 1,
      'cuenta_bancaria': '123456782',
      'tipo_cuenta': 'Ahorros',
      'banco': 'Banco Prueba',
      'eps': 'EPS Test',
      'fondo_pension': 'PENSION Test',
      'fondo_cesantias': 'CESANTIAS Test',
      'observaciones': 'Empleado para prueba auxilio transporte',
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Validaciones Normativas Duras - Fase 6', () {
    test('Debe liquidar nómina completa y calcular aportes parafiscales', () async {
      final liquidacion = await nominaService.liquidarNomina(
        entidadId: 'entidad-001',
        usuarioId: 'usuario-prueba',
        empleadoId: 'empleado-001',
        periodo: '2026-07',
        diasTrabajados: 30,
      );

      expect(liquidacion.salud, closeTo(2000000 * 0.085, 0.01));
      expect(liquidacion.pension, closeTo(2000000 * 0.12, 0.01));
      expect(liquidacion.fondoSolidaridad, equals(0));
      expect(liquidacion.riesgosLaborales, closeTo(2000000 * 0.00522, 0.01));
      expect(liquidacion.cajaCompensacion, closeTo(2000000 * 0.04, 0.01));
      expect(liquidacion.sena, closeTo(2000000 * 0.02, 0.01));
      expect(liquidacion.icbf, closeTo(2000000 * 0.03, 0.01));
      expect(liquidacion.auxilioTransporte, equals(0));
      expect(liquidacion.estado, equals(EstadoLiquidacion.generada));

      final registros = await db.query('liquidaciones_nomina');
      expect(registros, hasLength(1));
    });

   test('Debe aplicar fondo de solidaridad 1% para salario entre 4 y 16 SMMLV', () async {
     final salarioBase = 4542630.0;
     final liquidacion = await nominaService.liquidarNomina(
       entidadId: 'entidad-001',
       usuarioId: 'usuario-prueba',
       empleadoId: 'empleado-002',
       periodo: '2026-07',
       diasTrabajados: 30,
     );

     expect(liquidacion.salud, closeTo(salarioBase * 0.085, 0.01));
     expect(liquidacion.pension, closeTo(salarioBase * 0.12, 0.01));
     expect(liquidacion.fondoSolidaridad, closeTo(salarioBase * 0.01, 0.01));
     expect(liquidacion.auxilioTransporte, equals(0));
   });

   test('Debe aplicar fondo de solidaridad 2% para salario very alto', () async {
     final salarioBase = 16353468.0;
     final liquidacion = await nominaService.liquidarNomina(
       entidadId: 'entidad-001',
       usuarioId: 'usuario-prueba',
       empleadoId: 'empleado-003',
       periodo: '2026-07',
       diasTrabajados: 30,
     );

     expect(liquidacion.fondoSolidaridad, closeTo(salarioBase * 0.02, 0.01));
     expect(liquidacion.auxilioTransporte, equals(0));
   });

   test('Debe pagar auxilio de transporte para salario menor o igual a 2 SMMLV', () async {
     final liquidacion = await nominaService.liquidarNomina(
       entidadId: 'entidad-001',
       usuarioId: 'usuario-prueba',
       empleadoId: 'empleado-004',
       periodo: '2026-07',
       diasTrabajados: 30,
     );

     expect(liquidacion.auxilioTransporte, equals(162000));
     expect(liquidacion.fondoSolidaridad, equals(0));
   });
 });
}
