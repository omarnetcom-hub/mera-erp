/// Modelo de Liquidación de Nómina
/// Con cálculo de aportes parafiscales y PILA
library;


enum EstadoLiquidacion {
  generada,
  aprobada,
  pagada,
  anulada,
}

class LiquidacionNomina {
  final String id;
  final String entidadId;
  final String numeroLiquidacion; // Formato: LN-YYYY-MM-NNNNNN
  final String periodo; // Formato: YYYY-MM
  final String empleadoId;
  final String empleadoNombre;
  final String empleadoIdentificacion;
  final int diasTrabajados;
  final double salarioBasico;
  final double salarioDevengado;
  final double auxilioTransporte;
  final double auxilioAlimentacion;
  final double horasExtra;
  final double recargoNocturno;
  final double totalDevengado;
  final double salud; // 8.5%
  final double pension; // 12%
  final double fondoSolidaridad; // 1-2% según salario
  final double riesgosLaborales; // 0.522% - 8.7%
  final double cajaCompensacion; // 4%
  final double sena; // 2%
  final double icbf; // 3%
  final double totalAportes;
  final double netoPagar;
  final EstadoLiquidacion estado;
  final DateTime fechaLiquidacion;
  final DateTime? fechaPago;
  final String? pilaId; // ID en PILA
  final String? observaciones;

  LiquidacionNomina({
    required this.id,
    required this.entidadId,
    required this.numeroLiquidacion,
    required this.periodo,
    required this.empleadoId,
    required this.empleadoNombre,
    required this.empleadoIdentificacion,
    required this.diasTrabajados,
    required this.salarioBasico,
    required this.salarioDevengado,
    required this.auxilioTransporte,
    required this.auxilioAlimentacion,
    required this.horasExtra,
    required this.recargoNocturno,
    required this.totalDevengado,
    required this.salud,
    required this.pension,
    required this.fondoSolidaridad,
    required this.riesgosLaborales,
    required this.cajaCompensacion,
    required this.sena,
    required this.icbf,
    required this.totalAportes,
    required this.netoPagar,
    required this.estado,
    required this.fechaLiquidacion,
    this.fechaPago,
    this.pilaId,
    this.observaciones,
  });

