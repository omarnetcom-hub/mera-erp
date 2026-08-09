import 'package:flutter/material.dart';

import '../../features/module_definition.dart';
import '../../features/feature_key.dart';
import '../../logo_widget.dart';

import '../../caja_page.dart';
import '../../ventas_page.dart';
import '../../compras_page.dart';
import '../../inventario_page.dart';
import '../../clientes_page.dart';
import '../../proveedores_page.dart';
import '../../contabilidad_page.dart';
import '../../cuentas_por_cobrar_page.dart';
import '../../cuentas_por_pagar_page.dart';
import '../../comprobantes_page.dart';
import '../../reportes_page.dart';
import '../../extracto_caja_page.dart';
import '../../bancos_page.dart';
import '../../presupuestos_page.dart';
import '../../cierres_caja_page.dart';
import '../../erp_readiness_page.dart';
import '../../manual_page.dart';
import '../../empresas_page.dart';
import '../../facturacion_electronica_page.dart';
import '../../recibos_page.dart';
import '../../nomina_page.dart';
import '../../activos_fijos_page.dart';
import '../../adjuntos_page.dart';
import '../../usuarios_page.dart';
import '../../auditoria_page.dart';
import '../../respaldos_page.dart';
import '../../licensing_page.dart';
import '../../pages/license_activation_page.dart';
import '../../configuracion_page.dart';
import '../../currency_config_page.dart';
import '../../webhooks_page.dart';
import '../../templates_page.dart';
import '../../commissions_page.dart';
import '../../warranties_page.dart';
import '../../crm/pages/crm_pipeline_page.dart';

List<ModuleDefinition> operacion() => [
  ModuleDefinition(
    id: 'cash',
    title: 'Caja y bancos',
    icon: Icons.account_balance_wallet,
    builder: (_) => const CajaPage(),
    color: AppBrand.primary,
    category: ModuleCategory.operation,
    featureKey: FeatureKey.cash,
    permissionLabel: 'Caja',
  ),
  ModuleDefinition(
    id: 'sales',
    title: 'Ventas',
    icon: Icons.receipt_long,
    builder: (_) => const VentasPage(),
    color: const Color(0xFFE07A5F),
    category: ModuleCategory.operation,
    featureKey: FeatureKey.pos,
  ),
  ModuleDefinition(
    id: 'purchases',
    title: 'Compras',
    icon: Icons.shopping_bag,
    builder: (_) => const ComprasPage(),
    color: const Color(0xFF2A9D8F),
    category: ModuleCategory.operation,
    featureKey: FeatureKey.purchases,
  ),
  ModuleDefinition(
    id: 'inventory',
    title: 'Inventario',
    icon: Icons.inventory_2,
    builder: (_) => const InventarioPage(),
    color: const Color(0xFF457B9D),
    category: ModuleCategory.operation,
    featureKey: FeatureKey.inventory,
  ),
  ModuleDefinition(
    id: 'clients',
    title: 'Clientes',
    icon: Icons.people,
    builder: (_) => const ClientesPage(),
    color: const Color(0xFF8D5A97),
    category: ModuleCategory.operation,
    featureKey: FeatureKey.crm,
  ),
  ModuleDefinition(
    id: 'crm_pipeline',
    title: 'CRM Pipeline',
    icon: Icons.view_kanban,
    builder: (_) => const CrmPipelinePage(),
    color: const Color(0xFF264653),
    category: ModuleCategory.operation,
    featureKey: FeatureKey.crm,
  ),
  ModuleDefinition(
    id: 'suppliers',
    title: 'Proveedores',
    icon: Icons.business,
    builder: (_) => const ProveedoresPage(),
    color: const Color(0xFF6A994E),
    category: ModuleCategory.operation,
    featureKey: FeatureKey.purchases,
  ),
];

