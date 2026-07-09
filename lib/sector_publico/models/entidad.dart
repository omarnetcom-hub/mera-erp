/// Modelo de entidad territorial para el módulo de Sector Público
/// Implementa multi-tenant jerárquico según NICSP 40
library;


class EntidadTerritorial {
  final String id;
  final String nit;
  final String razonSocial;
  final TipoEntidad tipoEntidad;
  final String? departamento;
  final String? municipio;
  final String? gobernacionId; // ID de la gobernación consolidadora (si aplica)
  final DateTime fechaCreacion;
  final DateTime? fechaInicioVigencia;
  final bool activo;
  final String planCuentasCGC; // Versión del Catálogo General de Cuentas
  final Map<String, dynamic> configuracionNormativa;

  EntidadTerritorial({
    required this.id,
    required this.nit,
    required this.razonSocial,
    required this.tipoEntidad,
    this.departamento,
    this.municipio,
    this.gobernacionId,
    required this.fechaCreacion,
    this.fechaInicioVigencia,
    required this.activo,
    required this.planCuentasCGC,
    required this.configuracionNormativa,
  });

  factory EntidadTerritorial.fromJson(Map<String, dynamic> json) {
    return EntidadTerritorial(
      id: json['id'] as String,
      nit: json['nit'] as String,
      razonSocial: json['razon_social'] as String,
      tipoEntidad: TipoEntidad.values.firstWhere(
        (e) => e.toString() == 'TipoEntidad.${json['tipo_entidad']}',
      ),
      departamento: json['departamento'] as String?,
      municipio: json['municipio'] as String?,
      gobernacionId: json['gobernacion_id'] as String?,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      fechaInicioVigencia: json['fecha_inicio_vigencia'] != null
          ? DateTime.parse(json['fecha_inicio_vigencia'] as String)
          : null,
      activo: json['activo'] as bool,
      planCuentasCGC: json['plan_cuentas_cgc'] as String,
      configuracionNormativa: json['configuracion_normativa'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nit': nit,
      'razon_social': razonSocial,
      'tipo_entidad': tipoEntidad.toString().split('.').last,
      'departamento': departamento,
      'municipio': municipio,
      'gobernacion_id': gobernacionId,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_inicio_vigencia': fechaInicioVigencia?.toIso8601String(),
      'activo': activo,
      'plan_cuentas_cgc': planCuentasCGC,
      'configuracion_normativa': configuracionNormativa,
    };
  }

  /// Verifica si esta entidad está bajo una gobernación consolidadora
  bool get esConsolidada => gobernacionId != null;

  /// Verifica si esta entidad es una gobernación que puede consolidar
  bool get esGobernacion => tipoEntidad == TipoEntidad.gobernacion;

  EntidadTerritorial copyWith({
    String? id,
    String? nit,
    String? razonSocial,
    TipoEntidad? tipoEntidad,
    String? departamento,
    String? municipio,
    String? gobernacionId,
    DateTime? fechaCreacion,
    DateTime? fechaInicioVigencia,
    bool? activo,
    String? planCuentasCGC,
    Map<String, dynamic>? configuracionNormativa,
  }) {
    return EntidadTerritorial(
      id: id ?? this.id,
      nit: nit ?? this.nit,
      razonSocial: razonSocial ?? this.razonSocial,
      tipoEntidad: tipoEntidad ?? this.tipoEntidad,
      departamento: departamento ?? this.departamento,
      municipio: municipio ?? this.municipio,
      gobernacionId: gobernacionId ?? this.gobernacionId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaInicioVigencia: fechaInicioVigencia ?? this.fechaInicioVigencia,
      activo: activo ?? this.activo,
      planCuentasCGC: planCuentasCGC ?? this.planCuentasCGC,
      configuracionNormativa: configuracionNormativa ?? this.configuracionNormativa,
    );
  }
}

enum TipoEntidad {
  alcaldia,
  gobernacion,
  hospitalPublico, // ESE
  entidadDescentralizada,
  establecimientoEducativo,
}

/// Extension para obtener descripción legible del tipo de entidad
extension TipoEntidadExtension on TipoEntidad {
  String get descripcion {
    switch (this) {
      case TipoEntidad.alcaldia:
        return 'Alcaldía Municipal';
      case TipoEntidad.gobernacion:
        return 'Gobernación Departamental';
      case TipoEntidad.hospitalPublico:
        return 'Hospital Público (ESE)';
      case TipoEntidad.entidadDescentralizada:
        return 'Entidad Descentralizada';
      case TipoEntidad.establecimientoEducativo:
        return 'Establecimiento Educativo Público';
    }
  }
}
