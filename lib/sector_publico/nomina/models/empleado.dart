/// Modelo de Empleado Público
/// Para nómina pública con cálculo de aportes parafiscales
library;


enum TipoContrato {
  indefinido,
  fijo,
  aprendizaje,
  practicas,
  docente,
  misional,
}

enum TipoVinculacion {
  carrera,
  libreNombramiento,
  provision,
  contrato,
}

class Empleado {
  final String id;
  final String entidadId;
  final String numeroIdentificacion;
  final String nombreCompleto;
  final String cargo;
  final String dependencia;
  final TipoContrato tipoContrato;
  final TipoVinculacion tipoVinculacion;
  final double salarioBasico;
  final DateTime fechaIngreso;
  final DateTime? fechaRetiro;
  final bool activo;
  final String? cuentaBancaria;
  final String? tipoCuenta;
  final String? banco;
  final String? eps;
  final String? fondoPension;
  final String? fondoCesantias;
  final String? observaciones;

  Empleado({
    required this.id,
    required this.entidadId,
    required this.numeroIdentificacion,
    required this.nombreCompleto,
    required this.cargo,
    required this.dependencia,
    required this.tipoContrato,
    required this.tipoVinculacion,
    required this.salarioBasico,
    required this.fechaIngreso,
    this.fechaRetiro,
    required this.activo,
    this.cuentaBancaria,
    this.tipoCuenta,
    this.banco,
    this.eps,
    this.fondoPension,
    this.fondoCesantias,
    this.observaciones,
  });

  factory Empleado.fromJson(Map<String, dynamic> json) {
    return Empleado(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroIdentificacion: json['numero_identificacion'] as String,
      nombreCompleto: json['nombre_completo'] as String,
      cargo: json['cargo'] as String,
      dependencia: json['dependencia'] as String,
      tipoContrato: TipoContrato.values.firstWhere(
        (e) => e.toString() == 'TipoContrato.${json['tipo_contrato']}',
      ),
      tipoVinculacion: TipoVinculacion.values.firstWhere(
        (e) => e.toString() == 'TipoVinculacion.${json['tipo_vinculacion']}',
      ),
      salarioBasico: (json['salario_basico'] as num).toDouble(),
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      fechaRetiro: json['fecha_retiro'] != null
          ? DateTime.parse(json['fecha_retiro'] as String)
          : null,
      activo: json['activo'] == true || json['activo'] == 1,
      cuentaBancaria: json['cuenta_bancaria'] as String?,
      tipoCuenta: json['tipo_cuenta'] as String?,
      banco: json['banco'] as String?,
      eps: json['eps'] as String?,
      fondoPension: json['fondo_pension'] as String?,
      fondoCesantias: json['fondo_cesantias'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_identificacion': numeroIdentificacion,
      'nombre_completo': nombreCompleto,
      'cargo': cargo,
      'dependencia': dependencia,
      'tipo_contrato': tipoContrato.toString().split('.').last,
      'tipo_vinculacion': tipoVinculacion.toString().split('.').last,
      'salario_basico': salarioBasico,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'activo': activo,
      'cuenta_bancaria': cuentaBancaria,
      'tipo_cuenta': tipoCuenta,
      'banco': banco,
      'eps': eps,
      'fondo_pension': fondoPension,
      'fondo_cesantias': fondoCesantias,
      'observaciones': observaciones,
    };
  }

  /// Verifica si es docente (tiene cálculos especiales)
  bool esDocente() {
    return tipoContrato == TipoContrato.docente;
  }

  /// Calcula los días trabajados en un periodo
  int calcularDiasTrabajados(DateTime fechaInicio, DateTime fechaFin) {
    if (!activo && fechaRetiro != null) {
      fechaFin = fechaRetiro!;
    }
    return fechaFin.difference(fechaInicio).inDays + 1;
  }

  Empleado copyWith({
    String? id,
    String? entidadId,
    String? numeroIdentificacion,
    String? nombreCompleto,
    String? cargo,
    String? dependencia,
    TipoContrato? tipoContrato,
    TipoVinculacion? tipoVinculacion,
    double? salarioBasico,
    DateTime? fechaIngreso,
    DateTime? fechaRetiro,
    bool? activo,
    String? cuentaBancaria,
    String? tipoCuenta,
    String? banco,
    String? eps,
    String? fondoPension,
    String? fondoCesantias,
    String? observaciones,
  }) {
    return Empleado(
      id: id ?? this.id,
      entidadId: entidadId ?? this.entidadId,
      numeroIdentificacion: numeroIdentificacion ?? this.numeroIdentificacion,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      cargo: cargo ?? this.cargo,
      dependencia: dependencia ?? this.dependencia,
      tipoContrato: tipoContrato ?? this.tipoContrato,
      tipoVinculacion: tipoVinculacion ?? this.tipoVinculacion,
      salarioBasico: salarioBasico ?? this.salarioBasico,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      activo: activo ?? this.activo,
      cuentaBancaria: cuentaBancaria ?? this.cuentaBancaria,
      tipoCuenta: tipoCuenta ?? this.tipoCuenta,
      banco: banco ?? this.banco,
      eps: eps ?? this.eps,
      fondoPension: fondoPension ?? this.fondoPension,
      fondoCesantias: fondoCesantias ?? this.fondoCesantias,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
