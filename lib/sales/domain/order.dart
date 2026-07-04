// ============================================================
// order.dart
// Modelo para pedidos/pre-ventas
// ============================================================

class SalesOrder {
  final int? id;
  final int companyId;
  final String orderNumber;
  final int? customerId;
  final String customerName;
  final DateTime orderDate;
  final DateTime? estimatedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final double subtotal;
  final double taxAmount;
  final double total;
  final double discountAmount;
  final String status; // pending, confirmed, sent, delivered, cancelled
  final String? notes;
  final String? deliveryAddress;
  final String? contactPhone;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SalesOrder({
    this.id,
    required this.companyId,
    required this.orderNumber,
    this.customerId,
    required this.customerName,
    required this.orderDate,
    this.estimatedDeliveryDate,
    this.actualDeliveryDate,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.discountAmount = 0,
    this.status = 'pending',
    this.notes,
    this.deliveryAddress,
    this.contactPhone,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isSent => status == 'sent';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  bool get isOverdue {
    if (estimatedDeliveryDate == null || isDelivered || isCancelled) {
      return false;
    }
    return DateTime.now().isAfter(estimatedDeliveryDate!);
  }

  int get daysUntilDelivery {
    if (estimatedDeliveryDate == null) return 0;
    return estimatedDeliveryDate!.difference(DateTime.now()).inDays;
  }

  SalesOrder copyWith({
    int? id,
    int? companyId,
    String? orderNumber,
    int? customerId,
    String? customerName,
    DateTime? orderDate,
    DateTime? estimatedDeliveryDate,
    DateTime? actualDeliveryDate,
    double? subtotal,
    double? taxAmount,
    double? total,
    double? discountAmount,
    String? status,
    String? notes,
    String? deliveryAddress,
    String? contactPhone,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalesOrder(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      orderDate: orderDate ?? this.orderDate,
      estimatedDeliveryDate: estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      discountAmount: discountAmount ?? this.discountAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      contactPhone: contactPhone ?? this.contactPhone,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'order_date': orderDate.toIso8601String(),
      'estimated_delivery_date': estimatedDeliveryDate?.toIso8601String(),
      'actual_delivery_date': actualDeliveryDate?.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'discount_amount': discountAmount,
      'status': status,
      'notes': notes,
      'delivery_address': deliveryAddress,
      'contact_phone': contactPhone,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SalesOrder.fromMap(Map<String, dynamic> map) {
    return SalesOrder(
      id: map['id'] as int?,
      companyId: map['company_id'] as int,
      orderNumber: map['order_number'] as String,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String,
      orderDate: DateTime.parse(map['order_date'] as String),
      estimatedDeliveryDate: map['estimated_delivery_date'] != null
          ? DateTime.parse(map['estimated_delivery_date'] as String)
          : null,
      actualDeliveryDate: map['actual_delivery_date'] != null
          ? DateTime.parse(map['actual_delivery_date'] as String)
          : null,
      subtotal: (map['subtotal'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      deliveryAddress: map['delivery_address'] as String?,
      contactPhone: map['contact_phone'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
