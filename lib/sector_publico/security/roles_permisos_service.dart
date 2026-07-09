/// Servicio de roles y permisos con segregación de funciones dura
/// Implementa las reglas no negociables: un tesorero no puede aprobar su propio pago
library;


enum RolSectorPublico {
  alcaldeRepresentanteLegal,
  secretarioHacienda,
  tesorero,
  contador,
  jefeRentas,
  jefeControlInterno,
  ordenadorGasto,
  jefePlaneacion,
  secretarioSalud, // Para hospitales
  rector, // Para establecimientos educativos
}

enum Permiso {
  // Presupuesto
  expedirCDP,
  modificarCDP,
  expedirRP,
  modificarRP,
  registrarObligacion,
  aprobarPago,
  ejecutarPago,
  modificarPAC,

  // Contabilidad
  crearAsientoContable,
  reversarAsiento,
  cerrarVigencia,
  consultarEstadosFinancieros,

  // Nómina
  liquidarNomina,
  aprobarNomina,
  pagarNomina,
  reliquidarNomina,

  // Rentas
  liquidarTributo,
  cobrarTributo,
  iniciarCobroCoactivo,
  condonarTributo,

  // Contratación
  iniciarProcesoContratacion,
  adjudicarContrato,
  firmarContrato,
  liquidarContrato,
  supervisarContrato,

  // Planeación
  crearProyecto,
  modificarProyecto,
  aprobarProyecto,
  vincularProyectoPresupuesto,

  // Seguridad
  gestionarUsuarios,
  asignarRoles,
  consultarAuditoria,

  // General
  consultarTodo,
  exportarDatos,
}

class RolesPermisosService {
  /// Define qué roles tienen qué permisos
  static Map<RolSectorPublico, Set<Permiso>> get permisosPorRol => {
    RolSectorPublico.alcaldeRepresentanteLegal: {
      Permiso.consultarTodo,
      Permiso.aprobarPago,
      Permiso.firmarContrato,
      Permiso.liquidarContrato,
      Permiso.aprobarProyecto,
    },
    RolSectorPublico.secretarioHacienda: {
      Permiso.expedirCDP,
      Permiso.modificarCDP,
      Permiso.expedirRP,
      Permiso.modificarRP,
      Permiso.modificarPAC,
      Permiso.aprobarPago,
      Permiso.consultarEstadosFinancieros,
      Permiso.gestionarUsuarios,
      Permiso.asignarRoles,
      Permiso.consultarAuditoria,
      Permiso.consultarTodo,
    },
    RolSectorPublico.tesorero: {
      Permiso.ejecutarPago,
      Permiso.modificarPAC,
      Permiso.consultarEstadosFinancieros,
      Permiso.consultarTodo,
    },
    RolSectorPublico.contador: {
      Permiso.crearAsientoContable,
      Permiso.reversarAsiento,
      Permiso.cerrarVigencia,
      Permiso.consultarEstadosFinancieros,
      Permiso.liquidarNomina,
      Permiso.reliquidarNomina,
      Permiso.consultarTodo,
    },
    RolSectorPublico.jefeRentas: {
      Permiso.liquidarTributo,
      Permiso.cobrarTributo,
      Permiso.iniciarCobroCoactivo,
      Permiso.condonarTributo,
      Permiso.consultarTodo,
    },
    RolSectorPublico.jefeControlInterno: {
      Permiso.consultarAuditoria,
      Permiso.consultarTodo,
      Permiso.exportarDatos,
    },
    RolSectorPublico.ordenadorGasto: {
      Permiso.registrarObligacion,
      Permiso.expedirRP,
      Permiso.consultarTodo,
    },
    RolSectorPublico.jefePlaneacion: {
      Permiso.crearProyecto,
      Permiso.modificarProyecto,
      Permiso.aprobarProyecto,
      Permiso.vincularProyectoPresupuesto,
      Permiso.consultarTodo,
    },
    RolSectorPublico.secretarioSalud: {
      Permiso.expedirCDP,
      Permiso.expedirRP,
      Permiso.registrarObligacion,
      Permiso.aprobarPago,
      Permiso.firmarContrato,
      Permiso.consultarTodo,
    },
    RolSectorPublico.rector: {
      Permiso.expedirCDP,
      Permiso.expedirRP,
      Permiso.registrarObligacion,
      Permiso.liquidarNomina,
      Permiso.consultarTodo,
    },
  };

