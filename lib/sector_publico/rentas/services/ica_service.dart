/// Servicio de Impuesto de Industria y Comercio (ICA)
/// Impuesto de Industria y Comercio y Avisos
/// Ley 14/1983 y normas complementarias
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

enum TipoActividadICA {
  industrial,
  comercial,
  servicios,
}

enum PeriodoDeclaracionICA {
  bimestral,
  anual,
}

class ICAService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  ICAService({
    required this.db,
    required this.auditoriaService,
  });

  /// Registra un contribuyente de ICA en el censo
  Future<Map<String, dynamic>> registrarContribuyenteCenso({
    required String entidadId,
    required String usuarioId,
    required String nit,
    required String razonSocial,
    required String direccion,
    required String telefono,
    required TipoActividadICA tipoActividad,
    required String actividadEconomica,
    required double ingresosAnualesEstimados,
    String? email,
  }) async {
    final id = _uuid.v4();

    // Verificar si ya existe en censo
    final existente = await db.query(
      'censo_ica',
      where: 'entidad_id = ? AND nit = ?',
      whereArgs: [entidadId, nit],
    );

    if (existente.isNotEmpty) {
      throw Exception('El contribuyente ya está registrado en el censo de ICA');
    }

    await db.insert('censo_ica', {
      'id': id,
      'entidad_id': entidadId,
      'nit': nit,
      'razon_social': razonSocial,
      'direccion': direccion,
      'telefono': telefono,
      'tipo_actividad': tipoActividad.toString().split('.').last,
      'actividad_economica': actividadEconomica,
      'ingresos_anuales_estimados': ingresosAnualesEstimados,
      'email': email,
      'estado': 'activo',
      'fecha_registro': DateTime.now().toIso8601String(),
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas',
      accion: 'registro_contribuyente_censo_ica',
      valorAnterior: {},
      valorNuevo: {
        'contribuyente_id': id,
        'nit': nit,
        'razon_social': razonSocial,
      },
      referenciaId: id,
    );

    return {
      'contribuyente_id': id,
      'nit': nit,
      'razon_social': razonSocial,
      'estado': 'activo',
    };
  }

  /// Genera declaración de ICA bimestral
  Future<Map<String, dynamic>> generarDeclaracionICA({
    required String entidadId,
    required String usuarioId,
    required String contribuyenteId,
    required String periodo, // Formato: '2024-01' (enero-febrero)
    required PeriodoDeclaracionICA periodoDeclaracion,
    required double ingresosGravables,
    required double ingresosNoGravables,
    required double ingresosExentos,
  }) async {
    final id = _uuid.v4();
    final fechaDeclaracion = DateTime.now();

    // Obtener tarifa ICA según actividad
    final contribuyente = await db.query(
      'censo_ica',
      where: 'id = ?',
      whereArgs: [contribuyenteId],
    );

    if (contribuyente.isEmpty) {
      throw Exception('Contribuyente no encontrado');
    }

    final tipoActividad = TipoActividadICA.values.firstWhere(
      (e) => e.toString().split('.').last == contribuyente.first['tipo_actividad'],
    );

    final tarifa = _obtenerTarifaICA(tipoActividad);

    // Calcular base gravable
    final baseGravable = ingresosGravables - ingresosExentos;

    // Calcular impuesto
    final impuestoICA = baseGravable * tarifa;

    // Calcular intereses de mora si aplica
    final interesesMora = await _calcularInteresesMoraICA(
      entidadId: entidadId,
      contribuyenteId: contribuyenteId,
      periodo: periodo,
      valorImpuesto: impuestoICA,
    );

    // Calcular total a pagar
    final totalPagar = impuestoICA + interesesMora;

    await db.insert('declaraciones_ica', {
      'id': id,
      'entidad_id': entidadId,
      'contribuyente_id': contribuyenteId,
      'periodo': periodo,
      'periodo_declaracion': periodoDeclaracion.toString().split('.').last,
      'fecha_declaracion': fechaDeclaracion.toIso8601String(),
      'ingresos_gravables': ingresosGravables,
      'ingresos_no_gravables': ingresosNoGravables,
      'ingresos_exentos': ingresosExentos,
      'base_gravable': baseGravable,
      'tarifa': tarifa,
      'impuesto_ica': impuestoICA,
      'intereses_mora': interesesMora,
      'total_pagar': totalPagar,
      'estado': 'pendiente_pago',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas',
      accion: 'generacion_declaracion_ica',
      valorAnterior: {},
      valorNuevo: {
        'declaracion_id': id,
        'periodo': periodo,
        'impuesto_ica': impuestoICA,
        'total_pagar': totalPagar,
      },
      referenciaId: id,
    );

    return {
      'declaracion_id': id,
      'periodo': periodo,
      'impuesto_ica': impuestoICA,
      'intereses_mora': interesesMora,
      'total_pagar': totalPagar,
      'estado': 'pendiente_pago',
    };
  }

  /// Calcula intereses de mora para ICA
  Future<double> _calcularInteresesMoraICA({
    required String entidadId,
    required String contribuyenteId,
    required String periodo,
    required double valorImpuesto,
  }) async {
    // Verificar si hay vencimiento
    final fechaVencimiento = _obtenerFechaVencimientoICA(periodo);
    final hoy = DateTime.now();

    if (hoy.isBefore(fechaVencimiento)) {
      return 0;
    }

    // Calcular días de mora
    final diasMora = hoy.difference(fechaVencimiento).inDays;

    // Calcular intereses usando el servicio de intereses moratorios
    // Reutilizando el motor de intereses moratorios de la Fase 4
    final intereses = valorImpuesto * 0.024 * (diasMora / 30); // 2.4% mensual

    return intereses;
  }

  /// Obtiene la fecha de vencimiento para una declaración ICA
  DateTime _obtenerFechaVencimientoICA(String periodo) {
    // Para bimestral: vence el último día del mes siguiente al bimestre
    final partes = periodo.split('-');
    final anio = int.parse(partes[0]);
    final mes = int.parse(partes[1]);

    // Si es periodo bimestral (ej. 01 = enero-febrero), vence en marzo
    final mesVencimiento = mes + 1;
    final fechaVencimiento = DateTime(anio, mesVencimiento + 1, 0);

    return fechaVencimiento;
  }

  /// Obtiene la tarifa ICA según tipo de actividad
  double _obtenerTarifaICA(TipoActividadICA tipo) {
    switch (tipo) {
      case TipoActividadICA.industrial:
        return 0.006; // 0.6% sobre ingresos gravables
      case TipoActividadICA.comercial:
        return 0.008; // 0.8% sobre ingresos gravables
      case TipoActividadICA.servicios:
        return 0.010; // 1.0% sobre ingresos gravables
    }
  }

  /// Registra ReteICA (Retención en la fuente de ICA)
  Future<Map<String, dynamic>> registrarReteICA({
    required String entidadId,
    required String usuarioId,
    required String nitRetenedor,
    required String nitRetenido,
    required String periodo,
    required double valorRetenido,
    required String numeroFactura,
    required DateTime fechaFactura,
  }) async {
    final id = _uuid.v4();

    await db.insert('reteica', {
      'id': id,
      'entidad_id': entidadId,
      'nit_retenedor': nitRetenedor,
      'nit_retenido': nitRetenido,
      'periodo': periodo,
      'valor_retenido': valorRetenido,
      'numero_factura': numeroFactura,
      'fecha_factura': fechaFactura.toIso8601String(),
      'fecha_registro': DateTime.now().toIso8601String(),
      'estado': 'pendiente_declaracion',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas',
      accion: 'registro_reteica',
      valorAnterior: {},
      valorNuevo: {
        'reteica_id': id,
        'nit_retenedor': nitRetenedor,
        'nit_retenido': nitRetenido,
        'valor_retenido': valorRetenido,
      },
      referenciaId: id,
    );

    return {
      'reteica_id': id,
      'valor_retenido': valorRetenido,
      'estado': 'pendiente_declaracion',
    };
  }

  /// Genera aviso de tablero (impuesto de avisos)
  Future<Map<String, dynamic>> generarAvisoTablero({
    required String entidadId,
    required String usuarioId,
    required String contribuyenteId,
    required String periodo,
    required String tipoAviso,
    required double valorAviso,
    required String ubicacion,
    required double areaMetros,
  }) async {
    final id = _uuid.v4();

    // Calcular impuesto de aviso según tarifa
    final tarifaAviso = _obtenerTarifaAviso(tipoAviso);
    final impuestoAviso = areaMetros * tarifaAviso;

    await db.insert('avisos_tablero', {
      'id': id,
      'entidad_id': entidadId,
      'contribuyente_id': contribuyenteId,
      'periodo': periodo,
      'tipo_aviso': tipoAviso,
      'valor_aviso': valorAviso,
      'ubicacion': ubicacion,
      'area_metros': areaMetros,
      'tarifa': tarifaAviso,
      'impuesto_aviso': impuestoAviso,
      'fecha_registro': DateTime.now().toIso8601String(),
      'estado': 'pendiente_pago',
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'rentas',
      accion: 'generacion_aviso_tablero',
      valorAnterior: {},
      valorNuevo: {
        'aviso_id': id,
        'tipo_aviso': tipoAviso,
        'impuesto_aviso': impuestoAviso,
      },
      referenciaId: id,
    );

    return {
      'aviso_id': id,
      'impuesto_aviso': impuestoAviso,
      'estado': 'pendiente_pago',
    };
  }

  /// Obtiene la tarifa de aviso según tipo
  double _obtenerTarifaAviso(String tipoAviso) {
    switch (tipoAviso.toLowerCase()) {
      case 'luminoso':
        return 1500; // $1,500 por m²
      case 'fijo':
        return 1000; // $1,000 por m²
      case 'valla':
        return 2000; // $2,000 por m²
      default:
        return 1000;
    }
  }

  /// Genera tablero de recaudo de ICA
  Future<Map<String, dynamic>> generarTableroRecaudoICA({
    required String entidadId,
    required String periodo,
  }) async {
    // Total de declaraciones generadas
    final declaraciones = await db.query(
      'declaraciones_ica',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalDeclaraciones = declaraciones.length;
    final totalImpuestoDeclarado = declaraciones.fold<double>(
      0,
      (sum, r) => sum + (r['impuesto_ica'] as num).toDouble(),
    );

    // Total de pagos recibidos
    final pagos = await db.query(
      'pagos_ica',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalPagos = pagos.length;
    final totalRecaudado = pagos.fold<double>(
      0,
      (sum, r) => sum + (r['valor_pagado'] as num).toDouble(),
    );

    // Total de ReteICA
    final reteica = await db.query(
      'reteica',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalReteica = reteica.fold<double>(
      0,
      (sum, r) => sum + (r['valor_retenido'] as num).toDouble(),
    );

    // Total de avisos de tablero
    final avisos = await db.query(
      'avisos_tablero',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalAvisos = avisos.length;
    final totalImpuestoAvisos = avisos.fold<double>(
      0,
      (sum, r) => sum + (r['impuesto_aviso'] as num).toDouble(),
    );

    // Porcentaje de recaudo
    final porcentajeRecaudo = totalImpuestoDeclarado > 0
        ? (totalRecaudado / totalImpuestoDeclarado) * 100
        : 0;

    return {
      'periodo': periodo,
      'total_declaraciones': totalDeclaraciones,
      'total_impuesto_declarado': totalImpuestoDeclarado,
      'total_pagos': totalPagos,
      'total_recaudado': totalRecaudado,
      'total_reteica': totalReteica,
      'total_avisos': totalAvisos,
      'total_impuesto_avisos': totalImpuestoAvisos,
      'porcentaje_recaudo': porcentajeRecaudo,
      'saldo_pendiente': totalImpuestoDeclarado - totalRecaudado,
    };
  }

  /// Consulta contribuyentes del censo
  Future<List<Map<String, dynamic>>> consultarCensoICA({
    required String entidadId,
    TipoActividadICA? tipoActividad,
    String? estado,
  }) async {
    String query = 'SELECT * FROM censo_ica WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (tipoActividad != null) {
      query += ' AND tipo_actividad = ?';
      args.add(tipoActividad.toString().split('.').last);
    }

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado);
    }

    query += ' ORDER BY fecha_registro DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Consulta declaraciones de ICA
  Future<List<Map<String, dynamic>>> consultarDeclaracionesICA({
    required String entidadId,
    String? periodo,
    String? estado,
  }) async {
    String query = 'SELECT * FROM declaraciones_ica WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodo != null) {
      query += ' AND periodo = ?';
      args.add(periodo);
    }

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado);
    }

    query += ' ORDER BY fecha_declaracion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados;
  }

  /// Exporta la declaración oficial de ICA en formato plano
  Future<String> exportarDeclaracionICAAPlano(String declaracionId) async {
    final res = await db.query('declaraciones_ica', where: 'id = ?', whereArgs: [declaracionId]);
    if (res.isEmpty) throw Exception('Declaración ICA no encontrada');
    final dec = res.first;

    final buffer = StringBuffer();
    buffer.writeln('ICA_DECLARATION_HEADER|${dec['id']}|${dec['entidad_id']}|PERIODO|${dec['periodo']}');
    buffer.writeln('CONTRIBUYENTE_ID|${dec['contribuyente_id']}');
    buffer.writeln('VALORES|GRAVABLE|${dec['ingresos_gravables']}|EXENTO|${dec['ingresos_exentos']}|BASE|${dec['base_gravable']}');
    buffer.writeln('LIQUIDACION|TARIFA|${dec['tarifa']}|IMPUESTO_ICA|${dec['impuesto_ica']}|MORA|${dec['intereses_mora']}|TOTAL|${dec['total_pagar']}');
    buffer.writeln('ESTADO|${dec['estado']}');
    buffer.writeln('ICA_DECLARATION_FOOTER|DOCUMENTO_OFICIAL_RECAUDO');

    return buffer.toString();
  }
}

