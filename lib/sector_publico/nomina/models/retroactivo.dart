/// Modelo de Retroactivo
/// Cálculo de retroactivos por ajustes salariales o sentencias
library;


enum TipoRetroactivo {
  ajusteSalarial,
  sentenciaJudicial,
  conciliacion,
  reconocimientoAntiguedad,
  otro,
}

enum EstadoRetroactivo {
  calculado,
  aprobado,
  enPago,
  pagado,
  anulado,
}

class Retroactivo {
  final String id;
  final String entidadId;
  final String numeroRetroactivo; // Formato: RT-YYYY-NNNNNN
  final String empleadoId;
  final String empleadoNombre;
  final String empleadoIdentificacion;
  final TipoRetroactivo tipoRetroactivo;
  final String motivo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int meses;
  final double salarioAnterior;
  final double salarioNuevo;
  final double diferenciaMensual;
  final double valorTotal;
  final double valorPagado;
  final double saldoPendiente;
  final EstadoRetroactivo estado;
  final DateTime fechaCalculo;
  final DateTime? fechaAprobacion;
  final String? actoAdministrativo;
  final String? observaciones;

  Retroactivo({
    required this.id,
    required this.entidadId,
    required this.numeroRetroactivo,
    required this.empleadoId,
    required this.empleadoNombre,
    required this.empleadoIdentificacion,
    required this.tipoRetroactivo,
    required this.motivo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.meses,
    required this.salarioAnterior,
    required this.salarioNuevo,
    required this.diferenciaMensual,
    required this.valorTotal,
    required this.valorPagado,
    required this.saldoPendiente,
    required this.estado,
    required this.fechaCalculo,
    this.fechaAprobacion,
    this.actoAdministrativo,
    this.observaciones,
  });

  factory Retroactivo.fromJson(Map<String, dynamic> json) {
    return Retroactivo(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroRetroactivo: json['numero_retroactivo'] as String,
      empleadoId: json['empleado_id'] as String,
      empleadoNombre: json['empleado_nombre'] as String,
      empleadoIdentificacion: json['empleado_identificacion'] as String,
      tipoRetroactivo: TipoRetroactivo.values.firstWhere(
        (e) => e.toString() == 'TipoRetroactivo.${json['tipo_retroactivo']}',
      ),
      motivo: json['motivo'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: DateTime.parse(json['fecha_fin'] as String),
      meses: json['meses'] as int,
      salarioAnterior: (json['salario_anterior'] as num).toDouble(),
      salarioNuevo: (json['salario_nuevo'] as num).toDouble(),
      diferenciaMensual: (json['diferencia_mensual'] as num).toDouble(),
      valorTotal: (json['valor_total'] as num).toDouble(),
      valorPagado: (json['valor_pagado'] as num).toDouble(),
      saldoPendiente: (json['saldo_pendiente'] as num).toDouble(),
      estado: EstadoRetroactivo.values.firstWhere(
        (e) => e.toString() == 'EstadoRetroactivo.${json['estado']}',
      ),
      fechaCalculo: DateTime.parse(json['fecha_calculo'] as String),
      fechaAprobacion: json['fecha_aprobacion'] != null
          ? DateTime.parse(json['fecha_aprobacion'] as String)
          : null,
      actoAdministrativo: json['acto_administrativo'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_retroactivo': numeroRetroactivo,
      'empleado_id': empleadoId,
      'empleado_nombre': empleadoNombre,
      'empleado_identificacion': empleadoIdentificacion,
      'tipo_retroactivo': tipoRetroactivo.toString().split('.').last,
      'motivo': motivo,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'meses': meses,
      'salario_anterior': salarioAnterior,
      'salario_nuevo': salarioNuevo,
      'diferencia_mensual': diferenciaMensual,
      'valor_total': valorTotal,
      'valor_pagado': valorPagado,
      'saldo_pendiente': saldoPendiente,
      'estado': estado.toString().split('.').last,
      'fecha_calculo': fechaCalculo.toIso8601String(),
      'fecha_aprobacion': fechaAprobacion?.toIso8601String(),
      'acto_administrativo': actoAdministrativo,
      'observaciones': observaciones,
    };
  }

  bool estaPagado() {
    return estado == EstadoRetroactivo.pagado || saldoPendiente == 0;
  }

  Retroactivo copyWith({
    String? id,
    String? entidadId,
    String? numeroRetroactivo,
    String? empleadoId,
    String? empleadoNombre,
    String? empleadoIdentificacion,
    TipoRetroactivo? tipoRetroactivo,
    String? motivo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? meses,
    double? salarioAnterior,
    double? salarioNuevo,
    double? diferenciaMensual,
    double? valorTotal,
    double? valorPagado,
    double? saldoPendiente,
    EstadoRetroactivo? estado,
    DateTime? fechaCalculo,
    DateTime? fechaAprobacion,
    String? actoAdministrativo,
    String? observaciones,
  }) {
    return Retroactivo(
      id: id ?? this.id,
      entidadId: entidadId ?? this.entidadId,
      numeroRetroactivo: numeroRetroactivo ?? this.numeroRetroactivo,
      empleadoId: empleadoId ?? this.empleadoId,
      empleadoNombre: empleadoNombre ?? this.empleadoNombre,
      empleadoIdentificacion: empleadoIdentificacion ?? this.empleadoIdentificacion,
      tipoRetroactivo: tipoRetroactivo ?? this.tipoRetroactivo,
      motivo: motivo ?? this.motivo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      meses: meses ?? this.meses,
      salarioAnterior: salarioAnterior ?? this.salarioAnterior,
      salarioNuevo: salarioNuevo ?? this.salarioNuevo,
      diferenciaMensual: diferenciaMensual ?? this.diferenciaMensual,
      valorTotal: valorTotal ?? this.valorTotal,
      valorPagado: valorPagado ?? this.valorPagado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      estado: estado ?? this.estado,
      fechaCalculo: fechaCalculo ?? this.fechaCalculo,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      actoAdministrativo: actoAdministrativo ?? this.actoAdministrativo,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
