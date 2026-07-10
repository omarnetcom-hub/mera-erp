import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sqflite/sqflite.dart';


import 'activos_fijos_page.dart';
import 'adjuntos_page.dart';
import 'app_bootstrap.dart';
import 'app_session.dart';
import 'auditoria_page.dart';
import 'bancos_page.dart';
import 'caja_page.dart';
import 'cierres_caja_page.dart';
import 'clientes_page.dart';
import 'compras_page.dart';
import 'comprobantes_page.dart';
import 'commissions_page.dart';
import 'configuracion_page.dart';
import 'contabilidad_page.dart';
import 'control_center_agent.dart';
import 'cuentas_por_cobrar_page.dart';
import 'cuentas_por_pagar_page.dart';
import 'currency_config_page.dart';
import 'db_helper.dart';
import 'empresas_page.dart';
import 'erp_readiness_page.dart';
import 'exportar_excel.dart';
import 'extracto_caja_page.dart';
import 'facturacion_electronica_page.dart';
import 'features/company_configuration_service.dart';
import 'features/feature_key.dart';
import 'features/module_definition.dart';
import 'inventario_page.dart';
import 'licensing_page.dart';
import 'login_page.dart';
import 'logo_widget.dart';
import 'manual_page.dart';
import 'nomina_page.dart';
import 'onboarding/onboarding_page.dart';
import 'platform/database_bootstrap.dart';
import 'presupuestos_page.dart';
import 'proveedores_page.dart';
import 'public_api_server.dart';
import 'recibos_page.dart';
import 'reportes_page.dart';
import 'respaldos_page.dart';
import 'services/merka_intelligence_service.dart';
import 'services/task_scheduler_service.dart';
import 'services/licencia_service.dart';
import 'templates_page.dart';
import 'usuarios_page.dart';
import 'ui/enterprise_design_system.dart';
import 'ui/sales_mode_panel.dart';
import 'ui/operations_mode_panel.dart';
import 'ui/finance_mode_panel.dart';
import 'ui/copilot_panel.dart';
import 'ventas_page.dart';
import 'warranties_page.dart';
import 'webhooks_page.dart';
import 'sync/data/sqlite_sync_repository.dart';
import 'sync/domain/sync_models.dart';
import 'services/sync_service.dart';
import 'services/hybrid_sync_service.dart';
import 'core/logging/logging_service.dart';
import 'core/features/feature_flag.dart';
import 'core/cache/cache_manager.dart';
import 'core/theme/theme_service.dart';
import 'core/dashboard/dashboard_service.dart';
import 'core/accessibility/accessibility_service.dart';
import 'pages/license_activation_page.dart';
import 'sector_publico/presupuesto/pages/presupuesto_publico_page.dart';
import 'sector_publico/presupuesto/pages/pac_tesoreria_page.dart';
import 'sector_publico/contabilidad/pages/contabilidad_nicsp_page.dart';
import 'sector_publico/contratacion/pages/contratacion_publica_page.dart';
import 'sector_publico/nomina/pages/nomina_publica_page.dart';
import 'sector_publico/rentas/pages/predial_ica_page.dart';
import 'sector_publico/planeacion/pages/planeacion_page.dart';
import 'sector_publico/activos/pages/activos_estado_page.dart';
import 'sector_publico/auditoria/pages/auditoria_forense_page.dart';
import 'sector_publico/transparencia/pages/transparencia_page.dart';

