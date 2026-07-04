import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'numeric_input.dart';

class PresupuestosPage extends StatefulWidget {
  const PresupuestosPage({super.key});

  @override
  State<PresupuestosPage> createState() => _PresupuestosPageState();
}

class _PresupuestosPageState extends State<PresupuestosPage> {
  List<Map<String, dynamic>> presupuestos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DatabaseHelper.disableAutoLoadsForTests) {
        Future.microtask(_cargar);
      }
    });
  }

  Future<void> _cargar() async {
    await DatabaseHelper.instance.recalcularPresupuestos();
    final data = await DatabaseHelper.instance.obtenerPresupuestos();
    if (!mounted) return;
    setState(() {
      presupuestos = data;
    });
  }

  Future<void> _abrirFormulario() async {
    final ahora = DateTime.now();
    var anio = ahora.year;
    var mes = ahora.month;
    var tipo = 'ingreso';
    final categoriaCtrl = TextEditingController(text: 'Ventas');
    final valorCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Presupuesto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [NumericInput.integer],
                        controller: TextEditingController(text: '$anio'),
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          anio = int.tryParse(value) ?? ahora.year;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: mes,
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => mes = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'ingreso',
                      label: Text('Ingreso'),
                      icon: Icon(Icons.trending_up),
                    ),
                    ButtonSegment(
                      value: 'egreso',
                      label: Text('Egreso'),
                      icon: Icon(Icons.trending_down),
                    ),
                  ],
                  selected: {tipo},
                  onSelectionChanged: (seleccion) {
                    setDialogState(() {
                      tipo = seleccion.first;
                      categoriaCtrl.text = tipo == 'ingreso'
                          ? 'Ventas'
                          : 'Compras de inventario';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoriaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [NumericInput.decimal],
                  decoration: const InputDecoration(
                    labelText: 'Valor presupuestado',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observacion',
                    border: OutlineInputBorder(),
                  ),
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
                final valor =
                    double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
                if (valor <= 0 || categoriaCtrl.text.trim().isEmpty) return;
                await DatabaseHelper.instance.guardarPresupuesto(
                  anio: anio,
                  mes: mes,
                  categoria: categoriaCtrl.text.trim(),
                  tipo: tipo,
                  valorPresupuestado: valor,
                  observacion: obsCtrl.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardado == true) {
      await _cargar();
    }
  }

  String _fmt(num valor) => '\$${valor.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.add_chart),
        label: const Text('Nuevo'),
      ),
      body: presupuestos.isEmpty
          ? const Center(child: Text('No hay presupuestos registrados'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: presupuestos.length,
              itemBuilder: (context, index) {
                final p = presupuestos[index];
                final presupuestado = (p['valor_presupuestado'] as num)
                    .toDouble();
                final real = (p['valor_real'] as num).toDouble();
                final diferencia = (p['diferencia'] as num).toDouble();
                final favorable = diferencia >= 0;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      favorable ? Icons.check_circle : Icons.warning,
                      color: favorable ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      '${p['categoria']} - ${p['mes']}/${p['anio']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${p['tipo']} | Presupuesto: ${_fmt(presupuestado)} | Real: ${_fmt(real)}\n${p['observacion'] ?? ''}',
                    ),
                    trailing: Text(
                      _fmt(diferencia),
                      style: TextStyle(
                        color: favorable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
