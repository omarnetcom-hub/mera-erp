import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../control_center_agent.dart';
import '../sales/application/create_sale_use_case.dart';
import '../services/merka_intelligence_service.dart';
import '../core/invoicing/cufe.dart';

class SalesModePanel extends StatefulWidget {
  const SalesModePanel({
    super.key,
    required this.onCopilot,
    this.initialBarcodeQuery,
  });

  final VoidCallback onCopilot;
  final String? initialBarcodeQuery;

  @override
  State<SalesModePanel> createState() => _SalesModePanelState();
}

class _SalesModePanelState extends State<SalesModePanel> {
  final CreateSaleUseCase _crearVenta = CreateSaleUseCase();
  final MerkaIntelligenceService _intelligence = MerkaIntelligenceService();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  List<Map<String, dynamic>> _productosDisponibles = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _metodosPago = [];

  // Estado del Carrito
  final List<Map<String, dynamic>> _carrito = [];
  List<Map<String, dynamic>> _suggestions = [];

  // Datos de Factura/Cliente
  int? _clienteId;
  String _clienteNombre = 'Cliente general';
  int _metodoPagoId = 1;

  bool _loading = true;
  bool _resolvingBarcode = false;
  Timer? _debounceTimer;

  // Totales calculados
  double get _subtotal => _carrito.fold<double>(0.0, (sum, item) => sum + (item['subtotal'] as num).toDouble());
  double get _impuestos => _carrito.fold<double>(0.0, (sum, item) => sum + (item['impuesto_total'] as num).toDouble());
  double get _total => _subtotal + _impuestos;

