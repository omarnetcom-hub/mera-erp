import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'numeric_input.dart';

class NominaPage extends StatefulWidget {
  const NominaPage({super.key});

  @override
  State<NominaPage> createState() => _NominaPageState();
}

class _NominaPageState extends State<NominaPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> empleados = [];
  List<Map<String, dynamic>> nomina = [];
  late TabController _tabController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DatabaseHelper.disableAutoLoadsForTests) {
        Future.microtask(_cargar);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final e = await DatabaseHelper.instance.obtenerEmpleados();
    final n = await DatabaseHelper.instance.obtenerNomina();
    if (!mounted) return;
    setState(() {
      empleados = e;
      nomina = n;
      _loading = false;
    });
  }

  Future<void> _nuevoEmpleado({Map<String, dynamic>? empleado}) async {
    final nombreCtrl = TextEditingController(text: empleado?['nombre']?.toString() ?? '');
    final documentoCtrl = TextEditingController(text: empleado?['documento']?.toString() ?? '');
    final cargoCtrl = TextEditingController(text: empleado?['cargo']?.toString() ?? '');
    final salarioCtrl = TextEditingController(text: empleado?['salario_base']?.toString() ?? '');
    final auxilioCtrl = TextEditingController(text: empleado?['auxilio_transporte']?.toString() ?? '');
    final bancoCtrl = TextEditingController(text: empleado?['banco']?.toString() ?? '');
    final cuentaCtrl = TextEditingController(text: empleado?['numero_cuenta']?.toString() ?? '');
    
    String metodoPago = empleado?['metodo_pago']?.toString() ?? 'Efectivo';
    final metodos = ['Efectivo', 'Transferencia', 'Nequi', 'Daviplata'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(empleado == null ? 'Nuevo Empleado' : 'Editar Empleado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Completo *', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: documentoCtrl,
                  decoration: const InputDecoration(labelText: 'Documento / NIT', prefixIcon: Icon(Icons.badge)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cargoCtrl,
                  decoration: const InputDecoration(labelText: 'Cargo', prefixIcon: Icon(Icons.work)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: salarioCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.decimal],
                  decoration: const InputDecoration(labelText: 'Salario Base (COP) *', prefixIcon: Icon(Icons.attach_money)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: auxilioCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.decimal],
                  decoration: const InputDecoration(labelText: 'Auxilio de Transporte (COP)', prefixIcon: Icon(Icons.directions_bus)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: metodoPago,
                  decoration: const InputDecoration(labelText: 'Método de Pago', prefixIcon: Icon(Icons.payment)),
                  items: metodos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => metodoPago = val);
                    }
                  },
                ),
                if (metodoPago != 'Efectivo') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: bancoCtrl,
                    decoration: const InputDecoration(labelText: 'Banco', prefixIcon: Icon(Icons.account_balance)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cuentaCtrl,
                    decoration: const InputDecoration(labelText: 'Número de Cuenta', prefixIcon: Icon(Icons.credit_card)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final salario = double.tryParse(salarioCtrl.text.replaceAll(',', '.')) ?? 0;
                final auxilio = double.tryParse(auxilioCtrl.text.replaceAll(',', '.')) ?? 0;
                if (nombreCtrl.text.trim().isEmpty || salario <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor completa los campos obligatorios.')),
                  );
                  return;
                }

                if (empleado == null) {
                  await DatabaseHelper.instance.guardarEmpleado(
                    nombre: nombreCtrl.text.trim(),
                    documento: documentoCtrl.text.trim(),
                    cargo: cargoCtrl.text.trim(),
                    salarioBase: salario,
                    auxilioTransporte: auxilio,
                    metodoPago: metodoPago,
                    banco: bancoCtrl.text.trim(),
                    numeroCuenta: cuentaCtrl.text.trim(),
                  );
                } else {
                  await DatabaseHelper.instance.actualizarEmpleado(
                    id: empleado['id'] as int,
                    nombre: nombreCtrl.text.trim(),
                    documento: documentoCtrl.text.trim(),
                    cargo: cargoCtrl.text.trim(),
                    salarioBase: salario,
                    auxilioTransporte: auxilio,
                    metodoPago: metodoPago,
                    banco: bancoCtrl.text.trim(),
                    numeroCuenta: cuentaCtrl.text.trim(),
                  );
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) await _cargar();
  }

  Future<void> _liquidarIndividual() async {
    if (empleados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empleados registrados para liquidar.')),
      );
      return;
    }
    final ahora = DateTime.now();
    int empleadoId = empleados.first['id'] as int;
    int anio = ahora.year;
    int mes = ahora.month;
    final extrasCtrl = TextEditingController();
    final bonosCtrl = TextEditingController();
    final deduccionesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Liquidar Nómina Individual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: empleadoId,
                  decoration: const InputDecoration(labelText: 'Empleado'),
                  items: empleados.map((e) => DropdownMenuItem(value: e['id'] as int, child: Text(e['nombre'].toString()))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => empleadoId = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.integer],
                  decoration: const InputDecoration(labelText: 'Año'),
                  controller: TextEditingController(text: '$anio'),
                  onChanged: (v) => anio = int.tryParse(v) ?? ahora.year,
                ),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.integer],
                  decoration: const InputDecoration(labelText: 'Mes'),
                  controller: TextEditingController(text: '$mes'),
                  onChanged: (v) => mes = int.tryParse(v) ?? ahora.month,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: extrasCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.decimal],
                  decoration: const InputDecoration(labelText: 'Horas Extra (Valor COP)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bonosCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.decimal],
                  decoration: const InputDecoration(labelText: 'Bonificaciones'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: deduccionesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumericInput.decimal],
                  decoration: const InputDecoration(labelText: 'Otras Deducciones'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await DatabaseHelper.instance.liquidarNomina(
                    empleadoId: empleadoId,
                    anio: anio,
                    mes: mes,
                    horasExtra: double.tryParse(extrasCtrl.text.replaceAll(',', '.')) ?? 0,
                    bonificaciones: double.tryParse(bonosCtrl.text.replaceAll(',', '.')) ?? 0,
                    otrasDeducciones: double.tryParse(deduccionesCtrl.text.replaceAll(',', '.')) ?? 0,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Liquidar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _cargar();
      _tabController.animateTo(3); // Go to history
    }
  }

  Future<void> _liquidarMasivo() async {
    if (empleados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empleados registrados.')),
      );
      return;
    }
    final ahora = DateTime.now();
    int anio = ahora.year;
    int mes = ahora.month;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Liquidación Masiva Completa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Se liquidará la nómina base de TODOS los empleados activos para el período seleccionado. ¿Deseas continuar?'),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [NumericInput.integer],
              decoration: const InputDecoration(labelText: 'Año'),
              controller: TextEditingController(text: '$anio'),
              onChanged: (v) => anio = int.tryParse(v) ?? ahora.year,
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [NumericInput.integer],
              decoration: const InputDecoration(labelText: 'Mes'),
              controller: TextEditingController(text: '$mes'),
              onChanged: (v) => mes = int.tryParse(v) ?? ahora.month,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              int count = 0;
              for (final emp in empleados) {
                if (emp['activo'] == 1) {
                  await DatabaseHelper.instance.liquidarNomina(
                    empleadoId: emp['id'] as int,
                    anio: anio,
                    mes: mes,
                  );
                  count++;
                }
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Se liquidaron masivamente $count empleados.')),
              );
            },
            child: const Text('Liquidar Todos'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _cargar();
      _tabController.animateTo(3); // Go to history
    }
  }

  Future<void> _anularLiquidacion(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Liquidación'),
        content: const Text('¿Estás seguro de que deseas anular esta liquidación? Esto realizará el contrasiento contable y reversará la salida de caja/bancos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, Anular')),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.anularLiquidacionNomina(id);
      await _cargar();
    }
  }

  String _fmt(num v) => '\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nómina y Personal'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Empleados'),
            Tab(icon: Icon(Icons.payment), text: 'Liquidar Individual'),
            Tab(icon: Icon(Icons.group_work), text: 'Liquidación Masiva'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Empleados
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lista de Empleados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: () => _nuevoEmpleado(),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (empleados.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No hay empleados registrados.')))
                    else
                      ...empleados.map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(e['nombre']?[0]?.toUpperCase() ?? 'E')),
                            title: Text(e['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${e['documento'] ?? 'Sin Cédula'} | ${e['cargo'] ?? 'Sin Cargo'}\n${e['metodo_pago'] ?? 'Efectivo'} - ${e['banco'] ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_fmt((e['salario_base'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _nuevoEmpleado(empleado: e)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // TAB 2: Liquidar Individual
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_pin, size: 80, color: Colors.blueGrey),
                      const SizedBox(height: 16),
                      const Text(
                        'Liquidación Individual por Empleado',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Permite ingresar horas extra, comisiones, bonificaciones y deducciones manuales por empleado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                        onPressed: _liquidarIndividual,
                        icon: const Icon(Icons.payments),
                        label: const Text('Iniciar Liquidación Individual'),
                      ),
                    ],
                  ),
                ),
                // TAB 3: Liquidación Masiva
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups, size: 80, color: Colors.indigo),
                      const SizedBox(height: 16),
                      const Text(
                        'Liquidación Completa Masiva',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Procesa el salario base y subsidio de transporte de forma automática para todos los empleados de la nómina con un solo clic.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        onPressed: _liquidarMasivo,
                        icon: const Icon(Icons.bolt),
                        label: const Text('Liquidar Nómina Completa'),
                      ),
                    ],
                  ),
                ),
                // TAB 4: Historial
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Historial de Liquidaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (nomina.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No hay liquidaciones en el historial.')))
                    else
                      ...nomina.map(
                        (n) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: n['estado'] == 'anulada' ? Colors.red.withOpacity(0.05) : null,
                          child: ListTile(
                            title: Text('${n['empleado']} - Período ${n['mes']}/${n['anio']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Devengado: ${_fmt(n['devengado'])} | Deducciones: ${_fmt(n['deducciones'])}\nEstado: ${n['estado']?.toUpperCase()}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_fmt((n['neto'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: n['estado'] == 'anulada' ? Colors.grey : Colors.blue)),
                                if (n['estado'] != 'anulada')
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => _anularLiquidacion(n['id'] as int),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
