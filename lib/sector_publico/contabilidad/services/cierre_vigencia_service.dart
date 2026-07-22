/// Servicio de Cierre de Vigencia
/// Implementa cierre anual según Art. 89 EOP y NICSP
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/asiento_contable.dart';
import '../models/estado_financiero.dart';
import 'contabilidad_nicsp_service.dart';
import '../../security/auditoria_service.dart';
import '../../models/registro_auditoria.dart';

class CierreVigenciaService {
  final Database db;
  final ContabilidadNICSPService contabilidadService;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  CierreVigenciaService({
    required this.db,
    required this.contabilidadService,
    required this.auditoriaService,
  });

  /// Ejecuta el cierre de vigencia
  /// Cálculo de reservas y cuentas por pagar al 31-dic (Art. 89 EOP)
  Future<Map<String, dynamic>> ejecutarCierreVigencia({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required String motivo,
  }) async {
    // Verificar que no exista un cierre previo
    final cierreExistente = await db.query(
      'cierres_vigencia',
      where: 'entidad_id = ? AND vigencia = ?',
      whereArgs: [entidadId, vigencia],
    );

    if (cierreExistente.isNotEmpty) {
      throw Exception('Ya existe un cierre de vigencia para el año $vigencia');
    }

    final fechaCierre = DateTime(int.parse(vigencia), 12, 31);
    final fechaApertura = DateTime(int.parse(vigencia) + 1, 1, 1);

    // 1. Generar asiento de cierre de cuentas de resultado
    final asientoCierre = await _generarAsientoCierreResultados(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigencia: vigencia,
      fechaCierre: fechaCierre,
    );

    // 2. Calcular reservas y cuentas por pagar
    final reservas = await _calcularReservas(
      entidadId: entidadId,
      vigencia: vigencia,
    );

    // 3. Generar asiento de apertura del siguiente año
    final asientoApertura = await _generarAsientoApertura(
      entidadId: entidadId,
      usuarioId: usuarioId,
      vigenciaSiguiente: (int.parse(vigencia) + 1).toString(),
      fechaApertura: fechaApertura,
    );

    // 4. Registrar el cierre
    final cierreId = _uuid.v4();
    await db.insert('cierres_vigencia', {
      'id': cierreId,
      'entidad_id': entidadId,
      'vigencia': vigencia,
      'fecha_cierre': fechaCierre.toIso8601String(),
      'asiento_cierre_id': asientoCierre.id,
      'asiento_apertura_id': asientoApertura.id,
      'usuario_cerro': usuarioId,
      'estado': 'completado',
      'observaciones': motivo,
    });

    await auditoriaService.registrarEvento(
      entidadId: entidadId,
      usuarioId: usuarioId,
      tipoEvento: TipoEventoAuditoria.cierreVigencia,
      modulo: 'contabilidad',
      accion: 'cierre_vigencia',
      valorAnterior: {'vigencia': vigencia},
      valorNuevo: {
        'cierre_id': cierreId,
        'asiento_cierre': asientoCierre.id,
        'asiento_apertura': asientoApertura.id,
        'reservas': reservas,
      },
      referenciaId: cierreId,
    );

    return {
      'cierre_id': cierreId,
      'vigencia': vigencia,
      'fecha_cierre': fechaCierre.toIso8601String(),
      'asiento_cierre_id': asientoCierre.id,
      'asiento_apertura_id': asientoApertura.id,
      'reservas': reservas,
      'estado': 'completado',
    };
  }

