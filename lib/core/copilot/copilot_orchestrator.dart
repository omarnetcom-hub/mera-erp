import 'dart:convert';

import '../../db_helper.dart';
import '../../services/merka_intelligence_service.dart';
import 'copilot_models.dart';
import 'copilot_configuration_service.dart';
import 'copilot_tool_registry.dart';
import 'local_llm_client.dart';

class CopilotOrchestrator {
  CopilotOrchestrator({
    DatabaseHelper? databaseHelper,
    MerkaIntelligenceService? intelligence,
    LocalLlmClient? localLlm,
  }) : _db = databaseHelper ?? DatabaseHelper.instance,
       _intelligence = intelligence ?? MerkaIntelligenceService(),
       _localLlm = localLlm ?? LocalLlmClient(),
       _configuration = CopilotConfigurationService(
         databaseHelper: databaseHelper ?? DatabaseHelper.instance,
       ) {
    _registerTools();
  }

  final DatabaseHelper _db;
  final MerkaIntelligenceService _intelligence;
  final LocalLlmClient _localLlm;
  final CopilotConfigurationService _configuration;
  final CopilotToolRegistry tools = CopilotToolRegistry();

  Future<CopilotResponse> respond({
    required String prompt,
    required CopilotIdentity identity,
    List<CopilotConversationTurn> history = const [],
  }) async {
    final normalized = _normalize(prompt);
    if (normalized.isEmpty) {
      return const CopilotResponse(
        intent: 'empty',
        text: 'Escribe una consulta para poder ayudarte.',
        provider: 'deterministic',
      );
    }

    CopilotResponse response;
    Object? error;
    try {
      _registerNavigationTools(identity);
      final configuration = await _configuration.load();
      CopilotToolCall? call;
      var provider = 'deterministic';
      if (configuration.enabled) {
        try {
          final localResult = await _localLlm.complete(
            configuration: configuration,
            prompt: prompt,
            history: history.takeLast(8),
            tools: tools.schemas(identity),
          );
          call = localResult?.toolCall;
          if (call != null) provider = 'local_llm';
        } catch (_) {
          // El modelo es opcional. Un fallo nunca bloquea el ERP.
        }
      }
      call ??= _deterministicCall(normalized);
      if (call == null) {
        response = CopilotResponse(
          intent: 'fallback',
          provider: provider,
          text:
              'Puedo consultar ventas, inventario, cartera y cuentas por pagar, '
              'o preparar navegación y borradores autorizados. No encontré una '
              'operación segura para esa solicitud.',
        );
      } else {
        final executed = await tools.execute(call, identity);
        response = CopilotResponse(
          intent: executed.intent,
          text: executed.text,
          provider: provider,
          toolId: call.name,
          priority: executed.priority,
          sources: executed.sources,
          actions: executed.actions,
        );
      }
    } catch (caught) {
      error = caught;
      response = CopilotResponse(
        intent: 'denied_or_failed',
        provider: 'policy',
        priority: CopilotPriority.warning,
        text: _safeError(caught),
      );
    }
    await _audit(prompt, response, identity, error: error);
    return response;
  }

  Future<List<OperationalAlert>> authorizedAlerts(
    CopilotIdentity identity,
  ) async {
    final canInventory = identity.canAccess('inventory');
    final canReceivables = identity.canAccess('receivables');
    if (!canInventory && !canReceivables) return const [];
    final alerts = await _intelligence.operationalAlerts();
    return alerts
        .where((alert) {
          if (alert.kind == 'receivable') return canReceivables;
          return canInventory;
        })
        .toList(growable: false);
  }

  Future<void> auditAction({
    required CopilotActionProposal action,
    required CopilotIdentity identity,
    required String outcome,
  }) async {
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    await db.insert('conversaciones_copilot', {
      'company_id': companyId,
      'usuario': identity.userName,
      'usuario_id': identity.userId,
      'modulo': action.moduleId,
      'rol': identity.role,
      'mensaje_usuario': 'accion:${action.id}',
      'respuesta': outcome,
      'intent': 'copilot_action',
      'tool_id': action.id,
      'proveedor': 'policy',
      'resultado': outcome,
      'acciones': jsonEncode(action.arguments),
      'creada_en': DateTime.now().toIso8601String(),
    });
  }

