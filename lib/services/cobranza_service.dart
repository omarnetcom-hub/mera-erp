import 'dart:convert';
import '../db_helper.dart';

enum TipoAccionCobranza {
  recordatorioEmail,
  recordatorioSMS,
  llamada,
  visita,
  suspensionCredito,
  reporteCentralRiesgo,
}

enum EstadoAccionCobranza { pendiente, programada, ejecutada, fallida, cancelada }

class ReglaCobranza {
  const ReglaCobranza({
    required this.diasVencimiento,
    required this.tipoAccion,
    required this.prioridad,
    this.mensajePersonalizado,
  });

  final int diasVencimiento;
  final TipoAccionCobranza tipoAccion;
  final int prioridad; // 1-10, mayor = más urgente
  final String? mensajePersonalizado;

  Map<String, dynamic> toJson() {
    return {
      'dias_vencimiento': diasVencimiento,
      'tipo_accion': tipoAccion.name,
      'prioridad': prioridad,
      'mensaje_personalizado': mensajePersonalizado,
    };
  }

  static ReglaCobranza fromJson(Map<String, dynamic> json) {
    return ReglaCobranza(
      diasVencimiento: json['dias_vencimiento'] as int,
      tipoAccion: TipoAccionCobranza.values.firstWhere(
        (e) => e.name == json['tipo_accion'],
        orElse: () => TipoAccionCobranza.recordatorioEmail,
      ),
      prioridad: json['prioridad'] as int? ?? 5,
      mensajePersonalizado: json['mensaje_personalizado'] as String?,
    );
  }
}

class CampanaCobranza {
  const CampanaCobranza({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.reglas,
    required this.activa,
    required this.creadaEn,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final List<ReglaCobranza> reglas;
  final bool activa;
  final DateTime creadaEn;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'reglas': jsonEncode(reglas.map((r) => r.toJson()).toList()),
      'activa': activa ? 1 : 0,
      'creada_en': creadaEn.toIso8601String(),
    };
  }

  static CampanaCobranza fromMap(Map<String, dynamic> map) {
    final reglasJson = jsonDecode(map['reglas'] as String) as List;
    final reglas = reglasJson
        .map((r) => ReglaCobranza.fromJson(r as Map<String, dynamic>))
        .toList();

    return CampanaCobranza(
      id: map['id'] as int,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      reglas: reglas,
      activa: (map['activa'] as int) == 1,
      creadaEn: DateTime.parse(map['creada_en'] as String),
    );
  }
}

class AccionCobranza {
  const AccionCobranza({
    required this.id,
    required this.campanaId,
    required this.cuentaId,
    required this.tipo,
    required this.estado,
    required this.programadaPara,
    this.ejecutadaEn,
    this.resultado,
  });

  final int id;
  final int campanaId;
  final int cuentaId;
  final TipoAccionCobranza tipo;
  final EstadoAccionCobranza estado;
  final DateTime programadaPara;
  final DateTime? ejecutadaEn;
  final String? resultado;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'campana_id': campanaId,
      'cuenta_id': cuentaId,
      'tipo': tipo.name,
      'estado': estado.name,
      'programada_para': programadaPara.toIso8601String(),
      'ejecutada_en': ejecutadaEn?.toIso8601String(),
      'resultado': resultado,
    };
  }

  static AccionCobranza fromMap(Map<String, dynamic> map) {
    return AccionCobranza(
      id: map['id'] as int,
      campanaId: map['campana_id'] as int,
      cuentaId: map['cuenta_id'] as int,
      tipo: TipoAccionCobranza.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoAccionCobranza.recordatorioEmail,
      ),
      estado: EstadoAccionCobranza.values.firstWhere(
        (e) => e.name == map['estado'],
        orElse: () => EstadoAccionCobranza.pendiente,
      ),
      programadaPara: DateTime.parse(map['programada_para'] as String),
      ejecutadaEn: map['ejecutada_en'] != null
          ? DateTime.parse(map['ejecutada_en'] as String)
          : null,
      resultado: map['resultado'] as String?,
    );
  }
}

class CobranzaService {
  CobranzaService._();

  static final CobranzaService instance = CobranzaService._();

