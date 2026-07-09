/// Pruebas unitarias del camino normativo duro - Fase 5: Contratación Pública + SECOP II
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:merka_erp/sector_publico/contratacion/services/contratacion_service.dart';

void main() {
  late Database db;
  late ContratacionService contratacionService;
  
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
          CREATE TABLE procesos_contratacion (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_proceso TEXT NOT NULL UNIQUE,
            modalidad TEXT NOT NULL,
            estado TEXT NOT NULL,
            publicado_secop INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE contratos (
            id TEXT PRIMARY KEY,
            entidad_id TEXT NOT NULL,
            numero_contrato TEXT NOT NULL UNIQUE,
            proceso_id TEXT NOT NULL,
            cdp_id TEXT,
            rp_id TEXT,
            estado TEXT NOT NULL
          )
        ''');
      },
    );
    
    contratacionService = ContratacionService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Validaciones Normativas Duras - Fase 5', () {
    test('NO debe poder crear contrato sin CDP', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final procesoId = 'proceso-001';
      
      // Crear proceso
      await db.insert('procesos_contratacion', {
        'id': procesoId,
        'entidad_id': entidadId,
        'numero_proceso': 'PROC-2024-001',
        'modalidad': 'licitacion_publica',
        'estado': 'adjudicado',
        'publicado_secop': 1,
      });

      // Act & Assert
      expect(
        () => contratacionService.crearContrato(
          entidadId: entidadId,
          usuarioId: usuarioId,
          procesoId: procesoId,
          numeroContrato: 'CT-2024-001',
          valorContrato: 100000000,
          fechaFirma: DateTime(2024, 1, 1),
          cdpId: null, // Sin CDP
          rpId: 'rp-001',
        ),
        throwsException,
      );
    });

    test('NO debe poder crear contrato sin RP', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final procesoId = 'proceso-001';
      final cdpId = 'cdp-001';
      
      // Crear proceso
      await db.insert('procesos_contratacion', {
        'id': procesoId,
        'entidad_id': entidadId,
        'numero_proceso': 'PROC-2024-001',
        'modalidad': 'licitacion_publica',
        'estado': 'adjudicado',
        'publicado_secop': 1,
      });

      // Act & Assert
      expect(
        () => contratacionService.crearContrato(
          entidadId: entidadId,
          usuarioId: usuarioId,
          procesoId: procesoId,
          numeroContrato: 'CT-2024-001',
          valorContrato: 100000000,
          fechaFirma: DateTime(2024, 1, 1),
          cdpId: cdpId,
          rpId: null, // Sin RP
        ),
        throwsException,
      );
    });

    test('NO debe poder crear contrato si proceso no está publicado en SECOP', () async {
      // Arrange
      final entidadId = 'test-entidad';
      final usuarioId = 'test-usuario';
      final procesoId = 'proceso-001';
      
      // Crear proceso NO publicado en SECOP
      await db.insert('procesos_contratacion', {
        'id': procesoId,
        'entidad_id': entidadId,
        'numero_proceso': 'PROC-2024-001',
        'modalidad': 'licitacion_publica',
        'estado': 'adjudicado',
        'publicado_secop': 0, // No publicado
      });

      // Act & Assert
      expect(
        () => contratacionService.crearContrato(
          entidadId: entidadId,
          usuarioId: usuarioId,
          procesoId: procesoId,
          numeroContrato: 'CT-2024-001',
          valorContrato: 100000000,
          fechaFirma: DateTime(2024, 1, 1),
          cdpId: 'cdp-001',
          rpId: 'rp-001',
        ),
        throwsException,
      );
    });
  });
}
