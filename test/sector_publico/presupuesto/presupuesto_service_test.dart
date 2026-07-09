/// Pruebas unitarias del camino normativo duro - Fase 1: Presupuesto Público + PAC
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/sector_publico/presupuesto/services/presupuesto_service.dart';

void main() {
  late Database db;
  late PresupuestoService presupuestoService;
  
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // Crear tablas mínimas para pruebas
        await db.execute('''
          CREATE TABLE apropiaciones (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            codigo_rubro TEXT NOT NULL,
            nombre_rubro TEXT NOT NULL,
            valor_inicial REAL NOT NULL,
            saldo_disponible REAL NOT NULL,
            vigencia TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cdps (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_cdp TEXT NOT NULL UNIQUE,
            rubro_id TEXT NOT NULL,
            valor_cdp REAL NOT NULL,
            fecha_expedicion TEXT NOT NULL,
            fecha_vigencia TEXT NOT NULL,
            estado TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE rps (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_rp TEXT NOT NULL UNIQUE,
            cdp_id TEXT NOT NULL,
            valor_rp REAL NOT NULL,
            fecha_expedicion TEXT NOT NULL,
            estado TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE obligaciones (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_obligacion TEXT NOT NULL UNIQUE,
            rp_id TEXT NOT NULL,
            valor_obligacion REAL NOT NULL,
            fecha_obligacion TEXT NOT NULL,
            estado TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pagos (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_pago TEXT NOT NULL UNIQUE,
            obligacion_id TEXT NOT NULL,
            valor_pago REAL NOT NULL,
            fecha_pago TEXT NOT NULL,
            estado TEXT NOT NULL
          )
        ''');
      },
    );
    
    presupuestoService = PresupuestoService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Validaciones Normativas Duras - Fase 1', () {
    test('NO debe poder expedir CDP sin disponibilidad en rubro', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final rubroId = 'rubro-001';
      
      // Crear rubro con saldo 0
      await db.insert('apropiaciones', {
        'id': rubroId,
        'entidad_id': entidadId,
        'codigo_rubro': '110101',
        'nombre_rubro': 'Gastos de Personal',
        'valor_inicial': 0,
        'saldo_disponible': 0,
        'vigencia': '2024',
      });

      // Act & Assert
      expect(
        () => presupuestoService.expedirCDP(
          entidadId: entidadId,
          usuarioId: usuarioId,
          rubroId: rubroId,
          valorCDP: 1000000,
          fechaExpedicion: DateTime(2024, 1, 1),
          fechaVigencia: DateTime(2024, 12, 31),
        ),
        throwsException,
      );
    });

    test('NO debe poder expedir RP sin CDP previo', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final cdpId = 'cdp-inexistente';

      // Act & Assert
      expect(
        () => presupuestoService.expedirRP(
          entidadId: entidadId,
          usuarioId: usuarioId,
          cdpId: cdpId,
          valorRP: 1000000,
          fechaExpedicion: DateTime(2024, 1, 1),
        ),
        throwsException,
      );
    });

    test('NO debe poder expedir RP si CDP está vencido', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final rubroId = 'rubro-001';
      
      // Crear rubro con saldo
      await db.insert('apropiaciones', {
        'id': rubroId,
        'entidad_id': entidadId,
        'codigo_rubro': '110101',
        'nombre_rubro': 'Gastos de Personal',
        'valor_inicial': 10000000,
        'saldo_disponible': 10000000,
        'vigencia': '2024',
      });

      // Crear CDP vencido
      final cdpId = 'cdp-001';
      await db.insert('cdps', {
        'id': cdpId,
        'entidad_id': entidadId,
        'numero_cdp': 'CDP-2024-001',
        'rubro_id': rubroId,
        'valor_cdp': 1000000,
        'fecha_expedicion': DateTime(2023, 1, 1).toIso8601String(),
        'fecha_vigencia': DateTime(2023, 12, 31).toIso8601String(),
        'estado': 'expedido',
      });

      // Act & Assert
      expect(
        () => presupuestoService.expedirRP(
          entidadId: entidadId,
          usuarioId: usuarioId,
          cdpId: cdpId,
          valorRP: 1000000,
          fechaExpedicion: DateTime(2024, 1, 1),
        ),
        throwsException,
      );
    });

    test('NO debe poder expedir RP si valor excede saldo CDP', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final rubroId = 'rubro-001';
      
      // Crear rubro con saldo
      await db.insert('apropiaciones', {
        'id': rubroId,
        'entidad_id': entidadId,
        'codigo_rubro': '110101',
        'nombre_rubro': 'Gastos de Personal',
        'valor_inicial': 10000000,
        'saldo_disponible': 10000000,
        'vigencia': '2024',
      });

      // Crear CDP con valor menor
      final cdpId = 'cdp-001';
      await db.insert('cdps', {
        'id': cdpId,
        'entidad_id': entidadId,
        'numero_cdp': 'CDP-2024-001',
        'rubro_id': rubroId,
        'valor_cdp': 1000000,
        'fecha_expedicion': DateTime(2024, 1, 1).toIso8601String(),
        'fecha_vigencia': DateTime(2024, 12, 31).toIso8601String(),
        'estado': 'expedido',
      });

      // Act & Assert
      expect(
        () => presupuestoService.expedirRP(
          entidadId: entidadId,
          usuarioId: usuarioId,
          cdpId: cdpId,
          valorRP: 2000000, // Excede el valor del CDP
          fechaExpedicion: DateTime(2024, 1, 1),
        ),
        throwsException,
      );
    });

    test('NO debe poder crear obligación sin RP previo", () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final rpId = 'rp-inexistente';

      // Act & Assert
      expect(
        () => presupuestoService.crearObligacion(
          entidadId: entidadId,
          usuarioId: usuarioId,
          rpId: rpId,
          valorObligacion: 1000000,
          fechaObligacion: DateTime(2024, 1, 1),
        ),
        throwsException,
      );
    });

    test('NO debe poder crear pago sin obligación previa', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final obligacionId = 'obligacion-inexistente';

      // Act & Assert
      expect(
        () => presupuestoService.registrarPago(
          entidadId: entidadId,
          usuarioId: usuarioId,
          obligacionId: obligacionId,
          valorPago: 1000000,
          fechaPago: DateTime(2024, 1, 1),
        ),
        throwsException,
      );
    });
  });
}