  /// Define las NEGACIONES EXPLÍCITAS (segregación de funciones dura)
  /// Estas reglas tienen prioridad sobre los permisos positivos
  static Map<RolSectorPublico, Set<Permiso>> get negacionesPorRol => {
    // Tesorero NO puede expedir CDP ni RP (segregación de funciones)
    RolSectorPublico.tesorero: {
      Permiso.expedirCDP,
      Permiso.modificarCDP,
      Permiso.expedirRP,
      Permiso.modificarRP,
      Permiso.registrarObligacion,
      Permiso.aprobarPago, // No puede aprobar su propio pago
    },
    // Contador NO puede expedir CDP ni RP (segregación de funciones)
    RolSectorPublico.contador: {
      Permiso.expedirCDP,
      Permiso.modificarCDP,
      Permiso.expedirRP,
      Permiso.modificarRP,
      Permiso.aprobarPago,
      Permiso.ejecutarPago,
    },
    // Ordenador de gasto NO puede ejecutar pagos
    RolSectorPublico.ordenadorGasto: {
      Permiso.ejecutarPago,
      Permiso.aprobarPago,
    },
    // Jefe de rentas NO puede modificar presupuesto
    RolSectorPublico.jefeRentas: {
      Permiso.expedirCDP,
      Permiso.modificarCDP,
      Permiso.expedirRP,
      Permiso.modificarRP,
      Permiso.registrarObligacion,
    },
  };

  /// Verifica si un rol tiene un permiso específico
  static bool tienePermiso(RolSectorPublico rol, Permiso permiso) {
    // Primero verificar negaciones explícitas (tienen prioridad)
    final negaciones = negacionesPorRol[rol];
    if (negaciones != null && negaciones.contains(permiso)) {
      return false;
    }

    // Luego verificar permisos positivos
    final permisos = permisosPorRol[rol];
    return permisos != null && permisos.contains(permiso);
  }

  /// Verifica si un usuario puede realizar una acción específica
  /// Considera múltiples roles y segregación de funciones
  static bool puedeRealizarAccion({
    required Set<RolSectorPublico> roles,
    required Permiso permiso,
    String? usuarioId,
    String? referenciaId,
  }) {
    // Si no tiene roles, denegar
    if (roles.isEmpty) return false;

    // Verificar si alguno de sus roles tiene el permiso
    bool tienePermisoPositivo = roles.any((rol) => tienePermiso(rol, permiso));
    if (!tienePermisoPositivo) return false;

    // Verificar segregación de funciones específica por acción
    // Ejemplo: un tesorero no puede aprobar un pago que él mismo inició
    if (permiso == Permiso.aprobarPago && roles.contains(RolSectorPublico.tesorero)) {
      // Aquí se debería verificar si el usuario es quien inició el pago
      // Esta lógica se implementará con datos adicionales
      return false; // Por defecto, tesorero no aprueba pagos
    }

    // Ejemplo: un contador no puede reversar sus propios asientos del mismo día
    if (permiso == Permiso.reversarAsiento && roles.contains(RolSectorPublico.contador)) {
      // Verificar si el asiento fue creado por el mismo usuario
      // Esta lógica se implementará con datos adicionales
    }

    return true;
  }

  /// Obtiene todos los permisos de un rol (sin negaciones)
  static Set<Permiso> obtenerPermisos(RolSectorPublico rol) {
    return permisosPorRol[rol] ?? {};
  }

  /// Obtiene todas las negaciones de un rol
  static Set<Permiso> obtenerNegaciones(RolSectorPublico rol) {
    return negacionesPorRol[rol] ?? {};
  }

  /// Obtiene los permisos efectivos (positivos - negaciones)
  static Set<Permiso> obtenerPermisosEfectivos(RolSectorPublico rol) {
    final positivos = obtenerPermisos(rol);
    final negaciones = obtenerNegaciones(rol);
    return positivos.difference(negaciones);
  }

