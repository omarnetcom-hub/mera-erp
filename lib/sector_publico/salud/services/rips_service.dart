/// Servicio de RIPS (Registros Individuales de Prestación de Servicios)
/// Ministerio de Salud
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/rips.dart';
import '../../models/registro_auditoria.dart';
import '../../security/auditoria_service.dart';

class RIPSService {
  final Database db;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  RIPSService({
    required this.db,
    required this.auditoriaService,
  });

  /// Registra un RIPS
  Future<RIPS> registrarRIPS({
    required String entidadId,
    required String usuarioId,
    required TipoRIPS tipoRIPS,
    required String codigoPrestador,
    required String nombrePrestador,
    required String numeroFactura,
    required DateTime fechaFactura,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required String codigoPaciente,
    required String nombrePaciente,
    required String tipoIdentificacion,
    required String numeroIdentificacion,
    required String codigoServicio,
    required String nombreServicio,
    required double valorServicio,
    double? valorCopago,
    double? valorModera,
    String? diagnosticoPrincipal,
    String? diagnosticoRelacionado,
  }) async {
    final id = _uuid.v4();
    final copago = valorCopago ?? 0;
    final modera = valorModera ?? 0;
    final valorNeto = valorServicio - copago - modera;

    final rips = RIPS(
      id: id,
      entidadId: entidadId,
      tipoRIPS: tipoRIPS,
      codigoPrestador: codigoPrestador,
      nombrePrestador: nombrePrestador,
      numeroFactura: numeroFactura,
      fechaFactura: fechaFactura,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      codigoPaciente: codigoPaciente,
      nombrePaciente: nombrePaciente,
      tipoIdentificacion: tipoIdentificacion,
      numeroIdentificacion: numeroIdentificacion,
      codigoServicio: codigoServicio,
      nombreServicio: nombreServicio,
      valorServicio: valorServicio,
      valorCopago: copago,
      valorModera: modera,
      valorNeto: valorNeto,
      diagnosticoPrincipal: diagnosticoPrincipal,
      diagnosticoRelacionado: diagnosticoRelacionado,
    );

    await db.insert('rips', rips.toJson());

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.creacionRegistro,
      modulo: 'salud',
      accion: 'registro_rips',
      valorAnterior: {},
      valorNuevo: {
        'rips_id': id,
        'tipo_rips': tipoRIPS.toString(),
        'numero_factura': numeroFactura,
        'valor_neto': valorNeto,
      },
      referenciaId: id,
    );

