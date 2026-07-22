/// Modelo de Contrato EPS / ADRES para servicios de Salud Pública / ESE Hospital
library;

enum RegimenSalud {
  subsidiado,
  contributivo,
  vinculado,
  especial,
}

class ContratoEPS {
  final String id;
  final String entidadId;
  final String numeroContrato;
  final String epsAdresNombre;
  final String epsAdresNit;
  final RegimenSalud regimen;
  final double montoContrato;
  final double montoFacturado;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado; // activo, terminado, enConciliacion
  final String? observaciones;

  ContratoEPS({
    required this.id,
    required this.entidadId,
    required this.numeroContrato,
    required this.epsAdresNombre,
    required this.epsAdresNit,
    required this.regimen,
    required this.montoContrato,
    required this.montoFacturado,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    this.observaciones,
  });

  factory ContratoEPS.fromJson(Map<String, dynamic> json) {
    return ContratoEPS(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroContrato: json['numero_contrato'] as String,
      epsAdresNombre: json['eps_adres_nombre'] as String,
      epsAdresNit: json['eps_adres_nit'] as String,
      regimen: RegimenSalud.values.firstWhere(
        (e) => e.name == json['regimen'],
        orElse: () => RegimenSalud.subsidiado,
      ),
      montoContrato: (json['monto_contrato'] as num).toDouble(),
      montoFacturado: (json['monto_facturado'] as num?)?.toDouble() ?? 0.0,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: DateTime.parse(json['fecha_fin'] as String),
      estado: json['estado'] as String,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_contrato': numeroContrato,
      'eps_adres_nombre': epsAdresNombre,
      'eps_adres_nit': epsAdresNit,
      'regimen': regimen.name,
      'monto_contrato': montoContrato,
      'monto_facturado': montoFacturado,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'estado': estado,
      'observaciones': observaciones,
    };
  }

  double get saldoDisponibleFacturacion => montoContrato - montoFacturado;
}