  void _registerTools() {
    for (final spec
        in <({String id, String description, String module, String query})>[
          (
            id: 'sales_today',
            description: 'Consulta el total real de ventas emitidas hoy.',
            module: 'sales',
            query: 'ventas hoy',
          ),
          (
            id: 'sales_month',
            description: 'Consulta el total real de ventas del mes actual.',
            module: 'sales',
            query: 'ventas del mes',
          ),
          (
            id: 'critical_stock',
            description:
                'Lista productos de la empresa activa con stock crítico.',
            module: 'inventory',
            query: 'productos criticos',
          ),
          (
            id: 'expiring_products',
            description: 'Lista lotes próximos a vencer de la empresa activa.',
            module: 'inventory',
            query: 'productos por vencer',
          ),
          (
            id: 'receivables_total',
            description: 'Consulta el total real de cartera pendiente.',
            module: 'receivables',
            query: 'cartera pendiente',
          ),
          (
            id: 'payables_total',
            description: 'Consulta el total real de cuentas por pagar.',
            module: 'payables',
            query: 'cuentas por pagar',
          ),
        ]) {
      tools.register(
        CopilotToolDefinition(
          id: spec.id,
          description: spec.description,
          moduleId: spec.module,
          handler: (_, _) async {
            final reply = await _intelligence.answer(
              spec.query,
              persistConversation: false,
            );
            return CopilotResponse(
              intent: reply.intent,
              text: reply.response,
              provider: 'tool',
              toolId: spec.id,
              sources: [
                CopilotSource(
                  label: spec.description,
                  entity: spec.module,
                  asOf: DateTime.now(),
                ),
              ],
              actions: [
                CopilotActionProposal(
                  id: 'navigate.${spec.module}',
                  label: 'Abrir módulo',
                  kind: CopilotActionKind.navigate,
                  moduleId: spec.module,
                ),
              ],
            );
          },
        ),
      );
    }

    tools.register(
      CopilotToolDefinition(
        id: 'prepare_sale',
        description:
            'Prepara, sin guardar ni cobrar, una venta para un producto.',
        moduleId: 'sales',
        parameters: const {
          'product_query': {'type': 'string'},
        },
        handler: (arguments, _) async {
          final query = arguments['product_query']?.toString().trim() ?? '';
          if (query.isEmpty) {
            throw StateError('Indica qué producto deseas preparar para venta.');
          }
          final product = await _intelligence.findProduct(query);
          if (product == null) {
            throw StateError('No encontré ese producto en la empresa activa.');
          }
          return CopilotResponse(
            intent: 'prepare_sale',
            provider: 'tool',
            text:
                'Encontré ${product.name}, con existencia ${product.stock.toStringAsFixed(0)}. '
                'Puedo abrir Ventas y precargar la búsqueda; todavía no se '
                'guardará ni cobrará nada.',
            sources: [
              CopilotSource(
                label: 'Producto de la empresa activa',
                entity: 'productos',
                recordId: product.product['id']?.toString(),
                asOf: DateTime.now(),
              ),
            ],
            actions: [
              CopilotActionProposal(
                id: 'prepare.sale',
                label: 'Preparar en Ventas',
                kind: CopilotActionKind.prepareSale,
                moduleId: 'sales',
                arguments: {'query': query},
                requiresConfirmation: true,
              ),
            ],
          );
        },
      ),
    );
    tools.register(
      CopilotToolDefinition(
        id: 'prepare_purchase',
        description: 'Abre Compras para preparar una orden sin guardarla.',
        moduleId: 'purchases',
        handler: (_, _) async => const CopilotResponse(
          intent: 'prepare_purchase',
          provider: 'tool',
          text:
              'Puedo abrir Compras para preparar una orden. La orden no se '
              'creará hasta que completes los datos y confirmes en el módulo.',
          actions: [
            CopilotActionProposal(
              id: 'prepare.purchase',
              label: 'Abrir Compras',
              kind: CopilotActionKind.preparePurchase,
              moduleId: 'purchases',
              requiresConfirmation: true,
            ),
          ],
        ),
      ),
    );
  }

