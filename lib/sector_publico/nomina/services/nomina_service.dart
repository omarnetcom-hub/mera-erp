/// Servicio de Nómina Pública
/// Cálculo de nómina con aportes parafiscales
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/empleado.dart';
import '../models/liquidacion_nomina.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

class NominaService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  NominaService({required this.db, required this.auditoriaService});

  // Fuentes vigentes al 01-08-2026: MinSalud, aseguramiento al SGSSS
  // (12.5% salud: 8.5% empleador/4% trabajador; 16% pension:
  // 12%/4%); Decreto 1772/1994, art. 13 (ARL por clase); Ley 21/1982
  // y Ley 89/1988 (caja 4%, SENA 2%, ICBF 3%).
  static const double _saludPatronal = 0.085;
  static const double _saludTrabajador = 0.04;
  static const double _pensionPatronal = 0.12;
  static const double _pensionTrabajador = 0.04;
  static const double _cajaCompensacion = 0.04;
  static const double _sena = 0.02;
  static const double _icbf = 0.03;
  static const Map<int, double> _tarifasArl = {
    1: 0.00522,
    2: 0.01044,
    3: 0.02436,
    4: 0.0435,
    5: 0.0696,
  };

  /// Liquida nómina para un empleado
  Future<LiquidacionNomina> liquidarNomina({
    required String entidadId,
    required String usuarioId,
    required String empleadoId,
    required String periodo,
    required int diasTrabajados,
    double? horasExtra,
    double? recargoNocturno,
  }) async {
    final empleadoResult = await db.query(
      'empleados_sp',
      where: 'id = ?',
      whereArgs: [empleadoId],
    );

    if (empleadoResult.isEmpty) {
      throw Exception('Empleado no encontrado');
    }

    final empleado = Empleado.fromJson(empleadoResult.first);

    // Recuperar configuración de la entidad (SMMLV y Auxilio de Transporte) para evitar hardcoding
    final configResult = await db.query(
      'configuracion_entidad',
      where: 'entidad_id = ? AND parametro = ? AND vigente = 1',
      whereArgs: [entidadId, 'configuracion_legal'],
    );

    // Decreto 1469/2025 y Decreto 1470/2025, vigencia 2026.
    double smmlv = 1750905.0;
    double auxilioTransporteConfig = 249095.0;
    bool configPorDefecto = true;

    if (configResult.isNotEmpty) {
      try {
        final Map<String, dynamic> config = jsonDecode(
          configResult.first['valor'] as String,
        );
        bool hasSmmlv = config.containsKey('smmlv');
        bool hasAux = config.containsKey('auxilio_transporte');
        if (hasSmmlv) {
          smmlv = (config['smmlv'] as num).toDouble();
        }
        if (hasAux) {
          auxilioTransporteConfig = (config['auxilio_transporte'] as num)
              .toDouble();
        }
        if (hasSmmlv && hasAux) {
          configPorDefecto = false;
        }
      } catch (_) {
        // En caso de error, utiliza los valores por defecto
      }
    }

    final salarioDevengado = (empleado.salarioBasico / 30) * diasTrabajados;
    final auxilioTransporte = _calcularAuxilioTransporte(
      salarioBasico: empleado.salarioBasico,
      smmlv: smmlv,
      auxilioTransporte: auxilioTransporteConfig,
    );
    final auxilioAlimentacion = 0.0; // Implementar según política (Gap F3)

    final totalDevengado = _calcularTotalDevengado(
      salarioDevengado: salarioDevengado,
      auxTrans: auxilioTransporte,
      auxAlim: auxilioAlimentacion,
      hExtra: horasExtra ?? 0.0,
      recNoct: recargoNocturno ?? 0.0,
    );

    // El auxilio de transporte no integra el IBC. Horas extra y recargos si
    // constituyen salario; los componentes no salariales deben venir ya
    // identificados por el acto o convencion aplicable a cada regimen.
    final baseAportes =
        salarioDevengado + (horasExtra ?? 0) + (recargoNocturno ?? 0);
    final salud = baseAportes * _saludPatronal;
    final pension = baseAportes * _pensionPatronal;
    final fondoSolidaridad = _calcularFondoSolidaridad(baseAportes, smmlv);
    final tarifaArl = _tarifasArl[empleado.claseRiesgoArl];
    if (tarifaArl == null) {
      throw ArgumentError.value(
        empleado.claseRiesgoArl,
        'claseRiesgoArl',
        'Debe estar entre I y V',
      );
    }
    final riesgosLaborales = baseAportes * tarifaArl;

    final cajaCompensacion = baseAportes * _cajaCompensacion;
    final sena = baseAportes * _sena;
    final icbf = baseAportes * _icbf;

    final totalAportes =
        salud +
        pension +
        fondoSolidaridad +
        riesgosLaborales +
        cajaCompensacion +
        sena +
        icbf;
    final descuentosTrabajador =
        (baseAportes * _saludTrabajador) +
        (baseAportes * _pensionTrabajador) +
        fondoSolidaridad;
    final netoPagar = totalDevengado - descuentosTrabajador;

    final id = _uuid.v4();
    final numeroLiquidacion = 'LN-$periodo-${_generarNumeroSecuencial()}';
    final fechaLiquidacion = DateTime.now();

    final warnings = <String>[];
    warnings.add(
      'ARL clase ${empleado.claseRiesgoArl}: ${(tarifaArl * 100).toStringAsFixed(3)}% (Decreto 1772/1994).',
    );
    warnings.add(_descripcionRegimen(empleado.regimenNomina));
    if (configPorDefecto) {
      warnings.add(
        'Advertencia: SMMLV/auxilio de transporte por defecto. Falta configuración real de la entidad.',
      );
    }
    final observacionesStr = warnings.join(' | ');

    final liquidacion = LiquidacionNomina(
      id: id,
      entidadId: entidadId,
      numeroLiquidacion: numeroLiquidacion,
      periodo: periodo,
      empleadoId: empleadoId,
      empleadoNombre: empleado.nombreCompleto,
      empleadoIdentificacion: empleado.numeroIdentificacion,
      diasTrabajados: diasTrabajados,
      salarioBasico: empleado.salarioBasico,
      salarioDevengado: salarioDevengado,
      auxilioTransporte: auxilioTransporte,
      auxilioAlimentacion: auxilioAlimentacion,
      horasExtra: horasExtra ?? 0.0,
      recargoNocturno: recargoNocturno ?? 0.0,
      totalDevengado: totalDevengado,
      salud: salud,
      pension: pension,
      fondoSolidaridad: fondoSolidaridad,
      riesgosLaborales: riesgosLaborales,
      cajaCompensacion: cajaCompensacion,
      sena: sena,
      icbf: icbf,
      totalAportes: totalAportes,
      netoPagar: netoPagar,
      estado: EstadoLiquidacion.generada,
      fechaLiquidacion: fechaLiquidacion,
      observaciones: observacionesStr,
    );

    await db.insert('liquidaciones_nomina', liquidacion.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.liquidacionNomina,
      modulo: 'nomina',
      accion: 'liquidacion_nomina',
      valorAnterior: {'empleado_id': empleadoId},
      valorNuevo: {
        'liquidacion_id': id,
        'numero_liquidacion': numeroLiquidacion,
        'neto_pagar': netoPagar,
      },
      referenciaId: id,
    );

    return liquidacion;
  }

  double _calcularTotalDevengado({
    required double salarioDevengado,
    required double auxTrans,
    required double auxAlim,
    required double hExtra,
    required double recNoct,
  }) {
    return salarioDevengado + auxTrans + auxAlim + hExtra + recNoct;
  }

  /// Calcula auxilio de transporte (hasta 2 SMMLV)
  double _calcularAuxilioTransporte({
    required double salarioBasico,
    required double smmlv,
    required double auxilioTransporte,
  }) {
    if (salarioBasico <= (smmlv * 2)) {
      return auxilioTransporte;
    }
    return 0;
  }

  /// Calcula fondo de solidaridad (1-2% según salario)
  double _calcularFondoSolidaridad(double base, double smmlv) {
    if (base <= (smmlv * 4)) {
      return base * 0.0; // 0%
    } else if (base <= (smmlv * 16)) {
      return base * 0.01; // 1%
    }
    // Ley 797/2003, art. 7: 1% base mas aporte adicional gradual desde 16 SMMLV.
    if (base <= (smmlv * 17)) return base * 0.012;
    if (base <= (smmlv * 18)) return base * 0.014;
    if (base <= (smmlv * 19)) return base * 0.016;
    if (base <= (smmlv * 20)) return base * 0.018;
    return base * 0.02;
  }

  String _descripcionRegimen(RegimenNominaPublica regimen) {
    switch (regimen) {
      case RegimenNominaPublica.carreraAdministrativa:
        return 'Regimen de carrera administrativa (Ley 909/2004): IBC ordinario.';
      case RegimenNominaPublica.libreNombramientoRemocion:
        return 'Regimen de libre nombramiento y remocion (Ley 909/2004): IBC ordinario.';
      case RegimenNominaPublica.trabajadorOficial:
        return 'Trabajador oficial: factores adicionales deben provenir de contrato o convencion colectiva.';
      case RegimenNominaPublica.docenteTerritorial:
        return 'Docente territorial: escalafon y prestaciones se gestionan por Decreto 1278/2002.';
      case RegimenNominaPublica.saludEse:
        return 'ESE salud: clasificacion de empleo conforme a Ley 10/1990; IBC ordinario.';
      case RegimenNominaPublica.judicialFiscalia:
        return 'Rama Judicial/Fiscalia: escala y factores se cargan segun decreto salarial anual aplicable.';
    }
  }

  Future<List<LiquidacionNomina>> consultarLiquidaciones({
    required String entidadId,
    String? periodo,
    EstadoLiquidacion? estado,
  }) async {
    String query = 'SELECT * FROM liquidaciones_nomina WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (periodo != null) {
      query += ' AND periodo = ?';
      args.add(periodo);
    }

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado.toString().split('.').last);
    }

    query += ' ORDER BY fecha_liquidacion DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados.map((r) => LiquidacionNomina.fromJson(r)).toList();
  }

  String _generarNumeroSecuencial() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }
}
