/// Modelos de Estados Financieros según NICSP
/// NICSP 1: Estados Financieros
library;

enum TipoEstadoFinanciero {
  estadoSituacionFinanciera, // Balance General
  estadoResultadoOperacional, // PyG
  estadoCambiosPatrimonio, // Estado de Cambios en el Patrimonio
  estadoFlujosEfectivo, // NICSP 2
  estadoCuentasOrden, // Cuentas de Orden
}

class EstadoSituacionFinanciera {
  final String entidadId;
  final String vigencia;
  final DateTime fechaCorte;
  final double totalActivo;
  final double totalPasivo;
  final double totalPatrimonio;
  final double totalPasivoPatrimonio;
  final List<RenglonEstado> activos;
  final List<RenglonEstado> pasivos;
  final List<RenglonEstado> patrimonio;

  EstadoSituacionFinanciera({
    required this.entidadId,
    required this.vigencia,
    required this.fechaCorte,
    required this.totalActivo,
    required this.totalPasivo,
    required this.totalPatrimonio,
    required this.totalPasivoPatrimonio,
    required this.activos,
    required this.pasivos,
    required this.patrimonio,
  });

  factory EstadoSituacionFinanciera.fromJson(Map<String, dynamic> json) {
    return EstadoSituacionFinanciera(
      entidadId: json['entidad_id'] as String,
      vigencia: json['vigencia'] as String,
      fechaCorte: DateTime.parse(json['fecha_corte'] as String),
      totalActivo: (json['total_activo'] as num).toDouble(),
      totalPasivo: (json['total_pasivo'] as num).toDouble(),
      totalPatrimonio: (json['total_patrimonio'] as num).toDouble(),
      totalPasivoPatrimonio: (json['total_pasivo_patrimonio'] as num).toDouble(),
      activos: (json['activos'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
      pasivos: (json['pasivos'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
      patrimonio: (json['patrimonio'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entidad_id': entidadId,
      'vigencia': vigencia,
      'fecha_corte': fechaCorte.toIso8601String(),
      'total_activo': totalActivo,
      'total_pasivo': totalPasivo,
      'total_patrimonio': totalPatrimonio,
      'total_pasivo_patrimonio': totalPasivoPatrimonio,
      'activos': activos.map((r) => r.toJson()).toList(),
      'pasivos': pasivos.map((r) => r.toJson()).toList(),
      'patrimonio': patrimonio.map((r) => r.toJson()).toList(),
    };
  }

  /// Verifica que el estado esté cuadrado (Activo = Pasivo + Patrimonio)
  bool estaCuadrado() {
    return (totalActivo - totalPasivoPatrimonio).abs() < 0.01;
  }
}

class EstadoResultadoOperacional {
  final String entidadId;
  final String vigencia;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final double totalIngresos;
  final double totalGastos;
  final double resultadoOperacional;
  final List<RenglonEstado> ingresos;
  final List<RenglonEstado> gastos;

  EstadoResultadoOperacional({
    required this.entidadId,
    required this.vigencia,
    required this.fechaInicio,
    required this.fechaFin,
    required this.totalIngresos,
    required this.totalGastos,
    required this.resultadoOperacional,
    required this.ingresos,
    required this.gastos,
  });

  factory EstadoResultadoOperacional.fromJson(Map<String, dynamic> json) {
    return EstadoResultadoOperacional(
      entidadId: json['entidad_id'] as String,
      vigencia: json['vigencia'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: DateTime.parse(json['fecha_fin'] as String),
      totalIngresos: (json['total_ingresos'] as num).toDouble(),
      totalGastos: (json['total_gastos'] as num).toDouble(),
      resultadoOperacional: (json['resultado_operacional'] as num).toDouble(),
      ingresos: (json['ingresos'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
      gastos: (json['gastos'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entidad_id': entidadId,
      'vigencia': vigencia,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'total_ingresos': totalIngresos,
      'total_gastos': totalGastos,
      'resultado_operacional': resultadoOperacional,
      'ingresos': ingresos.map((r) => r.toJson()).toList(),
      'gastos': gastos.map((r) => r.toJson()).toList(),
    };
  }
}

class EstadoFlujosEfectivo {
  final String entidadId;
  final String vigencia;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final double totalActividadesOperacion;
  final double totalActividadesInversion;
  final double totalActividadesFinanciacion;
  final double variacionNetaEfectivo;
  final double efectivoAlInicio;
  final double efectivoAlFinal;
  final List<RenglonEstado> actividadesOperacion;
  final List<RenglonEstado> actividadesInversion;
  final List<RenglonEstado> actividadesFinanciacion;

  EstadoFlujosEfectivo({
    required this.entidadId,
    required this.vigencia,
    required this.fechaInicio,
    required this.fechaFin,
    required this.totalActividadesOperacion,
    required this.totalActividadesInversion,
    required this.totalActividadesFinanciacion,
    required this.variacionNetaEfectivo,
    required this.efectivoAlInicio,
    required this.efectivoAlFinal,
    required this.actividadesOperacion,
    required this.actividadesInversion,
    required this.actividadesFinanciacion,
  });

  factory EstadoFlujosEfectivo.fromJson(Map<String, dynamic> json) {
    return EstadoFlujosEfectivo(
      entidadId: json['entidad_id'] as String,
      vigencia: json['vigencia'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: DateTime.parse(json['fecha_fin'] as String),
      totalActividadesOperacion: (json['total_actividades_operacion'] as num).toDouble(),
      totalActividadesInversion: (json['total_actividades_inversion'] as num).toDouble(),
      totalActividadesFinanciacion: (json['total_actividades_financiacion'] as num).toDouble(),
      variacionNetaEfectivo: (json['variacion_neta_efectivo'] as num).toDouble(),
      efectivoAlInicio: (json['efectivo_al_inicio'] as num).toDouble(),
      efectivoAlFinal: (json['efectivo_al_final'] as num).toDouble(),
      actividadesOperacion: (json['actividades_operacion'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
      actividadesInversion: (json['actividades_inversion'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
      actividadesFinanciacion: (json['actividades_financiacion'] as List)
          .map((r) => RenglonEstado.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entidad_id': entidadId,
      'vigencia': vigencia,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'total_actividades_operacion': totalActividadesOperacion,
      'total_actividades_inversion': totalActividadesInversion,
      'total_actividades_financiacion': totalActividadesFinanciacion,
      'variacion_neta_efectivo': variacionNetaEfectivo,
      'efectivo_al_inicio': efectivoAlInicio,
      'efectivo_al_final': efectivoAlFinal,
      'actividades_operacion': actividadesOperacion.map((r) => r.toJson()).toList(),
      'actividades_inversion': actividadesInversion.map((r) => r.toJson()).toList(),
      'actividades_financiacion': actividadesFinanciacion.map((r) => r.toJson()).toList(),
    };
  }

  /// Verifica que el estado esté cuadrado
  bool estaCuadrado() {
    final calculadoFinal = efectivoAlInicio + variacionNetaEfectivo;
    return (efectivoAlFinal - calculadoFinal).abs() < 0.01;
  }
}

class RenglonEstado {
  final String codigoCuenta;
  final String nombreCuenta;
  final double valor;
  final int nivel; // Para indentación en reportes
  final bool esTotal; // Si es un renglón de subtotal

  RenglonEstado({
    required this.codigoCuenta,
    required this.nombreCuenta,
    required this.valor,
    required this.nivel,
    this.esTotal = false,
  });

  factory RenglonEstado.fromJson(Map<String, dynamic> json) {
    return RenglonEstado(
      codigoCuenta: json['codigo_cuenta'] as String,
      nombreCuenta: json['nombre_cuenta'] as String,
      valor: (json['valor'] as num).toDouble(),
      nivel: json['nivel'] as int,
      esTotal: json['es_total'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo_cuenta': codigoCuenta,
      'nombre_cuenta': nombreCuenta,
      'valor': valor,
      'nivel': nivel,
      'es_total': esTotal,
    };
  }
}
