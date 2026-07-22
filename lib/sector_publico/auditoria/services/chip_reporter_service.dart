/// Servicio de Reportes CHIP (Contaduría General de la Nación)
/// Generación de formularios CGN 2015_001 a 005 y CGN 2016C01
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/reporte_chip.dart';
import '../../security/auditoria_service.dart';
import '../../models/registro_auditoria.dart';

class CHIPReporterService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  CHIPReporterService({
    required this.db,
    required this.auditoriaService,
  });

  /// Genera formulario CGN 2015_001 - Información de la Entidad
  Future<ReporteCHIP> generarCGN2015_001({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DatosCGN2015_001 datos,
  }) async {
    final id = _uuid.v4();
    final fechaGeneracion = DateTime.now();

    final reporte = ReporteCHIP(
      id: id,
      entidadId: entidadId,
      tipoFormulario: TipoFormularioCHIP.cgn2015_001,
      vigencia: vigencia,
      fechaGeneracion: fechaGeneracion,
      usuarioGenero: usuarioId,
      datos: datos.toJson(),
      estado: 'generado',
    );

    await db.insert('reportes_chip', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'auditoria',
      accion: 'generacion_chip_cgn2015_001',
      valorAnterior: {},
      valorNuevo: {'reporte_id': id, 'vigencia': vigencia},
      referenciaId: id,
    );

    return reporte;
  }

  /// Genera formulario CGN 2015_002 - Ingresos y Gastos
  Future<ReporteCHIP> generarCGN2015_002({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DatosCGN2015_002 datos,
  }) async {
    final id = _uuid.v4();
    final fechaGeneracion = DateTime.now();

    final reporte = ReporteCHIP(
      id: id,
      entidadId: entidadId,
      tipoFormulario: TipoFormularioCHIP.cgn2015_002,
      vigencia: vigencia,
      fechaGeneracion: fechaGeneracion,
      usuarioGenero: usuarioId,
      datos: datos.toJson(),
      estado: 'generado',
    );

    await db.insert('reportes_chip', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'auditoria',
      accion: 'generacion_chip_cgn2015_002',
      valorAnterior: {},
      valorNuevo: {'reporte_id': id, 'vigencia': vigencia},
      referenciaId: id,
    );

    return reporte;
  }

  /// Genera formulario CGN 2015_003 - Situación Financiera
  Future<ReporteCHIP> generarCGN2015_003({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DatosCGN2015_003 datos,
  }) async {
    final id = _uuid.v4();
    final fechaGeneracion = DateTime.now();

    final reporte = ReporteCHIP(
      id: id,
      entidadId: entidadId,
      tipoFormulario: TipoFormularioCHIP.cgn2015_003,
      vigencia: vigencia,
      fechaGeneracion: fechaGeneracion,
      usuarioGenero: usuarioId,
      datos: datos.toJson(),
      estado: 'generado',
    );

    await db.insert('reportes_chip', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'auditoria',
      accion: 'generacion_chip_cgn2015_003',
      valorAnterior: {},
      valorNuevo: {'reporte_id': id, 'vigencia': vigencia},
      referenciaId: id,
    );

    return reporte;
  }

  /// Genera formulario CGN 2015_004 - Ejecución Presupuestal
  Future<ReporteCHIP> generarCGN2015_004({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DatosCGN2015_004 datos,
  }) async {
    final id = _uuid.v4();
    final fechaGeneracion = DateTime.now();

    final reporte = ReporteCHIP(
      id: id,
      entidadId: entidadId,
      tipoFormulario: TipoFormularioCHIP.cgn2015_004,
      vigencia: vigencia,
      fechaGeneracion: fechaGeneracion,
      usuarioGenero: usuarioId,
      datos: datos.toJson(),
      estado: 'generado',
    );

    await db.insert('reportes_chip', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'auditoria',
      accion: 'generacion_chip_cgn2015_004',
      valorAnterior: {},
      valorNuevo: {'reporte_id': id, 'vigencia': vigencia},
      referenciaId: id,
    );

    return reporte;
  }

  /// Genera formulario CGN 2015_005 - Deuda Pública
  Future<ReporteCHIP> generarCGN2015_005({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DatosCGN2015_005 datos,
  }) async {
    final id = _uuid.v4();
    final fechaGeneracion = DateTime.now();

    final reporte = ReporteCHIP(
      id: id,
      entidadId: entidadId,
      tipoFormulario: TipoFormularioCHIP.cgn2015_005,
      vigencia: vigencia,
      fechaGeneracion: fechaGeneracion,
      usuarioGenero: usuarioId,
      datos: datos.toJson(),
      estado: 'generado',
    );

    await db.insert('reportes_chip', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'auditoria',
      accion: 'generacion_chip_cgn2015_005',
      valorAnterior: {},
      valorNuevo: {'reporte_id': id, 'vigencia': vigencia},
      referenciaId: id,
    );

    return reporte;
  }

  /// Genera formulario CGN 2016C01 - Consolidado
  Future<ReporteCHIP> generarCGN2016C01({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required Map<String, dynamic> datosConsolidados,
  }) async {
    final id = _uuid.v4();
    final fechaGeneracion = DateTime.now();

    final reporte = ReporteCHIP(
      id: id,
      entidadId: entidadId,
      tipoFormulario: TipoFormularioCHIP.cgn2016C01,
      vigencia: vigencia,
      fechaGeneracion: fechaGeneracion,
      usuarioGenero: usuarioId,
      datos: datosConsolidados,
      estado: 'generado',
    );

    await db.insert('reportes_chip', reporte.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'auditoria',
      accion: 'generacion_chip_cgn2016c01',
      valorAnterior: {},
      valorNuevo: {'reporte_id': id, 'vigencia': vigencia},
      referenciaId: id,
    );

    return reporte;
  }

  /// Genera todos los formularios CHIP para una vigencia
  Future<Map<String, ReporteCHIP>> generarPaqueteCHIP({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DatosCGN2015_001 datos001,
    required DatosCGN2015_002 datos002,
    required DatosCGN2015_003 datos003,
    required DatosCGN2015_004 datos004,
    required DatosCGN2015_005 datos005,
  }) async {
    final reporte001 = await generarCGN2015_001(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigencia: vigencia,
      datos: datos001,
    );

    final reporte002 = await generarCGN2015_002(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigencia: vigencia,
      datos: datos002,
    );

    final reporte003 = await generarCGN2015_003(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigencia: vigencia,
      datos: datos003,
    );

    final reporte004 = await generarCGN2015_004(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigencia: vigencia,
      datos: datos004,
    );

    final reporte005 = await generarCGN2015_005(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigencia: vigencia,
      datos: datos005,
    );

    return {
      'cgn2015_001': reporte001,
      'cgn2015_002': reporte002,
      'cgn2015_003': reporte003,
      'cgn2015_004': reporte004,
      'cgn2015_005': reporte005,
    };
  }

  /// Marca un reporte como enviado
  Future<void> marcarEnviado({
    required String reporteId,
    required String usuarioId,
  }) async {
    await db.update(
      'reportes_chip',
      {'estado': 'enviado'},
      where: 'id = ?',
      whereArgs: [reporteId],
    );

    final reporte = await obtenerReporte(reporteId);
    if (reporte != null) {
      await auditoriaService.registrarEvento(
        entidadId: reporte.entidadId,
        usuarioId: usuarioId,
        tipoEvento: TipoEventoAuditoria.modificacionRegistro,
        modulo: 'auditoria',
        accion: 'envio_chip',
        valorAnterior: {'estado_anterior': 'generado'},
        valorNuevo: {'estado_nuevo': 'enviado'},
        referenciaId: reporteId,
      );
    }
  }

  /// Consulta reportes CHIP por entidad y vigencia
  Future<List<ReporteCHIP>> consultarReportes({
    required String entidadId,
    String? vigencia,
    TipoFormularioCHIP? tipoFormulario,
  }) async {
    String query = 'SELECT * FROM reportes_chip WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (vigencia != null) {
      query += ' AND vigencia = ?';
      args.add(vigencia);
    }

    if (tipoFormulario != null) {
      query += ' AND tipo_formulario = ?';
      args.add(tipoFormulario.toString().split('.').last);
    }

    query += ' ORDER BY fecha_generacion DESC';

    final resultados = await db.rawQuery(query, args);

    return resultados.map((r) => ReporteCHIP.fromJson(r)).toList();
  }

  /// Obtiene un reporte por ID
  Future<ReporteCHIP?> obtenerReporte(String id) async {
    final resultado = await db.query(
      'reportes_chip',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (resultado.isEmpty) return null;
    return ReporteCHIP.fromJson(resultado.first);
  }

  /// Exporta reporte a formato plano (para envío a CGN)
  Future<String> exportarAPlano(String reporteId) async {
    final reporte = await obtenerReporte(reporteId);
    if (reporte == null) {
      throw Exception('Reporte no encontrado');
    }

    // Generar formato plano según especificaciones CGN
    final buffer = StringBuffer();
    buffer.writeln('TIPO_FORMULARIO;${reporte.tipoFormulario.toString().split('.').last}');
    buffer.writeln('ENTIDAD_ID;${reporte.entidadId}');
    buffer.writeln('VIGENCIA;${reporte.vigencia}');
    buffer.writeln('FECHA_GENERACION;${reporte.fechaGeneracion.toIso8601String()}');
    buffer.writeln('USUARIO_GENERO;${reporte.usuarioGenero}');
    buffer.writeln('ESTADO;${reporte.estado}');

    // Datos específicos del formulario
    reporte.datos.forEach((key, value) {
      buffer.writeln('$key;$value');
    });

    return buffer.toString();
  }

  /// Valida formato plano CHIP contra especificaciones CGN
  Future<Map<String, dynamic>> validarFormatoCHIP({
    required String formatoPlano,
    required TipoFormularioCHIP tipoFormulario,
  }) async {
    final lineas = formatoPlano.split('\n');
    final errores = <String>[];
    final advertencias = <String>[];

    // Validaciones generales
    if (lineas.isEmpty) {
      errores.add('El archivo está vacío');
    }

    // Validaciones específicas por tipo de formulario
    switch (tipoFormulario) {
      case TipoFormularioCHIP.cgn2015_001:
        errores.addAll(_validarCGN2015_001(lineas));
        break;
      case TipoFormularioCHIP.cgn2015_002:
        errores.addAll(_validarCGN2015_002(lineas));
        break;
      case TipoFormularioCHIP.cgn2015_003:
        errores.addAll(_validarCGN2015_003(lineas));
        break;
      case TipoFormularioCHIP.cgn2015_004:
        errores.addAll(_validarCGN2015_004(lineas));
        break;
      case TipoFormularioCHIP.cgn2015_005:
        errores.addAll(_validarCGN2015_005(lineas));
        break;
      case TipoFormularioCHIP.cgn2016C01:
        errores.addAll(_validarCGN2016C01(lineas));
        break;
    }

    return {
      'valido': errores.isEmpty,
      'errores': errores,
      'advertencias': advertencias,
      'total_lineas': lineas.length,
    };
  }

  /// Valida CGN 2015_001 - Información de la Entidad
  List<String> _validarCGN2015_001(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_FORMULARIO',
      'ENTIDAD_ID',
      'VIGENCIA',
      'FECHA_GENERACION',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante: $campo');
      }
    }

    return errores;
  }

  /// Valida CGN 2015_002 - Ingresos y Gastos
  List<String> _validarCGN2015_002(List<String> lineas) {
    final errores = <String>[];
    
    for (final linea in lineas) {
      if (linea.startsWith('VALOR_')) {
        final partes = linea.split(';');
        if (partes.length < 2) continue;
        final valor = partes[1];
        if (double.tryParse(valor) == null) {
          errores.add('Valor no numérico: $valor');
        }
      }
    }

    return errores;
  }

  /// Valida CGN 2015_003 - Situación Financiera
  List<String> _validarCGN2015_003(List<String> lineas) {
    final errores = <String>[];
    
    double activo = 0;
    double pasivo = 0;
    double patrimonio = 0;

    for (final linea in lineas) {
      if (linea.startsWith('TOTAL_ACTIVO;')) {
        activo = double.tryParse(linea.split(';')[1]) ?? 0;
      }
      if (linea.startsWith('TOTAL_PASIVO;')) {
        pasivo = double.tryParse(linea.split(';')[1]) ?? 0;
      }
      if (linea.startsWith('TOTAL_PATRIMONIO;')) {
        patrimonio = double.tryParse(linea.split(';')[1]) ?? 0;
      }
    }

    if ((activo - (pasivo + patrimonio)).abs() > 0.01) {
      errores.add('El activo no cuadra con pasivo + patrimonio');
    }

    return errores;
  }

  /// Valida CGN 2015_004 - Ejecución Presupuestal
  List<String> _validarCGN2015_004(List<String> lineas) {
    final errores = <String>[];
    
    double ingresos = 0;
    double gastos = 0;

    for (final linea in lineas) {
      if (linea.startsWith('TOTAL_INGRESOS;')) {
        ingresos = double.tryParse(linea.split(';')[1]) ?? 0;
      }
      if (linea.startsWith('TOTAL_GASTOS;')) {
        gastos = double.tryParse(linea.split(';')[1]) ?? 0;
      }
    }

    if ((ingresos - gastos).abs() > 0.01) {
      errores.add('Los ingresos no cuadran con los gastos');
    }

    return errores;
  }

  /// Valida CGN 2015_005 - Deuda Pública
  List<String> _validarCGN2015_005(List<String> lineas) {
    final errores = <String>[];
    
    double deudaInterna = 0;
    double deudaExterna = 0;
    double deudaTotal = 0;

    for (final linea in lineas) {
      if (linea.startsWith('DEUDA_INTERNA;')) {
        deudaInterna = double.tryParse(linea.split(';')[1]) ?? 0;
      }
      if (linea.startsWith('DEUDA_EXTERNA;')) {
        deudaExterna = double.tryParse(linea.split(';')[1]) ?? 0;
      }
      if (linea.startsWith('DEUDA_TOTAL;')) {
        deudaTotal = double.tryParse(linea.split(';')[1]) ?? 0;
      }
    }

    if ((deudaTotal - (deudaInterna + deudaExterna)).abs() > 0.01) {
      errores.add('La deuda total no cuadra con interna + externa');
    }

    return errores;
  }

  /// Valida CGN 2016C01 - Consolidado
  List<String> _validarCGN2016C01(List<String> lineas) {
    final errores = <String>[];
    
    final formulariosComponentes = [
      'CGN2015_001',
      'CGN2015_002',
      'CGN2015_003',
      'CGN2015_004',
      'CGN2015_005',
    ];

    for (final formulario in formulariosComponentes) {
      if (!lineas.any((linea) => linea.contains(formulario))) {
        errores.add('Formulario componente faltante: $formulario');
      }
    }

    return errores;
  }

  /// Guarda o actualiza los funcionarios responsables y datos de contacto de la entidad
  Future<void> guardarFuncionariosResponsables({
    required String entidadId,
    required String representanteNombre,
    required String representanteId,
    required String ordenadorNombre,
    required String ordenadorId,
    required String contadorNombre,
    required String contadorId,
    required String contadorTarjeta,
    required String direccion,
    required String telefono,
    required String email,
  }) async {
    final batch = db.batch();

    // Representante Legal
    batch.insert('funcionarios_entidad', {
      'id': 'FL-$entidadId-representante_legal',
      'entidad_id': entidadId,
      'cargo_clave': 'representante_legal',
      'nombre_completo': representanteNombre,
      'identificacion': representanteId,
      'tarjeta_profesional': '',
      'telefono': '',
      'email': '',
      'direccion': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Ordenador
    batch.insert('funcionarios_entidad', {
      'id': 'FL-$entidadId-ordenador_gasto',
      'entidad_id': entidadId,
      'cargo_clave': 'ordenador_gasto',
      'nombre_completo': ordenadorNombre,
      'identificacion': ordenadorId,
      'tarjeta_profesional': '',
      'telefono': '',
      'email': '',
      'direccion': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Contador
    batch.insert('funcionarios_entidad', {
      'id': 'FL-$entidadId-contador',
      'entidad_id': entidadId,
      'cargo_clave': 'contador',
      'nombre_completo': contadorNombre,
      'identificacion': contadorId,
      'tarjeta_profesional': contadorTarjeta,
      'telefono': '',
      'email': '',
      'direccion': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Contacto Entidad
    batch.insert('funcionarios_entidad', {
      'id': 'FL-$entidadId-contacto_entidad',
      'entidad_id': entidadId,
      'cargo_clave': 'contacto_entidad',
      'nombre_completo': '',
      'identificacion': '',
      'tarjeta_profesional': '',
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
  }
}
