import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../db_helper.dart';
import '../../security/auditoria_service.dart';
import '../services/nomina_service.dart';
import '../services/pila_service.dart';
import '../services/retroactivos_service.dart';
import '../models/empleado.dart';
import '../models/liquidacion_nomina.dart';
import '../models/retroactivo.dart';

class NominaPublicaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const NominaPublicaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<NominaPublicaPage> createState() => _NominaPublicaPageState();
}

class _NominaPublicaPageState extends State<NominaPublicaPage> {
  int _selectedIndex = 0;
  bool _loading = true;
  late NominaService _nominaService;
  late PILAService _pilaService;
  late RetroactivosService _retroactivosService;

  List<Empleado> _empleados = [];
  List<LiquidacionNomina> _liquidaciones = [];
  List<Retroactivo> _retroactivos = [];
  Map<String, dynamic>? _pilaReporte;

  // Configuración Legal (SMMLV y Auxilio de Transporte)
  double _smmlvConfig = 1300000.0;
  double _auxilioTransporteConfig = 162000.0;

  final List<String> _titulos = [
    'Gestión de Empleados',
    'Liquidaciones de Nómina',
    'Retroactivos',
    'Planilla PILA',
    'Configuración Legal',
  ];

  @override
  void initState() {
    super.initState();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final auditoriaService = AuditoriaService(db);

      _nominaService = NominaService(db: db, auditoriaService: auditoriaService);
      _pilaService = PILAService(db: db, auditoriaService: auditoriaService);
      _retroactivosService = RetroactivosService(db: db, auditoriaService: auditoriaService);

      await _cargarConfiguracion();
      await _cargarDatos();
    } catch (e) {
      _mostrarError('Error al inicializar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final configResult = await db.query(
        'configuracion_entidad',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
      );

      if (configResult.isNotEmpty) {
        final Map<String, dynamic> config = jsonDecode(configResult.first['valor'] as String);
        setState(() {
          if (config.containsKey('smmlv')) {
            _smmlvConfig = (config['smmlv'] as num).toDouble();
          }
          if (config.containsKey('auxilio_transporte')) {
            _auxilioTransporteConfig = (config['auxilio_transporte'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      _mostrarError('Error al cargar configuración: $e');
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Cargar Empleados
      final empleadosResult = await db.query(
        'empleados_sp',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
        orderBy: 'nombre_completo',
      );
      _empleados = empleadosResult.map((r) => Empleado.fromJson(r)).toList();

      // 2. Cargar Liquidaciones
      _liquidaciones = await _nominaService.consultarLiquidaciones(
        entidadId: widget.entidadId,
      );

      // 3. Cargar Retroactivos
      _retroactivos = await _retroactivosService.consultarRetroactivos(
        entidadId: widget.entidadId,
      );
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_selectedIndex]),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildEmpleadosTab(),
                _buildLiquidacionesTab(),
                _buildRetroactivosTab(),
                _buildPILATab(),
                _buildConfiguracionTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF006D77),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Empleados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Nómina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Retroactivos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'PILA',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _registrarEmpleado,
              backgroundColor: const Color(0xFF006D77),
              child: const Icon(Icons.person_add),
            )
          : _selectedIndex == 1
              ? FloatingActionButton(
                  onPressed: _liquidarNomina,
                  backgroundColor: const Color(0xFF006D77),
                  child: const Icon(Icons.calculate),
                )
              : _selectedIndex == 2
                  ? FloatingActionButton(
                      onPressed: _calcularRetroactivo,
                      backgroundColor: const Color(0xFF006D77),
                      child: const Icon(Icons.add),
                    )
                  : null,
    );
  }

  Widget _buildEmpleadosTab() {
    if (_empleados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay empleados registrados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _registrarEmpleado,
              icon: const Icon(Icons.person_add),
              label: const Text('Registrar Empleado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D77),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _empleados.length,
      itemBuilder: (context, index) {
        final emp = _empleados[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(emp.nombreCompleto),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identificación: ${emp.numeroIdentificacion}'),
                Text('Cargo: ${emp.cargo} | Dependencia: ${emp.dependencia}'),
                Text('Salario: \$${emp.salarioBasico.toStringAsFixed(2)}'),
              ],
            ),
            trailing: Chip(
              label: Text(emp.activo ? 'ACTIVO' : 'RETIRO'),
              backgroundColor: emp.activo ? Colors.green : Colors.red,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiquidacionesTab() {
    if (_liquidaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay liquidaciones generadas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _liquidarNomina,
              icon: const Icon(Icons.calculate),
              label: const Text('Liquidar Nómina'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D77),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _liquidaciones.length,
      itemBuilder: (context, index) {
        final liq = _liquidaciones[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(liq.numeroLiquidacion),
            subtitle: Text('${liq.empleadoNombre} | Periodo: ${liq.periodo}'),
            trailing: Text(
              '\$${liq.netoPagar.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salario Básico: \$${liq.salarioBasico.toStringAsFixed(2)}'),
                    Text('Salario Devengado: \$${liq.salarioDevengado.toStringAsFixed(2)}'),
                    Text('Auxilio Transporte: \$${liq.auxilioTransporte.toStringAsFixed(2)}'),
                    Text('Horas Extra / Recargo Nocturno: \$${(liq.horasExtra + liq.recargoNocturno).toStringAsFixed(2)}'),
                    const Divider(),
                    Text('Deducción Salud (8.5%): \$${liq.salud.toStringAsFixed(2)}'),
                    Text('Deducción Pensión (12%): \$${liq.pension.toStringAsFixed(2)}'),
                    Text('Deducción Solidaridad: \$${liq.fondoSolidaridad.toStringAsFixed(2)}'),
                    Text('Riesgos Laborales: \$${liq.riesgosLaborales.toStringAsFixed(2)}'),
                    const Divider(),
                    Text('Aporte Caja Compensación: \$${liq.cajaCompensacion.toStringAsFixed(2)}'),
                    Text('Aporte SENA / ICBF: \$${(liq.sena + liq.icbf).toStringAsFixed(2)}'),
                    const Divider(),
                    Text(
                      'Neto a Pagar: \$${liq.netoPagar.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    if (liq.observaciones != null && liq.observaciones!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.amber, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                liq.observaciones!,
                                style: const TextStyle(fontSize: 11, color: Colors.brown),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetroactivosTab() {
    if (_retroactivos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay retroactivos calculados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _calcularRetroactivo,
              icon: const Icon(Icons.add),
              label: const Text('Calcular Retroactivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D77),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _retroactivos.length,
      itemBuilder: (context, index) {
        final ret = _retroactivos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(ret.numeroRetroactivo),
            subtitle: Text('${ret.empleadoNombre} | Total: \$${ret.valorTotal.toStringAsFixed(2)}'),
            trailing: Chip(
              label: Text(ret.estado.toString().split('.').last.toUpperCase()),
              backgroundColor: ret.estado == EstadoRetroactivo.pagado ? Colors.green : Colors.orange,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motivo: ${ret.motivo}'),
                    Text('Rango: ${ret.fechaInicio.toLocal().toString().split(' ')[0]} a ${ret.fechaFin.toLocal().toString().split(' ')[0]} (${ret.meses} meses)'),
                    Text('Salario Anterior: \$${ret.salarioAnterior.toStringAsFixed(2)} | Nuevo: \$${ret.salarioNuevo.toStringAsFixed(2)}'),
                    Text('Diferencia Mensual: \$${ret.diferenciaMensual.toStringAsFixed(2)}'),
                    if (ret.actoAdministrativo != null)
                      Text('Acto Administrativo: ${ret.actoAdministrativo}'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (ret.estado == EstadoRetroactivo.calculado)
                          TextButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Aprobar'),
                            onPressed: () => _aprobarRetroactivo(ret),
                          ),
                        if (ret.estado == EstadoRetroactivo.aprobado)
                          TextButton.icon(
                            icon: const Icon(Icons.payment),
                            label: const Text('Registrar Pago'),
                            onPressed: () => _registrarPagoRetroactivo(ret),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPILATab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planilla Integrada de Liquidación de Aportes (PILA)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF006D77)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consolida y reporta los aportes parafiscales y de seguridad social calculados en el periodo de nómina correspondiente.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generarReportePILA,
            icon: const Icon(Icons.calculate),
            label: const Text('Generar Liquidación PILA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          if (_pilaReporte != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const Text(
              'Resultados de Liquidación de Planilla',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Periodo: ${_pilaReporte!['periodo']}'),
            Text('Total Empleados: ${_pilaReporte!['total_empleados']}'),
            const SizedBox(height: 8),
            Text('Aporte Salud: \$${(_pilaReporte!['total_salud'] as double).toStringAsFixed(2)}'),
            Text('Aporte Pensión: \$${(_pilaReporte!['total_pension'] as double).toStringAsFixed(2)}'),
            Text('Fondo Solidaridad: \$${(_pilaReporte!['total_fondo_solidaridad'] as double).toStringAsFixed(2)}'),
            Text('Riesgos Laborales: \$${(_pilaReporte!['total_riesgos_laborales'] as double).toStringAsFixed(2)}'),
            Text('Caja Compensación: \$${(_pilaReporte!['total_caja_compensacion'] as double).toStringAsFixed(2)}'),
            Text('SENA: \$${(_pilaReporte!['total_sena'] as double).toStringAsFixed(2)} | ICBF: \$${(_pilaReporte!['total_icbf'] as double).toStringAsFixed(2)}'),
            const Divider(),
            Text(
              'Gran Total Planilla: \$${(_pilaReporte!['gran_total'] as double).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _enviarOperadorPILA,
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar a Operador'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportarPlanoPILA,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Exportar Formato Plano'),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildConfiguracionTab() {
    final formKey = GlobalKey<FormState>();
    final smmlvController = TextEditingController(text: _smmlvConfig.toString());
    final auxilioController = TextEditingController(text: _auxilioTransporteConfig.toString());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parámetros Legales de Nómina',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF006D77)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure los valores legales que rigen el cálculo de aportes, auxilios y retenciones en la liquidación.',
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),
            TextFormField(
              controller: smmlvController,
              decoration: const InputDecoration(labelText: 'Salario Mínimo Legal Vigente (SMMLV)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: auxilioController,
              decoration: const InputDecoration(labelText: 'Valor Mensual Auxilio de Transporte'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  setState(() => _loading = true);
                  try {
                    final db = await DatabaseHelper.instance.database;
                    final valorJson = jsonEncode({
                      'smmlv': double.parse(smmlvController.text),
                      'auxilio_transporte': double.parse(auxilioController.text),
                    });

                    final existente = await db.query(
                      'configuracion_entidad',
                      where: 'entidad_id = ?',
                      whereArgs: [widget.entidadId],
                    );

                    if (existente.isEmpty) {
                      await db.insert('configuracion_entidad', {
                        'id': const Uuid().v4(),
                        'entidad_id': widget.entidadId,
                        'parametro': 'configuracion_legal',
                        'valor': valorJson,
                        'fecha_actualizacion': DateTime.now().toIso8601String(),
                        'actualizado_por': widget.usuarioId,
                      });
                    } else {
                      await db.update(
                        'configuracion_entidad',
                        {
                          'valor': valorJson,
                          'fecha_actualizacion': DateTime.now().toIso8601String(),
                          'actualizado_por': widget.usuarioId,
                        },
                        where: 'entidad_id = ?',
                        whereArgs: [widget.entidadId],
                      );
                    }

                    _mostrarExito('Parámetros guardados y sincronizados correctamente');
                    await _cargarConfiguracion();
                  } catch (e) {
                    _mostrarError('Error al guardar configuración: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar Parámetros'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D77),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _registrarEmpleado() {
    final formKey = GlobalKey<FormState>();
    final identificacionController = TextEditingController();
    final nombreController = TextEditingController();
    final cargoController = TextEditingController();
    final dependenciaController = TextEditingController();
    final salarioController = TextEditingController();
    final bancoController = TextEditingController();
    final cuentaController = TextEditingController();
    final epsController = TextEditingController();
    final pensionController = TextEditingController();

    TipoContrato contratoSeleccionado = TipoContrato.indefinido;
    TipoVinculacion vinculacionSeleccionada = TipoVinculacion.carrera;
    DateTime fechaIngreso = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar Empleado Público'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: identificacionController,
                    decoration: const InputDecoration(labelText: 'Identificación NIT/CC'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: cargoController,
                    decoration: const InputDecoration(labelText: 'Cargo'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: dependenciaController,
                    decoration: const InputDecoration(labelText: 'Dependencia'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  DropdownButtonFormField<TipoContrato>(
                    initialValue: contratoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Tipo de Contrato'),
                    items: TipoContrato.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.toString().split('.').last));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => contratoSeleccionado = val);
                      }
                    },
                  ),
                  DropdownButtonFormField<TipoVinculacion>(
                    initialValue: vinculacionSeleccionada,
                    decoration: const InputDecoration(labelText: 'Tipo de Vinculación'),
                    items: TipoVinculacion.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.toString().split('.').last));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => vinculacionSeleccionada = val);
                      }
                    },
                  ),
                  TextFormField(
                    controller: salarioController,
                    decoration: const InputDecoration(labelText: 'Salario Básico Mensual'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fecha Ingreso: ${fechaIngreso.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaIngreso,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaIngreso = selected);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: bancoController,
                    decoration: const InputDecoration(labelText: 'Banco (Para Transferencia)'),
                  ),
                  TextFormField(
                    controller: cuentaController,
                    decoration: const InputDecoration(labelText: 'Cuenta Bancaria'),
                  ),
                  TextFormField(
                    controller: epsController,
                    decoration: const InputDecoration(labelText: 'EPS'),
                  ),
                  TextFormField(
                    controller: pensionController,
                    decoration: const InputDecoration(labelText: 'Fondo de Pensión'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    final db = await DatabaseHelper.instance.database;
                    final id = const Uuid().v4();

                    final emp = Empleado(
                      id: id,
                      entidadId: widget.entidadId,
                      numeroIdentificacion: identificacionController.text,
                      nombreCompleto: nombreController.text,
                      cargo: cargoController.text,
                      dependencia: dependenciaController.text,
                      tipoContrato: contratoSeleccionado,
                      tipoVinculacion: vinculacionSeleccionada,
                      salarioBasico: double.parse(salarioController.text),
                      fechaIngreso: fechaIngreso,
                      activo: true,
                      banco: bancoController.text.isEmpty ? null : bancoController.text,
                      cuentaBancaria: cuentaController.text.isEmpty ? null : cuentaController.text,
                      eps: epsController.text.isEmpty ? null : epsController.text,
                      fondoPension: pensionController.text.isEmpty ? null : pensionController.text,
                    );

                    await db.insert('empleados_sp', emp.toJson());

                    _mostrarExito('Empleado público registrado');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al registrar: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _liquidarNomina() {
    if (_empleados.isEmpty) {
      _mostrarError('Registre al menos un empleado antes de liquidar.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final periodoController = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
    final diasController = TextEditingController(text: '30');
    final horasExtraController = TextEditingController(text: '0.0');
    final recargoController = TextEditingController(text: '0.0');
    Empleado? empleadoSeleccionado;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Liquidar Nómina'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Empleado>(
                    initialValue: empleadoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Empleado'),
                    items: _empleados.where((e) => e.activo).map((e) {
                      return DropdownMenuItem(value: e, child: Text(e.nombreCompleto));
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => empleadoSeleccionado = val);
                    },
                    validator: (value) => value == null ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: periodoController,
                    decoration: const InputDecoration(labelText: 'Periodo (YYYY-MM)'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: diasController,
                    decoration: const InputDecoration(labelText: 'Días Trabajados (1-30)'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: horasExtraController,
                    decoration: const InputDecoration(labelText: 'Horas Extra (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextFormField(
                    controller: recargoController,
                    decoration: const InputDecoration(labelText: 'Recargo Nocturno (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && empleadoSeleccionado != null) {
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    await _nominaService.liquidarNomina(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      empleadoId: empleadoSeleccionado!.id,
                      periodo: periodoController.text,
                      diasTrabajados: int.parse(diasController.text),
                      horasExtra: double.parse(horasExtraController.text),
                      recargoNocturno: double.parse(recargoController.text),
                    );
                    _mostrarExito('Nómina liquidada correctamente');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al liquidar: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
              child: const Text('Liquidar'),
            ),
          ],
        ),
      ),
    );
  }

  void _calcularRetroactivo() {
    if (_empleados.isEmpty) {
      _mostrarError('Debe registrar empleados antes de calcular retroactivos.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final motivoController = TextEditingController();
    final nuevoSalarioController = TextEditingController();
    final anteriorSalarioController = TextEditingController();
    Empleado? empleadoSeleccionado;
    TipoRetroactivo tipoSeleccionado = TipoRetroactivo.ajusteSalarial;

    DateTime fechaInicio = DateTime(DateTime.now().year, 1, 1);
    DateTime fechaFin = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calcular Retroactivo'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Empleado>(
                    initialValue: empleadoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Empleado'),
                    items: _empleados.map((e) {
                      return DropdownMenuItem(value: e, child: Text(e.nombreCompleto));
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        empleadoSeleccionado = val;
                        if (val != null) {
                          anteriorSalarioController.text = val.salarioBasico.toString();
                        }
                      });
                    },
                    validator: (value) => value == null ? 'Requerido' : null,
                  ),
                  DropdownButtonFormField<TipoRetroactivo>(
                    initialValue: tipoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Tipo de Retroactivo'),
                    items: TipoRetroactivo.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.toString().split('.').last));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tipoSeleccionado = val);
                      }
                    },
                  ),
                  TextFormField(
                    controller: motivoController,
                    decoration: const InputDecoration(labelText: 'Motivo / Justificación del Ajuste'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: anteriorSalarioController,
                    decoration: const InputDecoration(labelText: 'Salario Anterior Mensual'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: nuevoSalarioController,
                    decoration: const InputDecoration(labelText: 'Nuevo Salario Mensual'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Inicio: ${fechaInicio.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaInicio = selected);
                          }
                        },
                        child: const Text('Fecha Inicio'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fin: ${fechaFin.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaFin,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaFin = selected);
                          }
                        },
                        child: const Text('Fecha Fin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && empleadoSeleccionado != null) {
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    await _retroactivosService.calcularRetroactivo(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      empleadoId: empleadoSeleccionado!.id,
                      motivo: motivoController.text,
                      fechaInicio: fechaInicio,
                      fechaFin: fechaFin,
                      salarioAnterior: double.parse(anteriorSalarioController.text),
                      salarioNuevo: double.parse(nuevoSalarioController.text),
                      tipoRetroactivo: tipoSeleccionado,
                    );
                    _mostrarExito('Retroactivo calculado exitosamente');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al calcular: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
              child: const Text('Calcular'),
            ),
          ],
        ),
      ),
    );
  }

  void _aprobarRetroactivo(Retroactivo ret) {
    final formKey = GlobalKey<FormState>();
    final actoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar Retroactivo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Empleado: ${ret.empleadoNombre}'),
              Text('Total a Pagar: \$${ret.valorTotal.toStringAsFixed(2)}'),
              const Divider(),
              TextFormField(
                controller: actoController,
                decoration: const InputDecoration(labelText: 'Acto Administrativo (Decreto / Resolución #)'),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                setState(() => _loading = true);
                try {
                  await _retroactivosService.aprobarRetroactivo(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    retroactivoId: ret.id,
                    actoAdministrativo: actoController.text,
                  );
                  _mostrarExito('Retroactivo aprobado exitosamente');
                  await _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al aprobar: $e');
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
  }

  void _registrarPagoRetroactivo(Retroactivo ret) {
    final formKey = GlobalKey<FormState>();
    final montoController = TextEditingController(text: ret.saldoPendiente.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago de Retroactivo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Empleado: ${ret.empleadoNombre}'),
              Text('Saldo Pendiente: \$${ret.saldoPendiente.toStringAsFixed(2)}'),
              const Divider(),
              TextFormField(
                controller: montoController,
                decoration: const InputDecoration(labelText: 'Monto de Pago'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                setState(() => _loading = true);
                try {
                  await _retroactivosService.registrarPago(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    retroactivoId: ret.id,
                    montoPago: double.parse(montoController.text),
                  );
                  _mostrarExito('Pago registrado correctamente');
                  await _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al pagar: $e');
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
            child: const Text('Registrar Pago'),
          ),
        ],
      ),
    );
  }

  void _generarReportePILA() {
    final formKey = GlobalKey<FormState>();
    final periodoController = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Liquidación PILA'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: periodoController,
            decoration: const InputDecoration(labelText: 'Periodo (YYYY-MM)'),
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                setState(() => _loading = true);
                try {
                  final result = await _pilaService.generarReportePILA(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    periodo: periodoController.text,
                  );
                  setState(() {
                    _pilaReporte = result;
                  });
                  _mostrarExito('Liquidación PILA calculada correctamente');
                } catch (e) {
                  _mostrarError('Error al generar: $e');
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
            child: const Text('Calcular'),
          ),
        ],
      ),
    );
  }

  void _enviarOperadorPILA() {
    if (_pilaReporte == null) return;
    
    final formKey = GlobalKey<FormState>();
    final nitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Reporte PILA'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Se transmitirá la planilla al operador de información gubernamental.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: nitController,
                decoration: const InputDecoration(labelText: 'NIT de la Entidad'),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                setState(() => _loading = true);
                try {
                  await _pilaService.enviarReportePILA(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    periodo: _pilaReporte!['periodo'] as String,
                    nitEntidad: nitController.text,
                  );
                  _mostrarExito('Planilla PILA enviada y radicada con el operador exitosamente');
                } catch (e) {
                  _mostrarError('Error al enviar: $e');
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _exportarPlanoPILA() async {
    if (_pilaReporte == null) return;
    setState(() => _loading = true);
    try {
      final contenidoPlano = await _pilaService.exportarFormatoPlano(
        entidadId: widget.entidadId,
        periodo: _pilaReporte!['periodo'] as String,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Formato Plano PILA (Archivo de Salida)'),
          content: SingleChildScrollView(
            child: Text(
              contenidoPlano,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarError('Error al exportar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
}
