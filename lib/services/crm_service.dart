import '../models/crm_opportunity.dart';
import '../db_helper.dart';

class CrmService {
  CrmService._();

  static final CrmService instance = CrmService._();

  Future<int> crearOportunidad({
    required int clienteId,
    required String clienteNombre,
    required String titulo,
    required double valorEstimado,
    required DateTime fechaCierreEstimada,
    int? vendedorId,
    String? vendedorNombre,
    String? descripcion,
    PrioridadOportunidad prioridad = PrioridadOportunidad.media,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final etapaInicial = EtapaOportunidad.prospecto;
    final probabilidad = CrmOpportunity.calcularProbabilidadPorEtapa(etapaInicial);

    final id = await db.insert('crm_oportunidades', {
      'company_id': companyId,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'titulo': titulo,
      'etapa': etapaInicial.name,
      'valor_estimado': valorEstimado,
      'probabilidad': probabilidad,
      'fecha_cierre_estimada': fechaCierreEstimada.toIso8601String(),
      'creado_en': DateTime.now().toIso8601String(),
      'vendedor_id': vendedorId,
      'vendedor_nombre': vendedorNombre,
      'descripcion': descripcion,
      'prioridad': prioridad.name,
      'ultima_actividad': DateTime.now().toIso8601String(),
      'actualizado_en': DateTime.now().toIso8601String(),
    });

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_OPORTUNIDAD_CREADA',
      entidad: 'crm',
      detalle: 'ID: $id, Cliente: $clienteNombre, Valor: $valorEstimado',
    );

    return id;
  }

  Future<CrmOpportunity?> obtenerOportunidad(int id) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final rows = await db.query(
      'crm_oportunidades',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return CrmOpportunity.fromMap(rows.first);
  }

