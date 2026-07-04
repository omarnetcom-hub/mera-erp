import 'product.dart';

class InventorySummary {
  const InventorySummary({
    required this.costValue,
    required this.saleValue,
    required this.productCount,
    required this.lowStockCount,
  });

  final double costValue;
  final double saleValue;
  final int productCount;
  final int lowStockCount;

  factory InventorySummary.fromProducts(List<Product> products) {
    return InventorySummary(
      costValue: products.fold<double>(
        0,
        (sum, product) => sum + product.stockCostValue,
      ),
      saleValue: products.fold<double>(
        0,
        (sum, product) => sum + product.stockSaleValue,
      ),
      productCount: products.length,
      lowStockCount: products.where((product) => product.lowStock).length,
    );
  }
}
