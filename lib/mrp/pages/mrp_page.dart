import 'package:flutter/material.dart';

import '../../core/currency/money_value.dart';
import '../../core/commands/command_registry.dart';
import '../application/mrp_services.dart';
import '../domain/mrp_bom.dart';
import '../domain/mrp_bom_item.dart';
import '../domain/mrp_work_order.dart';
import '../../ui/widgets/expandable_record_card.dart';

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
  late final String _commandOwner;

  @override
  void initState() {
    super.initState();
    _commandOwner = 'mrp.orders:${identityHashCode(this)}';
    _reload();
  }

  void _reload() {
    _boms = _bomService.list();
    _orders = _orderService.list();
  }

  @override
  void dispose() {
    CommandRegistry.instance.clearContext(_commandOwner);
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
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text('No se pudieron cargar las BOM: ${snapshot.error}'),
        );
      }
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
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_tree),
                    title: Text('Producto #${bom.itemId}'),
                    subtitle: Text(
                      'Cantidad ${bom.quantity} ${bom.uom} - '
                      'Costo total ${bom.totalCost.toMajorUnitsString()}',
                    ),
                    trailing: Icon(
                      bom.isActive ? Icons.check_circle : Icons.pause_circle,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: bom.id == null
                          ? null
                          : () => _showBomStructure(bom),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Editar estructura'),
                    ),
                  ),
                ],
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
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text('No se pudieron cargar ordenes: ${snapshot.error}'),
        );
      }
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
                : group.map(_buildOrderTile).toList(),
          );
        }).toList(),
      );
    },
  );

  Widget _buildOrderTile(MrpWorkOrder order) => FutureBuilder<bool>(
    future: _orderService.hasSufficientStock(order.id!),
    builder: (context, snapshot) {
      final stockOk = snapshot.data ?? true;
      final canBeBlocked =
          order.status == MrpWorkOrderStatus.borrador ||
          order.status == MrpWorkOrderStatus.noIniciada;
      final blocked = canBeBlocked && !stockOk;
      final actions = <RecordCardAction>[
        if (order.status == MrpWorkOrderStatus.noIniciada)
          RecordCardAction(
            id: 'start',
            label: 'Iniciar producción',
            icon: Icons.play_arrow,
            visible: !blocked,
            onPressed: (_) async {
              _activateOrderContext(context, order);
              await _orderService.transition(
                order.id!,
                MrpWorkOrderStatus.enProceso,
              );
              if (mounted) setState(_reload);
            },
          ),
        if (order.status == MrpWorkOrderStatus.enProceso)
          RecordCardAction(
            id: 'complete',
            label: 'Completar orden',
            icon: Icons.task_alt,
            onPressed: (_) async {
              _activateOrderContext(context, order);
              await _orderService.transition(
                order.id!,
                MrpWorkOrderStatus.completada,
              );
              if (mounted) setState(_reload);
            },
          ),
        RecordCardAction(
          id: 'bom',
          label: 'Ver BOM',
          icon: Icons.account_tree,
          onPressed: (_) async {
            _activateOrderContext(context, order);
            final boms = await _bomService.list();
            MrpBom? matchingBom;
            for (final bom in boms) {
              if (bom.id == order.bomId) {
                matchingBom = bom;
                break;
              }
            }
            if (matchingBom != null && mounted) {
              _tabs.index = 0;
              await _showBomStructure(matchingBom);
            }
          },
        ),
      ];
      return ExpandableRecordCard(
        criticalFields: [
          RecordCardField(
            label: 'Orden',
            value: '#${order.id}',
            icon: blocked ? Icons.lock : Icons.precision_manufacturing,
            emphasized: true,
          ),
          RecordCardField(
            label: 'Producto',
            value: '#${order.productionItemId}',
            icon: Icons.inventory_2,
            emphasized: true,
          ),
          RecordCardField(
            label: 'Cantidad',
            value: order.qtyPlanned.toString(),
            icon: Icons.numbers,
          ),
          RecordCardField(
            label: 'Estado',
            value: blocked ? 'Bloqueada: stock insuficiente' : _statusLabel(order.status),
            icon: blocked ? Icons.warning : Icons.flag,
            emphasized: true,
          ),
        ],
        secondaryFields: [
          RecordCardField(label: 'BOM', value: '#${order.bomId}'),
          RecordCardField(label: 'Costo total', value: order.totalCost.toMajorUnitsString()),
          RecordCardField(label: 'Materia prima', value: order.rawMaterialCost.toMajorUnitsString()),
          RecordCardField(
            label: 'Operación',
            value: order.plannedOperatingCost.toMajorUnitsString(),
          ),
          RecordCardField(label: 'Bodega WIP', value: '${order.wipWarehouseId}'),
          RecordCardField(label: 'Bodega producto terminado', value: '${order.fgWarehouseId}'),
          RecordCardField(label: 'Fecha límite', value: order.plannedEndDate?.toIso8601String() ?? 'Sin fecha'),
        ],
        actions: actions,
      );
    },
  );

  void _activateOrderContext(BuildContext context, MrpWorkOrder order) {
    final orderId = order.id;
    if (orderId == null) return;
    final actions = <String, CommandHandler>{
      'start': (commandContext, _) async {
        await _orderService.transition(orderId, MrpWorkOrderStatus.enProceso);
        if (mounted) setState(_reload);
      },
      'complete': (commandContext, _) async {
        await _orderService.transition(orderId, MrpWorkOrderStatus.completada);
        if (mounted) setState(_reload);
      },
      'bom': (commandContext, _) async {
        final boms = await _bomService.list();
        MrpBom? matchingBom;
        for (final bom in boms) {
          if (bom.id == order.bomId) {
            matchingBom = bom;
            break;
          }
        }
        if (matchingBom != null && mounted) {
          _tabs.index = 0;
          await _showBomStructure(matchingBom);
        }
      },
    };
    CommandRegistry.instance.setContext(
      CommandContext(
        moduleId: 'mrp',
        recordType: 'mrp_work_order',
        recordId: '$orderId',
        label: 'Orden #$orderId',
        ownerId: _commandOwner,
        actions: actions,
      ),
    );
  }

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

  Future<void> _showBomStructure(MrpBom bom) async {
    if (bom.id == null) return;
    var current = bom;
    var itemsFuture = _bomService.items(bom.id!);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Estructura BOM #${bom.id}'),
          content: SizedBox(
            width: 520,
            child: FutureBuilder<List<MrpBomItem>>(
              future: itemsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Costo total: ${current.totalCost.toMajorUnitsString()}',
                    ),
                    Text(
                      'Materiales: ${current.rawMaterialCost.toMajorUnitsString()} '
                      '- Operacion: ${current.operatingCost.toMajorUnitsString()}',
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Text('La BOM no tiene componentes.'),
                    ...items.map(
                      (item) => ListTile(
                        dense: true,
                        leading: Icon(
                          item.isSubAssemblyItem
                              ? Icons.account_tree
                              : Icons.inventory_2,
                        ),
                        title: Text('Producto #${item.itemId}'),
                        subtitle: Text(
                          'Cantidad ${item.qty} - '
                          '${item.isSubAssemblyItem ? 'Sub-ensamble' : 'Materia prima'}',
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final added = await _showAddBomItem(bom);
                          if (added != true) return;
                          current = await _bomService.recalculate(bom.id!);
                          itemsFuture = _bomService.items(bom.id!);
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar componente'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<bool?> _showAddBomItem(MrpBom bom) => showDialog<bool>(
    context: context,
    builder: (context) {
      final item = TextEditingController();
      final quantity = TextEditingController(text: '1');
      final rate = TextEditingController(text: '0');
      var isSubAssembly = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar componente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: item,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ID producto'),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              TextField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Costo unitario'),
              ),
              CheckboxListTile(
                value: isSubAssembly,
                onChanged: (value) =>
                    setState(() => isSubAssembly = value ?? false),
                title: const Text('Es sub-ensamble'),
                contentPadding: EdgeInsets.zero,
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
                final itemId = int.tryParse(item.text);
                final qty = double.tryParse(quantity.text);
                final rateValue = double.tryParse(rate.text);
                if (itemId == null ||
                    qty == null ||
                    qty <= 0 ||
                    rateValue == null ||
                    rateValue < 0) {
                  return;
                }
                final rateMoney = MoneyValue.fromMajorUnits(
                  rate.text,
                  currency: bom.totalCost.currency,
                );
                await _bomService.addItem(
                  MrpBomItem(
                    companyId: bom.companyId,
                    bomId: bom.id!,
                    itemId: itemId,
                    qty: qty,
                    rate: rateMoney,
                    amount: rateMoney.multiplyDecimal(qty.toString()),
                    isSubAssemblyItem: isSubAssembly,
                  ),
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      );
    },
  );

  String _statusLabel(MrpWorkOrderStatus status) => switch (status) {
    MrpWorkOrderStatus.borrador => 'Borrador',
    MrpWorkOrderStatus.noIniciada => 'No iniciada',
    MrpWorkOrderStatus.enProceso => 'En proceso',
    MrpWorkOrderStatus.completada => 'Completada',
    MrpWorkOrderStatus.cancelada => 'Cancelada',
  };
}
