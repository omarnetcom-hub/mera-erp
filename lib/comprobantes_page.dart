import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'documento_pdf_service.dart';

class ComprobantesPage extends StatefulWidget {
  const ComprobantesPage({super.key});

  @override
  State<ComprobantesPage> createState() => _ComprobantesPageState();
}

class _ComprobantesPageState extends State<ComprobantesPage> {
  List<Map<String, dynamic>> comprobantes = [];
  bool cargando = true;

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
    final data = await DatabaseHelper.instance.obtenerComprobantes();
    if (!mounted) return;
    setState(() {
      comprobantes = data;
      cargando = false;
    });
  }

  String _fmt(num valor) => '\$${valor.toStringAsFixed(2)}';

  String _fecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String pad(int n) => n.toString().padLeft(2, '0');
      return '${pad(dt.day)}/${pad(dt.month)}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _abrirDetalle(Map<String, dynamic> comprobante) async {
    final detalle = await DatabaseHelper.instance.obtenerDetalleComprobante(
      (comprobante['id'] as num).toInt(),
    );
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final totalDebito = detalle.fold<double>(
          0,
          (sum, l) => sum + ((l['debito'] as num?)?.toDouble() ?? 0),
        );
        final totalCredito = detalle.fold<double>(
          0,
          (sum, l) => sum + ((l['credito'] as num?)?.toDouble() ?? 0),
        );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comprobante['consecutivo']?.toString() ?? '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Compartir PDF',
                    onPressed: () async {
                      final archivo =
                          await DocumentoPdfService.crearComprobanteContable(
                            comprobante,
                          );
                      await DocumentoPdfService.compartir(
                        archivo,
                        'Comprobante ${comprobante['consecutivo']}',
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Imprimir / PDF',
                    onPressed: () async {
                      final archivo =
                          await DocumentoPdfService.crearComprobanteContable(
                            comprobante,
                          );
                      if (!context.mounted) return;
                      await DocumentoPdfService.mostrarOpcionesSalida(
                        context,
                        archivo,
                        titulo: 'Comprobante ${comprobante['consecutivo']}',
                      );
                    },
                    icon: const Icon(Icons.print),
                  ),
                ],
              ),
              Text('Fecha: ${_fecha(comprobante['fecha']?.toString() ?? '')}'),
              Text('Tipo: ${comprobante['tipo'] ?? ''}'),
              Text('Concepto: ${comprobante['concepto'] ?? ''}'),
              if ((comprobante['tercero'] ?? '').toString().isNotEmpty)
                Text('Tercero: ${comprobante['tercero']}'),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Cuadre contable'),
                  subtitle: Text(
                    'Debitos ${_fmt(totalDebito)} | Creditos ${_fmt(totalCredito)}',
                  ),
                  trailing: Icon(
                    (totalDebito - totalCredito).abs() < 0.01
                        ? Icons.check_circle
                        : Icons.warning,
                    color: (totalDebito - totalCredito).abs() < 0.01
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...detalle.map((linea) {
                final debito = (linea['debito'] as num?)?.toDouble() ?? 0;
                final credito = (linea['credito'] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(
                      '${linea['codigo']} - ${linea['cuenta']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(linea['descripcion']?.toString() ?? ''),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('D ${_fmt(debito)}'),
                        Text('C ${_fmt(credito)}'),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprobantes')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : comprobantes.isEmpty
          ? const Center(child: Text('No hay comprobantes emitidos'))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: comprobantes.length,
                itemBuilder: (context, index) {
                  final c = comprobantes[index];
                  final total = (c['total'] as num?)?.toDouble() ?? 0;

                  return Card(
                    child: ListTile(
                      onTap: () => _abrirDetalle(c),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: Icon(
                          Icons.description,
                          color: Colors.green.shade700,
                        ),
                      ),
                      title: Text(
                        c['consecutivo']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_fecha(c['fecha']?.toString() ?? '')}\n${c['concepto'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: Text(
                          _fmt(total),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
