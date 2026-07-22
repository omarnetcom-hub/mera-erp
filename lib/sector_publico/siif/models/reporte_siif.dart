/// Modelos de Reportes SIIF Nación (Ministerio de Hacienda y Crédito Público)
/// Integración mensual de Presupuesto, Tesorería y Pagos
library;

import 'dart:convert';

enum TipoReporteSIIF {
  presupuestoMensual,
  tesoreriaPagos,
  consolidadoMensual,
}

class ReporteSIIF {
  final String id;
  final String entidadId;
  final TipoReporteSIIF tipoReporte;
  final String vigencia;
  final int mes;
  final DateTime fechaGeneracion;
  final String usuarioGenero;
  final Map<String, dynamic> datos;
  final String estado; // generado, enviado, aceptado, rechazado
  final String? observaciones;

  ReporteSIIF({
    required this.id,
    required this.entidadId,
    required this.tipoReporte,
    required this.vigencia,
    required this.mes,
    required this.fechaGeneracion,
    required this.usuarioGenero,
    required this.datos,
    required this.estado,
    this.observaciones,
  });

  factory ReporteSIIF.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> datosMap;
    if (json['datos'] is String) {
      datosMap = jsonDecode(json['datos'] as String) as Map<String, dynamic>;
    } else {
      datosMap = json['datos'] as Map<String, dynamic>;
    }

    return ReporteSIIF(
      id: json['id'] as String,
      entidadId: json['entidad_id'] as String,
      tipoReporte: TipoReporteSIIF.values.firstWhere(
        (e) => e.name == json['tipo_reporte'],
        orElse: () => TipoReporteSIIF.presupuestoMensual,
      ),
      vigencia: json['vigencia'] as String,
      mes: json['mes'] is int ? json['mes'] as int : int.parse(json['mes'].toString()),
      fechaGeneracion: DateTime.parse(json['fecha_generacion'] as String),
      usuarioGenero: json['usuario_genero'] as String,
      datos: datosMap,
      estado: json['estado'] as String,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidad_id': entidadId,
      'tipo_reporte': tipoReporte.name,
      'vigencia': vigencia,
      'mes': mes,
      'fecha_generacion': fechaGeneracion.toIso8601String(),
      'usuario_genero': usuarioGenero,
      'datos': jsonEncode(datos),
      'estado': estado,
      'observaciones': observaciones,
    };
  }

  String get nombreReporte {
    switch (tipoReporte) {
      case TipoReporteSIIF.presupuestoMensual:
        return 'SIIF Presupuesto Mensual (CDP, RP, Obligaciones)';
      case TipoReporteSIIF.tesoreriaPagos:
        return 'SIIF Tesorería y Pagos Mensuales';
      case TipoReporteSIIF.consolidadoMensual:
        return 'SIIF Consolidado Presupuestal-Financiero';
    }
  }
}

/// Datos consolidados para reporte de Presupuesto Mensual SIIF Nación
class DatosSIIFPresupuesto {
  final double totalApropiacionInicial;
  final double totalAdiciones;
  final double totalReducciones;
  final double totalApropiacionDefinitiva;
  final double totalCDP;
  final double totalRP;
  final double totalObligaciones;
  final double totalPagos;
  final double saldoPorComprometer;
  final double saldoPorPagar;

  DatosSIIFPresupuesto({
    required this.totalApropiacionInicial,
    required this.totalAdiciones,
    required this.totalReducciones,
    required this.totalApropiacionDefinitiva,
    required this.totalCDP,
    required this.totalRP,
    required this.totalObligaciones,
    required this.totalPagos,
    required this.saldoPorComprometer,
    required this.saldoPorPagar,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_apropiacion_inicial': totalApropiacionInicial,
      'total_adiciones': totalAdiciones,
      'total_reducciones': totalReducciones,
      'total_apropiacion_definitiva': totalApropiacionDefinitiva,
      'total_cdp': totalCDP,
      'total_rp': totalRP,
      'total_obligaciones': totalObligaciones,
      'total_pagos': totalPagos,
      'saldo_por_comprometer': saldoPorComprometer,
      'saldo_por_pagar': saldoPorPagar,
    };
  }
}

/// Datos consolidados para reporte de Tesorería y Pagos SIIF Nación
class DatosSIIFTesoreria {
  final double totalPagosEfectuados;
  final double totalRetencionesEfectuadas;
  final double totalNetoPagado;
  final int numeroCuentasBancariasOperativas;
  final double totalTransferenciasSIIF;

  DatosSIIFTesoreria({
    required this.totalPagosEfectuados,
    required this.totalRetencionesEfectuadas,
    required this.totalNetoPagado,
    required this.numeroCuentasBancariasOperativas,
    required this.totalTransferenciasSIIF,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_pagos_efectuados': totalPagosEfectuados,
      'total_retenciones_efectuadas': totalRetencionesEfectuadas,
      'total_neto_pagado': totalNetoPagado,
      'numero_cuentas_bancarias_operativas': numeroCuentasBancariasOperativas,
      'total_transferencias_siif': totalTransferenciasSIIF,
    };
  }
}
