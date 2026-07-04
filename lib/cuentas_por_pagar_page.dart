import 'package:flutter/material.dart';
import 'core/financial/financial_ui_helpers.dart';
import 'db_helper.dart';
import 'numeric_input.dart';

class CuentasPorPagarPage extends StatefulWidget {
  const CuentasPorPagarPage({super.key});

  @override
  State<CuentasPorPagarPage> createState() => _CuentasPorPagarPageState();
}

class _CuentasPorPagarPageState extends State<CuentasPorPagarPage> {
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
    final db = await DatabaseHelper.instance.database;

    final data = await db.query('cuentas_por_pagar', orderBy: 'fecha DESC');

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
        title: const Text('Registrar Abono'),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saldo actual: ${FinancialUiHelpers.formatCurrency(cuenta['saldo'] as num? ?? 0)}'),

            const SizedBox(height: 12),

            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [NumericInput.decimal],
              decoration: const InputDecoration(
                labelText: 'Monto a abonar',
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
                if (v != null) {
                  metodoPago = v;
                }
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
                await DatabaseHelper.instance.registrarAbonoCXP(
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

              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abono registrado'),
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

  Future<List<Map<String, dynamic>>> _obtenerAbonos(int cuentaId) async {
    final db = await DatabaseHelper.instance.database;

    return await db.query(
      'abonos_cxp',
      where: 'cuenta_id = ?',
      whereArgs: [cuentaId],
      orderBy: 'fecha DESC',
    );
  }

  Future<void> _mostrarHistorialAbonos(Map<String, dynamic> cuenta) async {
    final abonos = await _obtenerAbonos(cuenta['id']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Factura ${cuenta['numero_factura'] ?? '-'} - ${cuenta['proveedor']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        content: SizedBox(
          width: double.maxFinite,
          child: abonos.isEmpty
              ? const Text('No hay abonos registrados')
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
                        subtitle: Text('${a['metodo_pago']} • ${a['fecha']}'),
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
      appBar: AppBar(title: const Text('Cuentas por pagar')),

      body: cuentas.isEmpty
          ? const Center(child: Text('No hay cuentas por pagar'))
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
                        Icons.receipt_long,
                        color: colorEstado(estado),
                      ),
                    ),

                    title: Text(
                      c['proveedor']?.toString() ?? 'Sin proveedor',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Factura: ${c['numero_factura'] ?? '-'}'),

                        Text('Saldo: ${FinancialUiHelpers.formatCurrency(saldo)}'),

                        Text('Estado: ${FinancialUiHelpers.accountStatusLabel(estado)}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'abonar') {
                          _mostrarDialogoAbono(c);
                        }

                        if (value == 'historial') {
                          _mostrarHistorialAbonos(c);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'abonar',
                          child: Text('Abonar'),
                        ),
                        const PopupMenuItem(
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
