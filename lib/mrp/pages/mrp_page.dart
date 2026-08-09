import 'package:flutter/material.dart';
import '../application/mrp_services.dart';
import '../domain/mrp_bom.dart';
import '../domain/mrp_work_order.dart';

class MrpPage extends StatefulWidget {
  const MrpPage({super.key});
  @override
  State<MrpPage> createState() => _MrpPageState();
}

class _MrpPageState extends State<MrpPage> with SingleTickerProviderStateMixin {
  final _bomService = MrpBomService();
  final _orderService = MrpWorkOrderService();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late Future<List<MrpBom>> _boms;
  late Future<List<MrpWorkOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _boms = _bomService.list();
    _orders = _orderService.list();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Produccion MRP'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Editor BOM'),
          Tab(text: 'Ordenes de produccion'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [_buildBoms(), _buildOrders()],
    ),
  );

  Widget _buildBoms() => FutureBuilder<List<MrpBom>>(
    future: _boms,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return Center(
          child: Text('No se pudieron cargar las BOM: ${snapshot.error}'),
        );
      final boms = snapshot.data ?? const <MrpBom>[];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(
                'Listas de materiales',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showBomEditor,
                icon: const Icon(Icons.add),
                label: const Text('Nueva BOM'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (boms.isEmpty) const Text('No hay BOM registradas.'),
          ...boms.map(
            (bom) => Card(
              child: ListTile(
                leading: const Icon(Icons.account_tree),
                title: Text('Producto #${bom.itemId}'),
                subtitle: Text(
                  'Cantidad ${bom.quantity} ${bom.uom} • Costo total ${bom.totalCost.toMajorUnitsString()}',
                ),
                trailing: Icon(
                  bom.isActive ? Icons.check_circle : Icons.pause_circle,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _buildOrders() => FutureBuilder<List<MrpWorkOrder>>(
    future: _orders,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return Center(
          child: Text('No se pudieron cargar ordenes: ${snapshot.error}'),
        );
      final orders = snapshot.data ?? const <MrpWorkOrder>[];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: MrpWorkOrderStatus.values.map((status) {
          final group = orders
              .where((order) => order.status == status)
              .toList();
          return ExpansionTile(
            title: Text(_statusLabel(status)),
            initiallyExpanded: true,
            children: group.isEmpty
                ? [const ListTile(title: Text('Sin ordenes'))]
                : group
                      .map(
                        (order) => ListTile(
                          title: Text(
                            'Orden #${order.id} • Producto #${order.productionItemId}',
                          ),
                          subtitle: Text(
                            'Cantidad ${order.qtyPlanned} • Total ${order.totalCost.toMajorUnitsString()}',
                          ),
                        ),
                      )
                      .toList(),
          );
        }).toList(),
      );
    },
  );

  Future<void> _showBomEditor() async {
    final product = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva BOM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: product,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID producto terminado',
              ),
            ),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final productId = int.tryParse(product.text);
              final qty = double.tryParse(quantity.text);
              if (productId == null || qty == null || qty <= 0) return;
              await _bomService.createDraft(itemId: productId, quantity: qty);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (created == true && mounted) setState(_reload);
  }

  String _statusLabel(MrpWorkOrderStatus status) => switch (status) {
    MrpWorkOrderStatus.borrador => 'Borrador',
    MrpWorkOrderStatus.noIniciada => 'No iniciada',
    MrpWorkOrderStatus.enProceso => 'En proceso',
    MrpWorkOrderStatus.completada => 'Completada',
    MrpWorkOrderStatus.cancelada => 'Cancelada',
  };
}