  /// Valida una transacción según segregación de funciones
  /// Retorna true si la transacción es válida según las reglas
  static bool validarSegregacionFunciones({
    required RolSectorPublico rolQuienEjecuta,
    required RolSectorPublico rolQuienAprobo,
    required Permiso accion,
  }) {
    // Un tesorero no puede aprobar su propio pago
    if (accion == Permiso.aprobarPago && 
        rolQuienEjecuta == RolSectorPublico.tesorero &&
        rolQuienAprobo == RolSectorPublico.tesorero) {
      return false;
    }

    // Un contador no puede reversar sus propios asientos
    if (accion == Permiso.reversarAsiento &&
        rolQuienEjecuta == RolSectorPublico.contador &&
        rolQuienAprobo == RolSectorPublico.contador) {
      return false;
    }

    // Un ordenador de gasto no puede ejecutar pagos
    if (accion == Permiso.ejecutarPago &&
        rolQuienEjecuta == RolSectorPublico.ordenadorGasto) {
      return false;
    }

    return true;
  }

  /// Obtiene descripción legible del rol
  static String obtenerDescripcionRol(RolSectorPublico rol) {
    switch (rol) {
      case RolSectorPublico.alcaldeRepresentanteLegal:
        return 'Alcalde / Representante Legal';
      case RolSectorPublico.secretarioHacienda:
        return 'Secretario de Hacienda';
      case RolSectorPublico.tesorero:
        return 'Tesorero';
      case RolSectorPublico.contador:
        return 'Contador';
      case RolSectorPublico.jefeRentas:
        return 'Jefe de Rentas';
      case RolSectorPublico.jefeControlInterno:
        return 'Jefe de Control Interno';
      case RolSectorPublico.ordenadorGasto:
        return 'Ordenador del Gasto';
      case RolSectorPublico.jefePlaneacion:
        return 'Jefe de Planeación';
      case RolSectorPublico.secretarioSalud:
        return 'Secretario de Salud';
      case RolSectorPublico.rector:
        return 'Rector';
    }
  }

  /// Obtiene descripción legible del permiso
  static String obtenerDescripcionPermiso(Permiso permiso) {
    switch (permiso) {
      case Permiso.expedirCDP:
        return 'Expedir CDP';
      case Permiso.modificarCDP:
        return 'Modificar CDP';
      case Permiso.expedirRP:
        return 'Expedir RP';
      case Permiso.modificarRP:
        return 'Modificar RP';
      case Permiso.registrarObligacion:
        return 'Registrar Obligación';
      case Permiso.aprobarPago:
        return 'Aprobar Pago';
      case Permiso.ejecutarPago:
        return 'Ejecutar Pago';
      case Permiso.modificarPAC:
        return 'Modificar PAC';
      case Permiso.crearAsientoContable:
        return 'Crear Asiento Contable';
      case Permiso.reversarAsiento:
        return 'Reversar Asiento';
      case Permiso.cerrarVigencia:
        return 'Cerrar Vigencia';
      case Permiso.consultarEstadosFinancieros:
        return 'Consultar Estados Financieros';
      case Permiso.liquidarNomina:
        return 'Liquidar Nómina';
      case Permiso.aprobarNomina:
        return 'Aprobar Nómina';
      case Permiso.pagarNomina:
        return 'Pagar Nómina';
      case Permiso.reliquidarNomina:
        return 'Reliquidar Nómina';
      case Permiso.liquidarTributo:
        return 'Liquidar Tributo';
      case Permiso.cobrarTributo:
        return 'Cobrar Tributo';
      case Permiso.iniciarCobroCoactivo:
        return 'Iniciar Cobro Coactivo';
      case Permiso.condonarTributo:
        return 'Condonar Tributo';
      case Permiso.iniciarProcesoContratacion:
        return 'Iniciar Proceso de Contratación';
      case Permiso.adjudicarContrato:
        return 'Adjudicar Contrato';
      case Permiso.firmarContrato:
        return 'Firmar Contrato';
      case Permiso.liquidarContrato:
        return 'Liquidar Contrato';
      case Permiso.supervisarContrato:
        return 'Supervisar Contrato';
      case Permiso.crearProyecto:
        return 'Crear Proyecto';
      case Permiso.modificarProyecto:
        return 'Modificar Proyecto';
      case Permiso.aprobarProyecto:
        return 'Aprobar Proyecto';
      case Permiso.vincularProyectoPresupuesto:
        return 'Vincular Proyecto a Presupuesto';
      case Permiso.gestionarUsuarios:
        return 'Gestionar Usuarios';
      case Permiso.asignarRoles:
        return 'Asignar Roles';
      case Permiso.consultarAuditoria:
        return 'Consultar Auditoría';
      case Permiso.consultarTodo:
        return 'Consultar Todo';
      case Permiso.exportarDatos:
        return 'Exportar Datos';
    }
  }
}
