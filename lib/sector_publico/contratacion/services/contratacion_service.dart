/// Servicio de Contratación Pública
/// Ley 80 de 1993 + Ley 1150 de 2007 + Decreto 1082 de 2015
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/proceso_contratacion.dart';
import '../models/contrato.dart';
import '../models/poliza.dart';
import '../../presupuesto/services/presupuesto_service.dart';
import '../../security/auditoria_service.dart';

class ContratacionService {
  final Database db;
  final PresupuestoService presupuestoService;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  ContratacionService({
    required this.db,
    required this.presupuestoService,
    required this.auditoriaService,
  });

  /// Crea un proceso de contratación
  Future<ProcesoContratacion> crearProceso({
    required String entidadId,
    required String usuarioId,
    required String objetoContrato,
    required ModalidadSeleccion modalidad,
    required double valorEstimado,
    required String tipoContrato,
    required String dependenciaSolicitante,
    required String responsableProceso,
  }) async {
    final id = _uuid.v4();
    final numeroProceso = 'PC-${DateTime.now().year}-${_generarNumeroSecuencial()}';
    final fechaInicio = DateTime.now();

    final proceso = ProcesoContratacion(
      id: id,
      entidadId: entidadId,
      numeroProceso: numeroProceso,
      objetoContrato: objetoContrato,
      modalidad: modalidad,
      valorEstimado: valorEstimado,
      tipoContrato: tipoContrato,
      dependenciaSolicitante: dependenciaSolicitante,
      responsableProceso: responsableProceso,
      fechaInicio: fechaInicio,
      estado: EstadoProceso.estudioPrevio,
    );

    await db.insert('procesos_contratacion', proceso.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'contratacion',
      accion: 'creacion_proceso_contratacion',
      valorAnterior: {},
      valorNuevo: {
        'proceso_id': id,
        'numero_proceso': numeroProceso,
        'modalidad': modalidad.toString(),
      },
      referenciaId: id,
    );

    return proceso;
  }