List<ModuleDefinition> finanzas() => [
  ModuleDefinition(
    id: 'accounting',
    title: 'Contabilidad',
    icon: Icons.account_balance,
    builder: (_) => const ContabilidadPage(),
    color: const Color(0xFF6D597A),
    category: ModuleCategory.accounting,
    featureKey: FeatureKey.accounting,
  ),
  ModuleDefinition(
    id: 'receivables',
    title: 'Cuentas por cobrar',
    icon: Icons.request_quote,
    builder: (_) => const CuentasPorCobrarPage(),
    color: const Color(0xFF118AB2),
    category: ModuleCategory.accounting,
    featureKey: FeatureKey.treasury,
  ),
  ModuleDefinition(
    id: 'payables',
    title: 'Cuentas por pagar',
    icon: Icons.payments,
    builder: (_) => const CuentasPorPagarPage(),
    color: const Color(0xFFB56576),
    category: ModuleCategory.accounting,
    featureKey: FeatureKey.treasury,
  ),
  ModuleDefinition(
    id: 'vouchers',
    title: 'Comprobantes',
    icon: Icons.description,
    builder: (_) => const ComprobantesPage(),
    color: const Color(0xFF5E548E),
    category: ModuleCategory.accounting,
    featureKey: FeatureKey.accounting,
  ),
];

List<ModuleDefinition> control() => [
  ModuleDefinition(
    id: 'reports',
    title: 'Reportes',
    icon: Icons.bar_chart,
    builder: (_) => const ReportesPage(),
    color: const Color(0xFF7B2CBF),
    category: ModuleCategory.control,
    featureKey: FeatureKey.reports,
  ),
  ModuleDefinition(
    id: 'cash_extract',
    title: 'Extracto caja',
    icon: Icons.receipt_long,
    builder: (_) => const ExtractoCajaPage(),
    color: const Color(0xFF457B9D),
    category: ModuleCategory.control,
    featureKey: FeatureKey.cash,
  ),
  ModuleDefinition(
    id: 'banks_catalog',
    title: 'Bancos',
    icon: Icons.account_balance,
    builder: (_) => const BancosPage(),
    color: const Color(0xFF1D3557),
    category: ModuleCategory.control,
    featureKey: FeatureKey.treasury,
  ),
  ModuleDefinition(
    id: 'budgets',
    title: 'Presupuestos',
    icon: Icons.add_chart,
    builder: (_) => const PresupuestosPage(),
    color: const Color(0xFFBB9457),
    category: ModuleCategory.control,
    featureKey: FeatureKey.projects,
  ),
  ModuleDefinition(
    id: 'cash_closings',
    title: 'Cierres caja',
    icon: Icons.lock_clock,
    builder: (_) => const CierresCajaPage(),
    color: const Color(0xFF4A5568),
    category: ModuleCategory.control,
    featureKey: FeatureKey.cash,
    permissionLabel: 'Cierres Caja',
  ),
];

