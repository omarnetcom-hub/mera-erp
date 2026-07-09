/// Servicio de Validación de Distribución de Regalías
/// Ley 1530/2012 y normas del SGR
/// Validación de la distribución de regalías y compensaciones
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/auditoria_service.dart';

enum TipoFondo {
  ahorro,
  pension,
  compensacionRegional,
  desarrolloRegional,
  reactivacionEconomica,
  cienciaTecnologia,
}

class ValidacionDistribucionService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  // Porcentajes de distribución según Ley 1530/2012
  static const Map<TipoFondo, double> _porcentajesDistribucion = {
    TipoFondo.ahorro: 0.20, // 20% Fondo de Ahorro
    TipoFondo.pension: 0.20, // 20% Fondo de Pensiones
    TipoFondo.compensacionRegional: 0.20, // 20% Compensación Regional
    TipoFondo.desarrolloRegional: 0.20, // 20% Desarrollo Regional
    TipoFondo.reactivacionEconomica: 0.10, // 10% Reactivación Económica
    TipoFondo.cienciaTecnologia: 0.10, // 10% Ciencia y Tecnología
  };

  ValidacionDistribucionService({
    required this.db,
    required this.auditoriaService,
  });

  /// Valida la distribución de regalías de un periodo
  Future<Map<String, dynamic>> validarDistribucion({
    required String entidadId,
    required String usuarioId,
    required String periodo, // Formato: '2024-01'
    required double totalRegalias,
    required Map<TipoFondo, double> distribucion,
  }) async {
    final id = _uuid.v4();

    // Validar que la suma de distribuciones sea 100%
    final sumaDistribucion = distribucion.values.fold<double>(0, (sum, v) => sum + v);
    if ((sumaDistribucion - 1.0).abs() > 0.01) {
      throw Exception('La distribución debe sumar 100% (actual: ${(sumaDistribucion * 100).toStringAsFixed(2)}%)');
    }

    // Calcular montos por fondo
    final montosPorFondo = <TipoFondo, double>{};
    final diferencias = <TipoFondo, double>{};
    bool esValida = true;

    for (final fondo in TipoFondo.values) {
      final porcentajeEsperado = _porcentajesDistribucion[fondo]!;
      final porcentajeAsignado = distribucion[fondo] ?? 0;
      final montoEsperado = totalRegalias * porcentajeEsperado;
      final montoAsignado = totalRegalias * porcentajeAsignado;
      final diferencia = (montoAsignado - montoEsperado).abs();

      montosPorFondo[fondo] = montoAsignado;
      diferencias[fondo] = diferencia;

      // Validar tolerancia del 1%
      if (diferencia > totalRegalias * 0.01) {
        esValida = false;
      }
    }

    await db.insert('validaciones_distribucion_regalias', {
      'id': id,
      'entidad_id': entidadId,
      'periodo': periodo,
      'total_regalias': totalRegalias,
      'distribucion_ahorro': montosPorFondo[TipoFondo.ahorro],
      'distribucion_pension': montosPorFondo[TipoFondo.pension],
      'distribucion_compensacion': montosPorFondo[TipoFondo.compensacionRegional],
      'distribucion_desarrollo': montosPorFondo[TipoFondo.desarrolloRegional],
      'distribucion_reactivacion': montosPorFondo[TipoFondo.reactivacionEconomica],
      'distribucion_ciencia': montosPorFondo[TipoFondo.cienciaTecnologia],
      'es_valida': esValida ? 1 : 0,
      'fecha_validacion': DateTime.now().toIso8601String(),
      'validado_por': usuarioId,
      'observaciones': esValida ? 'Distribución válida según Ley 1530/2012' : 'Distribución presenta diferencias significativas',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'regalias',
      accion: 'validacion_distribucion_regalias',
      valorAnterior: {},
      valorNuevo: {
        'validacion_id': id,
        'periodo': periodo,
        'total_regalias': totalRegalias,
        'es_valida': esValida,
      },
      referenciaId: id,
    );

    return {
      'validacion_id': id,
      'periodo': periodo,
      'total_regalias': totalRegalias,
      'montos_por_fondo': montosPorFondo,
      'diferencias': diferencias,
      'es_valida': esValida,
      'observaciones': esValida ? 'Distribución válida según Ley 1530/2012' : 'Distribución presenta diferencias significativas',
    };
  }

  /// Consulta validaciones de distribución por entidad
  Future<List<Map<String, dynamic>>> consultarValidaciones({
    required String entidadId,
    String? periodo,
    bool? soloInvalidas,
  }) async {
    String query = 'SELECT * FROM validaciones_distribucion_regalias WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodo != null) {
      query += ' AND periodo = ?';
      args.add(periodo);
    }

    if (soloInvalidas != null && soloInvalidas) {
      query += ' AND es_valida = ?';
      args.add(0);
    }

    query += ' ORDER BY fecha_validacion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Genera reporte de validaciones de distribución
  Future<Map<String, dynamic>> generarReporteValidaciones({
    required String entidadId,
    String? periodoInicio,
    String? periodoFin,
  }) async {
    String query = 'SELECT * FROM validaciones_distribucion_regalias WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodoInicio != null) {
      query += ' AND periodo >= ?';
      args.add(periodoInicio);
    }

    if (periodoFin != null) {
      query += ' AND periodo <= ?';
      args.add(periodoFin);
    }

    final validaciones = await db.rawQuery(query, args);

    int totalValidaciones = validaciones.length;
    int validas = validaciones.where((v) => v['es_valida'] == 1).length;
    int invalidas = validaciones.where((v) => v['es_valida'] == 0).length;

    double totalRegalias = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['total_regalias'] as num).toDouble(),
    );

    // Total por fondo
    double totalAhorro = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['distribucion_ahorro'] as num).toDouble(),
    );
    double totalPension = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['distribucion_pension'] as num).toDouble(),
    );
    double totalCompensacion = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['distribucion_compensacion'] as num).toDouble(),
    );
    double totalDesarrollo = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['distribucion_desarrollo'] as num).toDouble(),
    );
    double totalReactivacion = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['distribucion_reactivacion'] as num).toDouble(),
    );
    double totalCiencia = validaciones.fold<double>(
      0,
      (sum, r) => sum + (r['distribucion_ciencia'] as num).toDouble(),
    );

    return {
      'total_validaciones': totalValidaciones,
      'validas': validas,
      'invalidas': invalidas,
      'porcentaje_validas': totalValidaciones > 0 ? (validas / totalValidaciones) * 100 : 0,
      'total_regalias': totalRegalias,
      'total_por_fondo': {
        'ahorro': totalAhorro,
        'pension': totalPension,
        'compensacion': totalCompensacion,
        'desarrollo': totalDesarrollo,
        'reactivacion': totalReactivacion,
        'ciencia': totalCiencia,
      },
      'detalles': validaciones,
    };
  }

  /// Valida la distribución SGP (Sistema General de Participaciones)
  Future<Map<String, dynamic>> validarDistribucionSGP({
    required String entidadId,
    required String usuarioId,
    required String periodo,
    required double totalSGP,
    required double porcentajeSalud, // Debe ser 85% para municipios
    required double porcentajeEducacion, // Debe ser 15% para municipios
    required double porcentajeAguaPotable, // Variable
  }) async {
    final id = _uuid.v4();

    // Validar porcentajes según tipo de entidad
    final entidad = await db.query(
      'entidades_territoriales',
      where: 'id = ?',
      whereArgs: [entidadId],
    );

    if (entidad.isEmpty) {
      throw Exception('Entidad no encontrada');
    }

    final tipoEntidad = entidad.first['tipo'];
    bool esValida = true;
    final observaciones = <String>[];

    // Para municipios: 85% salud, 15% educación
    if (tipoEntidad == 'municipio') {
      if ((porcentajeSalud - 0.85).abs() > 0.01) {
        esValida = false;
        observaciones.add('Porcentaje salud debe ser 85% (actual: ${(porcentajeSalud * 100).toStringAsFixed(2)}%)');
      }
      if ((porcentajeEducacion - 0.15).abs() > 0.01) {
        esValida = false;
        observaciones.add('Porcentaje educación debe ser 15% (actual: ${(porcentajeEducacion * 100).toStringAsFixed(2)}%)');
      }
    }

    // Validar que la suma sea 100%
    final sumaPorcentajes = porcentajeSalud + porcentajeEducacion + porcentajeAguaPotable;
    if ((sumaPorcentajes - 1.0).abs() > 0.01) {
      esValida = false;
      observaciones.add('La suma de porcentajes debe ser 100% (actual: ${(sumaPorcentajes * 100).toStringAsFixed(2)}%)');
    }

    await db.insert('validaciones_distribucion_sgp', {
      'id': id,
      'entidad_id': entidadId,
      'periodo': periodo,
      'total_sgp': totalSGP,
      'porcentaje_salud': porcentajeSalud,
      'monto_salud': totalSGP * porcentajeSalud,
      'porcentaje_educacion': porcentajeEducacion,
      'monto_educacion': totalSGP * porcentajeEducacion,
      'porcentaje_agua': porcentajeAguaPotable,
      'monto_agua': totalSGP * porcentajeAguaPotable,
      'es_valida': esValida ? 1 : 0,
      'fecha_validacion': DateTime.now().toIso8601String(),
      'validado_por': usuarioId,
      'observaciones': observaciones.join('\n'),
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'regalias',
      accion: 'validacion_distribucion_sgp',
      valorAnterior: {},
      valorNuevo: {
        'validacion_id': id,
        'periodo': periodo,
        'total_sgp': totalSGP,
        'es_valida': esValida,
      },
      referenciaId: id,
    );

    return {
      'validacion_id': id,
      'periodo': periodo,
      'total_sgp': totalSGP,
      'monto_salud': totalSGP * porcentajeSalud,
      'monto_educacion': totalSGP * porcentajeEducacion,
      'monto_agua': totalSGP * porcentajeAguaPotable,
      'es_valida': esValida,
      'observaciones': observaciones,
    };
  }

  /// Consulta validaciones SGP
  Future<List<Map<String, dynamic>>> consultarValidacionesSGP({
    required String entidadId,
    String? periodo,
  }) async {
    String query = 'SELECT * FROM validaciones_distribucion_sgp WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodo != null) {
      query += ' AND periodo = ?';
      args.add(periodo);
    }

    query += ' ORDER BY fecha_validacion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Obtiene los porcentajes de distribución según Ley 1530/2012
  Map<TipoFondo, double> obtenerPorcentajesDistribucion() {
    return Map.from(_porcentajesDistribucion);
  }

  /// Calcula la distribución sugerida para un monto de regalías
  Map<TipoFondo, double> calcularDistribucionSugerida(double totalRegalias) {
    final distribucion = <TipoFondo, double>{};
    for (final entry in _porcentajesDistribucion.entries) {
      distribucion[entry.key] = totalRegalias * entry.value;
    }
    return distribucion;
  }
}
