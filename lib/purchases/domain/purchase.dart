class Purchase {
  const Purchase({
    this.id,
    this.companyId,
    this.supplierId,
    required this.supplier,
    this.invoiceNumber,
    this.invoiceDate,
    this.observation,
    required this.subtotal,
    required this.taxRate,
    required this.taxTotal,
    required this.total,
    required this.cashPayment,
    required this.bankPayment,
    required this.credit,
    required this.date,
    required this.paymentMethodId,
    required this.status,
  });

  final int? id;
  final int? companyId;
  final int? supplierId;
  final String supplier;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? observation;
  final double subtotal;
  final double taxRate;
  final double taxTotal;
  final double total;
  final double cashPayment;
  final double bankPayment;
  final double credit;
  final String date;
  final int paymentMethodId;
  final String status;

  bool get isCanceled => status == 'anulada';

  bool get hasCredit => credit > 0;

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: (map['id'] as num?)?.toInt(),
      companyId: (map['company_id'] as num?)?.toInt(),
      supplierId: (map['proveedor_id'] as num?)?.toInt(),
      supplier: map['proveedor']?.toString() ?? 'Sin proveedor',
      invoiceNumber: map['numero_factura']?.toString(),
      invoiceDate: map['fecha_factura']?.toString(),
      observation: map['observacion']?.toString(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (map['impuesto_pct'] as num?)?.toDouble() ?? 0,
      taxTotal: (map['impuesto_total'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      cashPayment: (map['efectivo'] as num?)?.toDouble() ?? 0,
      bankPayment: (map['transferencia'] as num?)?.toDouble() ?? 0,
      credit: (map['credito'] as num?)?.toDouble() ?? 0,
      date: map['fecha']?.toString() ?? '',
      paymentMethodId: (map['metodo_pago_id'] as num?)?.toInt() ?? 1,
      status: map['estado']?.toString() ?? 'pagada',
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      'proveedor_id': supplierId,
      'proveedor': supplier,
      'numero_factura': invoiceNumber,
      'fecha_factura': invoiceDate,
      'observacion': observation,
      'subtotal': subtotal,
      'impuesto_pct': taxRate,
      'impuesto_total': taxTotal,
      'total': total,
      'efectivo': cashPayment,
      'transferencia': bankPayment,
      'credito': credit,
      'fecha': date,
      'metodo_pago_id': paymentMethodId,
      'estado': status,
    };
  }
}

class PurchaseLine {
  const PurchaseLine({
    this.id,
    required this.purchaseId,
    required this.productId,
    required this.product,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
    this.unit,
    this.barcode,
  });

  final int? id;
  final int purchaseId;
  final int productId;
  final String product;
  final double quantity;
  final double unitCost;
  final double subtotal;
  final String? unit;
  final String? barcode;

  factory PurchaseLine.fromMap(Map<String, dynamic> map) {
    return PurchaseLine(
      id: (map['id'] as num?)?.toInt(),
      purchaseId: (map['compra_id'] as num?)?.toInt() ?? 0,
      productId: (map['producto_id'] as num?)?.toInt() ?? 0,
      product: map['producto']?.toString() ?? '',
      quantity: (map['cantidad'] as num?)?.toDouble() ?? 0,
      unitCost: (map['costo_unitario'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      unit: map['unidad_base']?.toString(),
      barcode: map['codigo_barras']?.toString(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'compra_id': purchaseId,
      'producto_id': productId,
      'producto': product,
      'cantidad': quantity,
      'costo_unitario': unitCost,
      'subtotal': subtotal,
      'unidad_base': unit,
      'codigo_barras': barcode,
    };
  }
}