  Future<int> crearCampana({
    required String nombre,
    String? descripcion,
    required List<ReglaCobranza> reglas,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final id = await db.insert('cobranza_campanas', {
      'company_id': companyId,
      'nombre': nombre,
      'descripcion': descripcion,
      'reglas': jsonEncode(reglas.map((r) => r.toJson()).toList()),
      'activa': 1,
      'creada_en': DateTime.now().toIso8601String(),
    });

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'COBRANZA_CAMPAÑA_CREADA',
      entidad: 'cobranza',
      detalle: 'ID: $id, Nombre: $nombre',
    );

    return id;
  }

  Future<List<CampanaCobranza>> listarCampanas({bool soloActivas = false}) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    String where = 'company_id = ?';
    List<dynamic> whereArgs = [companyId];

    if (soloActivas) {
      where += ' AND activa = ?';
      whereArgs.add(1);
    }

    final rows = await db.query(
      'cobranza_campanas',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'creada_en DESC',
    );

    return rows.map((row) => CampanaCobranza.fromMap(row)).toList();
  }

  Future<void> activarCampana(int id, bool activa) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    await db.update(
      'cobranza_campanas',
      {'activa': activa ? 1 : 0},
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'COBRANZA_CAMPAÑA_' + (activa ? 'ACTIVADA' : 'DESACTIVADA'),
      entidad: 'cobranza',
      detalle: 'ID: $id',
    );
  }

  Future<void> procesarCampanasActivas() async {
    final campanas = await listarCampanas(soloActivas: true);

    for (final campana in campanas) {
      await _procesarCampana(campana);
    }
  }

  Future<void> _procesarCampana(CampanaCobranza campana) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    // Obtener cuentas por cobrar vencidas
    final cuentasVencidas = await db.query(
      'cuentas_por_cobrar',
      where: 'company_id = ? AND estado = ? AND fecha_vencimiento < ?',
      whereArgs: [companyId, 'pendiente', DateTime.now().toIso8601String()],
    );

    for (final cuenta in cuentasVencidas) {
      final fechaVencimiento = DateTime.parse(cuenta['fecha_vencimiento'] as String);
      final diasVencidos = DateTime.now().difference(fechaVencimiento).inDays;

      for (final regla in campana.reglas) {
        if (diasVencidos >= regla.diasVencimiento) {
          // Verificar si ya existe una acción similar para esta cuenta
          final accionesExistentes = await db.query(
            'cobranza_acciones',
            where: 'campana_id = ? AND cuenta_id = ? AND tipo = ? AND estado != ?',
            whereArgs: [
              campana.id,
              cuenta['id'],
              regla.tipoAccion.name,
              EstadoAccionCobranza.ejecutada.name,
            ],
          );

          if (accionesExistentes.isEmpty) {
            await _crearAccionCobranza(
              campanaId: campana.id,
              cuentaId: cuenta['id'] as int,
              regla: regla,
              cuenta: cuenta,
            );
          }
        }
      }
    }
  }

  Future<void> _crearAccionCobranza({
    required int campanaId,
    required int cuentaId,
    required ReglaCobranza regla,
    required Map<String, dynamic> cuenta,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    // Calcular fecha de ejecución según prioridad
    final diasRetraso = regla.prioridad > 7 ? 1 : (regla.prioridad > 4 ? 3 : 7);
    final programadaPara = DateTime.now().add(Duration(days: diasRetraso));

    await db.insert('cobranza_acciones', {
      'company_id': companyId,
      'campana_id': campanaId,
      'cuenta_id': cuentaId,
      'tipo': regla.tipoAccion.name,
      'estado': EstadoAccionCobranza.programada.name,
      'programada_para': programadaPara.toIso8601String(),
    });

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'COBRANZA_ACCION_CREADA',
      entidad: 'cobranza',
      detalle: 'Cuenta ID: $cuentaId, Tipo: ${regla.tipoAccion.name}',
    );
  }

  Future<List<AccionCobranza>> listarAccionesPendientes() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    final ahora = DateTime.now().toIso8601String();

    final rows = await db.query(
      'cobranza_acciones',
      where: 'company_id = ? AND estado = ? AND programada_para <= ?',
      whereArgs: [companyId, EstadoAccionCobranza.programada.name, ahora],
      orderBy: 'programada_para ASC',
    );

    return rows.map((row) => AccionCobranza.fromMap(row)).toList();
  }

  Future<void> ejecutarAccion(int accionId) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final acciones = await db.query(
      'cobranza_acciones',
      where: 'id = ? AND company_id = ?',
      whereArgs: [accionId, companyId],
      limit: 1,
    );

    if (acciones.isEmpty) return;

    final accion = AccionCobranza.fromMap(acciones.first);

    try {
      // Aquí se implementaría la lógica de ejecución según el tipo
      String resultado = '';

      switch (accion.tipo) {
        case TipoAccionCobranza.recordatorioEmail:
          resultado = await _enviarRecordatorioEmail(accion);
          break;
        case TipoAccionCobranza.recordatorioSMS:
          resultado = await _enviarRecordatorioSMS(accion);
          break;
        case TipoAccionCobranza.llamada:
          resultado = 'Llamada programada - requiere ejecución manual';
          break;
        case TipoAccionCobranza.visita:
          resultado = 'Visita programada - requiere ejecución manual';
          break;
        case TipoAccionCobranza.suspensionCredito:
          resultado = await _suspenderCredito(accion);
          break;
        case TipoAccionCobranza.reporteCentralRiesgo:
          resultado = await _reportarCentralRiesgo(accion);
          break;
      }

      await db.update(
        'cobranza_acciones',
        {
          'estado': EstadoAccionCobranza.ejecutada.name,
          'ejecutada_en': DateTime.now().toIso8601String(),
          'resultado': resultado,
        },
        where: 'id = ?',
        whereArgs: [accionId],
      );

      await DatabaseHelper.instance.registrarEventoAuditoria(
        accion: 'COBRANZA_ACCION_EJECUTADA',
        entidad: 'cobranza',
        detalle: 'Acción ID: $accionId, Resultado: $resultado',
      );
    } catch (e) {
      await db.update(
        'cobranza_acciones',
        {
          'estado': EstadoAccionCobranza.fallida.name,
          'ejecutada_en': DateTime.now().toIso8601String(),
          'resultado': 'Error: $e',
        },
        where: 'id = ?',
        whereArgs: [accionId],
      );
    }
  }

  Future<String> _enviarRecordatorioEmail(AccionCobranza accion) async {
    // Implementación simulada - en producción se usaría un servicio de email
    return 'Email enviado exitosamente';
  }

  Future<String> _enviarRecordatorioSMS(AccionCobranza accion) async {
    // Implementación simulada - en producción se usaría un servicio de SMS
    return 'SMS enviado exitosamente';
  }

  Future<String> _suspenderCredito(AccionCobranza accion) async {
    final db = await DatabaseHelper.instance.database;
    
    // Marcar cliente como con crédito suspendido
    await db.update(
      'clientes',
      {'estado': 'credito_suspendido'},
      where: 'id = ?',
      whereArgs: [accion.cuentaId],
    );

    return 'Crédito suspendido exitosamente';
  }

  Future<String> _reportarCentralRiesgo(AccionCobranza accion) async {
    // Implementación simulada - en producción se reportaría a Datacrédito/TransUnion
    return 'Reporte enviado a central de riesgos';
  }

  Future<Map<String, dynamic>> obtenerMetricasCobranza() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final cuentas = await db.query(
      'cuentas_por_cobrar',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );

    double totalVencido = 0;
    double totalPorVencer = 0;
    int cuentasVencidas = 0;
    int cuentasPorVencer = 0;

    final ahora = DateTime.now();

    for (final cuenta in cuentas) {
      final fechaVencimiento = DateTime.parse(cuenta['fecha_vencimiento'] as String);
      final saldo = (cuenta['saldo'] as num).toDouble();

      if (ahora.isAfter(fechaVencimiento)) {
        totalVencido += saldo;
        cuentasVencidas++;
      } else {
        totalPorVencer += saldo;
        cuentasPorVencer++;
      }
    }

    final accionesPendientes = await listarAccionesPendientes();

    return {
      'total_cuentas': cuentas.length,
      'cuentas_vencidas': cuentasVencidas,
      'cuentas_por_vencer': cuentasPorVencer,
      'total_vencido': totalVencido,
      'total_por_vencer': totalPorVencer,
      'acciones_pendientes': accionesPendientes.length,
    };
  }
}
