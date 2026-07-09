/// Modelo de Glosa
/// Respuesta de glosa por parte de EPS
library;


enum TipoGlosa {
  servicioNoPrestado,
  inconsistenciaDocumental,
  errorFacturacion,
  duplicidad,
  otro,
}

enum EstadoGlosa {
  generada,
  enviada,
  respondida,
  aceptada,
  rechazada,
  parcialmenteAceptada,
}

class Glosa {
  final String id;
  final String entidadId;
  final String numeroGlosa; // Formato: GL-YYYY-NNNNNN
  final TipoGlosa tipoGlosa;
  final String ripsId;
  final String numeroFactura;
  final String eps;
  final String motivo;
  final double valorGlosado;
  final double valorAceptado;
  final double valorRechazado;
  final DateTime fechaGeneracion;
  final DateTime fechaEnvio;
  final DateTime? fechaRespuesta;
  final EstadoGlosa estado;
  final String? justificacionRespuesta;
  final String? observaciones;

  Glosa({
    required this.id,
    required this.entidadId,
    required this.numeroGlosa,
    required this.tipoGlosa,
    required this.ripsId,
    required this.numeroFactura,
    required this.eps,
    required this.motivo,
    required this.valorGlosado,
    required this.valorAceptado,
    required this.valorRechazado,
    required this.fechaGeneracion,
    required this.fechaEnvio,
    this.fechaRespuesta,
    required this.estado,
    this.justificacionRespuesta,
    this.observaciones,
  });

  factory Glosa.fromJson(Map<String, dynamic> json) {
    return Glosa(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroGlosa: json['numero_glosa'] as String,
      tipoGlosa: TipoGlosa.values.firstWhere(
        (e) => e.toString() == 'TipoGlosa.${json['tipo_glosa']}',
      ),
      ripsId: json['rips_id'] as String,
      numeroFactura: json['numero_factura'] as String,
      eps: json['eps'] as String,
      motivo: json['motivo'] as String,
      valorGlosado: (json['valor_glosado'] as num).toDouble(),
      valorAceptado: (json['valor_aceptado'] as num).toDouble(),
      valorRechazado: (json['valor_rechazado'] as num).toDouble(),
      fechaGeneracion: DateTime.parse(json['fecha_generacion'] as String),
      fechaEnvio: DateTime.parse(json['fecha_envio'] as String),
      fechaRespuesta: json['fecha_respuesta'] != null
          ? DateTime.parse(json['fecha_respuesta'] as String)
          : null,
      estado: EstadoGlosa.values.firstWhere(
        (e) => e.toString() == 'EstadoGlosa.${json['estado']}',
      ),
      justificacionRespuesta: json['justificacion_respuesta'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_glosa': numeroGlosa,
      'tipo_glosa': tipoGlosa.toString().split('.').last,
      'rips_id': ripsId,
      'numero_factura': numeroFactura,
      'eps': eps,
      'motivo': motivo,
      'valor_glosado': valorGlosado,
      'valor_aceptado': valorAceptado,
      'valor_rechazado': valorRechazado,
      'fecha_generacion': fechaGeneracion.toIso8601String(),
      'fecha_envio': fechaEnvio.toIso8601String(),
      'fecha_respuesta': fechaRespuesta?.toIso8601String(),
      'estado': estado.toString().split('.').last,
      'justificacion_respuesta': justificacionRespuesta,
      'observaciones': observaciones,
    };
  }

  bool estaRespondida() {
    return estado == EstadoGlosa.respondida ||
           estado == EstadoGlosa.aceptada ||
           estado == EstadoGlosa.rechazada ||
           estado == EstadoGlosa.parcialmenteAceptada;
  }

  Glosa copyWith({
    String? id,
    String? entidadId,
    String? numeroGlosa,
    TipoGlosa? tipoGlosa,
    String? ripsId,
    String? numeroFactura,
    String? eps,
    String? motivo,
    double? valorGlosado,
    double? valorAceptado,
    double? valorRechazado,
    DateTime? fechaGeneracion,
    DateTime? fechaEnvio,
    DateTime? fechaRespuesta,
    EstadoGlosa? estado,
    String? justificacionRespuesta,
    String? observaciones,
  }) {
    return Glosa(
      id: id ?? this.id,
      entidadId: entidadId ?? this.entidadId,
      numeroGlosa: numeroGlosa ?? this.numeroGlosa,
      tipoGlosa: tipoGlosa ?? this.tipoGlosa,
      ripsId: ripsId ?? this.ripsId,
      numeroFactura: numeroFactura ?? this.numeroFactura,
      eps: eps ?? this.eps,
      motivo: motivo ?? this.motivo,
      valorGlosado: valorGlosado ?? this.valorGlosado,
      valorAceptado: valorAceptado ?? this.valorAceptado,
      valorRechazado: valorRechazado ?? this.valorRechazado,
      fechaGeneracion: fechaGeneracion ?? this.fechaGeneracion,
      fechaEnvio: fechaEnvio ?? this.fechaEnvio,
      fechaRespuesta: fechaRespuesta ?? this.fechaRespuesta,
      estado: estado ?? this.estado,
      justificacionRespuesta: justificacionRespuesta ?? this.justificacionRespuesta,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