  Future<List<CrmOpportunity>> listarOportunidades({
    EtapaOportunidad? etapa,
    int? clienteId,
    int? vendedorId,
    DateTime? desde,
    DateTime? hasta,
    bool soloActivas = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    String where = 'company_id = ?';
    List<dynamic> whereArgs = [companyId];

    if (etapa != null) {
      where += ' AND etapa = ?';
      whereArgs.add(etapa.name);
    }

    if (clienteId != null) {
      where += ' AND cliente_id = ?';
      whereArgs.add(clienteId);
    }

    if (vendedorId != null) {
      where += ' AND vendedor_id = ?';
      whereArgs.add(vendedorId);
    }

    if (desde != null) {
      where += ' AND creado_en >= ?';
      whereArgs.add(desde.toIso8601String());
    }

    if (hasta != null) {
      where += ' AND creado_en <= ?';
      whereArgs.add(hasta.toIso8601String());
    }

    if (soloActivas) {
      where += ' AND etapa NOT IN (?, ?)';
      whereArgs.addAll([EtapaOportunidad.ganado.name, EtapaOportunidad.perdido.name]);
    }

    final rows = await db.query(
      'crm_oportunidades',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'actualizado_en DESC',
    );

    return rows.map((row) => CrmOpportunity.fromMap(row)).toList();
  }

  Future<void> actualizarEtapa(int id, EtapaOportunidad nuevaEtapa) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final nuevaProbabilidad = CrmOpportunity.calcularProbabilidadPorEtapa(nuevaEtapa);

    await db.update(
      'crm_oportunidades',
      {
        'etapa': nuevaEtapa.name,
        'probabilidad': nuevaProbabilidad,
        'ultima_actividad': DateTime.now().toIso8601String(),
        'actualizado_en': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_OPORTUNIDAD_ETAPA_ACTUALIZADA',
      entidad: 'crm',
      detalle: 'ID: $id, Nueva Etapa: ${nuevaEtapa.name}',
    );
  }

  Future<void> marcarGanada(int id) async {
    await actualizarEtapa(id, EtapaOportunidad.ganado);

    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    await db.update(
      'crm_oportunidades',
      {'actualizado_en': DateTime.now().toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_OPORTUNIDAD_GANADA',
      entidad: 'crm',
      detalle: 'ID: $id',
    );
  }

  Future<void> marcarPerdida(int id, String motivo) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    await db.update(
      'crm_oportunidades',
      {
        'etapa': EtapaOportunidad.perdido.name,
        'probabilidad': 0,
        'motivo_perdida': motivo,
        'ultima_actividad': DateTime.now().toIso8601String(),
        'actualizado_en': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_OPORTUNIDAD_PERDIDA',
      entidad: 'crm',
      detalle: 'ID: $id, Motivo: $motivo',
    );
  }

  Future<void> actualizarOportunidad(int id, {
    String? titulo,
    double? valorEstimado,
    DateTime? fechaCierreEstimada,
    String? descripcion,
    PrioridadOportunidad? prioridad,
    int? probabilidad,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final updates = <String, dynamic>{
      'ultima_actividad': DateTime.now().toIso8601String(),
      'actualizado_en': DateTime.now().toIso8601String(),
    };

    if (titulo != null) updates['titulo'] = titulo;
    if (valorEstimado != null) updates['valor_estimado'] = valorEstimado;
    if (fechaCierreEstimada != null) updates['fecha_cierre_estimada'] = fechaCierreEstimada.toIso8601String();
    if (descripcion != null) updates['descripcion'] = descripcion;
    if (prioridad != null) updates['prioridad'] = prioridad.name;
    if (probabilidad != null) updates['probabilidad'] = probabilidad;

    await db.update(
      'crm_oportunidades',
      updates,
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_OPORTUNIDAD_ACTUALIZADA',
      entidad: 'crm',
      detalle: 'ID: $id',
    );
  }

  Future<void> eliminarOportunidad(int id) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    await db.delete(
      'crm_oportunidades',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_OPORTUNIDAD_ELIMINADA',
      entidad: 'crm',
      detalle: 'ID: $id',
    );
  }

  // Actividades
  Future<int> crearActividad({
    required int oportunidadId,
    required String tipo,
    required String descripcion,
    int? usuarioId,
    String? usuarioNombre,
    String? resultado,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final id = await db.insert('crm_actividades', {
      'company_id': companyId,
      'oportunidad_id': oportunidadId,
      'tipo': tipo,
      'descripcion': descripcion,
      'fecha': DateTime.now().toIso8601String(),
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'resultado': resultado,
    });

    // Actualizar última actividad de la oportunidad
    await db.update(
      'crm_oportunidades',
      {'ultima_actividad': DateTime.now().toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [oportunidadId, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CRM_ACTIVIDAD_CREADA',
      entidad: 'crm',
      detalle: 'Oportunidad ID: $oportunidadId, Tipo: $tipo',
    );

    return id;
  }

  Future<List<CrmActividad>> listarActividades(int oportunidadId) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final rows = await db.query(
      'crm_actividades',
      where: 'oportunidad_id = ? AND company_id = ?',
      whereArgs: [oportunidadId, companyId],
      orderBy: 'fecha DESC',
    );

    return rows.map((row) => CrmActividad.fromMap(row)).toList();
  }

  // Métricas
  Future<Map<String, dynamic>> obtenerMetricasPipeline() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final activas = await listarOportunidades(soloActivas: true);

    final porEtapa = <String, List<CrmOpportunity>>{};
    for (final etapa in EtapaOportunidad.values) {
      porEtapa[etapa.name] = [];
    }

    double valorTotal = 0;
    double valorPonderado = 0;

    for (final op in activas) {
      porEtapa[op.etapa.name]!.add(op);
      valorTotal += op.valorEstimado;
      valorPonderado += op.valorEstimado * (op.probabilidad / 100);
    }

    return {
      'total_oportunidades': activas.length,
      'valor_total': valorTotal,
      'valor_ponderado': valorPonderado,
      'por_etapa': porEtapa.map((k, v) => MapEntry(k, {
        'cantidad': v.length,
        'valor': v.fold<double>(0, (sum, op) => sum + op.valorEstimado),
      })),
    };
  }

  Future<List<CrmOpportunity>> obtenerOportunidadesVencidas() async {
    final activas = await listarOportunidades(soloActivas: true);
    return activas.where((op) => op.estaVencida).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerResumenPorCliente() async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final rows = await db.rawQuery('''
      SELECT 
        cliente_id,
        cliente_nombre,
        COUNT(*) as total_oportunidades,
        SUM(CASE WHEN etapa = 'ganado' THEN 1 ELSE 0 END) as ganadas,
        SUM(CASE WHEN etapa = 'perdido' THEN 1 ELSE 0 END) as perdidas,
        SUM(valor_estimado) as valor_total
      FROM crm_oportunidades
      WHERE company_id = ?
      GROUP BY cliente_id, cliente_nombre
      ORDER BY valor_total DESC
    ''', [companyId]);

    return rows.map((row) => row as Map<String, dynamic>).toList();
  }
}
