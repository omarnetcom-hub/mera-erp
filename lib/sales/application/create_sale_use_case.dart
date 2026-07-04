import '../../commerce/application/payment_policy.dart';
import '../../db_helper.dart';
import '../../features/feature_key.dart';

class SaleItemInput {
  const SaleItemInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.subtotal,
    required this.taxRate,
    required this.taxTotal,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double unitCost;
  final double subtotal;
  final double taxRate;
  final double taxTotal;

  factory SaleItemInput.fromCart(Map<String, dynamic> item) {
    return SaleItemInput(
      productId: (item['producto_id'] as num).toInt(),
      productName: item['producto'].toString(),
      quantity: (item['cantidad'] as num).toDouble(),
      unitPrice: (item['precio'] as num).toDouble(),
      unitCost: (item['costo'] as num?)?.toDouble() ?? 0,
      subtotal: (item['subtotal'] as num).toDouble(),
      taxRate: (item['impuesto_pct'] as num?)?.toDouble() ?? 0,
      taxTotal: (item['impuesto_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CreateSaleRequest {
  const CreateSaleRequest({
    required this.items,
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.clientName,
    this.clientId,
    this.date,
    this.efectivo = 0.0,
    this.transferencia = 0.0,
    this.credito = 0.0,
    this.retefuente = 0.0,
    this.reteiva = 0.0,
    this.reteica = 0.0,
  });

  final List<SaleItemInput> items;
  final int paymentMethodId;
  final String paymentMethodName;
  final int? clientId;
  final String clientName;
  final DateTime? date;
  final double efectivo;
  final double transferencia;
  final double credito;
  final double retefuente;
  final double reteiva;
  final double reteica;
}

class CreateSaleResult {
  const CreateSaleResult({
    required this.saleId,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.costOfSale,
  });

  final int saleId;
  final double subtotal;
  final double tax;
  final double total;
  final double costOfSale;
}

class CreateSaleUseCase {
  CreateSaleUseCase({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<CreateSaleResult> execute(CreateSaleRequest request) async {
    if (request.items.isEmpty) {
      throw Exception('Agrega productos para emitir la factura.');
    }

    await _db.validarFeatureHabilitada(FeatureKey.pos);
    if (await _db.operacionBloqueadaPorCierre()) {
      throw Exception('Operacion bloqueada por cierre de caja.');
    }

    final saleDate = request.date ?? DateTime.now();
    if (await _db.periodoEstaCerrado(saleDate)) {
      throw Exception('El periodo contable de la fecha actual esta cerrado.');
    }

    final database = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final subtotal = request.items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final tax = request.items.fold<double>(
      0,
      (sum, item) => sum + item.taxTotal,
    );
    final total = subtotal + tax;
    final taxRate = subtotal <= 0 ? 0.0 : (tax / subtotal) * 100;
    final paymentMethod = request.paymentMethodName.toUpperCase().trim();

    final ef = request.efectivo;
    final tf = request.transferencia;
    final cr = request.credito;
    final isMixed = paymentMethod == 'PAGO MIXTO' || (ef + tf + cr) > 0;

    if (isMixed) {
      if ((ef + tf + cr - total).abs() > 0.01) {
        throw Exception('La suma del pago mixto debe igualar el total de la factura.');
      }
    }

    final origin = PaymentPolicy.cashOriginForSale(paymentMethod);
    late int saleId;
    var costOfSale = 0.0;

    await database.transaction((txn) async {
      for (final item in request.items) {
        final productRows = await txn.query(
          'productos',
          where: 'id = ? AND company_id = ?',
          whereArgs: [item.productId, companyId],
          limit: 1,
        );
        if (productRows.isEmpty ||
            ((productRows.first['stock'] as num?)?.toDouble() ?? 0) <
                item.quantity) {
          throw Exception('Stock insuficiente para ${item.productName}');
        }
      }

      saleId = await txn.insert('ventas', {
        'company_id': companyId,
        'producto_id': 0,
        'producto': 'Factura POS',
        'cantidad': request.items.length,
        'precio_unitario': 0,
        'costo_unitario': 0,
        'subtotal': subtotal,
        'impuesto_pct': taxRate,
        'impuesto_total': tax,
        'total': total,
        'fecha': saleDate.toIso8601String(),
        'metodo_pago_id': request.paymentMethodId,
        'cliente_id': request.clientId,
        'cliente': request.clientName,
        'estado': 'emitida',
        'efectivo': request.efectivo,
        'transferencia': request.transferencia,
        'credito': request.credito,
        'retefuente': request.retefuente,
        'reteiva': request.reteiva,
        'reteica': request.reteica,
      });

      await txn.update(
        'ventas',
        {'producto': 'Factura POS #$saleId'},
        where: 'id = ? AND company_id = ?',
        whereArgs: [saleId, companyId],
      );

      final ef = request.efectivo;
      final tf = request.transferencia;
      final cr = request.credito;

      if (ef == 0 && tf == 0 && cr == 0) {
        await txn.insert('movimientos_caja', {
          'company_id': companyId,
          'tipo': 'ingreso',
          'concepto': origin == 'cartera'
              ? 'Cuenta por cobrar factura POS #$saleId'
              : 'Factura POS #$saleId',
          'monto': total,
          'fecha': saleDate.toIso8601String(),
          'origen': origin,
        });
      } else {
        if (ef > 0) {
          await txn.insert('movimientos_caja', {
            'company_id': companyId,
            'tipo': 'ingreso',
            'concepto': 'Factura POS #$saleId (Efectivo)',
            'monto': ef,
            'fecha': saleDate.toIso8601String(),
            'origen': 'caja',
          });
        }
        if (tf > 0) {
          await txn.insert('movimientos_caja', {
            'company_id': companyId,
            'tipo': 'ingreso',
            'concepto': 'Factura POS #$saleId (Transferencia)',
            'monto': tf,
            'fecha': saleDate.toIso8601String(),
            'origen': 'banco',
          });
        }
        if (cr > 0) {
          await txn.insert('movimientos_caja', {
            'company_id': companyId,
            'tipo': 'ingreso',
            'concepto': 'Cuenta por cobrar factura POS #$saleId',
            'monto': cr,
            'fecha': saleDate.toIso8601String(),
            'origen': 'cartera',
          });
        }
      }

      if (origin == 'cartera') {
        await txn.insert('cuentas_por_cobrar', {
          'company_id': companyId,
          'cliente_id': request.clientId,
          'cliente': request.clientName,
          'venta_id': saleId,
          'total': total,
          'saldo': total,
          'estado': 'pendiente',
          'fecha': saleDate.toIso8601String(),
          'descripcion': 'Factura POS #$saleId a credito',
        });
      }

      for (final item in request.items) {
        costOfSale += item.unitCost * item.quantity;
        final productRows = await txn.query(
          'productos',
          where: 'id = ? AND company_id = ?',
          whereArgs: [item.productId, companyId],
          limit: 1,
        );
        final currentStock = (productRows.first['stock'] as num).toDouble();
        final newStock = currentStock - item.quantity;

        await txn.update(
          'productos',
          {'stock': newStock},
          where: 'id = ? AND company_id = ?',
          whereArgs: [item.productId, companyId],
        );
        await txn.insert('movimientos_inventario', {
          'company_id': companyId,
          'producto_id': item.productId,
          'tipo': 'salida',
          'cantidad': item.quantity,
          'stock_anterior': currentStock,
          'stock_nuevo': newStock,
          'motivo': 'FACTURA POS #$saleId',
          'fecha': saleDate.toIso8601String(),
        });
        await txn.insert('ventas_detalle', {
          'company_id': companyId,
          'venta_id': saleId,
          'producto_id': item.productId,
          'producto': item.productName,
          'cantidad': item.quantity,
          'precio_unitario': item.unitPrice,
          'subtotal': item.subtotal,
        });
      }
      await _db.registrarAsientoVenta(
        ventaId: saleId,
        total: total,
        metodoPago: paymentMethod,
        costoVenta: costOfSale,
        impuesto: tax,
        txn: txn,
      );
    });

    return CreateSaleResult(
      saleId: saleId,
      subtotal: subtotal,
      tax: tax,
      total: total,
      costOfSale: costOfSale,
    );
  }
}
