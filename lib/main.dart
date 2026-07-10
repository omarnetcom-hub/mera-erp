import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sqflite/sqflite.dart';


import 'app_bootstrap.dart';
import 'app_session.dart';
import 'control_center_agent.dart';
import 'db_helper.dart';
import 'exportar_excel.dart';
import 'features/company_configuration_service.dart';
import 'features/feature_key.dart';
import 'features/module_definition.dart';
import 'login_page.dart';
import 'logo_widget.dart';
import 'onboarding/onboarding_page.dart';
import 'platform/database_bootstrap.dart';
import 'public_api_server.dart';
import 'services/merka_intelligence_service.dart';
import 'services/task_scheduler_service.dart';
import 'services/licencia_service.dart';
import 'ui/enterprise_design_system.dart';
import 'ui/sales_mode_panel.dart';
import 'ui/operations_mode_panel.dart';
import 'ui/finance_mode_panel.dart';
import 'ui/copilot_panel.dart';
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

import 'core/workspace/workspace_config.dart';
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
    await _showNotificationCenterSheet(this, context, modules);
  }



  void _showCopilot(BuildContext context, List<ModuleDefinition> modules) {
    _showCopilotDialog(this, context, modules);
  }

  void _showMobileQuickActions(
    BuildContext context,
    List<ModuleDefinition> modules,
  ) {
    _showMobileQuickActionsSheet(this, context, modules);
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