    return rips;
  }

  /// Genera archivo plano RIPS para envío a EPS
  Future<String> generarArchivoPlanoRIPS({
    required String entidadId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final resultados = await db.query(
      'rips',
      where: 'entidad_id = ? AND fecha_factura BETWEEN ? AND ?',
      whereArgs: [
        entidadId,
        fechaInicio.toIso8601String(),
        fechaFin.toIso8601String(),
      ],
    );

    final buffer = StringBuffer();
    buffer.writeln('TIPO_REGISTRO;1');
    buffer.writeln('ENTIDAD;$entidadId');
    buffer.writeln('FECHA_INICIO;${fechaInicio.toIso8601String()}');
    buffer.writeln('FECHA_FIN;${fechaFin.toIso8601String()}');
    buffer.writeln('TOTAL_REGISTROS;${resultados.length}');

    for (final rips in resultados) {
      buffer.writeln('DETALLE');
      buffer.writeln('TIPO_RIPS;${rips['tipo_rips']}');
      buffer.writeln('CODIGO_PRESTADOR;${rips['codigo_prestador']}');
      buffer.writeln('NUMERO_FACTURA;${rips['numero_factura']}');
      buffer.writeln('CODIGO_PACIENTE;${rips['codigo_paciente']}');
      buffer.writeln('IDENTIFICACION;${rips['numero_identificacion']}');
      buffer.writeln('CODIGO_SERVICIO;${rips['codigo_servicio']}');
      buffer.writeln('VALOR_SERVICIO;${rips['valor_servicio']}');
      buffer.writeln('VALOR_NETO;${rips['valor_neto']}');
    }

    return buffer.toString();
  }

  Future<List<RIPS>> consultarRIPS({
    required String entidadId,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    TipoRIPS? tipoRIPS,
  }) async {
    String query = 'SELECT * FROM rips WHERE entidad_id = ?';
    List<dynamic> args = [entidadId];

    if (fechaDesde != null) {
      query += ' AND fecha_factura >= ?';
      args.add(fechaDesde.toIso8601String());
    }

    if (fechaHasta != null) {
      query += ' AND fecha_factura <= ?';
      args.add(fechaHasta.toIso8601String());
    }

    if (tipoRIPS != null) {
      query += ' AND tipo_rips = ?';
      args.add(tipoRIPS.toString().split('.').last);
    }

    query += ' ORDER BY fecha_factura DESC';

    final resultados = await db.rawQuery(query, args);
    return resultados.map((r) => RIPS.fromJson(r)).toList();
  }

  /// Valida formato RIPS contra Resolución 2275/2023
  Future<Map<String, dynamic>> validarFormatoRIPS({
    required String formatoPlano,
    required TipoRIPS tipoRIPS,
  }) async {
    final lineas = formatoPlano.split('\n');
    final errores = <String>[];
    final advertencias = <String>[];

    // Validaciones generales
    if (lineas.isEmpty) {
      errores.add('El archivo está vacío');
    }

    // Validaciones específicas por tipo de RIPS
    switch (tipoRIPS) {
      case TipoRIPS.ac:
        errores.addAll(_validarRIPSAC(lineas));
        break;
      case TipoRIPS.ap:
        errores.addAll(_validarRIPSAP(lineas));
        break;
      case TipoRIPS.am:
        errores.addAll(_validarRIPSAM(lineas));
        break;
      case TipoRIPS.at:
        errores.addAll(_validarRIPSAT(lineas));
        break;
      case TipoRIPS.ah:
        errores.addAll(_validarRIPSAH(lineas));
        break;
      case TipoRIPS.an:
        errores.addAll(_validarRIPSAN(lineas));
        break;
      case TipoRIPS.au:
        errores.addAll(_validarRIPSAU(lineas));
        break;
      case TipoRIPS.af:
        errores.addAll(_validarRIPSAF(lineas));
        break;
    }

    return {
      'valido': errores.isEmpty,
      'errores': errores,
      'advertencias': advertencias,
      'total_lineas': lineas.length,
    };
  }

  /// Valida RIPS AC - Consultas
  List<String> _validarRIPSAC(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'FECHA_CONSULTA',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AC: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AP - Procedimientos
  List<String> _validarRIPSAP(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'CODIGO_PROCEDIMIENTO',
      'FECHA_PROCEDIMIENTO',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AP: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AM - Medicamentos
  List<String> _validarRIPSAM(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'CODIGO_MEDICAMENTO',
      'FECHA_DISPENSACION',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AM: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AT - Otros Servicios
  List<String> _validarRIPSAT(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'CODIGO_SERVICIO',
      'FECHA_SERVICIO',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AT: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AH - Hospitalización
  List<String> _validarRIPSAH(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'FECHA_INGRESO',
      'FECHA_SALIDA',
      'DIAGNOSTICO_PRINCIPAL',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AH: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AN - Urgencias
  List<String> _validarRIPSAN(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'FECHA_INGRESO',
      'DIAGNOSTICO_PRINCIPAL',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AN: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AU - Usuarios
  List<String> _validarRIPSAU(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'CODIGO_PACIENTE',
      'IDENTIFICACION',
      'TIPO_IDENTIFICACION',
      'NOMBRE_PACIENTE',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AU: $campo');
      }
    }

    return errores;
  }

  /// Valida RIPS AF - Facturación
  List<String> _validarRIPSAF(List<String> lineas) {
    final errores = <String>[];
    
    final camposObligatorios = [
      'TIPO_REGISTRO',
      'CODIGO_PRESTADOR',
      'NUMERO_FACTURA',
      'FECHA_FACTURA',
      'VALOR_TOTAL',
    ];

    for (final campo in camposObligatorios) {
      if (!lineas.any((linea) => linea.startsWith(campo))) {
        errores.add('Campo obligatorio faltante en AF: $campo');
      }
    }

    return errores;
  }
}

