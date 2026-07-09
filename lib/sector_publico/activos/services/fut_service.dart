/// Servicio de FUT (Fondo de Unidad de Tesorería)
/// Manejo de recursos de terceros
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/fut.dart';
import '../../security/auditoria_service.dart';

class FUTService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  FUTService({
    required this.db,
    required this.auditoriaService,
  });

  /// Crea un FUT
  Future<FUT> crearFUT({
    required String entidadId,
    required String usuarioId,
    required String nombreFUT,
    required TipoFUT tipoFUT,
    required String terceroId,
    required String terceroNombre,
    required String terceroIdentificacion,
    required double valorInicial,
    String? numeroContrato,
    String? numeroConvenio,
    String? responsable,
  }) async {
    final id = _uuid.v4();
    final numeroFUT = 'FUT-${DateTime.now().year}-${_generarNumeroSecuencial()}';
    final fechaApertura = DateTime.now();

    final fut = FUT(
      id: id,
      entidadId: entidadId,
      numeroFUT: numeroFUT,
      nombreFUT: nombreFUT,
      tipoFUT: tipoFUT,
      numeroContrato: numeroContrato,
      numeroConvenio: numeroConvenio,
      terceroId: terceroId,
      terceroNombre: terceroNombre,
      terceroIdentificacion: terceroIdentificacion,
      valorInicial: valorInicial,
      valorEjecutado: 0,
      saldoDisponible: valorInicial,
      fechaApertura: fechaApertura,
      estado: EstadoFUT.activo,
      responsable: responsable,
    );

    await db.insert('fut', fut.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'activos',
      accion: 'creacion_fut',
      valorAnterior: {},
      valorNuevo: {
        'fut_id': id,
        'numero_fut': numeroFUT,
        'valor_inicial': valorInicial,
      },
      referenciaId: id,
    );

    return fut;
  }

  /// Registra una ejecución en el FUT
  Future<FUT> registrarEjecucion({
    required String entidadId,
    required String usuarioId,
    required String futId,
    required double montoEjecucion,
  }) async {
    final futResult = await db.query(
      'fut',
      where: 'id = ?',
      whereArgs: [futId],
    );

    if (futResult.isEmpty) {
      throw Exception('FUT no encontrado');
    }

    final fut = FUT.fromJson(futResult.first);

    if (!fut.estaActivo()) {
      throw Exception('El FUT no está activo');
    }

    if (montoEjecucion > fut.saldoDisponible) {
      throw Exception('El monto excede el saldo disponible');
    }

    final nuevoValorEjecutado = fut.valorEjecutado + montoEjecucion;
    final nuevoSaldo = fut.saldoDisponible - montoEjecucion;

    await db.update(
      'fut',
      {
        'valor_ejecutado': nuevoValorEjecutado,
        'saldo_disponible': nuevoSaldo,
        'estado': EstadoFUT.enEjecucion.toString().split('.').last,
      },
      where: 'id = ?',
      whereArgs: [futId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'activos',
      accion: 'ejecucion_fut',
      valorAnterior: {
        'valor_ejecutado_anterior': fut.valorEjecutado,
        'saldo_anterior': fut.saldoDisponible,
      },
      valorNuevo: {
        'monto_ejecucion': montoEjecucion,
        'valor_ejecutado_nuevo': nuevoValorEjecutado,
        'saldo_nuevo': nuevoSaldo,
      },
      referenciaId: futId,
    );

    return fut.copyWith(
      valorEjecutado: nuevoValorEjecutado,
      saldoDisponible: nuevoSaldo,
      estado: EstadoFUT.enEjecucion,
    );
  }

  /// Cierra un FUT
  Future<FUT> cerrarFUT({
    required String entidadId,
    required String usuarioId,
    required String futId,
  }) async {
    final futResult = await db.query(
      'fut',
      where: 'id = ?',
      whereArgs: [futId],
    );

    if (futResult.isEmpty) {
      throw Exception('FUT no encontrado');
    }

    final fut = FUT.fromJson(futResult.first);

    if (fut.saldoDisponible > 0) {
      throw Exception('No se puede cerrar FUT con saldo disponible');
    }

    final fechaCierre = DateTime.now();

    await db.update(
      'fut',
      {
        'estado': EstadoFUT.terminado.toString().split('.').last,
        'fecha_cierre': fechaCierre.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [futId],
    );

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.modificacionRegistro,
      modulo: 'activos',
      accion: 'cierre_fut',
      valorAnterior: {'estado_anterior': fut.estado.toString()},
      valorNuevo: {
        'estado_nuevo': EstadoFUT.terminado.toString(),
        'fecha_cierre': fechaCierre.toIso8601String(),
      },
      referenciaId: futId,
    );

    return fut.copyWith(
      estado: EstadoFUT.terminado,
      fechaCierre: fechaCierre,
    );
  }

  Future<List<FUT>> consultarFUT({
    required String entidadId,
    EstadoFUT? estado,
  }) async {
    String query = 'SELECT * FROM fut WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (estado != null) {
      query += ' AND estado = ?';
      args.add(estado.toString().split('.').last);
    }

    query += ' ORDER BY fecha_apertura DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados.map((r) => FUT.fromJson(r)).toList();
  }

  String _generarNumeroSecuencial() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }
}
