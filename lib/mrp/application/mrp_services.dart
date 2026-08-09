import '../../core/currency/money_value.dart';
import '../../inventory/application/warehouse_stock_service.dart';
import '../data/mrp_repositories.dart';
import '../domain/mrp_bom.dart';
import '../domain/mrp_bom_item.dart';
import '../domain/mrp_operation.dart';
import '../domain/mrp_routing.dart';
import '../domain/mrp_work_order.dart';
import '../domain/mrp_work_order_item.dart';
import '../domain/mrp_workstation.dart';

class MrpWorkstationService {
  MrpWorkstationService({MrpWorkstationRepository? repository})
    : _repository = repository ?? MrpWorkstationRepository();
  final MrpWorkstationRepository _repository;
  Future<int> create(MrpWorkstation value) => _repository.save(value);
  Future<List<MrpWorkstation>> list() => _repository.list();
}

class MrpRoutingService {
  MrpRoutingService({MrpRoutingRepository? repository})
    : _repository = repository ?? MrpRoutingRepository();
  final MrpRoutingRepository _repository;
  Future<int> create(MrpRouting value) => _repository.save(value);
  Future<List<MrpRouting>> list() => _repository.list();
}

class MrpOperationService {
  MrpOperationService({MrpOperationRepository? repository})
    : _repository = repository ?? MrpOperationRepository();
  final MrpOperationRepository _repository;
  Future<int> create(MrpOperation value) => _repository.save(value);
  Future<List<MrpOperation>> listForRouting(int routingId) =>
      _repository.listForRouting(routingId);
}

class MrpBomService {
  MrpBomService({
    MrpBomRepository? boms,
    MrpBomItemRepository? items,
    MrpOperationRepository? operations,
    MrpWorkstationRepository? workstations,
    MrpRepositoryContext? context,
  }) : _context = context ?? MrpRepositoryContext(),
       _boms = boms ?? MrpBomRepository(context: context),
       _items = items ?? MrpBomItemRepository(context: context),
       _operations = operations ?? MrpOperationRepository(context: context),
       _workstations =
           workstations ?? MrpWorkstationRepository(context: context);
  final MrpRepositoryContext _context;
  final MrpBomRepository _boms;
  final MrpBomItemRepository _items;
  final MrpOperationRepository _operations;
  final MrpWorkstationRepository _workstations;
  Future<int> create(MrpBom value) => _boms.save(value);
  Future<int> createDraft({
    required int itemId,
    required double quantity,
  }) async {
    final currency = await _context.currency;
    return create(
      MrpBom(
        companyId: await _context.companyId,
        itemId: itemId,
        quantity: quantity,
        rawMaterialCost: MoneyValue(minorUnits: 0, currency: currency),
        operatingCost: MoneyValue(minorUnits: 0, currency: currency),
        totalCost: MoneyValue(minorUnits: 0, currency: currency),
      ),
    );
  }

  Future<int> addItem(MrpBomItem value) => _items.save(value);
  Future<List<MrpBom>> list() => _boms.list();
  Future<List<MrpBomItem>> items(int bomId) => _items.listForBom(bomId);

  Future<MrpBom> recalculate(int bomId) async {
    final bom = await _boms.findById(bomId);
    if (bom == null) throw StateError('BOM no encontrada.');
    var raw = MoneyValue(minorUnits: 0, currency: bom.totalCost.currency);
    for (final item in await _items.listForBom(bomId))
      raw += item.rate.multiplyDecimal(item.qty.toString());
    var operating = MoneyValue(minorUnits: 0, currency: bom.totalCost.currency);
    if (bom.routingId != null) {
      final workstations = {
        for (final ws in await _workstations.list()) ws.id: ws,
      };
      for (final operation in await _operations.listForRouting(
        bom.routingId!,
      )) {
        final workstation = workstations[operation.workstationId];
        if (workstation != null)
          operating += workstation.hourRate.multiplyDecimal(
            (operation.timeMinutes / 60).toString(),
          );
      }
    }
    final updated = MrpBom(
      id: bom.id,
      companyId: bom.companyId,
      itemId: bom.itemId,
      quantity: bom.quantity,
      uom: bom.uom,
      isActive: bom.isActive,
      isDefault: bom.isDefault,
      routingId: bom.routingId,
      rawMaterialCost: raw,
      operatingCost: operating,
      totalCost: raw + operating,
      entityType: bom.entityType,
    );
    await _boms.save(updated);
    return updated;
  }
}

class MrpWorkOrderService {
  MrpWorkOrderService({
    MrpWorkOrderRepository? orders,
    MrpWorkOrderItemRepository? items,
    MrpBomRepository? boms,
    MrpBomItemRepository? bomItems,
    WarehouseStockService? stock,
  }) : _orders = orders ?? MrpWorkOrderRepository(),
       _items = items ?? MrpWorkOrderItemRepository(),
       _boms = boms ?? MrpBomRepository(),
       _bomItems = bomItems ?? MrpBomItemRepository(),
       _stock = stock ?? WarehouseStockService();
  final MrpWorkOrderRepository _orders;
  final MrpWorkOrderItemRepository _items;
  final MrpBomRepository _boms;
  final MrpBomItemRepository _bomItems;
  final WarehouseStockService _stock;

