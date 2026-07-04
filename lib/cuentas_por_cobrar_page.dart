import 'package:flutter/material.dart';

import 'core/financial/financial_ui_helpers.dart';
import 'db_helper.dart';
import 'numeric_input.dart';

class CuentasPorCobrarPage extends StatefulWidget {
  const CuentasPorCobrarPage({super.key});

  @override
  State<CuentasPorCobrarPage> createState() => _CuentasPorCobrarPageState();
}

class _CuentasPorCobrarPageState extends State<CuentasPorCobrarPage> {
  List<Map<String, dynamic>> cuentas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DatabaseHelper.disableAutoLoadsForTests) {
        Future.microtask(cargar);
      }
    });
  }

  Future<void> cargar() async {
    final data = await DatabaseHelper.instance.obtenerCuentasPorCobrar();

    if (!mounted) return;

    setState(() {
      cuentas = data;
    });
  }

  Color colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagada':
        return Colors.green;
      case 'parcial':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Future<void> _mostrarDialogoAbono(Map<String, dynamic> cuenta) async {
    final montoCtrl = TextEditingController();
    String metodoPago = 'EFECTIVO';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar cobro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saldo actual: ${FinancialUiHelpers.formatCurrency(cuenta['saldo'] as num? ?? 0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [NumericInput.decimal],
              decoration: const InputDecoration(
                labelText: 'Monto a cobrar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: metodoPago,
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'EFECTIVO', child: Text('EFECTIVO')),
                DropdownMenuItem(
                  value: 'TRANSFERENCIA',
                  child: Text('TRANSFERENCIA'),
                ),
                DropdownMenuItem(value: 'NEQUI', child: Text('NEQUI')),
                DropdownMenuItem(value: 'DAVIPLATA', child: Text('DAVIPLATA')),
              ],
              onChanged: (v) {
                if (v != null) metodoPago = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final monto =
                  double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0;

              if (monto <= 0) return;

              try {
                await DatabaseHelper.instance.registrarAbonoCXC(
                  cuentaId: cuenta['id'],
                  monto: monto,
                  metodoPago: metodoPago,
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              await cargar();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cobro registrado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarHistorialAbonos(Map<String, dynamic> cuenta) async {
    final abonos = await DatabaseHelper.instance.obtenerAbonosCXC(cuenta['id']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Venta #${cuenta['venta_id'] ?? '-'} - ${cuenta['cliente']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: abonos.isEmpty
              ? const Text('No hay cobros registrados')
              : SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: abonos.length,
                    itemBuilder: (context, i) {
                      final a = abonos[i];

                      return ListTile(
                        leading: const Icon(
                          Icons.payments,
                          color: Colors.green,
                        ),
                        title: Text(FinancialUiHelpers.formatCurrency(a['monto'] as num? ?? 0)),
                        subtitle: Text('${a['metodo_pago']} · ${a['fecha']}'),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas por cobrar')),
      body: cuentas.isEmpty
          ? const Center(child: Text('No hay cuentas por cobrar'))
          : ListView.builder(
              itemCount: cuentas.length,
              itemBuilder: (context, i) {
                final c = cuentas[i];
                final saldo = (c['saldo'] as num?)?.toDouble() ?? 0;
                final estado = c['estado']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorEstado(
                        estado,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.request_quote,
                        color: colorEstado(estado),
                      ),
                    ),
                    title: Text(
                      c['cliente']?.toString() ?? 'Cliente general',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Venta: #${c['venta_id'] ?? '-'}'),
                        Text('Saldo: ${FinancialUiHelpers.formatCurrency(saldo)}'),
                        Text('Estado: ${FinancialUiHelpers.accountStatusLabel(estado)}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'abonar') _mostrarDialogoAbono(c);
                        if (value == 'historial') _mostrarHistorialAbonos(c);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'abonar', child: Text('Cobrar')),
                        PopupMenuItem(
                          value: 'historial',
                          child: Text('Ver historial'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
