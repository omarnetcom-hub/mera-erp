/// Servicio de Impuesto de Industria y Comercio (ICA)
/// Impuesto de Industria y Comercio y Avisos
/// Ley 14/1983 y normas complementarias
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/currency/money_value.dart';
import '../../../core/currency/public_sector_money.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

enum TipoActividadICA { industrial, comercial, servicios }

enum PeriodoDeclaracionICA { bimestral, anual }

class ICAService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  ICAService({required this.db, required this.auditoriaService});

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
    required MoneyValue ingresosAnualesEstimados,
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
      'ingresos_anuales_estimados': ingresosAnualesEstimados.toSql(),
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
    required MoneyValue ingresosGravables,
    required MoneyValue ingresosNoGravables,
    required MoneyValue ingresosExentos,
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
      (e) =>
          e.toString().split('.').last == contribuyente.first['tipo_actividad'],
    );

    final tarifa = _obtenerTarifaICA(tipoActividad);

    // Calcular base gravable
    final baseGravable = ingresosGravables - ingresosExentos;

    // Calcular impuesto
    final impuestoICA = baseGravable.multiplyDecimal(tarifa.toString());

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
      'ingresos_gravables': ingresosGravables.toSql(),
      'ingresos_no_gravables': ingresosNoGravables.toSql(),
      'ingresos_exentos': ingresosExentos.toSql(),
      'base_gravable': baseGravable.toSql(),
      'tarifa': tarifa,
      'impuesto_ica': impuestoICA.toSql(),
      'intereses_mora': interesesMora.toSql(),
      'total_pagar': totalPagar.toSql(),
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
        'impuesto_ica': impuestoICA.toSql(),
        'total_pagar': totalPagar.toSql(),
      },
      referenciaId: id,
    );

    return {
      'declaracion_id': id,
      'periodo': periodo,
      'impuesto_ica': publicMoneyForDisplay(impuestoICA),
      'intereses_mora': publicMoneyForDisplay(interesesMora),
      'total_pagar': publicMoneyForDisplay(totalPagar),
      'estado': 'pendiente_pago',
    };
  }

  /// Calcula intereses de mora para ICA
  Future<MoneyValue> _calcularInteresesMoraICA({
    required String entidadId,
    required String contribuyenteId,
    required String periodo,
    required MoneyValue valorImpuesto,
  }) async {
    // Verificar si hay vencimiento
    final fechaVencimiento = _obtenerFechaVencimientoICA(periodo);
    final hoy = DateTime.now();

    if (hoy.isBefore(fechaVencimiento)) {
      return publicMoneyZero();
    }

    // Calcular días de mora
    final diasMora = hoy.difference(fechaVencimiento).inDays;

    // Calcular intereses usando el servicio de intereses moratorios
    // Reutilizando el motor de intereses moratorios de la Fase 4
    final intereses = valorImpuesto.multiplyRatio(
      numerator: 24 * diasMora,
      denominator: 30000,
    ); // 2.4% mensual prorrateado por dias

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
    required MoneyValue valorRetenido,
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
      'valor_retenido': valorRetenido.toSql(),
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
        'valor_retenido': valorRetenido.toSql(),
      },
      referenciaId: id,
    );

    return {
      'reteica_id': id,
      'valor_retenido': publicMoneyForDisplay(valorRetenido),
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
    required MoneyValue valorAviso,
    required String ubicacion,
    required double areaMetros,
  }) async {
    final id = _uuid.v4();

    // Calcular impuesto de aviso según tarifa
    final tarifaAviso = _obtenerTarifaAviso(tipoAviso);
    final impuestoAviso = tarifaAviso.multiplyDecimal(areaMetros.toString());

    await db.insert('avisos_tablero', {
      'id': id,
      'entidad_id': entidadId,
      'contribuyente_id': contribuyenteId,
      'periodo': periodo,
      'tipo_aviso': tipoAviso,
      'valor_aviso': valorAviso.toSql(),
      'ubicacion': ubicacion,
      'area_metros': areaMetros,
      'tarifa': publicMoneyForDisplay(tarifaAviso),
      'impuesto_aviso': impuestoAviso.toSql(),
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
        'impuesto_aviso': impuestoAviso.toSql(),
      },
      referenciaId: id,
    );

    return {
      'aviso_id': id,
      'impuesto_aviso': publicMoneyForDisplay(impuestoAviso),
      'estado': 'pendiente_pago',
    };
  }

  /// Obtiene la tarifa de aviso según tipo
  MoneyValue _obtenerTarifaAviso(String tipoAviso) {
    switch (tipoAviso.toLowerCase()) {
      case 'luminoso':
        return publicMoneyFromMajor('1500'); // $1,500 por m²
      case 'fijo':
        return publicMoneyFromMajor('1000'); // $1,000 por m²
      case 'valla':
        return publicMoneyFromMajor('2000'); // $2,000 por m²
      default:
        return publicMoneyFromMajor('1000');
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
    final totalImpuestoDeclarado = declaraciones.fold<MoneyValue>(
      publicMoneyZero(),
      (sum, r) => sum + publicMoneyFromSql(r['impuesto_ica']),
    );

    // Total de pagos recibidos
    final pagos = await db.query(
      'pagos_ica',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalPagos = pagos.length;
    final totalRecaudado = pagos.fold<MoneyValue>(
      publicMoneyZero(),
      (sum, r) => sum + publicMoneyFromSql(r['valor_pagado']),
    );

    // Total de ReteICA
    final reteica = await db.query(
      'reteica',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalReteica = reteica.fold<MoneyValue>(
      publicMoneyZero(),
      (sum, r) => sum + publicMoneyFromSql(r['valor_retenido']),
    );

    // Total de avisos de tablero
    final avisos = await db.query(
      'avisos_tablero',
      where: 'entidad_id = ? AND periodo = ?',
      whereArgs: [entidadId, periodo],
    );

    final totalAvisos = avisos.length;
    final totalImpuestoAvisos = avisos.fold<MoneyValue>(
      publicMoneyZero(),
      (sum, r) => sum + publicMoneyFromSql(r['impuesto_aviso']),
    );

    // Porcentaje de recaudo
    final porcentajeRecaudo = totalImpuestoDeclarado > publicMoneyZero()
        ? (totalRecaudado.minorUnits / totalImpuestoDeclarado.minorUnits) * 100
        : 0;

    return {
      'periodo': periodo,
      'total_declaraciones': totalDeclaraciones,
      'total_impuesto_declarado': publicMoneyForDisplay(totalImpuestoDeclarado),
      'total_pagos': totalPagos,
      'total_recaudado': publicMoneyForDisplay(totalRecaudado),
      'total_reteica': publicMoneyForDisplay(totalReteica),
      'total_avisos': totalAvisos,
      'total_impuesto_avisos': publicMoneyForDisplay(totalImpuestoAvisos),
      'porcentaje_recaudo': porcentajeRecaudo,
      'saldo_pendiente': publicMoneyForDisplay(
        totalImpuestoDeclarado - totalRecaudado,
      ),
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
    final res = await db.query(
      'declaraciones_ica',
      where: 'id = ?',
      whereArgs: [declaracionId],
    );
    if (res.isEmpty) throw Exception('Declaración ICA no encontrada');
    final dec = res.first;

    final buffer = StringBuffer();
    buffer.writeln(
      'ICA_DECLARATION_HEADER|${dec['id']}|${dec['entidad_id']}|PERIODO|${dec['periodo']}',
    );
    buffer.writeln('CONTRIBUYENTE_ID|${dec['contribuyente_id']}');
    buffer.writeln(
      'VALORES|GRAVABLE|${publicMoneyFromSql(dec['ingresos_gravables']).toMajorUnitsString()}|'
      'EXENTO|${publicMoneyFromSql(dec['ingresos_exentos']).toMajorUnitsString()}|'
      'BASE|${publicMoneyFromSql(dec['base_gravable']).toMajorUnitsString()}',
    );
    buffer.writeln(
      'LIQUIDACION|TARIFA|${dec['tarifa']}|'
      'IMPUESTO_ICA|${publicMoneyFromSql(dec['impuesto_ica']).toMajorUnitsString()}|'
      'MORA|${publicMoneyFromSql(dec['intereses_mora']).toMajorUnitsString()}|'
      'TOTAL|${publicMoneyFromSql(dec['total_pagar']).toMajorUnitsString()}',
    );
    buffer.writeln('ESTADO|${dec['estado']}');
    buffer.writeln('ICA_DECLARATION_FOOTER|DOCUMENTO_OFICIAL_RECAUDO');

    return buffer.toString();
  }
}