  Future<int> create({required MrpWorkOrder draft}) async {
    final bom = await _boms.findById(draft.bomId);
    if (bom == null || bom.itemId != draft.productionItemId)
      throw StateError(
        'La BOM no existe o no corresponde al producto terminado.',
      );
    final id = await _orders.save(draft);
    for (final item in await _explode(draft.bomId, draft.qtyPlanned, <int>{})) {
      await _items.save(
        MrpWorkOrderItem(
          companyId: draft.companyId,
          workOrderId: id,
          itemId: item.itemId,
          requiredQty: item.requiredQty,
          sourceWarehouseId: item.sourceWarehouseId,
        ),
      );
    }
    return id;
  }

  Future<List<MrpWorkOrder>> list() => _orders.list();
  Future<List<MrpWorkOrderItem>> items(int orderId) =>
      _items.listForOrder(orderId);

  Future<void> transition(int orderId, MrpWorkOrderStatus target) async {
    final order = await _orders.findById(orderId);
    if (order == null) throw StateError('Orden de produccion no encontrada.');
    if (!_allowed(order.status, target))
      throw StateError(
        'Transicion ${order.status.name} -> ${target.name} no permitida.',
      );
    final now = DateTime.now();
    if (target == MrpWorkOrderStatus.enProceso) {
      for (final item in await _items.listForOrder(orderId)) {
        if (item.transferredQty >= item.requiredQty) continue;
        await _stock.transfer(
          productId: item.itemId,
          fromWarehouseId: item.sourceWarehouseId ?? 1,
          toWarehouseId: order.wipWarehouseId,
          quantity: item.requiredQty - item.transferredQty,
          reason: 'MRP WO#$orderId materia prima',
        );
        await _items.save(
          MrpWorkOrderItem(
            id: item.id,
            companyId: item.companyId,
            workOrderId: item.workOrderId,
            itemId: item.itemId,
            requiredQty: item.requiredQty,
            transferredQty: item.requiredQty,
            consumedQty: item.consumedQty,
            sourceWarehouseId: item.sourceWarehouseId,
          ),
        );
      }
    }
    if (target == MrpWorkOrderStatus.completada) {
      await _stock.receiveProduction(
        productId: order.productionItemId,
        warehouseId: order.wipWarehouseId,
        quantity: order.qtyPlanned,
        reason: 'MRP WO#$orderId producto terminado',
      );
      await _stock.transfer(
        productId: order.productionItemId,
        fromWarehouseId: order.wipWarehouseId,
        toWarehouseId: order.fgWarehouseId,
        quantity: order.qtyPlanned,
        reason: 'MRP WO#$orderId producto terminado a FG',
      );
    }
    await _orders.save(
      MrpWorkOrder(
        id: order.id,
        companyId: order.companyId,
        productionItemId: order.productionItemId,
        bomId: order.bomId,
        qtyPlanned: order.qtyPlanned,
        qtyProduced: target == MrpWorkOrderStatus.completada
            ? order.qtyPlanned
            : order.qtyProduced,
        status: target,
        wipWarehouseId: order.wipWarehouseId,
        fgWarehouseId: order.fgWarehouseId,
        plannedStartDate: order.plannedStartDate,
        actualStartDate: target == MrpWorkOrderStatus.enProceso
            ? now
            : order.actualStartDate,
        plannedEndDate: order.plannedEndDate,
        actualEndDate: target == MrpWorkOrderStatus.completada
            ? now
            : order.actualEndDate,
        plannedOperatingCost: order.plannedOperatingCost,
        actualOperatingCost: target == MrpWorkOrderStatus.completada
            ? order.plannedOperatingCost
            : order.actualOperatingCost,
        rawMaterialCost: order.rawMaterialCost,
        totalCost: order.totalCost,
      ),
    );
  }

  bool _allowed(
    MrpWorkOrderStatus from,
    MrpWorkOrderStatus to,
  ) => switch (from) {
    MrpWorkOrderStatus.borrador =>
      to == MrpWorkOrderStatus.noIniciada || to == MrpWorkOrderStatus.cancelada,
    MrpWorkOrderStatus.noIniciada =>
      to == MrpWorkOrderStatus.enProceso || to == MrpWorkOrderStatus.cancelada,
    MrpWorkOrderStatus.enProceso =>
      to == MrpWorkOrderStatus.completada || to == MrpWorkOrderStatus.cancelada,
    _ => false,
  };

  Future<List<MrpWorkOrderItem>> _explode(
    int bomId,
    double multiplier,
    Set<int> visited,
  ) async {
    if (!visited.add(bomId))
      throw StateError('La BOM contiene un ciclo multinivel.');
    final result = <MrpWorkOrderItem>[];
    for (final item in await _bomItems.listForBom(bomId)) {
      final required = item.qty * multiplier;
      final child = (await _boms.list())
          .where((b) => b.itemId == item.itemId && b.isActive)
          .firstOrNull;
      if (item.isSubAssemblyItem && child != null) {
        result.addAll(
          await _explode(child.id!, required / child.quantity, {...visited}),
        );
      } else {
        result.add(
          MrpWorkOrderItem(
            companyId: item.companyId,
            workOrderId: 0,
            itemId: item.itemId,
            requiredQty: required,
            sourceWarehouseId: item.sourceWarehouseId,
          ),
        );
      }
    }
    return result;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
