/// Modelo de FUT (Fondo de Unidad de Tesorería)
/// Fondo de Unidad de Tesorería - Manejo de recursos de terceros
library;


enum TipoFUT {
  contrato,
  convenio,
  donacion,
  fiducia,
  otro,
}

enum EstadoFUT {
  activo,
  enEjecucion,
  suspendido,
  terminado,
  liquidado,
  cancelado,
}

class FUT {
  final String id;
  final String entidadId;
  final String numeroFUT; // Formato: FUT-YYYY-NNNNNN
  final String nombreFUT;
  final TipoFUT tipoFUT;
  final String? numeroContrato;
  final String? numeroConvenio;
  final String terceroId;
  final String terceroNombre;
  final String terceroIdentificacion;
  final double valorInicial;
  final double valorEjecutado;
  final double saldoDisponible;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final EstadoFUT estado;
  final String? responsable;
  final String? observaciones;

  FUT({
    required this.id,
    required this.entidadId,
    required this.numeroFUT,
    required this.nombreFUT,
    required this.tipoFUT,
    this.numeroContrato,
    this.numeroConvenio,
    required this.terceroId,
    required this.terceroNombre,
    required this.terceroIdentificacion,
    required this.valorInicial,
    required this.valorEjecutado,
    required this.saldoDisponible,
    required this.fechaApertura,
    this.fechaCierre,
    required this.estado,
    this.responsable,
    this.observaciones,
  });

  factory FUT.fromJson(Map<String, dynamic> json) {
    return FUT(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroFUT: json['numero_fut'] as String,
      nombreFUT: json['nombre_fut'] as String,
      tipoFUT: TipoFUT.values.firstWhere(
        (e) => e.toString() == 'TipoFUT.${json['tipo_fut']}',
      ),
      numeroContrato: json['numero_contrato'] as String?,
      numeroConvenio: json['numero_convenio'] as String?,
      terceroId: json['tercero_id'] as String,
      terceroNombre: json['tercero_nombre'] as String,
      terceroIdentificacion: json['tercero_identificacion'] as String,
      valorInicial: (json['valor_inicial'] as num).toDouble(),
      valorEjecutado: (json['valor_ejecutado'] as num).toDouble(),
      saldoDisponible: (json['saldo_disponible'] as num).toDouble(),
      fechaApertura: DateTime.parse(json['fecha_apertura'] as String),
      fechaCierre: json['fecha_cierre'] != null
          ? DateTime.parse(json['fecha_cierre'] as String)
          : null,
      estado: EstadoFUT.values.firstWhere(
        (e) => e.toString() == 'EstadoFUT.${json['estado']}',
      ),
      responsable: json['responsable'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_fut': numeroFUT,
      'nombre_fut': nombreFUT,
      'tipo_fut': tipoFUT.toString().split('.').last,
      'numero_contrato': numeroContrato,
      'numero_convenio': numeroConvenio,
      'tercero_id': terceroId,
      'tercero_nombre': terceroNombre,
      'tercero_identificacion': terceroIdentificacion,
      'valor_inicial': valorInicial,
      'valor_ejecutado': valorEjecutado,
      'saldo_disponible': saldoDisponible,
      'fecha_apertura': fechaApertura.toIso8601String(),
      'fecha_cierre': fechaCierre?.toIso8601String(),
      'estado': estado.toString().split('.').last,
      'responsable': responsable,
      'observaciones': observaciones,
    };
  }

  /// Calcula el porcentaje de ejecución
  double calcularPorcentajeEjecucion() {
    if (valorInicial == 0) return 0;
    return (valorEjecutado / valorInicial) * 100;
  }

  /// Verifica si está activo
  bool estaActivo() {
    return estado == EstadoFUT.activo || estado == EstadoFUT.enEjecucion;
  }

  /// Verifica si tiene saldo disponible
  bool tieneSaldo() {
    return saldoDisponible > 0;
  }

  FUT copyWith({
    String? id,
    String? entidadId,
    String? numeroFUT,
    String? nombreFUT,
    TipoFUT? tipoFUT,
    String? numeroContrato,
    String? numeroConvenio,
    String? terceroId,
    String? terceroNombre,
    String? terceroIdentificacion,
    double? valorInicial,
    double? valorEjecutado,
    double? saldoDisponible,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    EstadoFUT? estado,
    String? responsable,
    String? observaciones,
  }) {
    return FUT(
      id: id ?? this.id,
      entidadId: entidadId ?? this.entidadId,
      numeroFUT: numeroFUT ?? this.numeroFUT,
      nombreFUT: nombreFUT ?? this.nombreFUT,
      tipoFUT: tipoFUT ?? this.tipoFUT,
      numeroContrato: numeroContrato ?? this.numeroContrato,
      numeroConvenio: numeroConvenio ?? this.numeroConvenio,
      terceroId: terceroId ?? this.terceroId,
      terceroNombre: terceroNombre ?? this.terceroNombre,
      terceroIdentificacion: terceroIdentificacion ?? this.terceroIdentificacion,
      valorInicial: valorInicial ?? this.valorInicial,
      valorEjecutado: valorEjecutado ?? this.valorEjecutado,
      saldoDisponible: saldoDisponible ?? this.saldoDisponible,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      estado: estado ?? this.estado,
      responsable: responsable ?? this.responsable,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
