import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'numeric_input.dart';

class ReportesFiscalesPage extends StatefulWidget {
  const ReportesFiscalesPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ReportesFiscalesPage> createState() => _ReportesFiscalesPageState();
}

class _ReportesFiscalesPageState extends State<ReportesFiscalesPage> {
  int anio = DateTime.now().year;
  int mes = DateTime.now().month;
  Map<String, double> reporte = {};

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
    final data = await DatabaseHelper.instance.obtenerReporteFiscal(
      anio: anio,
      mes: mes,
    );
    if (!mounted) return;
    setState(() => reporte = data);
  }

  String _fmt(num valor) => '\$${valor.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final filas = [
      ['Ventas gravadas/reportadas', reporte['ventas'] ?? 0, 'ventas'],
      ['Compras y costos', reporte['compras'] ?? 0, 'compras'],
      ['IVA generado', reporte['iva_generado'] ?? 0, 'iva_generado'],
      ['IVA descontable', reporte['iva_descontable'] ?? 0, 'iva_descontable'],
      ['IVA estimado por pagar', reporte['iva_por_pagar'] ?? 0, 'iva_por_pagar'],
      ['Retefuente practicada', reporte['retefuente_practicada'] ?? 0, 'retefuente_practicada'],
      ['ReteIVA practicada', reporte['reteiva_practicada'] ?? 0, 'reteiva_practicada'],
      ['ReteICA practicada', reporte['reteica_practicada'] ?? 0, 'reteica_practicada'],
      ['Retefuente recibida (compras)', reporte['retefuente_recibida'] ?? 0, 'retefuente_recibida'],
      ['Nómina pagada', reporte['nomina'] ?? 0, 'nomina'],
    ];

    final body = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: '$anio'),
                keyboardType: TextInputType.number,
                inputFormatters: [NumericInput.integer],
                decoration: const InputDecoration(labelText: 'Año', isDense: true),
                onChanged: (value) => anio = int.tryParse(value) ?? DateTime.now().year,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: mes,
                decoration: const InputDecoration(labelText: 'Mes', isDense: true),
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => mes = value);
                  _cargar();
                },
              ),
            ),
            IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.gavel),
            title: Text('Resumen fiscal interactivo'),
            subtitle: Text(
              'IVA, retenciones e ICA del período. Toque un concepto para ver el detalle estimado.',
            ),
          ),
        ),
        ...filas.map(
          (f) => Card(
            child: ListTile(
              title: Text(f[0] as String),
              trailing: Text(
                _fmt(f[1] as num),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(f[0] as String),
                    content: Text(
                      'Total del período $mes/$anio: ${_fmt(f[1] as num)}\n\n'
                      'Este valor se calcula desde ventas, compras y nómina registradas en el sistema.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes fiscales')),
      body: body,
    );
  }
}