  /// Asocia un CDP a un proceso de contratación
  Future<ProcesoContratacion> asociarCDP({
    required String entidadId,
    required String usuarioId,
    required String procesoId,
    required String cdpId,
    required String numeroCDP,
  }) async {
    final procesoResult = await db.query(
      'procesos_contratacion',
      where: 'id = ?',
      whereArgs: [procesoId],
    );

    if (procesoResult.isEmpty) {
      throw Exception('Proceso no encontrado');
    }

    await db.update(
      'procesos_contratacion',
      {
        'cdp_id': cdpId,
        'numero_cdp': numeroCDP,
      },
      where: 'id = ?',
      whereArgs: [procesoId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'contratacion',
      accion: 'asociacion_cdp',
      valorAnterior: {'proceso_id': procesoId},
      valorNuevo: {'cdp_id': cdpId, 'numero_cdp': numeroCDP},
      referenciaId: procesoId,
    );

    final proceso = ProcesoContratacion.fromJson(procesoResult.first);
    return proceso.copyWith(cdpId: cdpId, numeroCDP: numeroCDP);
  }

  /// Crea un contrato a partir de un proceso adjudicado
  /// VALIDACIÓN NORMATIVA: Requiere CDP y RP (Ley 80/1993 Art. 41)
  Future<Contrato> crearContrato({
    required String entidadId,
    required String usuarioId,
    required String procesoId,
    required String contratistaId,
    required String contratistaNombre,
    required String contratistaIdentificacion,
    required String cdpId,
    required String numeroCDP,
    required String rpId,
    required String numeroRP,
    required DateTime fechaFirma,
    required DateTime fechaInicioEjecucion,
    required DateTime fechaFinEjecucion,
  }) async {
    final procesoResult = await db.query(
      'procesos_contratacion',
      where: 'id = ?',
      whereArgs: [procesoId],
    );

    if (procesoResult.isEmpty) {
      throw Exception('Proceso no encontrado');
    }

    final proceso = ProcesoContratacion.fromJson(procesoResult.first);

    // VALIDACIÓN NORMATIVA: Verificar que el proceso esté adjudicado
    if (proceso.estado != EstadoProceso.adjudicado) {
      throw Exception('Solo se pueden crear contratos de procesos adjudicados');
    }

    // VALIDACIÓN NORMATIVA: Verificar CDP
    if (proceso.cdpId == null || proceso.cdpId!.isEmpty) {
      throw Exception('El proceso debe tener CDP asociado (Ley 80/1993 Art. 41)');
    }

    final duracionDias = fechaFinEjecucion.difference(fechaInicioEjecucion).inDays;
    final id = _uuid.v4();
    final numeroContrato = 'CT-${DateTime.now().year}-${_generarNumeroSecuencial()}';

    final contrato = Contrato(
      id: id,
      entidadId: entidadId,
      numeroContrato: numeroContrato,
      procesoId: procesoId,
      numeroProceso: proceso.numeroProceso,
      objetoContrato: proceso.objetoContrato,
      tipoContrato: _parseTipoContrato(proceso.tipoContrato),
      valorContrato: proceso.valorEstimado,
      contratistaId: contratistaId,
      contratistaNombre: contratistaNombre,
      contratistaIdentificacion: contratistaIdentificacion,
      cdpId: cdpId,
      numeroCDP: numeroCDP,
      rpId: rpId,
      numeroRP: numeroRP,
      fechaFirma: fechaFirma,
      fechaInicioEjecucion: fechaInicioEjecucion,
      fechaFinEjecucion: fechaFinEjecucion,
      duracionDias: duracionDias,
      estado: EstadoContrato.enFirma,
    );

    await db.insert('contratos', contrato.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'contratacion',
      accion: 'creacion_contrato',
      valorAnterior: {'proceso_id': procesoId},
      valorNuevo: {
        'contrato_id': id,
        'numero_contrato': numeroContrato,
        'cdp': numeroCDP,
        'rp': numeroRP,
      },
      referenciaId: id,
    );

    return contrato;
  }

  /// Registra una póliza de garantía
  Future<Poliza> registrarPoliza({
    required String entidadId,
    required String usuarioId,
    required String contratoId,
    required String numeroContrato,
    required TipoPoliza tipoPoliza,
    required String aseguradora,
    required double valorAsegurado,
    required DateTime fechaInicioVigencia,
    required DateTime fechaFinVigencia,
  }) async {
    final id = _uuid.v4();
    final numeroPoliza = 'PL-${DateTime.now().year}-${_generarNumeroSecuencial()}';
    final fechaEmision = DateTime.now();

    final poliza = Poliza(
      id: id,
      entidadId: entidadId,
      contratoId: contratoId,
      numeroContrato: numeroContrato,
      numeroPoliza: numeroPoliza,
      tipoPoliza: tipoPoliza,
      aseguradora: aseguradora,
      valorAsegurado: valorAsegurado,
      fechaEmision: fechaEmision,
      fechaInicioVigencia: fechaInicioVigencia,
      fechaFinVigencia: fechaFinVigencia,
      estado: EstadoPoliza.vigente,
    );

    await db.insert('polizas', poliza.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'contratacion',
      accion: 'registro_poliza',
      valorAnterior: {'contrato_id': contratoId},
      valorNuevo: {
        'poliza_id': id,
        'numero_poliza': numeroPoliza,
        'tipo_poliza': tipoPoliza.toString(),
      },
      referenciaId: id,
    );

    return poliza;
  }

  /// Legaliza un contrato
  Future<Contrato> legalizarContrato({
    required String entidadId,
    required String usuarioId,
    required String contratoId,
  }) async {
    final contratoResult = await db.query(
      'contratos',
      where: 'id = ?',
      whereArgs: [contratoId],
    );

    if (contratoResult.isEmpty) {
      throw Exception('Contrato no encontrado');
    }

    final contrato = Contrato.fromJson(contratoResult.first);

    if (!contrato.requiereLegalizacion()) {
      throw Exception('El contrato no requiere legalización');
    }

    final fechaLegalizacion = DateTime.now();

    await db.update(
      'contratos',
      {
        'estado': EstadoContrato.legalizado.toString().split('.').last,
        'fecha_legalizacion': fechaLegalizacion.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [contratoId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'contratacion',
      accion: 'legalizacion_contrato',
      valorAnterior: {'estado_anterior': contrato.estado.toString()},
      valorNuevo: {'estado_nuevo': EstadoContrato.legalizado.toString()},
      referenciaId: contratoId,
    );

    return contrato.copyWith(
      estado: EstadoContrato.legalizado,
      fechaLegalizacion: fechaLegalizacion,
    );
  }

  /// Consulta contratos por entidad
  Future<List<Contrato>> consultarContratos({
    required String entidadId,
    EstadoContrato? estado,
  }) async {
    String query = 'SELECT * FROM contratos WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado.toString().split('.').last);
    }

    query += ' ORDER BY fecha_firma DESC';

    final resultados = await db.rawQuery(query, args);

    return resultados.map((r) => Contrato.fromJson(r)).toList();
  }

  /// Consulta pólizas por contrato
  Future<List<Poliza>> consultarPolizasPorContrato(String contratoId) async {
    final resultados = await db.query(
      'polizas',
      where: 'contrato_id = ?',
      whereArgs: [contratoId],
      orderBy: 'fecha_emision DESC',
    );

    return resultados.map((r) => Poliza.fromJson(r)).toList();
  }

  TipoContrato _parseTipoContrato(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'obra':
        return TipoContrato.obra;
      case 'consultoria':
        return TipoContrato.consultoria;
      case 'suministro':
        return TipoContrato.suministro;
      case 'prestacion_servicios':
        return TipoContrato.prestacionServicios;
      case 'concesion':
        return TipoContrato.concesion;
      case 'interadministrativo':
        return TipoContrato.interadministrativo;
      default:
        return TipoContrato.otro;
    }
  }

  String _generarNumeroSecuencial() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }
}
