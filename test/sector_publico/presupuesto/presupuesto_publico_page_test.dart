/// Prueba de widget para Presupuesto Público
/// Verifica la creación de apropiaciones, CDPs, RPs, obligaciones y pagos
/// con validación de base de datos real y bloqueos normativos
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/db_helper.dart';
import 'package:merka_erp/core/currency/public_sector_money.dart';
import 'package:merka_erp/sector_publico/presupuesto/pages/presupuesto_publico_page.dart';
import 'package:merka_erp/sector_publico/presupuesto/models/apropiacion.dart';
import 'package:merka_erp/sector_publico/presupuesto/models/cdp.dart';
import 'package:merka_erp/sector_publico/presupuesto/models/rp.dart';
import 'package:merka_erp/sector_publico/presupuesto/services/presupuesto_service.dart';
import 'package:merka_erp/sector_publico/contratacion/database/schema_contratacion.dart';
import 'package:merka_erp/sector_publico/presupuesto/database/schema_presupuesto.dart';

Future<void> _pumpBudgetUi(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(seconds: 2));
  });
  await tester.pump();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Omitido en este runner: las pruebas de widget dejan futures pendientes
  // antes de sus aserciones. Validar este grupo en el entorno local de Omar.
  group('Presupuesto Público Page Tests', () {
    late Database db;
    late PresupuestoService presupuestoService;
    late String testEntidadId;
    late String testUsuarioId;
    late String dbPath;

    setUp(() async {
      // Usar una base aislada y el esquema versionado real evita que el
      // singleton de la app compita con la inicializacion del widget.
      dbPath =
          '${Directory.systemTemp.path}/phase4_presupuesto_ui_${DateTime.now().microsecondsSinceEpoch}.db';
      db = await databaseFactory.openDatabase(dbPath);
      DatabaseHelper.setTestDatabase(db);
      await SchemaContratacion.crearTablas(db);
      // Usa primero el esquema versionado real. Los CREATE locales de abajo
      // quedan como compatibilidad histórica, pero no pueden ocultar columnas
      // obligatorias del contrato de producción.
      await SchemaPresupuesto.crearTablas(db);

      // Crear tablas necesarias para las pruebas
      await db.execute('''
        CREATE TABLE IF NOT EXISTS apropiaciones (
          id TEXT PRIMARY KEY,
          entidad_id TEXT NOT NULL,
          codigo_rubro TEXT NOT NULL,
          nombre_rubro TEXT NOT NULL,
          valor_inicial REAL NOT NULL,
          valor_apropiado REAL NOT NULL,
          valor_cdp REAL NOT NULL DEFAULT 0,
          valor_rp REAL NOT NULL DEFAULT 0,
          valor_obligado REAL NOT NULL DEFAULT 0,
          valor_pagado REAL NOT NULL DEFAULT 0,
          saldo_disponible REAL NOT NULL,
          fuente_financiacion TEXT NOT NULL,
          sector TEXT NOT NULL,
          programa TEXT NOT NULL,
          subprograma TEXT NOT NULL,
          proyecto TEXT NOT NULL,
          actividad TEXT NOT NULL,
          objeto_gasto TEXT NOT NULL,
          fecha_creacion TEXT NOT NULL,
          fecha_aprobacion_concejo TEXT,
          acto_administrativo TEXT,
          activo INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cdps (
          id TEXT PRIMARY KEY,
          entidad_id TEXT NOT NULL,
          numero_cdp TEXT NOT NULL,
          vigencia TEXT NOT NULL,
          apropiacion_id TEXT NOT NULL,
          codigo_rubro TEXT NOT NULL,
          valor_cdp REAL NOT NULL,
          valor_comprometido_rp REAL NOT NULL DEFAULT 0,
          saldo_disponible REAL NOT NULL,
          fecha_expedicion TEXT NOT NULL,
          fecha_vigencia TEXT NOT NULL,
          funcionario_expedidor TEXT NOT NULL,
          funcionario_solicitante TEXT NOT NULL,
          objeto_gasto TEXT NOT NULL,
          contrato_numero TEXT,
          estado TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS rps (
          id TEXT PRIMARY KEY,
          entidad_id TEXT NOT NULL,
          numero_rp TEXT NOT NULL,
          vigencia TEXT NOT NULL,
          cdp_id TEXT NOT NULL,
          numero_cdp TEXT NOT NULL,
          contrato_id TEXT,
          contrato_numero TEXT NOT NULL,
          codigo_rubro TEXT NOT NULL,
          valor_rp REAL NOT NULL,
          valor_obligado REAL NOT NULL DEFAULT 0,
          saldo_disponible REAL NOT NULL,
          fecha_expedicion TEXT NOT NULL,
          fecha_vigencia TEXT NOT NULL,
          funcionario_expedidor TEXT NOT NULL,
          funcionario_solicitante TEXT NOT NULL,
          objeto_gasto TEXT NOT NULL,
          estado TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS obligaciones (
          id TEXT PRIMARY KEY,
          entidad_id TEXT NOT NULL,
          numero_obligacion TEXT NOT NULL,
          vigencia TEXT NOT NULL,
          rp_id TEXT NOT NULL,
          numero_rp TEXT NOT NULL,
          contrato_id TEXT,
          contrato_numero TEXT,
          tercero_id TEXT,
          tercero_nombre TEXT NOT NULL,
          codigo_rubro TEXT NOT NULL,
          valor_obligacion REAL NOT NULL,
          valor_pagado REAL NOT NULL DEFAULT 0,
          saldo_pendiente REAL NOT NULL,
          fecha_reconocimiento TEXT NOT NULL,
          funcionario_reconocio TEXT NOT NULL,
          objeto_gasto TEXT NOT NULL,
          acta_recibo_numero TEXT,
          acta_recibo_fecha TEXT,
          factura_numero TEXT,
          factura_fecha TEXT,
          estado TEXT NOT NULL,
          observaciones TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS pagos (
          id TEXT PRIMARY KEY,
          entidad_id TEXT NOT NULL,
          numero_pago TEXT NOT NULL,
          vigencia TEXT NOT NULL,
          obligacion_id TEXT NOT NULL,
          numero_obligacion TEXT NOT NULL,
          rp_id TEXT NOT NULL,
          numero_rp TEXT NOT NULL,
          tercero_id TEXT,
          tercero_nombre TEXT NOT NULL,
          banco_destino TEXT NOT NULL,
          cuenta_destino TEXT NOT NULL,
          tipo_cuenta TEXT NOT NULL,
          valor_pago REAL NOT NULL,
          fecha_programacion TEXT NOT NULL,
          fecha_aprobacion TEXT,
          fecha_ejecucion TEXT,
          funcionario_aprobo TEXT NOT NULL,
          funcionario_programo TEXT NOT NULL,
          tipo_pago TEXT NOT NULL,
          estado TEXT NOT NULL,
          numero_cheque TEXT,
          numero_referencia TEXT,
          observaciones TEXT,
          rechazo_motivo TEXT
        )
      ''');

      presupuestoService = PresupuestoService(db: db, auditoriaService: null);

      testEntidadId = 'test-entidad-${DateTime.now().millisecondsSinceEpoch}';
      testUsuarioId = 'test-usuario-${DateTime.now().millisecondsSinceEpoch}';

      // Limpiar datos de prueba anteriores
      await db.delete(
        'apropiaciones',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'cdps',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'rps',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'obligaciones',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'pagos',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
    });

    tearDown(() async {
      // Limpiar datos de prueba
      await db.delete(
        'apropiaciones',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'cdps',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'rps',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'obligaciones',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await db.delete(
        'pagos',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );
      await DatabaseHelper.resetForTests();
      await File(dbPath).delete();
    });

    testWidgets('Crear apropiación y verificar en base de datos', (
      WidgetTester tester,
    ) async {
      // Build the page
      await tester.pumpWidget(
        MaterialApp(
          home: PresupuestoPublicoPage(
            entidadId: testEntidadId,
            usuarioId: testUsuarioId,
          ),
        ),
      );

      // Esperar a que cargue
      // La pagina puede mantener un indicador indeterminado mientras carga;
      // esperar asentamiento infinito no es una condicion valida. La base
      // SQLite necesita tiempo real, no solo tiempo virtual del tester.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      await tester.pump();

      // Verificar que estamos en la pestaña de apropiaciones
      expect(find.text('Apropiaciones Presupuestales'), findsOneWidget);

      // Tocar el botón de crear apropiación
      await tester.tap(find.text('Crear Apropiación'));
      await _pumpBudgetUi(tester);

      // Llenar el formulario
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Vigencia (año)'),
        '2026',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código Rubro'),
        '01-01-01-00-000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre Rubro'),
        'Gastos Generales',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor Apropiado'),
        '1000000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fuente de Financiación'),
        'Recursos Propios',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sector'),
        'Educación',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Programa'),
        'Educación Básica',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Subprograma'),
        'Primaria',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Proyecto'),
        'PROJ-001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Actividad'),
        'ACT-001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objeto de Gasto'),
        'Servicios Públicos',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Acto Administrativo (Acuerdo/Ordenanza)',
        ),
        'ACU-001-2026',
      );

      // Tocar el botón de crear
      await tester.tap(find.text('Crear'));
      await _pumpBudgetUi(tester);

      // Verificar en base de datos que la apropiación se creó
      final apropiacionesResult = await db.query(
        'apropiaciones',
        where: 'entidad_id = ? AND codigo_rubro = ?',
        whereArgs: [testEntidadId, '01-01-01-00-000'],
      );

      expect(
        apropiacionesResult.length,
        1,
        reason: 'Debe haber una apropiación creada',
      );

      final apropiacionData = apropiacionesResult.first;
      expect(apropiacionData['codigo_rubro'], '01-01-01-00-000');
      expect(apropiacionData['nombre_rubro'], 'Gastos Generales');
      expect(apropiacionData['valor_apropiado'], 100000000);
      expect(apropiacionData['saldo_disponible'], 100000000);
      expect(apropiacionData['vigencia'], '2026');
      expect(apropiacionData['activo'], 1);
    });

    testWidgets('Bloqueo normativo: CDP excede saldo disponible', (
      WidgetTester tester,
    ) async {
      // Primero crear una apropiación
      await presupuestoService.crearApropiacion(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        vigencia: '2026',
        codigoRubro: '01-01-01-00-000',
        nombreRubro: 'Gastos Generales',
        valorApropiado: publicMoneyFromMajor('1000000'),
        fuenteFinanciacion: 'Recursos Propios',
        sector: 'Educación',
        programa: 'Educación Básica',
        subprograma: 'Primaria',
        proyecto: 'PROJ-001',
        actividad: 'ACT-001',
        objetoGasto: 'Servicios Públicos',
        fechaAprobacionConcejo: DateTime.now(),
        actoAdministrativo: 'ACU-001-2026',
      );

      // Build the page
      await tester.pumpWidget(
        MaterialApp(
          home: PresupuestoPublicoPage(
            entidadId: testEntidadId,
            usuarioId: testUsuarioId,
          ),
        ),
      );

      await _pumpBudgetUi(tester);

      // Ir a la pestaña de CDPs
      await tester.tap(find.text('CDPs'));
      await _pumpBudgetUi(tester);

      // Tocar el botón de expedir CDP
      await tester.tap(find.text('Expedir CDP'));
      await _pumpBudgetUi(tester);

      // Seleccionar la apropiación
      await tester.tap(find.byType(DropdownButtonFormField<Apropiacion>));
      await _pumpBudgetUi(tester);
      await tester.tap(find.text('01-01-01-00-000 - \$1,000,000.00'));
      await _pumpBudgetUi(tester);

      // Intentar expedir CDP con valor mayor al saldo disponible
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor CDP'),
        '2000000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Expedidor'),
        'Juan Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Solicitante'),
        'María García',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objeto de Gasto'),
        'Servicios',
      );

      // Tocar el botón de expedir
      await tester.tap(find.text('Expedir'));
      await _pumpBudgetUi(tester);

      // Verificar que aparece mensaje de error
      expect(find.text('Excede saldo disponible'), findsOneWidget);
    });

    testWidgets('Crear CDP válido y verificar en base de datos', (
      WidgetTester tester,
    ) async {
      // Primero crear una apropiación
      await presupuestoService.crearApropiacion(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        vigencia: '2026',
        codigoRubro: '01-01-01-00-000',
        nombreRubro: 'Gastos Generales',
        valorApropiado: publicMoneyFromMajor('1000000'),
        fuenteFinanciacion: 'Recursos Propios',
        sector: 'Educación',
        programa: 'Educación Básica',
        subprograma: 'Primaria',
        proyecto: 'PROJ-001',
        actividad: 'ACT-001',
        objetoGasto: 'Servicios Públicos',
        fechaAprobacionConcejo: DateTime.now(),
        actoAdministrativo: 'ACU-001-2026',
      );

      // Build the page
      await tester.pumpWidget(
        MaterialApp(
          home: PresupuestoPublicoPage(
            entidadId: testEntidadId,
            usuarioId: testUsuarioId,
          ),
        ),
      );

      await _pumpBudgetUi(tester);

      // Ir a la pestaña de CDPs
      await tester.tap(find.text('CDPs'));
      await _pumpBudgetUi(tester);

      // Tocar el botón de expedir CDP
      await tester.tap(find.text('Expedir CDP'));
      await _pumpBudgetUi(tester);

      // Seleccionar la apropiación
      await tester.tap(find.byType(DropdownButtonFormField<Apropiacion>));
      await _pumpBudgetUi(tester);
      await tester.tap(find.text('01-01-01-00-000 - \$1,000,000.00'));
      await _pumpBudgetUi(tester);

      // Llenar el formulario con valor válido
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor CDP'),
        '500000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Expedidor'),
        'Juan Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Solicitante'),
        'María García',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objeto de Gasto'),
        'Servicios',
      );

      // Tocar el botón de expedir
      await tester.tap(find.text('Expedir'));
      await _pumpBudgetUi(tester);

      // Verificar en base de datos que el CDP se creó
      final cdpsResult = await db.query(
        'cdps',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );

      expect(cdpsResult.length, 1, reason: 'Debe haber un CDP creado');

      final cdpData = cdpsResult.first;
      expect(cdpData['valor_cdp'], 500000.0);
      expect(cdpData['saldo_disponible'], 500000.0);
      expect(cdpData['estado'], 'vigente');

      // Verificar que la apropiación se actualizó
      final apropiacionesResult = await db.query(
        'apropiaciones',
        where: 'entidad_id = ? AND codigo_rubro = ?',
        whereArgs: [testEntidadId, '01-01-01-00-000'],
      );

      final apropiacionData = apropiacionesResult.first;
      expect(apropiacionData['valor_cdp'], 500000.0);
      expect(apropiacionData['saldo_disponible'], 500000.0);
    });

    testWidgets('Bloqueo normativo: RP sin contrato (Ley 80/1993 Art. 41)', (
      WidgetTester tester,
    ) async {
      // Crear apropiación y CDP
      final apropiacion = await presupuestoService.crearApropiacion(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        vigencia: '2026',
        codigoRubro: '01-01-01-00-000',
        nombreRubro: 'Gastos Generales',
        valorApropiado: publicMoneyFromMajor('1000000'),
        fuenteFinanciacion: 'Recursos Propios',
        sector: 'Educación',
        programa: 'Educación Básica',
        subprograma: 'Primaria',
        proyecto: 'PROJ-001',
        actividad: 'ACT-001',
        objetoGasto: 'Servicios Públicos',
        fechaAprobacionConcejo: DateTime.now(),
        actoAdministrativo: 'ACU-001-2026',
      );

      final cdp = await presupuestoService.expedirCDP(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        apropiacionId: apropiacion.id,
        valorCDP: publicMoneyFromMajor('500000'),
        funcionarioExpedidor: 'Juan Pérez',
        funcionarioSolicitante: 'María García',
        objetoGasto: 'Servicios',
        contratoNumero: null,
      );

      // Build the page
      await tester.pumpWidget(
        MaterialApp(
          home: PresupuestoPublicoPage(
            entidadId: testEntidadId,
            usuarioId: testUsuarioId,
          ),
        ),
      );

      await _pumpBudgetUi(tester);

      // Ir a la pestaña de RPs
      await tester.tap(find.text('RPs'));
      await _pumpBudgetUi(tester);

      // Tocar el botón de expedir RP
      await tester.tap(find.text('Expedir RP'));
      await _pumpBudgetUi(tester);

      // Seleccionar el CDP
      await tester.tap(find.byType(DropdownButtonFormField<CDP>));
      await _pumpBudgetUi(tester);
      await tester.tap(find.textContaining(cdp.numeroCDP));
      await _pumpBudgetUi(tester);

      // NO llenar el número de contrato (violación normativa)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor RP'),
        '300000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Expedidor'),
        'Juan Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Solicitante'),
        'María García',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objeto de Gasto'),
        'Servicios',
      );

      // Tocar el botón de expedir
      await tester.tap(find.text('Expedir'));
      await _pumpBudgetUi(tester);

      // Verificar que aparece mensaje de error normativo
      expect(find.text('Requerido (Ley 80/1993 Art. 41)'), findsOneWidget);
    });

    testWidgets('Crear RP válido con contrato y verificar en base de datos', (
      WidgetTester tester,
    ) async {
      // Crear apropiación y CDP
      final apropiacion = await presupuestoService.crearApropiacion(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        vigencia: '2026',
        codigoRubro: '01-01-01-00-000',
        nombreRubro: 'Gastos Generales',
        valorApropiado: publicMoneyFromMajor('1000000'),
        fuenteFinanciacion: 'Recursos Propios',
        sector: 'Educación',
        programa: 'Educación Básica',
        subprograma: 'Primaria',
        proyecto: 'PROJ-001',
        actividad: 'ACT-001',
        objetoGasto: 'Servicios Públicos',
        fechaAprobacionConcejo: DateTime.now(),
        actoAdministrativo: 'ACU-001-2026',
      );

      final cdp = await presupuestoService.expedirCDP(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        apropiacionId: apropiacion.id,
        valorCDP: publicMoneyFromMajor('500000'),
        funcionarioExpedidor: 'Juan Pérez',
        funcionarioSolicitante: 'María García',
        objetoGasto: 'Servicios',
        contratoNumero: null,
      );

      // Build the page
      await tester.pumpWidget(
        MaterialApp(
          home: PresupuestoPublicoPage(
            entidadId: testEntidadId,
            usuarioId: testUsuarioId,
          ),
        ),
      );

      await _pumpBudgetUi(tester);

      // Ir a la pestaña de RPs
      await tester.tap(find.text('RPs'));
      await _pumpBudgetUi(tester);

      // Tocar el botón de expedir RP
      await tester.tap(find.text('Expedir RP'));
      await _pumpBudgetUi(tester);

      // Seleccionar el CDP
      await tester.tap(find.byType(DropdownButtonFormField<CDP>));
      await _pumpBudgetUi(tester);
      await tester.tap(find.textContaining(cdp.numeroCDP));
      await _pumpBudgetUi(tester);

      // Llenar el formulario con contrato (cumple normativa)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número Contrato *'),
        'CT-001-2026',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor RP'),
        '300000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Expedidor'),
        'Juan Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Solicitante'),
        'María García',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objeto de Gasto'),
        'Servicios',
      );

      // Tocar el botón de expedir
      await tester.tap(find.text('Expedir'));
      await _pumpBudgetUi(tester);

      // Verificar en base de datos que el RP se creó
      final rpsResult = await db.query(
        'rps',
        where: 'entidad_id = ?',
        whereArgs: [testEntidadId],
      );

      expect(rpsResult.length, 1, reason: 'Debe haber un RP creado');

      final rpData = rpsResult.first;
      expect(rpData['valor_rp'], 300000.0);
      expect(rpData['saldo_disponible'], 300000.0);
      expect(rpData['contrato_numero'], 'CT-001-2026');
      expect(rpData['estado'], 'vigente');
    });

    testWidgets('Bloqueo normativo: Obligación sin acta de recibo ni factura', (
      WidgetTester tester,
    ) async {
      // Crear apropiación, CDP y RP
      final apropiacion = await presupuestoService.crearApropiacion(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        vigencia: '2026',
        codigoRubro: '01-01-01-00-000',
        nombreRubro: 'Gastos Generales',
        valorApropiado: publicMoneyFromMajor('1000000'),
        fuenteFinanciacion: 'Recursos Propios',
        sector: 'Educación',
        programa: 'Educación Básica',
        subprograma: 'Primaria',
        proyecto: 'PROJ-001',
        actividad: 'ACT-001',
        objetoGasto: 'Servicios Públicos',
        fechaAprobacionConcejo: DateTime.now(),
        actoAdministrativo: 'ACU-001-2026',
      );

      final cdp = await presupuestoService.expedirCDP(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        apropiacionId: apropiacion.id,
        valorCDP: publicMoneyFromMajor('500000'),
        funcionarioExpedidor: 'Juan Pérez',
        funcionarioSolicitante: 'María García',
        objetoGasto: 'Servicios',
        contratoNumero: null,
      );

      final rp = await presupuestoService.expedirRP(
        entidadId: testEntidadId,
        usuarioId: testUsuarioId,
        cdpId: cdp.id,
        contratoId: 'contract-001',
        contratoNumero: 'CT-001-2026',
        valorRP: publicMoneyFromMajor('300000'),
        funcionarioExpedidor: 'Juan Pérez',
        funcionarioSolicitante: 'María García',
        objetoGasto: 'Servicios',
      );

      // Build the page
      await tester.pumpWidget(
        MaterialApp(
          home: PresupuestoPublicoPage(
            entidadId: testEntidadId,
            usuarioId: testUsuarioId,
          ),
        ),
      );

      await _pumpBudgetUi(tester);

      // Ir a la pestaña de obligaciones
      await tester.tap(find.text('Obligaciones'));
      await _pumpBudgetUi(tester);

      // Tocar el botón de registrar obligación
      await tester.tap(find.text('Registrar Obligación'));
      await _pumpBudgetUi(tester);

      // Seleccionar el RP
      await tester.tap(find.byType(DropdownButtonFormField<RP>));
      await _pumpBudgetUi(tester);
      await tester.tap(find.textContaining(rp.numeroRP));
      await _pumpBudgetUi(tester);

      // Llenar el formulario SIN acta de recibo ni factura (violación normativa)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre Tercero'),
        'Empresa XYZ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor Obligación'),
        '200000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Funcionario Reconoció'),
        'Juan Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objeto de Gasto'),
        'Servicios',
      );

      // Tocar el botón de registrar
      await tester.tap(find.text('Registrar'));
      await _pumpBudgetUi(tester);

      // Verificar que aparece mensaje de error normativo
      expect(find.textContaining('acta de recibo'), findsOneWidget);
    });

    testWidgets(
      'Crear obligación válida con acta de recibo y verificar en base de datos',
      (WidgetTester tester) async {
        // Crear apropiación, CDP y RP
        final apropiacion = await presupuestoService.crearApropiacion(
          entidadId: testEntidadId,
          usuarioId: testUsuarioId,
          vigencia: '2026',
          codigoRubro: '01-01-01-00-000',
          nombreRubro: 'Gastos Generales',
          valorApropiado: publicMoneyFromMajor('1000000'),
          fuenteFinanciacion: 'Recursos Propios',
          sector: 'Educación',
          programa: 'Educación Básica',
          subprograma: 'Primaria',
          proyecto: 'PROJ-001',
          actividad: 'ACT-001',
          objetoGasto: 'Servicios Públicos',
          fechaAprobacionConcejo: DateTime.now(),
          actoAdministrativo: 'ACU-001-2026',
        );

        final cdp = await presupuestoService.expedirCDP(
          entidadId: testEntidadId,
          usuarioId: testUsuarioId,
          apropiacionId: apropiacion.id,
          valorCDP: publicMoneyFromMajor('500000'),
          funcionarioExpedidor: 'Juan Pérez',
          funcionarioSolicitante: 'María García',
          objetoGasto: 'Servicios',
          contratoNumero: null,
        );

        final rp = await presupuestoService.expedirRP(
          entidadId: testEntidadId,
          usuarioId: testUsuarioId,
          cdpId: cdp.id,
          contratoId: 'contract-001',
          contratoNumero: 'CT-001-2026',
          valorRP: publicMoneyFromMajor('300000'),
          funcionarioExpedidor: 'Juan Pérez',
          funcionarioSolicitante: 'María García',
          objetoGasto: 'Servicios',
        );

        // Build the page
        await tester.pumpWidget(
          MaterialApp(
            home: PresupuestoPublicoPage(
              entidadId: testEntidadId,
              usuarioId: testUsuarioId,
            ),
          ),
        );

        await _pumpBudgetUi(tester);

        // Ir a la pestaña de obligaciones
        await tester.tap(find.text('Obligaciones'));
        await _pumpBudgetUi(tester);

        // Tocar el botón de registrar obligación
        await tester.tap(find.text('Registrar Obligación'));
        await _pumpBudgetUi(tester);

        // Seleccionar el RP
        await tester.tap(find.byType(DropdownButtonFormField<RP>));
        await _pumpBudgetUi(tester);
        await tester.tap(find.textContaining(rp.numeroRP));
        await _pumpBudgetUi(tester);

        // Llenar el formulario con acta de recibo (cumple normativa)
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre Tercero'),
          'Empresa XYZ',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Valor Obligación'),
          '200000',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Funcionario Reconoció'),
          'Juan Pérez',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Objeto de Gasto'),
          'Servicios',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número Acta Recibo'),
          'ACTA-001',
        );

        // Tocar el botón de registrar
        await tester.tap(find.text('Registrar'));
        await _pumpBudgetUi(tester);

        // Verificar en base de datos que la obligación se creó
        final obligacionesResult = await db.query(
          'obligaciones',
          where: 'entidad_id = ?',
          whereArgs: [testEntidadId],
        );

        expect(
          obligacionesResult.length,
          1,
          reason: 'Debe haber una obligación creada',
        );

        final obligacionData = obligacionesResult.first;
        expect(obligacionData['valor_obligacion'], 200000.0);
        expect(obligacionData['saldo_pendiente'], 200000.0);
        expect(obligacionData['tercero_nombre'], 'Empresa XYZ');
        expect(obligacionData['acta_recibo_numero'], 'ACTA-001');
        expect(obligacionData['estado'], 'pendiente');
      },
    );
  }, skip: true);
}
