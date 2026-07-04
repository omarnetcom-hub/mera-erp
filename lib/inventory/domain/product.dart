class Product {
  const Product({
    this.id,
    this.companyId,
    required this.name,
    required this.unit,
    required this.stock,
    required this.cost,
    required this.price,
    required this.taxRate,
    this.barcode = '',
    this.conversionName = '',
    this.conversionQuantity = 0,
  });

  final int? id;
  final int? companyId;
  final String name;
  final String unit;
  final double stock;
  final double cost;
  final double price;
  final double taxRate;
  final String barcode;
  final String conversionName;
  final double conversionQuantity;

  bool get lowStock => stock <= 5;

  double get stockCostValue => stock * cost;

  double get stockSaleValue => stock * price;

  Product copyWith({
    int? id,
    int? companyId,
    String? name,
    String? unit,
    double? stock,
    double? cost,
    double? price,
    double? taxRate,
    String? barcode,
    String? conversionName,
    double? conversionQuantity,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      barcode: barcode ?? this.barcode,
      conversionName: conversionName ?? this.conversionName,
      conversionQuantity: conversionQuantity ?? this.conversionQuantity,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] as num?)?.toInt(),
      companyId: (map['company_id'] as num?)?.toInt(),
      name: map['nombre']?.toString() ?? '',
      unit: map['unidad_base']?.toString() ?? 'UND',
      stock: (map['stock'] as num?)?.toDouble() ?? 0,
      cost: (map['costo'] as num?)?.toDouble() ?? 0,
      price: (map['precio'] as num?)?.toDouble() ?? 0,
      taxRate: (map['impuesto_pct'] as num?)?.toDouble() ?? 0,
      barcode: map['codigo_barras']?.toString() ?? '',
      conversionName: map['conversion_nombre']?.toString() ?? '',
      conversionQuantity: (map['conversion_cantidad'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      'nombre': name,
      'unidad_base': unit,
      'stock': stock,
      'costo': cost,
      'precio': price,
      'impuesto_pct': taxRate,
      'codigo_barras': barcode,
      'conversion_nombre': conversionName,
      'conversion_cantidad': conversionQuantity,
    };
  }

  Map<String, Object?> toPersistenceMap() {
    final map = toMap()..remove('id');
    return map;
  }
}