  void _registerNavigationTools(CopilotIdentity identity) {
    for (final moduleId in identity.allowedModuleIds) {
      final toolId =
          'open_${moduleId.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_')}';
      tools.register(
        CopilotToolDefinition(
          id: toolId,
          description:
              'Abre el modulo $moduleId si esta visible para el usuario.',
          moduleId: moduleId,
          handler: (_, _) async => CopilotResponse(
            intent: 'navigate',
            provider: 'tool',
            text: 'El modulo $moduleId esta disponible para tu rol.',
            actions: [
              CopilotActionProposal(
                id: 'navigate.$moduleId',
                label: 'Abrir modulo',
                kind: CopilotActionKind.navigate,
                moduleId: moduleId,
              ),
            ],
          ),
        ),
      );
    }
  }

  CopilotToolCall? _deterministicCall(String text) {
    if (_contains(text, ['ventas hoy', 'vendi hoy'])) {
      return const CopilotToolCall(name: 'sales_today');
    }
    if (_contains(text, ['ventas mes', 'ventas del mes', 'vendido mes'])) {
      return const CopilotToolCall(name: 'sales_month');
    }
    if (_contains(text, [
      'stock critico',
      'productos criticos',
      'bajo stock',
    ])) {
      return const CopilotToolCall(name: 'critical_stock');
    }
    if (_contains(text, ['por vencer', 'vencimiento', 'vence'])) {
      return const CopilotToolCall(name: 'expiring_products');
    }
    if (_contains(text, ['cartera', 'cobranza', 'deuda'])) {
      return const CopilotToolCall(name: 'receivables_total');
    }
    if (_contains(text, ['cuentas por pagar', 'proveedores'])) {
      return const CopilotToolCall(name: 'payables_total');
    }
    if (text.startsWith('vender ') && text.length > 7) {
      return CopilotToolCall(
        name: 'prepare_sale',
        arguments: {'product_query': text.substring(7).trim()},
      );
    }
    if (_contains(text, ['crear compra', 'orden de compra'])) {
      return const CopilotToolCall(name: 'prepare_purchase');
    }
    if (text.startsWith('abrir ')) {
      final requested = text.substring(6).trim().replaceAll(' ', '_');
      if (requested.isNotEmpty) {
        return CopilotToolCall(name: 'open_$requested');
      }
    }
    return null;
  }

  Future<void> _audit(
    String prompt,
    CopilotResponse response,
    CopilotIdentity identity, {
    Object? error,
  }) async {
    final db = await _db.database;
    final companyId = await _db.obtenerEmpresaActivaId();
    await db.insert('conversaciones_copilot', {
      'company_id': companyId,
      'usuario': identity.userName,
      'usuario_id': identity.userId,
      'modulo': 'workspace',
      'rol': identity.role,
      'mensaje_usuario': prompt,
      'respuesta': response.text,
      'intent': response.intent,
      'tool_id': response.toolId,
      'proveedor': response.provider,
      'resultado': error == null ? 'exitoso' : 'rechazado',
      'detalle_error': error?.toString(),
      'acciones': jsonEncode(
        response.actions
            .map((action) => {'id': action.id, 'module': action.moduleId})
            .toList(),
      ),
      'creada_en': DateTime.now().toIso8601String(),
    });
  }

  String _safeError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('permiso')) return text;
    if (error is StateError) return text;
    return 'No pude completar la consulta de forma segura. Revisa la '
        'configuración o intenta nuevamente.';
  }

  bool _contains(String value, List<String> patterns) =>
      patterns.any((pattern) => value.contains(pattern));

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .trim();
}

extension<T> on List<T> {
  List<T> takeLast(int count) =>
      length <= count ? this : sublist(length - count, length);
}