List<ModuleDefinition> gestion() => [
  ModuleDefinition(
    id: 'erp_readiness',
    title: 'Centro ERP',
    icon: Icons.fact_check,
    builder: (_) => const ErpReadinessPage(),
    color: AppBrand.primary,
    category: ModuleCategory.management,
    featureKey: FeatureKey.reports,
  ),
  ModuleDefinition(
    id: 'manual',
    title: 'Manual',
    icon: Icons.menu_book,
    builder: (_) => const ManualPage(),
    color: AppBrand.primary,
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
  ),
  ModuleDefinition(
    id: 'companies',
    title: 'Empresas',
    icon: Icons.domain_add,
    builder: (_) => const EmpresasPage(),
    color: const Color(0xFF0A9396),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
  ),
  ModuleDefinition(
    id: 'electronic_invoice',
    title: 'Facturacion',
    icon: Icons.verified,
    builder: (_) => const FacturacionElectronicaPage(),
    color: const Color(0xFF2D6A4F),
    category: ModuleCategory.management,
    featureKey: FeatureKey.electronicInvoice,
  ),
  ModuleDefinition(
    id: 'receipts',
    title: 'Recibos',
    icon: Icons.receipt,
    builder: (_) => const RecibosPage(),
    color: const Color(0xFFC77DFF),
    category: ModuleCategory.management,
    featureKey: FeatureKey.documents,
  ),
  ModuleDefinition(
    id: 'payroll',
    title: 'Nomina',
    icon: Icons.badge,
    builder: (_) => const NominaPage(),
    color: const Color(0xFFF4A261),
    category: ModuleCategory.management,
    featureKey: FeatureKey.payroll,
  ),
  ModuleDefinition(
    id: 'fixed_assets',
    title: 'Activos fijos',
    icon: Icons.factory,
    builder: (_) => const ActivosFijosPage(),
    color: const Color(0xFF4361EE),
    category: ModuleCategory.management,
    featureKey: FeatureKey.fixedAssets,
  ),
  ModuleDefinition(
    id: 'attachments',
    title: 'Adjuntos',
    icon: Icons.attach_file,
    builder: (_) => const AdjuntosPage(),
    color: const Color(0xFFE76F51),
    category: ModuleCategory.management,
    featureKey: FeatureKey.documents,
  ),
  ModuleDefinition(
    id: 'users',
    title: 'Usuarios',
    icon: Icons.security,
    builder: (_) => const UsuariosPage(),
    color: const Color(0xFF495057),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
    requiresAdmin: true,
  ),
  ModuleDefinition(
    id: 'audit',
    title: 'Auditoria',
    icon: Icons.history,
    builder: (_) => const AuditoriaPage(),
    color: const Color(0xFF212529),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
  ),
  ModuleDefinition(
    id: 'backups',
    title: 'Respaldos',
    icon: Icons.backup,
    builder: (_) => const RespaldosPage(),
    color: const Color(0xFF3A86FF),
    category: ModuleCategory.management,
    featureKey: FeatureKey.documents,
    requiresAdmin: true,
  ),
  ModuleDefinition(
    id: 'licensing',
    title: 'Licencias',
    icon: Icons.vpn_key,
    builder: (_) => const LicensingPage(),
    color: const Color(0xFF2563EB),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
    requiresAdmin: true,
  ),
  ModuleDefinition(
    id: 'license_activation',
    title: 'Activar Licencia',
    icon: Icons.key,
    builder: (_) => const LicenseActivationPage(),
    color: const Color(0xFF10B981),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
  ),
  ModuleDefinition(
    id: 'settings',
    title: 'Configuracion',
    icon: Icons.settings,
    builder: (_) => const ConfiguracionPage(),
    color: const Color(0xFF6C757D),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
    requiresAdmin: true,
    permissionLabel: 'Config.',
  ),
  ModuleDefinition(
    id: 'currency_config',
    title: 'Monedas',
    icon: Icons.currency_exchange,
    builder: (_) => const CurrencyConfigPage(),
    color: const Color(0xFF2A9D8F),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
  ),
  ModuleDefinition(
    id: 'webhooks',
    title: 'Webhooks',
    icon: Icons.webhook,
    builder: (_) => const WebhooksPage(),
    color: const Color(0xFFE76F51),
    category: ModuleCategory.management,
    featureKey: FeatureKey.settings,
  ),
  ModuleDefinition(
    id: 'templates',
    title: 'Plantillas',
    icon: Icons.description,
    builder: (_) => const TemplatesPage(),
    color: const Color(0xFF457B9D),
    category: ModuleCategory.management,
    featureKey: FeatureKey.documents,
  ),
  ModuleDefinition(
    id: 'commissions',
    title: 'Comisiones',
    icon: Icons.payments,
    builder: (_) => const CommissionsPage(),
    color: const Color(0xFFE07A5F),
    category: ModuleCategory.management,
    featureKey: FeatureKey.pos,
  ),
  ModuleDefinition(
    id: 'warranties',
    title: 'Garantias',
    icon: Icons.verified_user,
    builder: (_) => const WarrantiesPage(),
    color: const Color(0xFF8D5A97),
    category: ModuleCategory.management,
    featureKey: FeatureKey.pos,
  ),
];