part 'ui/widgets/workspace_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await AppBootstrap.initialize(
    configureDatabase: () async {
      await configureLocalDatabaseRuntime();
      await DatabaseHelper.instance.database;
    },
    preloadTheme: _loadThemePreference,
    startServices: () async {
      try {
        ControlCenterAgent.startBackground();
      } catch (_) {}
      try {
        await PublicApiServer.start();
      } catch (_) {}
      
      // Inicializar nuevos servicios
      try {
        await LoggingService.instance.initialize();
      } catch (_) {}
      try {
        await FeatureFlagService.instance.initialize();
      } catch (_) {}
      try {
        await CacheManager.instance.initialize();
      } catch (_) {}
      try {
        await ThemeService.instance.initialize();
      } catch (_) {}
      try {
        await DashboardService.instance.initialize();
      } catch (_) {}
      try {
        await AccessibilityService.instance.initialize();
      } catch (_) {}
      try {
        await SyncService.instance.initialize();
      } catch (_) {}
      try {
        await HybridSyncService.instance.initialize();
      } catch (_) {}
      
      // Ejecutar tareas programadas al iniciar la aplicación
      try {
        final taskScheduler = TaskSchedulerService();
        final results = await taskScheduler.runPendingTasks();
        final pendingTasks = results.where((r) => r.status == 'completed').toList();
        if (pendingTasks.isNotEmpty) {
          debugPrint('Tareas ejecutadas: ${pendingTasks.map((r) => r.taskName).join(', ')}');
        }
      } catch (_) {}
    },
  );

  if (bootstrap.errors.isNotEmpty) {
    debugPrint('Bootstrap warnings: ${bootstrap.errors.join(', ')}');
  }

  runApp(const MiApp());
}

final ValueNotifier<ThemeMode> merkaThemeMode = ValueNotifier(ThemeMode.system);

Future<void> _loadThemePreference() async {
  try {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'preferencias_usuario',
      where: 'clave = ?',
      whereArgs: ['theme_mode'],
      orderBy: 'actualizado_en DESC',
      limit: 1,
    );
    if (rows.isEmpty) return;
    final value = rows.first['valor']?.toString();
    if (value == 'dark') merkaThemeMode.value = ThemeMode.dark;
    if (value == 'light') merkaThemeMode.value = ThemeMode.light;
  } catch (_) {
    merkaThemeMode.value = ThemeMode.system;
  }
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: merkaThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppBrand.name,
          theme: _merkaTheme(),
          darkTheme: _merkaTheme(brightness: Brightness.dark),
          highContrastTheme: _merkaTheme(highContrast: true),
          highContrastDarkTheme: _merkaTheme(
            brightness: Brightness.dark,
            highContrast: true,
          ),
          themeMode: mode,
          home: const LicenseCheckWrapper(),
        );
      },
    );
  }
}

class LicenseCheckWrapper extends StatefulWidget {
  const LicenseCheckWrapper({super.key});

  @override
  State<LicenseCheckWrapper> createState() => _LicenseCheckWrapperState();
}

class _LicenseCheckWrapperState extends State<LicenseCheckWrapper> {
  void _reload() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLicense(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.data == true) {
          return const LoginPage();
        } else {
          return LicenseActivationPage(onActivated: _reload);
        }
      },
    );
  }

  Future<bool> _checkLicense() async {
    try {
      final license = await LicenciaService.instance.obtenerLicencia();
      return license != null && license.estado == EstadoLicencia.activa;
    } catch (e) {
      return false;
    }
  }
}

