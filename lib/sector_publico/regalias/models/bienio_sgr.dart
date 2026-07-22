/// Modelo de Bienio Presupuestal SGR (Sistema General de Regalías - Colombia)
/// Ley 2056 de 2020 - Ciclo presupuestal bienal (2 años)
library;

enum EstadoBienioSGR {
  vigente,
  cerrado,
}

class BienioSGR {
  final String id;
  final String entidadId;
  final String codigoBienio; // Formato bienal: 2025-2026
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final double montoPresupuestadoBienio;
  final double montoEjecutadoBienio;
  final EstadoBienioSGR estado;
  final String? observaciones;

  BienioSGR({
    required this.id,
    required this.entidadId,
    required this.codigoBienio,
    required this.fechaInicio,
    required this.fechaFin,
    required this.montoPresupuestadoBienio,
    required this.montoEjecutadoBienio,
    required this.estado,
    this.observaciones,
  });

  factory BienioSGR.fromJson(Map<String, dynamic> json) {
    return BienioSGR(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      codigoBienio: json['codigo_bienio'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: DateTime.parse(json['fecha_fin'] as String),
      montoPresupuestadoBienio: (json['monto_presupuestado_bienio'] as num).toDouble(),
      montoEjecutadoBienio: (json['monto_ejecutado_bienio'] as num?)?.toDouble() ?? 0.0,
      estado: EstadoBienioSGR.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoBienioSGR.vigente,
      ),
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'codigo_bienio': codigoBienio,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'monto_presupuestado_bienio': montoPresupuestadoBienio,
      'monto_ejecutado_bienio': montoEjecutadoBienio,
      'estado': estado.name,
      'observaciones': observaciones,
    };
  }

  bool get estaVigente => estado == EstadoBienioSGR.vigente;
}
