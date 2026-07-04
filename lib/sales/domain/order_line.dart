// ============================================================
// order_line.dart
// Modelo para líneas de pedido
// ============================================================

class OrderLine {
  final int? id;
  final int companyId;
  final int orderId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double unitCost;
  final double discountAmount;
  final double taxPercentage;
  final double taxAmount;
  final double subtotal;
  final double total;
  final String? notes;
  final DateTime createdAt;

  OrderLine({
    this.id,
    required this.companyId,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    this.discountAmount = 0,
    this.taxPercentage = 0,
    this.taxAmount = 0,
    required this.subtotal,
    required this.total,
    this.notes,
    required this.createdAt,
  });

  OrderLine copyWith({
    int? id,
    int? companyId,
    int? orderId,
    int? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? unitCost,
    double? discountAmount,
    double? taxPercentage,
    double? taxAmount,
    double? subtotal,
    double? total,
    String? notes,
    DateTime? createdAt,
  }) {
    return OrderLine(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'discount_amount': discountAmount,
      'tax_percentage': taxPercentage,
      'tax_amount': taxAmount,
      'subtotal': subtotal,
      'total': total,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      id: map['id'] as int?,
      companyId: map['company_id'] as int,
      orderId: map['order_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Calcula los totales automáticamente
  static OrderLine calculate({
    required int companyId,
    required int orderId,
    required int productId,
    required String productName,
    required double quantity,
    required double unitPrice,
    required double unitCost,
    double discountAmount = 0,
    double taxPercentage = 0,
    String? notes,
  }) {
    final lineSubtotal = quantity * unitPrice;
    final lineDiscount = discountAmount;
    final taxableAmount = lineSubtotal - lineDiscount;
    final lineTax = taxableAmount * (taxPercentage / 100);
    final lineTotal = taxableAmount + lineTax;

    return OrderLine(
      companyId: companyId,
      orderId: orderId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      unitCost: unitCost,
      discountAmount: lineDiscount,
      taxPercentage: taxPercentage,
      taxAmount: lineTax,
      subtotal: lineSubtotal,
      total: lineTotal,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }
}