  @override
  void initState() {
    super.initState();
    _loadSalesData().then((_) {
      if (widget.initialBarcodeQuery != null && widget.initialBarcodeQuery!.isNotEmpty) {
        _barcodeController.text = widget.initialBarcodeQuery!;
        _resolverBusquedaAutomatica(widget.initialBarcodeQuery!);
      }
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSalesData() async {
    setState(() => _loading = true);
    try {
      _productosDisponibles = await DatabaseHelper.instance.obtenerProductos();
      _clientes = await DatabaseHelper.instance.obtenerClientes();
      _metodosPago = await DatabaseHelper.instance.obtenerMetodosPago();
      
      if (_metodosPago.isNotEmpty) {
        _metodoPagoId = (_metodosPago.first['id'] as num).toInt();
      }
    } catch (e) {
      debugPrint('Error loading sales POS data: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _agregarProducto(Map<String, dynamic> producto, double cantidad) {
    final productoId = (producto['id'] as num).toInt();
    final stock = (producto['stock'] as num?)?.toDouble() ?? 0.0;
    
    // Validar cantidad total en carrito vs stock
    final yaAgregado = _carrito
        .where((item) => item['producto_id'] == productoId)
        .fold<double>(
          0.0,
          (sum, item) => sum + (item['cantidad'] as num).toDouble(),
        );

    if (yaAgregado + cantidad > stock) {
      SystemSound.play(SystemSoundType.alert);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock insuficiente para ${producto['nombre']} (Dispo: $stock)'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final precio = (producto['precio'] as num).toDouble();
    final impuestoPct = (producto['impuesto_pct'] as num?)?.toDouble() ?? 0.0;
    final impuestoItem = precio * cantidad * (impuestoPct / 100);
    final existente = _carrito.where((i) => i['producto_id'] == productoId);

    setState(() {
      if (existente.isNotEmpty) {
        final item = existente.first;
        final nuevaCantidad = (item['cantidad'] as num).toDouble() + cantidad;
        item['cantidad'] = nuevaCantidad;
        item['subtotal'] = nuevaCantidad * precio;
        item['impuesto_total'] = (item['subtotal'] as num).toDouble() * (impuestoPct / 100);
      } else {
        _carrito.add({
          'producto_id': productoId,
          'producto': producto['nombre'],
          'codigo_barras': producto['codigo_barras'] ?? '',
          'unidad': producto['unidad_base'] ?? 'unid.',
          'cantidad': cantidad,
          'precio': precio,
          'costo': producto['costo'] ?? 0.0,
          'subtotal': cantidad * precio,
          'impuesto_pct': impuestoPct,
          'impuesto_total': impuestoItem,
          'ubicacion_codigo': producto['ubicacion_codigo'] ?? '',
          'codigo_lote': producto['codigo_lote'] ?? '',
          'fecha_vencimiento': producto['fecha_vencimiento'] ?? '',
        });
      }
      
      _loadCrossSellingRecommendations(productoId);
      
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
    });
  }

  Future<void> _loadCrossSellingRecommendations(int productId) async {
    final suggs = await _intelligence.crossSellSuggestions(productId);
    setState(() {
      _suggestions = suggs;
    });
  }

  Map<String, dynamic>? _buscarPorCodigo(String codigo) {
    final limpio = codigo.trim().toLowerCase();
    if (limpio.isEmpty) return null;
    for (final producto in _productosDisponibles) {
      final barras = (producto['codigo_barras'] ?? '').toString().toLowerCase();
      final id = producto['id'].toString();
      if (barras == limpio || id == limpio) return producto;
    }
    return null;
  }

  Future<void> _resolverBusquedaAutomatica(String value) async {
    final query = value.trim();
    if (query.length < 3 || _resolvingBarcode) return;
    _resolvingBarcode = true;
    try {
      final local = _buscarPorCodigo(query);
      final lookup = local == null ? await _intelligence.findProduct(query) : null;
      final productoBase = local ?? lookup?.product;
      
      if (productoBase == null) {
        SystemSound.play(SystemSoundType.alert);
        return;
      }
      
      final lote = lookup?.lot;
      final producto = {
        ...productoBase,
        if (lote != null) 'codigo_lote': lote['codigo_lote'],
        if (lote != null) 'fecha_vencimiento': lote['fecha_vencimiento'],
      };
      
      _agregarProducto(producto, 1);
      SystemSound.play(SystemSoundType.click);
      
      final loc = ProductLookupResult(
        product: producto,
        matchedBy: lookup?.matchedBy ?? 'codigo_barras',
        lot: lote,
        suggestions: lookup?.suggestions ?? const [],
      ).location;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.isEmpty
                  ? '${producto['nombre']} agregado al carrito'
                  : '${producto['nombre']} agregado | Ubicación: $loc',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      _resolvingBarcode = false;
    }
  }

  void _abrirSelectorClienteRapido() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Cliente (POS)'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Cliente General'),
                onTap: () {
                  setState(() {
                    _clienteId = null;
                    _clienteNombre = 'Cliente general';
                  });
                  Navigator.pop(ctx);
                },
              ),
              ..._clientes.map((c) => ListTile(
                title: Text(c['nombre'].toString()),
                subtitle: Text('NIT/CC: ${c['nit'] ?? 'N/A'}'),
                onTap: () {
                  setState(() {
                    _clienteId = (c['id'] as num).toInt();
                    _clienteNombre = c['nombre'].toString();
                  });
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarVaciarCarrito() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar Carrito'),
        content: const Text('¿Desea limpiar todos los productos de la venta actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _carrito.clear();
                _suggestions.clear();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Sí, vaciar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTicketDialog({
    required int saleId,
    required double subtotal,
    required double impuestos,
    required double total,
    required String clientName,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now();
    final fechaIso = now.toIso8601String();

    // Obtain persisted PIN; if absent, show a pending message instead of generating CUFE.
    final pin = await DatabaseHelper.instance.obtenerDianPin();
    final String? cufeFull = pin == null ? null : computeCufe(ventaId: saleId, total: total, fechaIso: fechaIso, pin: pin);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool printing = false;

          void simulatePrint() {
            setDialogState(() {
              printing = true;
            });
            SystemSound.play(SystemSoundType.click);
            final navigatorContext = ctx;
            final messenger = ScaffoldMessenger.of(navigatorContext);
            Timer(const Duration(seconds: 2), () {
              if (navigatorContext.mounted) {
                Navigator.pop(navigatorContext);
              }
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Comprobante POS impreso correctamente.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.all(16),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (printing) ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Imprimiendo ticket...', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Simulando impresión térmica (80mm)...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 40),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('*** MERKA ERP ***', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text('MERKA ERP COLOMBIA S.A.S.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                          const Text('NIT: 901.458.123-9', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                          const Text('REGIMEN COMUN - RESPONSABLE DE IVA', textAlign: TextAlign.center, style: TextStyle(fontSize: 10)),
                          const Text('Dirección: Calle 26 # 69-76, Bogotá', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                          const Text('Tel: (601) 456-7890', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                          const Text('------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TICKET POS: #$saleId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Text('Fecha: ${fechaIso.split('T').first}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          Text('Cliente: $clientName', style: const TextStyle(fontSize: 11)),
                          Text('Cajero: Administrador', style: const TextStyle(fontSize: 11)),
                          const Text('------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                          for (final item in items) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item['producto']} x${(item['cantidad'] as num).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text('\$${(item['subtotal'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                          const Text('------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('SUBTOTAL:', style: TextStyle(fontSize: 11)),
                              Text('\$${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('IVA (19%):', style: TextStyle(fontSize: 11)),
                              Text('\$${impuestos.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL A PAGAR:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('\$${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const Text('------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('Metodo de Pago: $paymentMethod', style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 8),
                          const Text('RESOLUCION DIAN NO. 187640000001', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          const Text('Prefijo: FE | Rango: 1001 a 20000', textAlign: TextAlign.center, style: TextStyle(fontSize: 9)),
                          const Text('Habilitado por Proveedor Tecnológico DIAN', textAlign: TextAlign.center, style: TextStyle(fontSize: 9)),
                          const SizedBox(height: 6),
                          if (cufeFull == null)
                            const Text('CUFE: Pendiente -- configure PIN en Centro de Facturación', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontStyle: FontStyle.italic))
                          else
                            SelectableText(cufeFull, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, fontFamily: 'monospace')),
                          const SizedBox(height: 8),
                          const Text('*** GRACIAS POR SU COMPRA ***', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          const Text('MerkaERP Software de Gestión', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: simulatePrint,
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Imprimir'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pagarCarrito() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final isBlocked = await DatabaseHelper.instance.operacionBloqueadaPorCierre();
    if (!mounted) return;
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación bloqueada por cierre de caja activo.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      final metodo = _metodosPago.firstWhere(
        (m) => (m['id'] as num).toInt() == _metodoPagoId,
        orElse: () => {'nombre': 'Efectivo'},
      );

      // Copias de totales y de items del carrito para previsualizar el ticket
      final sub = _subtotal;
      final imp = _impuestos;
      final tot = _total;
      final client = _clienteNombre;
      final paymentName = metodo['nombre'].toString();
      final itemsCopy = List<Map<String, dynamic>>.from(_carrito.map((i) => Map<String, dynamic>.from(i)));

      final result = await _crearVenta.execute(
        CreateSaleRequest(
          items: _carrito.map(SaleItemInput.fromCart).toList(),
          paymentMethodId: _metodoPagoId,
          paymentMethodName: paymentName,
          clientId: _clienteId,
          clientName: client,
        ),
      );

      await ControlCenterAgent.reportEvent(
        event: 'sale.created.${result.saleId}',
        module: 'sales',
      );

      SystemSound.play(SystemSoundType.click);
      
      setState(() {
        _carrito.clear();
        _suggestions.clear();
        _clienteId = null;
        _clienteNombre = 'Cliente general';
      });

      _barcodeFocusNode.requestFocus();

      if (mounted) {
        _showTicketDialog(
          saleId: result.saleId,
          subtotal: sub,
          impuestos: imp,
          total: tot,
          clientName: client,
          paymentMethod: paymentName,
          items: itemsCopy,
        );
      }
    } catch (e) {
      SystemSound.play(SystemSoundType.alert);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar venta: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            _barcodeFocusNode.requestFocus();
          } else if (event.logicalKey == LogicalKeyboardKey.f2) {
            _abrirSelectorClienteRapido();
          } else if (event.logicalKey == LogicalKeyboardKey.f10 || event.logicalKey == LogicalKeyboardKey.f12) {
            _pagarCarrito();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_carrito.isNotEmpty) {
              _confirmarVaciarCarrito();
            }
          } else if (event.logicalKey == LogicalKeyboardKey.f9) {
            widget.onCopilot();
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          
          final posForm = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Escriba o escanee código de barras [F1]...',
                    prefixIcon: Icon(Icons.qr_code_scanner, color: Color(0xFF4B5563)),
                    suffixIcon: Icon(Icons.camera_alt_outlined, color: Color(0xFF4B5563)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 180),
                      () => _resolverBusquedaAutomatica(value),
                    );
                  },
                  onSubmitted: (value) {
                    final prod = _buscarPorCodigo(value);
                    if (prod != null) {
                      _agregarProducto(prod, 1);
                    } else {
                      _resolverBusquedaAutomatica(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: _carrito.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFF9CA3AF)),
                              SizedBox(height: 12),
                              Text('El carrito está vacío', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold)),
                              Text('[F1] Buscar producto | [F9] Copilot', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                            ],
                          ),
                        )
                      : Scrollbar(
                          child: ListView.separated(
                            itemCount: _carrito.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = _carrito[idx];
                              final sub = (item['subtotal'] as num).toDouble();
                              return ListTile(
                                dense: true,
                                title: Text(item['producto'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Row(
                                  children: [
                                    Text('${item['cantidad']} x \$${item['precio'].toStringAsFixed(0)}'),
                                    if (item['ubicacion_codigo'] != null && item['ubicacion_codigo'].toString().isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF4B5563)),
                                      Text(' ${item['ubicacion_codigo']}', style: const TextStyle(fontSize: 10)),
                                    ],
                                    if (item['codigo_lote'] != null && item['codigo_lote'].toString().isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.discount_outlined, size: 12, color: Color(0xFF4B5563)),
                                      Text(' Lote: ${item['codigo_lote']}', style: const TextStyle(fontSize: 10)),
                                    ]
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('\$${sub.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                                      onPressed: () {
                                        setState(() {
                                          if (item['cantidad'] > 1) {
                                            item['cantidad']--;
                                            item['subtotal'] = item['cantidad'] * item['precio'];
                                            item['impuesto_total'] = item['subtotal'] * (item['impuesto_pct'] / 100);
                                          } else {
                                            _carrito.removeAt(idx);
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
                                      onPressed: () {
                                        final prod = _productosDisponibles.firstWhere((p) => p['id'] == item['producto_id']);
                                        _agregarProducto(prod, 1);
                                      },
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Recomendaciones Inteligentes (Cross-Selling)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, idx) {
                      final item = _suggestions[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text('${item['nombre']} (\$${(item['precio'] as num).toStringAsFixed(0)})'),
                          onPressed: () => _agregarProducto(item, 1),
                        ),
                      );
                    },
                  ),
                ),
              ]
            ],
          );

          final checkoutForm = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Información del Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 14),
                      label: const Text('Rápido [F2]', style: TextStyle(fontSize: 12)),
                      onPressed: _abrirSelectorClienteRapido,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _clienteId,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Cliente',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Cliente general')),
                    ..._clientes.map((c) => DropdownMenuItem(
                      value: (c['id'] as num).toInt(),
                      child: Text(c['nombre'].toString()),
                    ))
                  ],
                  onChanged: (val) {
                    setState(() {
                      _clienteId = val;
                      if (val == null) {
                        _clienteNombre = 'Cliente general';
                      } else {
                        _clienteNombre = _clientes.firstWhere((c) => c['id'] == val)['nombre'].toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _metodoPagoId,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _metodosPago.map((m) => DropdownMenuItem(
                    value: (m['id'] as num).toInt(),
                    child: Text(m['nombre'].toString()),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _metodoPagoId = val);
                    }
                  },
                ),
                const Spacer(),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:', style: TextStyle(color: Color(0xFF4B5563))),
                    Text('\$${_subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Impuestos:', style: TextStyle(color: Color(0xFF4B5563))),
                    Text('\$${_impuestos.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                    Text(
                      '\$${_total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _carrito.isEmpty ? null : _pagarCarrito,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('COBRAR [F10]', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _carrito.isEmpty
                        ? null
                        : () => _confirmarVaciarCarrito(),
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: const Text('CANCELAR VENTA [Esc]'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.8,
                child: Column(
                  children: [
                    Expanded(flex: 3, child: posForm),
                    const SizedBox(height: 16),
                    Expanded(flex: 2, child: checkoutForm),
                  ],
                ),
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: posForm),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: checkoutForm),
            ],
          );
        },
      ),
    );
  }
}
