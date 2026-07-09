import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../commerce/application/payment_policy.dart';
import '../../db_helper.dart';
import '../../features/feature_key.dart';

class PurchaseItemInput {
  const PurchaseItemInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double unitCost;
  final double subtotal;

  factory PurchaseItemInput.fromCart(Map<String, dynamic> item) {
    return PurchaseItemInput(
      productId: (item['producto_id'] as num).toInt(),
      productName: item['producto'].toString(),
      quantity: (item['cantidad'] as num).toDouble(),
      unitCost: (item['costo'] as num).toDouble(),
      subtotal: (item['subtotal'] as num).toDouble(),
    );
  }
}

class CreatePurchaseRequest {
  const CreatePurchaseRequest({
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNumber,
    required this.observation,
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.taxRate,
    required this.items,
    this.manualCash = 0,
    this.manualBank = 0,
    this.manualCredit = 0,
    this.date,
    this.retefuente = 0.0,
    this.reteiva = 0.0,
    this.reteica = 0.0,
  });

  final int supplierId;
  final String supplierName;
  final String invoiceNumber;
  final String observation;
  final int paymentMethodId;
  final String paymentMethodName;
  final double taxRate;
  final double manualCash;
  final double manualBank;
  final double manualCredit;
  final List<PurchaseItemInput> items;
  final DateTime? date;
  final double retefuente;
  final double reteiva;
  final double reteica;
}

class CreatePurchaseResult {
  const CreatePurchaseResult({
    required this.purchaseId,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.payment,
  });

  final int purchaseId;
  final double subtotal;
  final double tax;
  final double total;
  final PaymentAllocation payment;
}

