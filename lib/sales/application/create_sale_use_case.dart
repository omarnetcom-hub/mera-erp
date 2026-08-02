import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    
    // Obtener parámetros de impuestos del año actual
    final currentYear = saleDate.year;
    final taxParams = await database.query(
      'tax_parameters',
      where: 'year = ? AND (company_id = ? OR company_id IS NULL)',
      whereArgs: [currentYear, companyId],
      limit: 1,
    );
    
    final ivaGeneralRate = taxParams.isEmpty ? 0.19 : (taxParams.first['iva_general_rate'] as num).toDouble();
    final ivaReducedRate = taxParams.isEmpty ? 0.05 : (taxParams.first['iva_reduced_rate'] as num).toDouble();
    final retefuenteUvt = taxParams.isEmpty ? 1090 : (taxParams.first['retefuente_general_uvt'] as num).toDouble();
    final retefuentePurchasesDeclaring = taxParams.isEmpty ? 0.025 : (taxParams.first['retefuente_purchases_declaring'] as num).toDouble();
    final retefuentePurchasesNonDeclaring = taxParams.isEmpty ? 0.035 : (taxParams.first['retefuente_purchases_non_declaring'] as num).toDouble();
    final retefuenteServices1 = taxParams.isEmpty ? 0.04 : (taxParams.first['retefuente_services_1'] as num).toDouble();
    final retefuenteServices2 = taxParams.isEmpty ? 0.06 : (taxParams.first['retefuente_services_2'] as num).toDouble();
    final retefuenteHonoraries1 = taxParams.isEmpty ? 0.10 : (taxParams.first['retefuente_honoraries_1'] as num).toDouble();
    final retefuenteHonoraries2 = taxParams.isEmpty ? 0.11 : (taxParams.first['retefuente_honoraries_2'] as num).toDouble();
    final reteicaRules = await database.query(
      'reglas_retenciones_empresa',
      columns: ['tasa', 'base_minima'],
      where: 'company_id = ? AND activo = 1 AND aplica_ventas = 1',
      whereArgs: [companyId],
      orderBy: 'id ASC',
      limit: 1,
    );
    final reteicaBaseRate = reteicaRules.isEmpty
        ? 0.0
        : (reteicaRules.first['tasa'] as num).toDouble() / 100;
    final reteicaMinimumBase = reteicaRules.isEmpty
        ? 0.0
        : (reteicaRules.first['base_minima'] as num).toDouble();
    
    // Obtener banderas fiscales del cliente si existe
    bool isAutoretainer = false;
    bool isDeclarante = true;
    if (request.clientId != null) {
      final clientRows = await database.query(
        'clientes',
        where: 'id = ? AND company_id = ?',
        whereArgs: [request.clientId, companyId],
        limit: 1,
      );
      if (clientRows.isNotEmpty) {
        isAutoretainer = (clientRows.first['autorretenedor'] as int?) == 1;
        isDeclarante = (clientRows.first['declarante'] as int?) != 0;
      }
    }
    
    // Calcular retenciones automáticamente si el cliente no es autorretenedor
    double calculatedRetefuente = request.retefuente;
    double calculatedReteiva = request.reteiva;
    double calculatedReteica = request.reteica;
    
    final subtotal = request.items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    
    if (!isAutoretainer) {
      // Calcular retefuente basado en el subtotal y tipo de cliente
      // (Simplificado - debería usar tabla UVT completa)
      if (subtotal > retefuenteUvt * 47062) { // 47062 es valor UVT 2024
        calculatedRetefuente = subtotal * (isDeclarante ? retefuentePurchasesDeclaring : retefuentePurchasesNonDeclaring);
      }
      
      if (subtotal >= reteicaMinimumBase) {
        calculatedReteica = subtotal * reteicaBaseRate;
      }
    }
    
    final tax = request.items.fold<double>(
      0,
      (sum, item) => sum + item.taxTotal,
    );
    final total = subtotal + tax - calculatedRetefuente - calculatedReteiva - calculatedReteica;
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
        'retefuente': calculatedRetefuente,
        'reteiva': calculatedReteiva,
        'reteica': calculatedReteica,
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
        final currentCost = (productRows.first['costo'] as num?)?.toDouble() ?? 0;
        final newStock = currentStock - item.quantity;

        // Verificar si el producto tiene lotes
        final lotes = await txn.query(
          'lotes',
          where: 'producto_id = ? AND company_id = ? AND status = ? AND cantidad > 0',
          whereArgs: [item.productId, companyId, 'active'],
          orderBy: 'fecha_vencimiento ASC', // FEFO: First Expired, First Out
        );

        if (lotes.isNotEmpty) {
          // Descontar de lotes usando FEFO
          double cantidadRestante = item.quantity;
          for (final lote in lotes) {
            if (cantidadRestante <= 0) break;
            
            final loteCantidad = (lote['cantidad'] as num).toDouble();
            final loteId = lote['id'] as int;
            
            if (loteCantidad >= cantidadRestante) {
              // El lote tiene suficiente para cubrir todo lo restante
              await txn.update(
                'lotes',
                {'cantidad': loteCantidad - cantidadRestante},
                where: 'id = ?',
                whereArgs: [loteId],
              );
              cantidadRestante = 0;
            } else {
              // Descontar todo del lote y continuar con el siguiente
              await txn.update(
                'lotes',
                {'cantidad': 0},
                where: 'id = ?',
                whereArgs: [loteId],
              );
              cantidadRestante -= loteCantidad;
            }
          }
        }

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
          'costo_anterior': currentCost,
          'costo_nuevo': currentCost,
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

    // Trigger asíncrono: Disparar webhooks (Fire-and-Forget)
    // No bloquea la operación principal, si falla solo se loguea el error
    Future.microtask(() async {
      try {
        final payload = {
          'invoice_id': saleId,
          'total': total,
          'subtotal': subtotal,
          'tax': tax,
          'client_name': request.clientName,
          'client_id': request.clientId,
          'date': saleDate.toIso8601String(),
          'payment_method': paymentMethod,
          'status': 'emitida',
        };
        await _db.dispararWebhooks('invoice.created', payload);
      } catch (e) {
        // Loguear error en auditoría pero no afectar la operación principal
        await _db.registrarEventoAuditoria(
          accion: 'ERROR_WEBHOOK',
          entidad: 'webhooks',
          entidadId: saleId,
          detalle: 'Error al disparar webhook invoice.created: $e',
        );
      }
    });

    // Trigger asíncrono: Crear garantías automáticas para productos con has_warranty = true
    Future.microtask(() async {
      try {
        for (final item in request.items) {
          final productRows = await database.query(
            'productos',
            where: 'id = ? AND company_id = ?',
            whereArgs: [item.productId, companyId],
            limit: 1,
          );
          
          if (productRows.isNotEmpty) {
            final product = productRows.first;
            final hasWarranty = (product['has_warranty'] as int?) == 1;
            final warrantyDays = (product['warranty_days'] as int?) ?? 365;
            
            if (hasWarranty) {
              await _db.registrarGarantia(
                ventaId: saleId,
                productoId: item.productId,
                descripcionProblema: 'Garantía automática generada al momento de venta',
                diasGarantia: warrantyDays,
              );
            }
          }
        }
      } catch (e) {
        // Loguear error en auditoría pero no afectar la operación principal
        await _db.registrarEventoAuditoria(
          accion: 'ERROR_GARANTIA_AUTOMATICA',
          entidad: 'warranties',
          entidadId: saleId,
          detalle: 'Error al crear garantía automática: $e',
        );
      }
    });

    // Trigger asíncrono: Encolar sincronización con Control Center
    Future.microtask(() async {
      try {
        final payload = {
          'invoice_id': saleId,
          'total': total,
          'subtotal': subtotal,
          'tax': tax,
          'client_name': request.clientName,
          'client_id': request.clientId,
          'date': saleDate.toIso8601String(),
          'payment_method': paymentMethod,
          'status': 'emitida',
          'items': request.items.map((item) => {
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'subtotal': item.subtotal,
          }).toList(),
        };
        await _db.enqueueSync(
          table: 'invoices',
          recordId: saleId.toString(),
          action: 'INSERT',
          payload: jsonEncode(payload),
        );
      } catch (e) {
        // Loguear error pero no afectar la operación principal
        debugPrint('Error en enqueueSync para venta: $e');
      }
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