ThemeData _merkaTheme({
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) {
  return EnterpriseThemeEngine.theme(
    brightness: brightness,
    highContrast: highContrast,
  );
}

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  late Future<void> _configurationFuture;
  final _globalSearchController = TextEditingController();
  final Set<String> _favoriteModuleIds = {
    'erp_readiness',
    'sales',
    'purchases',
  };
  final List<String> _recentModuleIds = [];
  bool _sidebarCollapsed = false;
  _WorkspaceMode _workspaceMode = _WorkspaceMode.dashboard;

  @override
  void initState() {
    super.initState();
    _configurationFuture = CompanyConfigurationService.instance.loadActive(
      force: true,
    );
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
  }

  /// Wrapper para exponer setState() al part file (workspace_widgets.dart) sin
  /// triggers de invalid_use_of_protected_member. El part accede a campos
  /// privados de State sin problemas, pero setState() requiere este wrapper
  /// porque es un miembro protegido (solo instancias de State pueden usarlo).
  void _updateState(VoidCallback fn) {
    setState(fn);
  }

  List<ModuleDefinition> _operacion() => [
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
      id: 'suppliers',
      title: 'Proveedores',
      icon: Icons.business,
      builder: (_) => const ProveedoresPage(),
      color: const Color(0xFF6A994E),
      category: ModuleCategory.operation,
      featureKey: FeatureKey.purchases,
    ),
  ];

  List<ModuleDefinition> _finanzas() => [
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

  List<ModuleDefinition> _control() => [
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

  List<ModuleDefinition> _gestion() => [
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

  List<ModuleDefinition> _visible(List<ModuleDefinition> modules) {
    return modules.where(AppSession.puedeAbrirModulo).toList();
  }

  List<ModuleDefinition> _allModules(List<_WorkspaceSection> sections) {
    return sections.expand((section) => section.modules).toList();
  }

  List<_WorkspaceSection> _filterSections(List<_WorkspaceSection> sections) {
    final query = _globalSearchController.text.toLowerCase().trim();
    if (query.isEmpty) return sections;
    return [
      for (final section in sections)
        _WorkspaceSection(
          label: section.label,
          icon: section.icon,
          modules: section.modules.where((module) {
            final haystack =
                '${module.title} ${module.id} ${_moduleSubtitle(module.id)} ${section.label}'
                    .toLowerCase();
            return haystack.contains(query);
          }).toList(),
        ),
    ];
  }

  List<ModuleDefinition> _modulesByIds(
    List<ModuleDefinition> modules,
    Iterable<String> ids,
  ) {
    final byId = {for (final module in modules) module.id: module};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  List<_WorkspaceSection> _seccionesSectorPublico() {
    return [
      _WorkspaceSection(
        label: 'Presupuesto Público',
        icon: Icons.account_balance,
        modules: _visible(_modulosPresupuestoPublico()),
      ),
      _WorkspaceSection(
        label: 'Contabilidad NICSP',
        icon: Icons.receipt_long,
        modules: _visible(_modulosContabilidadNICSP()),
      ),
      _WorkspaceSection(
        label: 'Contratación Pública',
        icon: Icons.gavel,
        modules: _visible(_modulosContratacionPublica()),
      ),
      _WorkspaceSection(
        label: 'Nómina Pública',
        icon: Icons.badge,
        modules: _visible(_modulosNominaPublica()),
      ),
      _WorkspaceSection(
        label: 'Rentas',
        icon: Icons.attach_money,
        modules: _visible(_modulosRentas()),
      ),
      _WorkspaceSection(
        label: 'Planeación',
        icon: Icons.map,
        modules: _visible(_modulosPlaneacion()),
      ),
      _WorkspaceSection(
        label: 'Activos del Estado',
        icon: Icons.factory,
        modules: _visible(_modulosActivosEstado()),
      ),
      _WorkspaceSection(
        label: 'Auditoría y Transparencia',
        icon: Icons.security,
        modules: _visible(_modulosAuditoriaTransparencia()),
      ),
    ];
  }

  List<ModuleDefinition> _modulosPresupuestoPublico() => [
    ModuleDefinition(
      id: 'presupuesto_publico',
      title: 'Presupuesto Público',
      icon: Icons.account_balance,
      color: Colors.blue,
      category: ModuleCategory.operation,
      builder: (context) => PresupuestoPublicoPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.presupuesto_publico,
    ),
    ModuleDefinition(
      id: 'pac',
      title: 'Plan Anual de Caja',
      icon: Icons.calendar_month,
      color: Colors.blue,
      category: ModuleCategory.operation,
      builder: (context) => PACTesoreriaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.presupuesto_publico,
    ),
  ];

  List<ModuleDefinition> _modulosContabilidadNICSP() => [
    ModuleDefinition(
      id: 'contabilidad_nicsp',
      title: 'Contabilidad NICSP',
      icon: Icons.receipt_long,
      color: Colors.green,
      category: ModuleCategory.accounting,
      builder: (context) => ContabilidadNICSPPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.contabilidad_nicsp,
    ),
    ModuleDefinition(
      id: 'estado_flujos_efectivo',
      title: 'Estado de Flujos de Efectivo',
      icon: Icons.trending_up,
      color: Colors.green,
      category: ModuleCategory.accounting,
      builder: (context) => ContabilidadNICSPPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.contabilidad_nicsp,
    ),
    ModuleDefinition(
      id: 'provisiones_nicsp',
      title: 'Provisiones NICSP 19',
      icon: Icons.warning,
      color: Colors.green,
      category: ModuleCategory.accounting,
      builder: (context) => ContabilidadNICSPPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.contabilidad_nicsp,
    ),
  ];

  List<ModuleDefinition> _modulosContratacionPublica() => [
    ModuleDefinition(
      id: 'contratacion_publica',
      title: 'Contratación Pública',
      icon: Icons.gavel,
      color: Colors.orange,
      category: ModuleCategory.operation,
      builder: (context) => ContratacionPublicaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.contratacion_publica,
    ),
    ModuleDefinition(
      id: 'secop_ii',
      title: 'SECOP II',
      icon: Icons.public,
      color: Colors.orange,
      category: ModuleCategory.operation,
      builder: (context) => ContratacionPublicaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.contratacion_publica,
    ),
    ModuleDefinition(
      id: 'interventoria',
      title: 'Interventoría',
      icon: Icons.assignment,
      color: Colors.orange,
      category: ModuleCategory.operation,
      builder: (context) => ContratacionPublicaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.contratacion_publica,
    ),
  ];

  List<ModuleDefinition> _modulosNominaPublica() => [
    ModuleDefinition(
      id: 'nomina_publica',
      title: 'Nómina Pública',
      icon: Icons.badge,
      color: Colors.purple,
      category: ModuleCategory.management,
      builder: (context) => NominaPublicaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.nomina_publica,
    ),
    ModuleDefinition(
      id: 'pila',
      title: 'PILA',
      icon: Icons.description,
      color: Colors.purple,
      category: ModuleCategory.management,
      builder: (context) => NominaPublicaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.nomina_publica,
    ),
    ModuleDefinition(
      id: 'horas_extra',
      title: 'Horas Extra',
      icon: Icons.schedule,
      color: Colors.purple,
      category: ModuleCategory.management,
      builder: (context) => NominaPublicaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.nomina_publica,
    ),
  ];

  List<ModuleDefinition> _modulosRentas() => [
    ModuleDefinition(
      id: 'predial',
      title: 'Predial',
      icon: Icons.home,
      color: Colors.red,
      category: ModuleCategory.operation,
      builder: (context) => PredialICAPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.predial,
    ),
    ModuleDefinition(
      id: 'ica',
      title: 'ICA',
      icon: Icons.business,
      color: Colors.red,
      category: ModuleCategory.operation,
      builder: (context) => PredialICAPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.predial,
    ),
    ModuleDefinition(
      id: 'rentas_departamentales',
      title: 'Rentas Departamentales',
      icon: Icons.directions_car,
      color: Colors.red,
      category: ModuleCategory.operation,
      builder: (context) => PredialICAPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.rentas_departamentales,
    ),
  ];

  List<ModuleDefinition> _modulosPlaneacion() => [
    ModuleDefinition(
      id: 'planeacion',
      title: 'Planeación',
      icon: Icons.map,
      color: Colors.teal,
      category: ModuleCategory.operation,
      builder: (context) => PlaneacionPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.planeacion,
    ),
    ModuleDefinition(
      id: 'mga',
      title: 'MGA',
      icon: Icons.analytics,
      color: Colors.teal,
      category: ModuleCategory.operation,
      builder: (context) => PlaneacionPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.planeacion,
    ),
    ModuleDefinition(
      id: 'pdt',
      title: 'PDT',
      icon: Icons.description,
      color: Colors.teal,
      category: ModuleCategory.operation,
      builder: (context) => PlaneacionPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.planeacion,
    ),
  ];

  List<ModuleDefinition> _modulosActivosEstado() => [
    ModuleDefinition(
      id: 'activos_estado',
      title: 'Activos del Estado',
      icon: Icons.factory,
      color: Colors.brown,
      category: ModuleCategory.accounting,
      builder: (context) => ActivosEstadoPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.activos_estado,
    ),
    ModuleDefinition(
      id: 'fut',
      title: 'FUT',
      icon: Icons.inventory,
      color: Colors.brown,
      category: ModuleCategory.accounting,
      builder: (context) => ActivosEstadoPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.activos_estado,
    ),
  ];

  List<ModuleDefinition> _modulosAuditoriaTransparencia() => [
    ModuleDefinition(
      id: 'auditoria_forense',
      title: 'Auditoría Forense',
      icon: Icons.security,
      color: Colors.indigo,
      category: ModuleCategory.control,
      builder: (context) => AuditoriaForensePage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.auditoria_forense,
    ),
    ModuleDefinition(
      id: 'chip',
      title: 'CHIP',
      icon: Icons.verified_user,
      color: Colors.indigo,
      category: ModuleCategory.control,
      builder: (context) => AuditoriaForensePage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.auditoria_forense,
    ),
    ModuleDefinition(
      id: 'transparencia',
      title: 'Transparencia',
      icon: Icons.public,
      color: Colors.indigo,
      category: ModuleCategory.control,
      builder: (context) => TransparenciaPage(
        entidadId: 'default',
        usuarioId: 'default',
      ),
      featureKey: FeatureKey.transparencia,
    ),
  ];

  void _toggleFavorite(String moduleId) {
    setState(() {
      if (_favoriteModuleIds.contains(moduleId)) {
        _favoriteModuleIds.remove(moduleId);
      } else {
        _favoriteModuleIds.add(moduleId);
      }
    });
  }

  Future<void> _toggleTheme() async {
    final next = merkaThemeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    merkaThemeMode.value = next;
    final db = await DatabaseHelper.instance.database;
    await db.insert('preferencias_usuario', {
      'usuario': AppSession.nombre,
      'clave': 'theme_mode',
      'valor': next == ThemeMode.dark ? 'dark' : 'light',
      'actualizado_en': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _openModule(BuildContext context, ModuleDefinition module) {
    if (!AppSession.puedeAbrirModulo(module)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No tienes acceso a ${module.title}.')),
      );
      return;
    }
    setState(() {
      _recentModuleIds.remove(module.id);
      _recentModuleIds.insert(0, module.id);
      if (_recentModuleIds.length > 8) {
        _recentModuleIds.removeLast();
      }
    });
    Navigator.push(context, MaterialPageRoute(builder: module.builder));
  }

  void _showCommandPalette(
    BuildContext context,
    List<ModuleDefinition> modules,
  ) {
    _showCommandPaletteDialog(this, context, modules);
  }


  Future<void> _showNotificationCenter(
    BuildContext context,
    List<ModuleDefinition> modules,
  ) async {
    final alerts = await MerkaIntelligenceService().operationalAlerts();
    if (!context.mounted) return;
    final notifications = alerts.isEmpty
        ? _notificationItems(modules)
        : [
            for (final alert in alerts)
              _NotificationItem(
                title: alert.title,
                detail: alert.detail,
                icon: alert.kind == 'expiring_product'
                    ? PhosphorIcons.timer()
                    : alert.kind == 'critical_stock'
                    ? PhosphorIcons.warningCircle()
                    : PhosphorIcons.wallet(),
                color: alert.priority == 'urgent'
                    ? const Color(0xFFEF4444)
                    : alert.priority == 'warning'
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
                module: _moduleById(
                  modules,
                  alert.kind == 'receivable' ? 'receivables' : 'inventory',
                ),
              ),
          ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Center',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: EnterpriseSpacing.md),
                  for (final item in notifications)
                    _NotificationTile(
                      item: item,
                      onTap: () {
                        Navigator.pop(context);
                        _openModule(context, item.module);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ModuleDefinition _moduleById(List<ModuleDefinition> modules, String id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return modules.first;
  }

  List<_NotificationItem> _notificationItems(List<ModuleDefinition> modules) {
    if (modules.isEmpty) return const [];

    ModuleDefinition module(String id) {
      for (final item in modules) {
        if (item.id == id) return item;
      }
      return modules.first;
    }

    _NotificationItem notification({
      required String title,
      required String detail,
      required IconData icon,
      required Color color,
      required String moduleId,
    }) {
      return _NotificationItem(
        title: title,
        detail: detail,
        icon: icon,
        color: color,
        module: module(moduleId),
      );
    }

    return [
      notification(
        title: 'Aprobaciones de compras',
        detail: 'Revisa RFQ, ordenes y recepciones con SLA activo.',
        icon: Icons.approval,
        color: AppBrand.warning,
        moduleId: 'purchases',
      ),
      notification(
        title: 'Cartera y vencimientos',
        detail: 'Consulta aging, promesas de pago y reglas de bloqueo.',
        icon: Icons.request_quote,
        color: AppBrand.info,
        moduleId: 'receivables',
      ),
      notification(
        title: 'Posicion de tesoreria',
        detail: 'Valida cash flow, bancos, conciliacion y pagos programados.',
        icon: Icons.account_balance_wallet,
        color: AppBrand.success,
        moduleId: 'erp_readiness',
      ),
      notification(
        title: 'Impuestos y reportes',
        detail: 'Revisa tax engine, reportes fiscales y materializados.',
        icon: Icons.gavel,
        color: AppBrand.error,
        moduleId: 'tax_reports',
      ),
    ];
  }

  void _showCopilot(BuildContext context, List<ModuleDefinition> modules) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 380,
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: CopilotPanel(
              onClose: () => Navigator.pop(dialogContext),
              modules: modules,
              onNavigateToModule: (moduleId) {
                final module = _moduleById(modules, moduleId);
                Navigator.pop(dialogContext);
                _openModule(context, module);
              },
              onLoadSaleProduct: (query) {
                Navigator.pop(dialogContext);
                setState(() {
                  _workspaceMode = _WorkspaceMode.sales;
                });
              },
              onLoadClientPayment: () {
                final module = _moduleById(modules, 'receivables');
                Navigator.pop(dialogContext);
                _openModule(context, module);
              },
              onLoadPurchaseOrder: () {
                final module = _moduleById(modules, 'purchases');
                Navigator.pop(dialogContext);
                _openModule(context, module);
              },
            ),
          ),
        );
      },
    );
  }

  void _showMobileQuickActions(
    BuildContext context,
    List<ModuleDefinition> modules,
  ) {
    ModuleDefinition? findModule(String id) {
      for (final module in modules) {
        if (module.id == id) return module;
      }
      return null;
    }

    void openIfAvailable(String id) {
      final module = findModule(id);
      Navigator.pop(context);
      if (module != null) {
        _openModule(context, module);
      } else {
        _showCommandPalette(context, modules);
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acciones rapidas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: EnterpriseSpacing.md),
                _MobileQuickActionTile(
                  icon: Icons.point_of_sale,
                  color: AppBrand.secondary,
                  title: 'Crear venta',
                  detail: 'POS, factura o documento comercial.',
                  onTap: () => openIfAvailable('sales'),
                ),
                _MobileQuickActionTile(
                  icon: Icons.shopping_bag,
                  color: AppBrand.success,
                  title: 'Crear compra',
                  detail: 'Orden, recepcion o factura proveedor.',
                  onTap: () => openIfAvailable('purchases'),
                ),
                _MobileQuickActionTile(
                  icon: Icons.payments,
                  color: AppBrand.warning,
                  title: 'Registrar pago',
                  detail: 'Cobros, pagos y aplicaciones parciales.',
                  onTap: () => openIfAvailable('receivables'),
                ),
                _MobileQuickActionTile(
                  icon: Icons.search,
                  color: AppBrand.info,
                  title: 'Buscar en el ERP',
                  detail: 'Clientes, compras, ventas, activos y reportes.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCommandPalette(context, modules);
                  },
                ),
                _MobileQuickActionTile(
                  icon: Icons.auto_awesome,
                  color: AppBrand.accent,
                  title: 'Preguntar al Copilot',
                  detail: 'Analisis, pendientes, alertas y acciones.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCopilot(context, modules);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCentroTrabajo(BuildContext context) {
    return _buildWorkspaceCenter(this, context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _configurationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          // Si hay error en la configuración, mostrar el menú de todos modos
          debugPrint('Error loading configuration: ${snapshot.error}');
          return _buildCentroTrabajo(context);
        }
        
        final config = CompanyConfigurationService.instance.cached;
        if (config?.onboardingCompleted == false) {
          return OnboardingPage(
            onFinished: () {
              setState(() {
                _configurationFuture = CompanyConfigurationService.instance
                    .loadActive(force: true);
              });
            },
          );
        }
        return _buildCentroTrabajo(context);
      },
    );
  }
}


