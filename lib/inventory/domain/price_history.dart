// ============================================================
// price_history.dart
// Modelo para historial de precios de productos
// ============================================================

class PriceHistory {
  final int? id;
  final int companyId;
  final int productId;
  final String productName;
  final double oldPrice;
  final double newPrice;
  final double percentageChange;
  final String changeReason; // manual_update, supplier_change, promotion, etc.
  final String? changedBy;
  final DateTime changedAt;

  PriceHistory({
    this.id,
    required this.companyId,
    required this.productId,
    required this.productName,
    required this.oldPrice,
    required this.newPrice,
    required this.percentageChange,
    required this.changeReason,
    this.changedBy,
    required this.changedAt,
  });

  bool get isIncrease => newPrice > oldPrice;
  bool get isDecrease => newPrice < oldPrice;
  bool get isNoChange => newPrice == oldPrice;

  PriceHistory copyWith({
    int? id,
    int? companyId,
    int? productId,
    String? productName,
    double? oldPrice,
    double? newPrice,
    double? percentageChange,
    String? changeReason,
    String? changedBy,
    DateTime? changedAt,
  }) {
    return PriceHistory(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      oldPrice: oldPrice ?? this.oldPrice,
      newPrice: newPrice ?? this.newPrice,
      percentageChange: percentageChange ?? this.percentageChange,
      changeReason: changeReason ?? this.changeReason,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'product_id': productId,
      'product_name': productName,
      'old_price': oldPrice,
      'new_price': newPrice,
      'percentage_change': percentageChange,
      'change_reason': changeReason,
      'changed_by': changedBy,
      'changed_at': changedAt.toIso8601String(),
    };
  }

  factory PriceHistory.fromMap(Map<String, dynamic> map) {
    return PriceHistory(
      id: map['id'] as int?,
      companyId: map['company_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      oldPrice: (map['old_price'] as num).toDouble(),
      newPrice: (map['new_price'] as num).toDouble(),
      percentageChange: (map['percentage_change'] as num).toDouble(),
      changeReason: map['change_reason'] as String,
      changedBy: map['changed_by'] as String?,
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }
}