  factory LiquidacionNomina.fromJson(Map<String, dynamic> json) {
    return LiquidacionNomina(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      numeroLiquidacion: json['numero_liquidacion'] as String,
      periodo: json['periodo'] as String,
      empleadoId: json['empleado_id'] as String,
      empleadoNombre: json['empleado_nombre'] as String,
      empleadoIdentificacion: json['empleado_identificacion'] as String,
      diasTrabajados: json['dias_trabajados'] as int,
      salarioBasico: (json['salario_basico'] as num).toDouble(),
      salarioDevengado: (json['salario_devengado'] as num).toDouble(),
      auxilioTransporte: (json['auxilio_transporte'] as num).toDouble(),
      auxilioAlimentacion: (json['auxilio_alimentacion'] as num).toDouble(),
      horasExtra: (json['horas_extra'] as num).toDouble(),
      recargoNocturno: (json['recargo_nocturno'] as num).toDouble(),
      totalDevengado: (json['total_devengado'] as num).toDouble(),
      salud: (json['salud'] as num).toDouble(),
      pension: (json['pension'] as num).toDouble(),
      fondoSolidaridad: (json['fondo_solidaridad'] as num).toDouble(),
      riesgosLaborales: (json['riesgos_laborales'] as num).toDouble(),
      cajaCompensacion: (json['caja_compensacion'] as num).toDouble(),
      sena: (json['sena'] as num).toDouble(),
      icbf: (json['icbf'] as num).toDouble(),
      totalAportes: (json['total_aportes'] as num).toDouble(),
      netoPagar: (json['neto_pagar'] as num).toDouble(),
      estado: EstadoLiquidacion.values.firstWhere(
        (e) => e.toString() == 'EstadoLiquidacion.${json['estado']}',
      ),
      fechaLiquidacion: DateTime.parse(json['fecha_liquidacion'] as String),
      fechaPago: json['fecha_pago'] != null
          ? DateTime.parse(json['fecha_pago'] as String)
          : null,
      pilaId: json['pila_id'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'numero_liquidacion': numeroLiquidacion,
      'periodo': periodo,
      'empleado_id': empleadoId,
      'empleado_nombre': empleadoNombre,
      'empleado_identificacion': empleadoIdentificacion,
      'dias_trabajados': diasTrabajados,
      'salario_basico': salarioBasico,
      'salario_devengado': salarioDevengado,
      'auxilio_transporte': auxilioTransporte,
      'auxilio_alimentacion': auxilioAlimentacion,
      'horas_extra': horasExtra,
      'recargo_nocturno': recargoNocturno,
      'total_devengado': totalDevengado,
      'salud': salud,
      'pension': pension,
      'fondo_solidaridad': fondoSolidaridad,
      'riesgos_laborales': riesgosLaborales,
      'caja_compensacion': cajaCompensacion,
      'sena': sena,
      'icbf': icbf,
      'total_aportes': totalAportes,
      'neto_pagar': netoPagar,
      'estado': estado.toString().split('.').last,
      'fecha_liquidacion': fechaLiquidacion.toIso8601String(),
      'fecha_pago': fechaPago?.toIso8601String(),
      'pila_id': pilaId,
      'observaciones': observaciones,
    };
  }

  bool estaPagada() {
    return estado == EstadoLiquidacion.pagada;
  }

  bool tienePILA() {
    return pilaId != null && pilaId!.isNotEmpty;
  }

  LiquidacionNomina copyWith({
    String? id,
    String? entidadId,
    String? numeroLiquidacion,
    String? periodo,
    String? empleadoId,
    String? empleadoNombre,
    String? empleadoIdentificacion,
    int? diasTrabajados,
    double? salarioBasico,
    double? salarioDevengado,
    double? auxilioTransporte,
    double? auxilioAlimentacion,
    double? horasExtra,
    double? recargoNocturno,
    double? totalDevengado,
    double? salud,
    double? pension,
    double? fondoSolidaridad,
    double? riesgosLaborales,
    double? cajaCompensacion,
    double? sena,
    double? icbf,
    double? totalAportes,
    double? netoPagar,
    EstadoLiquidacion? estado,
    DateTime? fechaLiquidacion,
    DateTime? fechaPago,
    String? pilaId,
    String? observaciones,
  }) {
    return LiquidacionNomina(
      id: id ?? this.id,
      entidadId: entidadId ?? this.entidadId,
      numeroLiquidacion: numeroLiquidacion ?? this.numeroLiquidacion,
      periodo: periodo ?? this.periodo,
      empleadoId: empleadoId ?? this.empleadoId,
      empleadoNombre: empleadoNombre ?? this.empleadoNombre,
      empleadoIdentificacion: empleadoIdentificacion ?? this.empleadoIdentificacion,
      diasTrabajados: diasTrabajados ?? this.diasTrabajados,
      salarioBasico: salarioBasico ?? this.salarioBasico,
      salarioDevengado: salarioDevengado ?? this.salarioDevengado,
      auxilioTransporte: auxilioTransporte ?? this.auxilioTransporte,
      auxilioAlimentacion: auxilioAlimentacion ?? this.auxilioAlimentacion,
      horasExtra: horasExtra ?? this.horasExtra,
      recargoNocturno: recargoNocturno ?? this.recargoNocturno,
      totalDevengado: totalDevengado ?? this.totalDevengado,
      salud: salud ?? this.salud,
      pension: pension ?? this.pension,
      fondoSolidaridad: fondoSolidaridad ?? this.fondoSolidaridad,
      riesgosLaborales: riesgosLaborales ?? this.riesgosLaborales,
      cajaCompensacion: cajaCompensacion ?? this.cajaCompensacion,
      sena: sena ?? this.sena,
      icbf: icbf ?? this.icbf,
      totalAportes: totalAportes ?? this.totalAportes,
      netoPagar: netoPagar ?? this.netoPagar,
      estado: estado ?? this.estado,
      fechaLiquidacion: fechaLiquidacion ?? this.fechaLiquidacion,
      fechaPago: fechaPago ?? this.fechaPago,
      pilaId: pilaId ?? this.pilaId,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
