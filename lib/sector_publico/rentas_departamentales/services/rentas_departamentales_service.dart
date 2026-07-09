/// Servicio de Rentas Departamentales
/// Gestión de rentas propias de departamentos
/// Impuestos departamentales específicos
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/auditoria_service.dart';

enum TipoImpuestoDepartamental {
  impuestoAlConsumo,
  impuestoAlJuegos,
  impuestoTasaUsoAeroportuario,
  impuestoDegradacion,
  otros,
}

class RentasDepartamentalesService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  // Tarifas de impuestos departamentales (ejemplo)
  static const Map<TipoImpuestoDepartamental, double> _tarifas = {
    TipoImpuestoDepartamental.impuestoAlConsumo: 0.08, // 8%
    TipoImpuestoDepartamental.impuestoAlJuegos: 0.15, // 15%
    TipoImpuestoDepartamental.impuestoTasaUsoAeroportuario: 0.04, // 4%
    TipoImpuestoDepartamental.impuestoDegradacion: 0.02, // 2%
  };

  RentasDepartamentalesService({
    required this.db,
    required this.auditoriaService,
  });

  /// Registra un contribuyente de rentas departamentales
  Future<Map<String, dynamic>> registrarContribuyente({
    required String entidadId,
    required String usuarioId,
    required String nit,
    required String razonSocial,
    required String direccion,
    required String municipio,
    required TipoImpuestoDepartamental tipoImpuesto,
    String? email,
  }) async {
    final id = _uuid.v4();

    await db.insert('contribuyentes_rentas_departamentales', {
      'id': id,
      'entidad_id': entidadId,
      'nit': nit,
      'razon_social': razonSocial,
      'direccion': direccion,
      'municipio': municipio,
      'tipo_impuesto': tipoImpuesto.toString().split('.').last,
      'email': email,
      'fecha_registro': DateTime.now().toIso8601String(),
      'estado': 'activo',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas_departamentales',
      accion: 'registro_contribuyente',
      valorAnterior: {},
      valorNuevo: {
        'contribuyente_id': id,
        'nit': nit,
        'razon_social': razonSocial,
        'tipo_impuesto': tipoImpuesto.toString(),
      },
      referenciaId: id,
    );

    return {
      'contribuyente_id': id,
      'nit': nit,
      'razon_social': razonSocial,
      'tipo_impuesto': tipoImpuesto.toString(),
      'estado': 'activo',
    };
  }

  /// Genera declaración de impuesto departamental
  Future<Map<String, dynamic>> generarDeclaracion({
    required String entidadId,
    required String usuarioId,
    required String contribuyenteId,
    required TipoImpuestoDepartamental tipoImpuesto,
    required String periodo,
    required double baseGravable,
    required double ingresosNoGravables,
    required double ingresosExentos,
  }) async {
    final id = _uuid.v4();

    // Calcular base gravable
    final baseGravableCalculada = baseGravable - ingresosExentos;

    // Obtener tarifa
    final tarifa = _tarifas[tipoImpuesto] ?? 0;

    // Calcular impuesto
    final impuesto = baseGravableCalculada * tarifa;

    await db.insert('declaraciones_rentas_departamentales', {
      'id': id,
      'entidad_id': entidadId,
      'contribuyente_id': contribuyenteId,
      'tipo_impuesto': tipoImpuesto.toString().split('.').last,
      'periodo': periodo,
      'fecha_declaracion': DateTime.now().toIso8601String(),
      'ingresos_gravables': baseGravable,
      'ingresos_no_gravables': ingresosNoGravables,
      'ingresos_exentos': ingresosExentos,
      'base_gravable': baseGravableCalculada,
      'tarifa': tarifa,
      'impuesto': impuesto,
      'estado': 'pendiente_pago',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas_departamentales',
      accion: 'generacion_declaracion',
      valorAnterior: {},
      valorNuevo: {
        'declaracion_id': id,
        'periodo': periodo,
        'impuesto': impuesto,
      },
      referenciaId: id,
    );

    return {
      'declaracion_id': id,
      'periodo': periodo,
      'impuesto': impuesto,
      'estado': 'pendiente_pago',
    };
  }

  /// Registra pago de impuesto departamental
  Future<Map<String, dynamic>> registrarPago({
    required String entidadId,
    required String usuarioId,
    required String declaracionId,
    required double valorPagado,
    required DateTime fechaPago,
    required String referenciaPago,
  }) async {
    final id = _uuid.v4();

    final declaracion = await db.query(
      'declaraciones_rentas_departamentales',
      where: 'id = ?',
      whereArgs: [declaracionId],
    );

    if (declaracion.isEmpty) {
      throw Exception('Declaración no encontrada');
    }

    final impuestoDeclarado = declaracion.first['impuesto'] as double;

    if (valorPagado > impuestoDeclarado) {
      throw Exception('El pago excede el impuesto declarado');
    }

    await db.insert('pagos_rentas_departamentales', {
      'id': id,
      'entidad_id': entidadId,
      'declaracion_id': declaracionId,
      'valor_pagado': valorPagado,
      'fecha_pago': fechaPago.toIso8601String(),
      'referencia_pago': referenciaPago,
      'fecha_registro': DateTime.now().toIso8601String(),
      'estado': 'aplicado',
    });

    // Actualizar estado de declaración
    final saldoPendiente = impuestoDeclarado - valorPagado;
    final nuevoEstado = saldoPendiente <= 0 ? 'pagado' : 'parcialmente_pagado';

    await db.update(
      'declaraciones_rentas_departamentales',
      {
        'estado': nuevoEstado,
        'saldo_pendiente': saldoPendiente,
      },
      where: 'id = ?',
      whereArgs: [declaracionId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas_departamentales',
      accion: 'registro_pago',
      valorAnterior: {},
      valorNuevo: {
        'pago_id': id,
        'declaracion_id': declaracionId,
        'valor_pagado': valorPagado,
      },
      referenciaId: id,
    );

    return {
      'pago_id': id,
      'declaracion_id': declaracionId,
      'valor_pagado': valorPagado,
      'saldo_pendiente': saldoPendiente,
      'estado_declaracion': nuevoEstado,
    };
  }

  /// Genera reporte de recaudo departamental
  Future<Map<String, dynamic>> generarReporteRecaudo({
    required String entidadId,
    required String periodo,
  }) async {
    final declaraciones = await db.query(
      'declaraciones_rentas_departamentales',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final pagos = await db.query(
      'pagos_rentas_departamentales',
      where: 'entidad_id = ?',
      whereArgs: [entidadId],
    );

    double totalDeclarado = declaraciones.fold<double>(
      0,
      (sum, r) => sum + (r['impuesto'] as num).toDouble(),
    );

    double totalRecaudado = pagos.fold<double>(
      0,
      (sum, r) => sum + (r['valor_pagado'] as num).toDouble(),
    );

    // Por tipo de impuesto
    final porTipo = <String, double>{};
    for (final d in declaraciones) {
      final tipo = d['tipo_impuesto'];
      porTipo[tipo] = (porTipo[tipo] ?? 0) + (d['impuesto'] as num).toDouble();
    }

    // Por municipio
    final porMunicipio = <String, double>{};
    for (final d in declaraciones) {
      final contribuyente = await db.query(
        'contribuyentes_rentas_departamentales',
        where: 'id = ?',
        whereArgs: [d['contribuyente_id']],
      );
      if (contribuyente.isNotEmpty) {
        final municipio = contribuyente.first['municipio'];
        porMunicipio[municipio] = (porMunicipio[municipio] ?? 0) + (d['impuesto'] as num).toDouble();
      }
    }

    return {
      'periodo': periodo,
      'total_declaraciones': declaraciones.length,
      'total_declarado': totalDeclarado,
      'total_recaudado': totalRecaudado,
      'porcentaje_recaudo': totalDeclarado > 0 ? (totalRecaudado / totalDeclarado) * 100 : 0,
      'saldo_pendiente': totalDeclarado - totalRecaudado,
      'por_tipo': porTipo,
      'por_municipio': porMunicipio,
    };
  }

  /// Consulta contribuyentes
  Future<List<Map<String, dynamic>>> consultarContribuyentes({
    required String entidadId,
    TipoImpuestoDepartamental? tipoImpuesto,
    String? municipio,
  }) async {
    String query = 'SELECT * FROM contribuyentes_rentas_departamentales WHERE entidad_id = ? AND estado = ?';
    List<dynamic> args = [entidadId, 'activo'];

    if (tipoImpuesto != null) {
      query += ' AND tipo_impuesto = ?';
      args.add(tipoImpuesto.toString().split('.').last);
    }

    if (municipio != null) {
      query += ' AND municipio = ?';
      args.add(municipio);
    }

    query += ' ORDER BY fecha_registro DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Consulta declaraciones
  Future<List<Map<String, dynamic>>> consultarDeclaraciones({
    required String entidadId,
    String? periodo,
    TipoImpuestoDepartamental? tipoImpuesto,
    String? estado,
  }) async {
    String query = 'SELECT * FROM declaraciones_rentas_departamentales WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodo != null) {
      query += ' AND periodo = ?';
      args.add(periodo);
    }

    if (tipoImpuesto != null) {
      query += ' AND tipo_impuesto = ?';
      args.add(tipoImpuesto.toString().split('.').last);
    }

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado);
    }

    query += ' ORDER BY fecha_declaracion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Obtiene las tarifas de impuestos departamentales
  Map<TipoImpuestoDepartamental, double> obtenerTarifas() {
    return Map.from(_tarifas);
  }

  /// Calcula el impuesto según tipo y base gravable
  double calcularImpuesto({
    required TipoImpuestoDepartamental tipo,
    required double baseGravable,
  }) {
    final tarifa = _tarifas[tipo] ?? 0;
    return baseGravable * tarifa;
  }
}
