import 'package:flutter/material.dart';

import 'db_helper.dart';

class DetalleCompraPage extends StatefulWidget {
  const DetalleCompraPage({super.key, required this.compra});

  final Map<String, dynamic> compra;

  @override
  State<DetalleCompraPage> createState() => _DetalleCompraPageState();
}

class _DetalleCompraPageState extends State<DetalleCompraPage> {
  List<Map<String, dynamic>> _detalles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DatabaseHelper.disableAutoLoadsForTests) {
        Future.microtask(_cargarDetalle);
      }
    });
  }

  Future<void> _cargarDetalle() async {
    final id = (widget.compra['id'] as num).toInt();
    final data = await DatabaseHelper.instance.obtenerDetalleCompra(id);
    if (!mounted) return;
    setState(() {
      _detalles = data;
      _cargando = false;
    });
  }

  String _moneda(double valor) =>
      '\$${valor.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toString();

  String _fecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String pad(int n) => n.toString().padLeft(2, '0');
      return '${pad(dt.day)}/${pad(dt.month)}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compra = widget.compra;
    final id = (compra['id'] as num).toInt();
    final subtotal = (compra['subtotal'] as num?)?.toDouble() ?? 0;
    final impuesto = (compra['impuesto_total'] as num?)?.toDouble() ?? 0;
    final total = (compra['total'] as num?)?.toDouble() ?? 0;
    final efectivo = (compra['efectivo'] as num?)?.toDouble() ?? 0;
    final banco = (compra['transferencia'] as num?)?.toDouble() ?? 0;
    final credito = (compra['credito'] as num?)?.toDouble() ?? 0;
    final estado = compra['estado']?.toString() ?? 'pagada';
    final anulada = estado == 'anulada';

    return Scaffold(
      appBar: AppBar(title: Text('Compra #$id')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  color: anulada ? Colors.red.shade50 : Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: anulada
                                  ? Colors.red
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.shopping_bag),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    compra['proveedor']?.toString() ??
                                        'Sin proveedor',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Factura ${compra['numero_factura']?.toString().isNotEmpty == true ? compra['numero_factura'] : '-'}',
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(estado),
                              backgroundColor: anulada
                                  ? Colors.red.shade100
                                  : Colors.white,
                            ),
                          ],
                        ),
                        const Divider(height: 22),
                        _Dato(
                          label: 'Fecha',
                          value: _fecha(compra['fecha']?.toString() ?? ''),
                        ),
                        if ((compra['observacion'] ?? '').toString().isNotEmpty)
                          _Dato(
                            label: 'Observacion',
                            value: compra['observacion'].toString(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Productos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_detalles.isEmpty)
                          const Text('Sin detalle de productos.')
                        else
                          ..._detalles.map((item) {
                            final cantidad =
                                (item['cantidad'] as num?)?.toDouble() ?? 0;
                            final costo =
                                (item['costo_unitario'] as num?)?.toDouble() ??
                                0;
                            final subtotalItem =
                                (item['subtotal'] as num?)?.toDouble() ??
                                cantidad * costo;

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['producto']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_cantidad(cantidad)} ${item['unidad_base'] ?? ''} x ${_moneda(costo)}',
                              ),
                              trailing: Text(
                                _moneda(subtotalItem),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _TotalRow(label: 'Subtotal', value: _moneda(subtotal)),
                        _TotalRow(label: 'Impuesto', value: _moneda(impuesto)),
                        const Divider(height: 18),
                        _TotalRow(
                          label: 'Total',
                          value: _moneda(total),
                          destacado: true,
                        ),
                        const SizedBox(height: 10),
                        _TotalRow(
                          label: 'Pagado en caja',
                          value: _moneda(efectivo),
                        ),
                        _TotalRow(
                          label: 'Pagado en banco',
                          value: _moneda(banco),
                        ),
                        _TotalRow(label: 'Credito', value: _moneda(credito)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.destacado = false,
  });

  final String label;
  final String value;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: destacado ? FontWeight.bold : FontWeight.w500,
              fontSize: destacado ? 20 : 13,
              color: destacado ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
