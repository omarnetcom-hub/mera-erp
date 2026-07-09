/// Modelo de Apropiación Presupuestal
/// Primera etapa del flujo: APROPIACIÓN → CDP → RP → OBLIGACIÓN → PAGO
library;


class Apropiacion {
  final String id;
  final String entidadId;
  final String vigencia; // Año fiscal (ej. "2026")
  final String codigoRubro; // Código del rubro presupuestal
  final String nombreRubro;
  final double valorInicial;
  double valorApropiado;
  double valorCDP;
  double valorRP;
  double valorObligado;
  double valorPagado;
  double saldoDisponible;
  final String fuenteFinanciacion;
  final String sector;
  final String programa;
  final String subprograma;
  final String proyecto; // Vinculado a Banco de Proyectos MGA
  final String actividad;
  final String objetoGasto;
  final DateTime fechaCreacion;
  final DateTime fechaAprobacionConcejo;
  final String actoAdministrativo; // Número del acuerdo/ordenanza
  final bool activo;
  final String? observaciones;

  Apropiacion({
    required this.id,
    required this.entidadId,
    required this.vigencia,
    required this.codigoRubro,
    required this.nombreRubro,
    required this.valorInicial,
    required this.valorApropiado,
    required this.valorCDP,
    required this.valorRP,
    required this.valorObligado,
    required this.valorPagado,
    required this.saldoDisponible,
    required this.fuenteFinanciacion,
    required this.sector,
    required this.programa,
    required this.subprograma,
    required this.proyecto,
    required this.actividad,
    required this.objetoGasto,
    required this.fechaCreacion,
    required this.fechaAprobacionConcejo,
    required this.actoAdministrativo,
    required this.activo,
    this.observaciones,
  });

  factory Apropiacion.fromJson(Map<String, dynamic> json) {
    return Apropiacion(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      vigencia: json['vigencia'] as String,
      codigoRubro: json['codigo_rubro'] as String,
      nombreRubro: json['nombre_rubro'] as String,
      valorInicial: (json['valor_inicial'] as num).toDouble(),
      valorApropiado: (json['valor_apropiado'] as num).toDouble(),
      valorCDP: (json['valor_cdp'] as num).toDouble(),
      valorRP: (json['valor_rp'] as num).toDouble(),
      valorObligado: (json['valor_obligado'] as num).toDouble(),
      valorPagado: (json['valor_pagado'] as num).toDouble(),
      saldoDisponible: (json['saldo_disponible'] as num).toDouble(),
      fuenteFinanciacion: json['fuente_financiacion'] as String,
      sector: json['sector'] as String,
      programa: json['programa'] as String,
      subprograma: json['subprograma'] as String,
      proyecto: json['proyecto'] as String,
      actividad: json['actividad'] as String,
      objetoGasto: json['objeto_gasto'] as String,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      fechaAprobacionConcejo: DateTime.parse(json['fecha_aprobacion_concejo'] as String),
      actoAdministrativo: json['acto_administrativo'] as String,
      activo: json['activo'] as bool,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'vigencia': vigencia,
      'codigo_rubro': codigoRubro,
      'nombre_rubro': nombreRubro,
      'valor_inicial': valorInicial,
      'valor_apropiado': valorApropiado,
      'valor_cdp': valorCDP,
      'valor_rp': valorRP,
      'valor_obligado': valorObligado,
      'valor_pagado': valorPagado,
      'saldo_disponible': saldoDisponible,
      'fuente_financiacion': fuenteFinanciacion,
      'sector': sector,
      'programa': programa,
      'subprograma': subprograma,
      'proyecto': proyecto,
      'actividad': actividad,
      'objeto_gasto': objetoGasto,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_aprobacion_concejo': fechaAprobacionConcejo.toIso8601String(),
      'acto_administrativo': actoAdministrativo,
      'activo': activo,
      'observaciones': observaciones,
    };
  }

  /// Calcula el saldo disponible para expedir CDP
  /// Saldo = Valor Apropiado - Valor CDP - Valor RP
  double calcularSaldoDisponibleCDP() {
    return valorApropiado - valorCDP - valorRP;
  }

  /// Verifica si hay disponibilidad para un monto específico
  bool tieneDisponibilidad(double monto) {
    return calcularSaldoDisponibleCDP() >= monto;
  }

  /// Actualiza los valores después de una operación
  void actualizarValores({
    double? valorCDPAdicional,
    double? valorRPAdicional,
    double? valorObligadoAdicional,
    double? valorPagadoAdicional,
  }) {
    valorCDP += valorCDPAdicional ?? 0;
    valorRP += valorRPAdicional ?? 0;
    valorObligado += valorObligadoAdicional ?? 0;
    valorPagado += valorPagadoAdicional ?? 0;
    saldoDisponible = calcularSaldoDisponibleCDP();
  }

  Apropiacion copyWith({
    String? id,
    String? entidadId,
    String? vigencia,
    String? codigoRubro,
    String? nombreRubro,
    double? valorInicial,
    double? valorApropiado,
    double? valorCDP,
    double? valorRP,
    double? valorObligado,
    double? valorPagado,
    double? saldoDisponible,
    String? fuenteFinanciacion,
    String? sector,
    String? programa,
    String? subprograma,
    String? proyecto,
    String? actividad,
    String? objetoGasto,
    DateTime? fechaCreacion,
    DateTime? fechaAprobacionConcejo,
    String? actoAdministrativo,
    bool? activo,
    String? observaciones,
  }) {
    return Apropiacion(
      id: id ?? this.id,
      entidadId: entidadId ?? this.entidadId,
      vigencia: vigencia ?? this.vigencia,
      codigoRubro: codigoRubro ?? this.codigoRubro,
      nombreRubro: nombreRubro ?? this.nombreRubro,
      valorInicial: valorInicial ?? this.valorInicial,
      valorApropiado: valorApropiado ?? this.valorApropiado,
      valorCDP: valorCDP ?? this.valorCDP,
      valorRP: valorRP ?? this.valorRP,
      valorObligado: valorObligado ?? this.valorObligado,
      valorPagado: valorPagado ?? this.valorPagado,
      saldoDisponible: saldoDisponible ?? this.saldoDisponible,
      fuenteFinanciacion: fuenteFinanciacion ?? this.fuenteFinanciacion,
      sector: sector ?? this.sector,
      programa: programa ?? this.programa,
      subprograma: subprograma ?? this.subprograma,
      proyecto: proyecto ?? this.proyecto,
      actividad: actividad ?? this.actividad,
      objetoGasto: objetoGasto ?? this.objetoGasto,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaAprobacionConcejo: fechaAprobacionConcejo ?? this.fechaAprobacionConcejo,
      actoAdministrativo: actoAdministrativo ?? this.actoAdministrativo,
      activo: activo ?? this.activo,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