class CreatePurchaseUseCase {
  CreatePurchaseUseCase({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<CreatePurchaseResult> execute(CreatePurchaseRequest request) async {
    if (request.items.isEmpty) {
      throw Exception('Agrega productos para registrar la compra.');
    }

    await _db.validarFeatureHabilitada(FeatureKey.purchases);
    if (await _db.operacionBloqueadaPorCierre()) {
      throw Exception('Operacion bloqueada por cierre de caja.');
    }

    final purchaseDate = request.date ?? DateTime.now();
    if (await _db.periodoEstaCerrado(purchaseDate)) {
      throw Exception('El periodo contable de la fecha actual esta cerrado.');
    }

    final subtotal = request.items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final tax = subtotal * (request.taxRate / 100);
    final total = subtotal + tax;
    final payment = PaymentPolicy.allocatePurchase(
      total: total,
      method: request.paymentMethodName,
      manualCash: request.manualCash,
      manualBank: request.manualBank,
      manualCredit: request.manualCredit,
    );

    if (payment.cash > 0) {
      final cashBalance = await _db.obtenerSaldoPorCuenta('caja');
      if (cashBalance < payment.cash) {
        throw Exception('Saldo insuficiente en caja.');
      }
    }
    if (payment.bank > 0) {
      final bankBalance = await _db.obtenerSaldoPorCuenta('banco');
      if (bankBalance < payment.bank) {
        throw Exception('Saldo insuficiente en banco.');
      }
    }

    final database = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    final now = purchaseDate.toIso8601String();
    final status = payment.credit > 0 ? 'pendiente' : 'pagada';
    late int purchaseId;

    await database.transaction((txn) async {
      purchaseId = await txn.insert('compras', {
        'company_id': companyId,
        'proveedor_id': request.supplierId,
        'proveedor': request.supplierName,
        'numero_factura': request.invoiceNumber,
        'fecha_factura': now,
        'observacion': request.observation,
        'subtotal': subtotal,
        'impuesto_pct': request.taxRate,
        'impuesto_total': tax,
        'total': total,
        'efectivo': payment.cash,
        'transferencia': payment.bank,
        'credito': payment.credit,
        'fecha': now,
        'metodo_pago_id': request.paymentMethodId,
        'estado': status,
        'retefuente': request.retefuente,
        'reteiva': request.reteiva,
        'reteica': request.reteica,
      });

      for (final item in request.items) {
        final products = await txn.query(
          'productos',
          where: 'id = ? AND company_id = ?',
          whereArgs: [item.productId, companyId],
          limit: 1,
        );
        if (products.isEmpty) {
          throw Exception('Producto no encontrado: ${item.productName}');
        }
        final currentStock = (products.first['stock'] as num).toDouble();
        final currentCost = (products.first['costo'] as num?)?.toDouble() ?? 0;
        final newStock = currentStock + item.quantity;

        // Costeo Promedio Ponderado
        // average_cost = ((Stock actual * Costo actual) + (Nueva cantidad * Nuevo costo)) / (Stock actual + Nueva cantidad)
        final averageCost = newStock > 0 
            ? ((currentStock * currentCost) + (item.quantity * item.unitCost)) / newStock
            : item.unitCost;

        await txn.insert('compras_detalle', {
          'company_id': companyId,
          'compra_id': purchaseId,
          'producto_id': item.productId,
          'producto': item.productName,
          'cantidad': item.quantity,
          'costo_unitario': item.unitCost,
          'subtotal': item.subtotal,
        });
        await txn.update(
          'productos',
          {'stock': newStock, 'costo': averageCost},
          where: 'id = ? AND company_id = ?',
          whereArgs: [item.productId, companyId],
        );
        await txn.insert('movimientos_inventario', {
          'company_id': companyId,
          'producto_id': item.productId,
          'tipo': 'entrada',
          'cantidad': item.quantity,
          'stock_anterior': currentStock,
          'stock_nuevo': newStock,
          'costo_anterior': currentCost,
          'costo_nuevo': averageCost,
          'motivo': 'COMPRA #$purchaseId',
          'fecha': now,
        });
      }

      if (payment.credit > 0) {
        await txn.insert('cuentas_por_pagar', {
          'company_id': companyId,
          'proveedor': request.supplierName,
          'proveedor_id': request.supplierId,
          'compra_id': purchaseId,
          'numero_factura': request.invoiceNumber,
          'total': payment.credit,
          'saldo': payment.credit,
          'estado': 'pendiente',
          'fecha': now,
          'descripcion': 'Credito desde compra #$purchaseId',
        });
      }

      if (payment.cash > 0) {
        await txn.insert('movimientos_caja', {
          'company_id': companyId,
          'tipo': 'egreso',
          'concepto': 'Compra #$purchaseId (Caja)',
          'monto': payment.cash,
          'fecha': now,
          'origen': 'caja',
        });
      }
      if (payment.bank > 0) {
        await txn.insert('movimientos_caja', {
          'company_id': companyId,
          'tipo': 'egreso',
          'concepto': 'Compra #$purchaseId (Banco)',
          'monto': payment.bank,
          'fecha': now,
          'origen': 'banco',
        });
      }
      await _db.registrarAsientoCompra(
        compraId: purchaseId,
        total: total,
        pagoCaja: payment.cash,
        pagoBanco: payment.bank,
        credito: payment.credit,
        proveedor: request.supplierName,
        impuesto: tax,
        txn: txn,
      );
    });

    // Trigger asíncrono: Encolar sincronización con Control Center
    Future.microtask(() async {
      try {
        final payload = {
          'purchase_id': purchaseId,
          'total': total,
          'subtotal': subtotal,
          'tax': tax,
          'supplier_name': request.supplierName,
          'supplier_id': request.supplierId,
          'invoice_number': request.invoiceNumber,
          'date': purchaseDate.toIso8601String(),
          'payment_method': request.paymentMethodName,
          'status': status,
          'items': request.items.map((item) => {
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_cost': item.unitCost,
            'subtotal': item.subtotal,
          }).toList(),
        };
        await _db.enqueueSync(
          table: 'purchases',
          recordId: purchaseId.toString(),
          action: 'INSERT',
          payload: jsonEncode(payload),
        );
      } catch (e) {
        // Loguear error pero no afectar la operación principal
        debugPrint('Error en enqueueSync para compra: $e');
      }
    });

    return CreatePurchaseResult(
      purchaseId: purchaseId,
      subtotal: subtotal,
      tax: tax,
      total: total,
      payment: payment,
    );
  }
}
