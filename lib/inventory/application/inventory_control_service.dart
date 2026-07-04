import '../domain/product.dart';

enum CostingMethod { weightedAverage, fifo }

class ReplenishmentSuggestion {
  const ReplenishmentSuggestion({
    required this.product,
    required this.recommendedQuantity,
    required this.reason,
  });

  final Product product;
  final double recommendedQuantity;
  final String reason;

  Map<String, Object?> toMap() => {
    'product_id': product.id,
    'product': product.name,
    'stock': product.stock,
    'recommended_quantity': recommendedQuantity,
    'reason': reason,
  };
}

class InventoryControlReport {
  const InventoryControlReport({
    required this.products,
    required this.suggestions,
    required this.costValue,
    required this.saleValue,
  });

  final int products;
  final List<ReplenishmentSuggestion> suggestions;
  final double costValue;
  final double saleValue;

  double get potentialMargin => saleValue - costValue;

  Map<String, Object?> toMap() => {
    'products': products,
    'cost_value': costValue,
    'sale_value': saleValue,
    'potential_margin': potentialMargin,
    'replenishment': suggestions.map((item) => item.toMap()).toList(),
  };
}

class InventoryControlService {
  const InventoryControlService({
    this.reorderPoint = 5,
    this.targetStock = 15,
    this.costingMethod = CostingMethod.weightedAverage,
  });

  final double reorderPoint;
  final double targetStock;
  final CostingMethod costingMethod;

  InventoryControlReport analyze(List<Product> products) {
    final suggestions = <ReplenishmentSuggestion>[];
    var costValue = 0.0;
    var saleValue = 0.0;

    for (final product in products) {
      costValue += product.stock * product.cost;
      saleValue += product.stock * product.price;
      if (product.stock <= reorderPoint) {
        final quantity = (targetStock - product.stock).clamp(0, targetStock);
        suggestions.add(
          ReplenishmentSuggestion(
            product: product,
            recommendedQuantity: quantity.toDouble(),
            reason: 'Stock igual o inferior al punto de reposicion.',
          ),
        );
      }
    }

    return InventoryControlReport(
      products: products.length,
      suggestions: suggestions,
      costValue: costValue,
      saleValue: saleValue,
    );
  }

  double weightedAverageCost({
    required double currentStock,
    required double currentCost,
    required double incomingQuantity,
    required double incomingCost,
  }) {
    if (currentStock < 0 || incomingQuantity < 0) {
      throw ArgumentError('Las cantidades no pueden ser negativas.');
    }
    final totalQuantity = currentStock + incomingQuantity;
    if (totalQuantity == 0) return 0;
    final totalCost =
        (currentStock * currentCost) + (incomingQuantity * incomingCost);
    return totalCost / totalQuantity;
  }
}
