/// Modelo de Acta de Responsabilidad y Custodia de Bienes del Estado (NICSP 17)
/// Asignación y traspaso de cuentadantes de activos públicos
library;

enum EstadoActaResponsabilidad {
  activa,
  devuelta,
  trasladada,
}

class ActaResponsabilidad {
  final String id;
  final String entidadId;
  final String numeroActa; // Formato: ACTA-YYYY-NNNNNN
  final String activoId;
  final String funcionarioId;
  final String funcionarioNombre;
  final String funcionarioIdentificacion;
  final String dependencia;
  final String ubicacionFisica;
  final DateTime fechaAsignacion;
  final DateTime? fechaDevolucion;
  final EstadoActaResponsabilidad estadoActa;
  final String? observaciones;

  ActaResponsabilidad({
    required this.id,
    required this.entidadId,
    required this.numeroActa,
    required this.activoId,
    required this.funcionarioId,
    required this.funcionarioNombre,
    required this.funcionarioIdentificacion,
    required this.dependencia,
    required this.ubicacionFisica,
    required this.fechaAsignacion,
    this.fechaDevolucion,
    required this.estadoActa,
    this.observaciones,
  });

  factory ActaResponsabilidad.fromJson(Map<String, dynamic> json) {
    return ActaResponsabilidad(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroActa: json['numero_acta'] as String,
      activoId: json['activo_id'] as String,
      funcionarioId: json['funcionario_id'] as String,
      funcionarioNombre: json['funcionario_nombre'] as String,
      funcionarioIdentificacion: json['funcionario_identificacion'] as String,
      dependencia: json['dependencia'] as String,
      ubicacionFisica: json['ubicacion_fisica'] as String,
      fechaAsignacion: DateTime.parse(json['fecha_asignacion'] as String),
      fechaDevolucion: json['fecha_devolucion'] != null
          ? DateTime.parse(json['fecha_devolucion'] as String)
          : null,
      estadoActa: EstadoActaResponsabilidad.values.firstWhere(
        (e) => e.name == json['estado_acta'],
        orElse: () => EstadoActaResponsabilidad.activa,
      ),
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_acta': numeroActa,
      'activo_id': activoId,
      'funcionario_id': funcionarioId,
      'funcionario_nombre': funcionarioNombre,
      'funcionario_identificacion': funcionarioIdentificacion,
      'dependencia': dependencia,
      'ubicacion_fisica': ubicacionFisica,
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'fecha_devolucion': fechaDevolucion?.toIso8601String(),
      'estado_acta': estadoActa.name,
      'observaciones': observaciones,
    };
  }
}