  /// Genera asiento de cierre de cuentas de resultado (ingresos y gastos)
  Future<AsientoContable> _generarAsientoCierreResultados({
    required String entidadId,
    required String usuarioId,
    required String vigencia,
    required DateTime fechaCierre,
  }) async {
    // Obtener saldos de cuentas de ingreso (Clase 4)
    final ingresos = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '4%'],
    );

    // Obtener saldos de cuentas de gasto (Clase 5)
    final gastos = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '5%'],
    );

    final detalles = <DetalleAsiento>[];

    // Cerrar ingresos (crédito)
    for (final ingreso in ingresos) {
      final saldoNeto = (ingreso['saldo_neto'] as num).toDouble();
      if (saldoNeto > 0) {
        detalles.add(DetalleAsiento(
          id: _uuid.v4(),
          cuentaCodigo: ingreso['cuenta_codigo'] as String,
          cuentaNombre: ingreso['cuenta_nombre'] as String,
          debito: saldoNeto,
          credito: 0,
        ));
      }
    }

    // Cerrar gastos (débito)
    for (final gasto in gastos) {
      final saldoNeto = (gasto['saldo_neto'] as num).toDouble();
      if (saldoNeto > 0) {
        detalles.add(DetalleAsiento(
          id: _uuid.v4(),
          cuentaCodigo: gasto['cuenta_codigo'] as String,
          cuentaNombre: gasto['cuenta_nombre'] as String,
          debito: 0,
          credito: saldoNeto,
        ));
      }
    }

    // Si hay resultado, llevarlo a resultado del ejercicio
    final totalIngresos = ingresos.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final totalGastos = gastos.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final resultado = totalIngresos - totalGastos;

    if (resultado.abs() > 0.01) {
      detalles.add(DetalleAsiento(
        id: _uuid.v4(),
        cuentaCodigo: '3115',
        cuentaNombre: 'Resultado del ejercicio',
        debito: resultado > 0 ? resultado : 0,
        credito: resultado < 0 ? resultado.abs() : 0,
      ));
    }

    return await contabilidadService.crearAsientoManual(
      entidadId: entidadId,
      usuarioId: usuarioId,
      fechaAsiento: fechaCierre,
      descripcion: 'Cierre de cuentas de resultado - Vigencia $vigencia',
      detalles: detalles,
    );
  }

  /// Genera asiento de apertura del siguiente año
  Future<AsientoContable> _generarAsientoApertura({
    required String entidadId,
    required String usuarioId,
    required String vigenciaSiguiente,
    required DateTime fechaApertura,
  }) async {
    // Obtener saldos de cuentas de balance (Clases 1, 2, 3) al cierre
    final saldosBalance = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND (cuenta_codigo LIKE ? OR cuenta_codigo LIKE ? OR cuenta_codigo LIKE ?)',
      whereArgs: [entidadId, (int.parse(vigenciaSiguiente) - 1).toString(), '1%', '2%', '3%'],
    );

    final detalles = <DetalleAsiento>[];

    for (final saldo in saldosBalance) {
      final saldoNeto = (saldo['saldo_neto'] as num).toDouble();
      if (saldoNeto.abs() > 0.01) {
        detalles.add(DetalleAsiento(
          id: _uuid.v4(),
          cuentaCodigo: saldo['cuenta_codigo'] as String,
          cuentaNombre: saldo['cuenta_nombre'] as String,
          debito: saldoNeto > 0 ? saldoNeto : 0,
          credito: saldoNeto < 0 ? saldoNeto.abs() : 0,
        ));
      }
    }

    return await contabilidadService.crearAsientoManual(
      entidadId: entidadId,
      usuarioId: usuarioId,
      fechaAsiento: fechaApertura,
      descripcion: 'Apertura de cuentas de balance - Vigencia $vigenciaSiguiente',
      detalles: detalles,
    );
  }

  /// Calcula reservas y cuentas por pagar al cierre
  Future<Map<String, dynamic>> _calcularReservas({
    required String entidadId,
    required String vigencia,
  }) async {
    // Cuentas por pagar pendientes (Clase 2)
    final cuentasPagar = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '24%'],
    );

    // Provisiones (NICSP 19)
    final provisiones = await db.query(
      'provisiones',
      where: 'entidad_id = ? AND estado = ?',
      whereArgs: [entidadId, 'activa'],
    );

    final totalCuentasPagar = cuentasPagar.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final totalProvisiones = provisiones.fold(
0.0, (sum, r) => sum + (r['valor_provision'] as num).toDouble());

    return {
      'cuentas_por_pagar': totalCuentasPagar,
      'provisiones': totalProvisiones,
      'total_reservas': totalCuentasPagar + totalProvisiones,
    };
  }

  /// Genera Estado de Situación Financiera (Balance General)
  Future<EstadoSituacionFinanciera> generarEstadoSituacionFinanciera({
    required String entidadId,
    required String vigencia,
    required DateTime fechaCorte,
  }) async {
    // Activos (Clase 1)
    final activos = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '1%'],
    );

    // Pasivos (Clase 2)
    final pasivos = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '2%'],
    );

    // Patrimonio (Clase 3)
    final patrimonio = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '3%'],
    );

    final totalActivo = activos.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final totalPasivo = pasivos.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final totalPatrimonio = patrimonio.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());

    return EstadoSituacionFinanciera(
      entidadId: entidadId,
      vigencia: vigencia,
      fechaCorte: fechaCorte,
      totalActivo: totalActivo,
      totalPasivo: totalPasivo,
      totalPatrimonio: totalPatrimonio,
      totalPasivoPatrimonio: totalPasivo + totalPatrimonio,
      activos: activos.map((r) => RenglonEstado(
        codigoCuenta: r['cuenta_codigo'] as String,
        nombreCuenta: r['cuenta_nombre'] as String,
        valor: (r['saldo_neto'] as num).toDouble(),
        nivel: 1,
      )).toList(),
      pasivos: pasivos.map((r) => RenglonEstado(
        codigoCuenta: r['cuenta_codigo'] as String,
        nombreCuenta: r['cuenta_nombre'] as String,
        valor: (r['saldo_neto'] as num).toDouble(),
        nivel: 1,
      )).toList(),
      patrimonio: patrimonio.map((r) => RenglonEstado(
        codigoCuenta: r['cuenta_codigo'] as String,
        nombreCuenta: r['cuenta_nombre'] as String,
        valor: (r['saldo_neto'] as num).toDouble(),
        nivel: 1,
      )).toList(),
    );
  }

  /// Genera Estado de Resultado Operacional (PyG)
  Future<EstadoResultadoOperacional> generarEstadoResultado({
    required String entidadId,
    required String vigencia,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    // Ingresos (Clase 4)
    final ingresos = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '4%'],
    );

    // Gastos (Clase 5)
    final gastos = await db.query(
      'saldos_cuentas',
      where: 'entidad_id = ? AND vigencia = ? AND cuenta_codigo LIKE ?',
      whereArgs: [entidadId, vigencia, '5%'],
    );

    final totalIngresos = ingresos.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final totalGastos = gastos.fold(
0.0, (sum, r) => sum + (r['saldo_neto'] as num).toDouble());
    final resultadoOperacional = totalIngresos - totalGastos;

    return EstadoResultadoOperacional(
      entidadId: entidadId,
      vigencia: vigencia,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      totalIngresos: totalIngresos,
      totalGastos: totalGastos,
      resultadoOperacional: resultadoOperacional,
      ingresos: ingresos.map((r) => RenglonEstado(
        codigoCuenta: r['cuenta_codigo'] as String,
        nombreCuenta: r['cuenta_nombre'] as String,
        valor: (r['saldo_neto'] as num).toDouble(),
        nivel: 1,
      )).toList(),
      gastos: gastos.map((r) => RenglonEstado(
        codigoCuenta: r['cuenta_codigo'] as String,
        nombreCuenta: r['cuenta_nombre'] as String,
        valor: (r['saldo_neto'] as num).toDouble(),
        nivel: 1,
      )).toList(),
    );
  }

  /// Genera Estado de Flujos de Efectivo (NICSP 2)
  Future<EstadoFlujosEfectivo> generarEstadoFlujosEfectivo({
    required String entidadId,
    required String vigencia,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    // Actividades de operación (cuentas 1, 4, 5 relacionadas con operación)
    final actividadesOperacion = await db.query(
      'detalles_asientos d JOIN asientos_contables_sp a ON d.asiento_id = a.id',
      columns: ['d.cuenta_codigo', 'd.cuenta_nombre', 'd.debito', 'd.credito'],
      where: 'a.entidad_id = ? AND a.fecha_asiento BETWEEN ? AND ? AND d.cuenta_codigo IN (?, ?)',
      whereArgs: [
        entidadId,
        fechaInicio.toIso8601String(),
        fechaFin.toIso8601String(),
        '1110',
        '1120',
      ],
    );

    // Cálculo simplificado - en producción se requiere lógica más compleja
    final totalOperacion = actividadesOperacion.fold(
0.0, (sum, r) => sum + ((r['debito'] as num).toDouble() - (r['credito'] as num).toDouble()));

    return EstadoFlujosEfectivo(
      entidadId: entidadId,
      vigencia: vigencia,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      totalActividadesOperacion: totalOperacion,
      totalActividadesInversion: 0,
      totalActividadesFinanciacion: 0,
      variacionNetaEfectivo: totalOperacion,
      efectivoAlInicio: 0,
      efectivoAlFinal: totalOperacion,
      actividadesOperacion: [],
      actividadesInversion: [],
      actividadesFinanciacion: [],
    );
  }

  /// Verifica si una vigencia está cerrada
  Future<bool> vigenciaCerrada(String entidadId, String vigencia) async {
    final resultado = await db.query(
      'cierres_vigencia',
      where: 'entidad_id = ? AND vigencia = ? AND estado = ?',
      whereArgs: [entidadId, vigencia, 'completado'],
    );

    return resultado.isNotEmpty;
  }
}
