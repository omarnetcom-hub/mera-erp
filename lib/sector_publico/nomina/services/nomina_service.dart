/// Servicio de Nómina Pública
/// Cálculo de nómina con aportes parafiscales
library;

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

  NominaService({
    required this.db,
    required this.auditoriaService,
  });

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
      'empleados',
      where: 'id = ?',
      whereArgs: [empleadoId],
    );

    if (empleadoResult.isEmpty) {
      throw Exception('Empleado no encontrado');
    }

    final empleado = Empleado.fromJson(empleadoResult.first);

    final salarioDevengado = (empleado.salarioBasico / 30) * diasTrabajados;
    final auxilioTransporte = _calcularAuxilioTransporte(empleado.salarioBasico);
    final auxilioAlimentacion = 0.0; // Implementar según política

    final totalDevengado = salarioDevengado + auxilioTransporte + auxilioAlimentacion + 
                           (horasExtra ?? 0) + (recargoNocturno ?? 0);

    final baseAportes = totalDevengado;
    final salud = baseAportes * 0.085; // 8.5%
    final pension = baseAportes * 0.12; // 12%
    final fondoSolidaridad = _calcularFondoSolidaridad(baseAportes);
    final riesgosLaborales = baseAportes * 0.00522; // 0.522% (clase I)
    final cajaCompensacion = baseAportes * 0.04; // 4%
    final sena = baseAportes * 0.02; // 2%
    final icbf = baseAportes * 0.03; // 3%

    final totalAportes = salud + pension + fondoSolidaridad + riesgosLaborales + 
                         cajaCompensacion + sena + icbf;
    final netoPagar = totalDevengado - salud - pension - fondoSolidaridad - riesgosLaborales;

    final id = _uuid.v4();
    final numeroLiquidacion = 'LN-$periodo-${_generarNumeroSecuencial()}';
    final fechaLiquidacion = DateTime.now();

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

  /// Calcula auxilio de transporte (hasta 2 SMMLV)
  double _calcularAuxilioTransporte(double salarioBasico) {
    const smmlv = 908526; // Valor SMMLV 2024
    const auxilioMaximo = smmlv * 2;
    
    if (salarioBasico <= (smmlv * 2)) {
      return 162000; // Valor fijo auxilio transporte
    }
    return 0;
  }

  /// Calcula fondo de solidaridad (1-2% según salario)
  double _calcularFondoSolidaridad(double base) {
    const smmlv = 908526;
    
    if (base <= (smmlv * 4)) {
      return base * 0.0; // 0%
    } else if (base <= (smmlv * 16)) {
      return base * 0.01; // 1%
    } else if (base <= (smmlv * 17)) {
      return base * 0.015; // 1.5%
    } else {
      return base * 0.02; // 2%
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

