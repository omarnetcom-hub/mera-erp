import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/merka_intelligence_service.dart';

class CopilotMessage {
  const CopilotMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

class CopilotPanel extends StatefulWidget {
  const CopilotPanel({
    super.key,
    required this.onClose,
    required this.modules,
    required this.onNavigateToModule,
    required this.onLoadSaleProduct,
    required this.onLoadClientPayment,
    required this.onLoadPurchaseOrder,
  });

  final VoidCallback onClose;
  final List<dynamic> modules;
  final ValueChanged<String> onNavigateToModule; // moduleId
  final ValueChanged<String> onLoadSaleProduct;  // product search query
  final VoidCallback onLoadClientPayment;
  final VoidCallback onLoadPurchaseOrder;

  @override
  State<CopilotPanel> createState() => _CopilotPanelState();
}

class _CopilotPanelState extends State<CopilotPanel> {
  final MerkaIntelligenceService _intelligence = MerkaIntelligenceService();
  final List<CopilotMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWelcomeMessage() async {
    setState(() => _loading = true);
    try {
      final alerts = await _intelligence.operationalAlerts();
      final expiring = alerts.where((a) => a.kind == 'expiring_product').length;
      final critical = alerts.where((a) => a.kind == 'critical_stock').length;
      final receivables = alerts.where((a) => a.kind == 'receivable').length;

      String welcomeText = '¡Buenos días! Soy tu Copilot MerkaERP.\n\n';
      if (expiring > 0 || critical > 0 || receivables > 0) {
        welcomeText += 'He detectado algunas novedades operativas hoy:\n';
        if (critical > 0) welcomeText += '• ⚠️ Tienes $critical productos con stock crítico.\n';
        if (expiring > 0) welcomeText += '• ⏳ Tienes $expiring lotes próximos a vencer.\n';
        if (receivables > 0) welcomeText += '• 💳 Tienes $receivables cobranzas pendientes.\n';
        welcomeText += '\n¿Deseas que te ayude a revisarlos o prefieres realizar alguna acción?';
      } else {
        welcomeText += 'Todo parece estar en orden hoy. ¿En qué puedo ayudarte? Puedes preguntarme sobre ventas, inventario, finanzas o controlar el sistema.';
      }

      if (!mounted) return;
      setState(() {
        _messages.add(CopilotMessage(fromUser: false, text: welcomeText));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(const CopilotMessage(
          fromUser: false,
          text: 'Hola. Ocurrió un error al cargar las alertas del día. ¿En qué te puedo colaborar hoy?',
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(CopilotMessage(fromUser: true, text: query));
      _inputController.clear();
    });
    
    _scrollToBottom();

    // NLP intent mapping & Action execution
    final reply = await _intelligence.answer(query, module: 'workspace');

    // Action triggers based on intent
    if (reply.intent == 'critical_stock' || reply.intent == 'expiring_products') {
      widget.onNavigateToModule('inventory');
    } else if (reply.intent == 'sales_today' || reply.intent == 'sales_month') {
      widget.onNavigateToModule('sales');
    } else if (reply.intent == 'receivables') {
      widget.onNavigateToModule('receivables');
    } else if (reply.intent == 'payables') {
      widget.onNavigateToModule('payables');
    } else if (reply.intent == 'open_purchase') {
      widget.onLoadPurchaseOrder();
    } else if (reply.intent == 'cash_closing') {
      widget.onNavigateToModule('cash_closings');
    }

    // Direct product loading logic
    final lower = query.toLowerCase();
    if (lower.startsWith('vender ') && lower.length > 7) {
      final queryProduct = query.substring(7).trim();
      widget.onLoadSaleProduct(queryProduct);
    } else if (lower.startsWith('cobrar ') || lower.contains('registrar pago')) {
      widget.onLoadClientPayment();
    }

    if (!mounted) return;
    setState(() {
      _messages.add(CopilotMessage(fromUser: false, text: reply.response));
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(PhosphorIcons.brain(), color: const Color(0xFF2563EB), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Copilot MerkaERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                    Text('Asistente Operativo con IA', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.x(), size: 18),
                onPressed: widget.onClose,
              )
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Chat Area
        Expanded(
          child: _loading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final msg = _messages[idx];
                    return _Bubble(message: msg);
                  },
                ),
        ),
        
        // Suggestion chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _SuggestionChip(label: '📊 Ventas de hoy', onTap: () => _submit('Ventas de hoy')),
              _SuggestionChip(label: '⚠️ Productos críticos', onTap: () => _submit('Productos críticos')),
              _SuggestionChip(label: '💳 Cobranza pendiente', onTap: () => _submit('Cobranza pendiente')),
              _SuggestionChip(label: '📦 Crear compra', onTap: () => _submit('Crear compra')),
            ],
          ),
        ),
        
        // Input text box
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Pregunta algo al Copilot...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _submit(_inputController.text),
                child: Icon(PhosphorIcons.paperPlaneRight(), size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final CopilotMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 12),
          ),
          border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1F2937),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
        ),
      ),
    );
  }
}
