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
    final tipoDocCtrl = TextEditingController(text: empleado?['tipo_documento']?.toString() ?? 'CC');
    final cargoCtrl = TextEditingController(text: empleado?['cargo']?.toString() ?? '');
    final salarioCtrl = TextEditingController(text: empleado?['salario_base']?.toString() ?? '');
    final auxilioFlag = empleado?['auxilio_transporte'] == 1;
    final bancoCtrl = TextEditingController(text: empleado?['nombre_banco']?.toString() ?? '');
    final codigoBancoCtrl = TextEditingController(text: empleado?['codigo_banco']?.toString() ?? '');
    final cuentaCtrl = TextEditingController(text: empleado?['cuenta_bancaria']?.toString() ?? '');
    final epsCtrl = TextEditingController(text: empleado?['eps']?.toString() ?? '');
    final fondoPensionCtrl = TextEditingController(text: empleado?['fondo_pension']?.toString() ?? '');
    
    String tipoDoc = empleado?['tipo_documento']?.toString() ?? 'CC';
    final tiposDoc = ['CC', 'CE', 'TI', 'PP', 'RC'];
    String nivelArl = empleado?['nivel_arl']?.toString() ?? 'I';
    final nivelesArl = ['I', 'II', 'III', 'IV', 'V'];
    String tipoContrato = empleado?['tipo_contrato']?.toString() ?? 'indefinido';
    final tiposContrato = ['indefinido', 'fijo', 'prestacion_servicios'];
    String frecuenciaPago = empleado?['frecuencia_pago']?.toString() ?? 'mensual';
    final frecuenciasPago = ['mensual', 'quincenal', 'semanal'];

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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: documentoCtrl,
                        decoration: const InputDecoration(labelText: 'Documento *', prefixIcon: Icon(Icons.badge)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: tipoDoc,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: tiposDoc.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tipoDoc = val);
                        },
                      ),
                    ),
                  ],
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
                CheckboxListTile(
                  title: const Text('Auxilio de Transporte'),
                  subtitle: const Text('Aplica si gana < 2 SMMLV'),
                  value: auxilioFlag,
                  onChanged: (val) => setDialogState(() {}),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: nivelArl,
                  decoration: const InputDecoration(labelText: 'Nivel ARL *', prefixIcon: Icon(Icons.security)),
                  items: nivelesArl.map((n) => DropdownMenuItem(value: n, child: Text('Nivel $n'))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => nivelArl = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: epsCtrl,
                  decoration: const InputDecoration(labelText: 'EPS', prefixIcon: Icon(Icons.local_hospital)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fondoPensionCtrl,
                  decoration: const InputDecoration(labelText: 'Fondo de Pensión', prefixIcon: Icon(Icons.account_balance_wallet)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tipoContrato,
                  decoration: const InputDecoration(labelText: 'Tipo de Contrato'),
                  items: tiposContrato.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => tipoContrato = val);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: frecuenciaPago,
                  decoration: const InputDecoration(labelText: 'Frecuencia de Pago'),
                  items: frecuenciasPago.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => frecuenciaPago = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bancoCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Banco', prefixIcon: Icon(Icons.account_balance)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codigoBancoCtrl,
                        decoration: const InputDecoration(labelText: 'Código Banco'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cuentaCtrl,
                        decoration: const InputDecoration(labelText: 'Número Cuenta'),
                      ),
                    ),
                  ],
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
                final salario = double.tryParse(salarioCtrl.text.replaceAll(',', '.')) ?? 0;
                if (nombreCtrl.text.trim().isEmpty || documentoCtrl.text.trim().isEmpty || salario <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor completa los campos obligatorios.')),
                  );
                  return;
                }

                if (empleado == null) {
                  await DatabaseHelper.instance.guardarEmpleado(
                    nombre: nombreCtrl.text.trim(),
                    documento: documentoCtrl.text.trim(),
                    tipoDocumento: tipoDoc,
                    cargo: cargoCtrl.text.trim(),
                    salarioBase: salario,
                    auxilioTransporte: auxilioFlag ? 1 : 0,
                    cuentaBancaria: cuentaCtrl.text.trim(),
                    codigoBanco: codigoBancoCtrl.text.trim(),
                    nombreBanco: bancoCtrl.text.trim(),
                    nivelArl: nivelArl,
                    fondoPension: fondoPensionCtrl.text.trim(),
                    eps: epsCtrl.text.trim(),
                    tipoContrato: tipoContrato,
                    frecuenciaPago: frecuenciaPago,
                  );
                } else {
                  await DatabaseHelper.instance.actualizarEmpleado(
                    id: empleado['id'] as int,
                    nombre: nombreCtrl.text.trim(),
                    documento: documentoCtrl.text.trim(),
                    tipoDocumento: tipoDoc,
                    cargo: cargoCtrl.text.trim(),
                    salarioBase: salario,
                    auxilioTransporte: auxilioFlag ? 1 : 0,
                    cuentaBancaria: cuentaCtrl.text.trim(),
                    codigoBanco: codigoBancoCtrl.text.trim(),
                    nombreBanco: bancoCtrl.text.trim(),
                    nivelArl: nivelArl,
                    fondoPension: fondoPensionCtrl.text.trim(),
                    eps: epsCtrl.text.trim(),
                    tipoContrato: tipoContrato,
                    frecuenciaPago: frecuenciaPago,
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
