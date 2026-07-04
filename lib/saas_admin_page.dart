import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'core/release/release_readiness.dart';
import 'db_helper.dart';
import 'licensing/application/license_policy_service.dart';
import 'licensing/domain/license_models.dart';
import 'logo_widget.dart';
import 'ui/enterprise_design_system.dart';

class SaasAdminPage extends StatefulWidget {
  const SaasAdminPage({super.key});

  @override
  State<SaasAdminPage> createState() => _SaasAdminPageState();
}

class _SaasAdminPageState extends State<SaasAdminPage> {
  late Future<_SaasAdminSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  Future<_SaasAdminSnapshot> _load() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tenant_licenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        plan_id TEXT NOT NULL,
        status TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        max_branches INTEGER NOT NULL DEFAULT 1,
        max_devices INTEGER NOT NULL DEFAULT 1,
        modules_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, plan_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS remote_support_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        session_code TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        requested_by TEXT,
        created_at TEXT NOT NULL,
        expires_at TEXT,
        closed_at TEXT
      )
    ''');
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    final existingLicenses = await db.query(
      'tenant_licenses',
      where: 'company_id = ?',
      whereArgs: [companyId],
      limit: 1,
    );
    if (existingLicenses.isEmpty) {
      final now = DateTime.now();
      await db.insert('tenant_licenses', {
        'company_id': companyId,
        'plan_id': 'enterprise-local',
        'status': 'trial',
        'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
        'max_branches': 20,
        'max_devices': 50,
        'modules_json':
            '["sales","purchases","inventory","accounting","reports","sync","workflows"]',
        'updated_at': now.toIso8601String(),
      });
    }
    final licenseRows = await db.rawQuery('''
      SELECT l.*, c.name AS company_name, c.country AS country
      FROM tenant_licenses l
      LEFT JOIN companies c ON c.id = l.company_id
      ORDER BY l.updated_at DESC
    ''');
    final supportRows = await db.query(
      'remote_support_sessions',
      orderBy: 'created_at DESC',
      limit: 20,
    );
    final licenses = licenseRows.map(_TenantControl.fromRow).toList();
    final support = supportRows.map(_SupportCase.fromRow).toList();
    final readiness = const ReleaseReadinessService().localRuntimeReport();
    return _SaasAdminSnapshot(
      tenants: licenses,
      supportCases: support,
      readiness: readiness,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _setTenantStatus(_TenantControl tenant, String status) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'tenant_licenses',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: status == 'suspended'
          ? 'SUSPENDER_TENANT_SAAS'
          : 'REACTIVAR_TENANT_SAAS',
      entidad: 'tenant_licenses',
      entidadId: tenant.id,
      detalle: '${tenant.companyName} -> $status',
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tenant.companyName}: estado $status')),
    );
  }

  Future<void> _renewTenant(_TenantControl tenant) async {
    final db = await DatabaseHelper.instance.database;
    final nextDate = DateTime.now().add(const Duration(days: 30));
    await db.update(
      'tenant_licenses',
      {
        'status': 'active',
        'expires_at': nextDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'RENOVAR_TENANT_SAAS',
      entidad: 'tenant_licenses',
      entidadId: tenant.id,
      detalle: '${tenant.companyName} renovado 30 dias',
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tenant.companyName}: renovado por 30 dias')),
    );
  }

  Future<void> _openSupportSession(_TenantControl tenant) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final code =
        'SUP-${tenant.companyId}-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final id = await db.insert('remote_support_sessions', {
      'company_id': tenant.companyId,
      'branch_id': 1,
      'session_code': code,
      'status': 'active',
      'requested_by': AppSession.nombre,
      'created_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(hours: 2)).toIso8601String(),
      'closed_at': null,
    });
    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'ABRIR_SOPORTE_REMOTO',
      entidad: 'remote_support_sessions',
      entidadId: id,
      detalle: '${tenant.companyName} - $code',
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sesion de soporte creada: $code')));
  }

  Future<void> _closeSupportCase(_SupportCase supportCase) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'remote_support_sessions',
      {'status': 'closed', 'closed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [supportCase.id],
    );
    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'CERRAR_SOPORTE_REMOTO',
      entidad: 'remote_support_sessions',
      entidadId: supportCase.id,
      detalle: supportCase.sessionCode,
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administracion SaaS'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_SaasAdminSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.requireData;
          return LayoutBuilder(
            builder: (context, constraints) {
              final viewport = EnterpriseBreakpoints.fromWidth(
                constraints.maxWidth,
              );
              final padding = viewport.isMobile ? 12.0 : 18.0;
              if (viewport.isMobile) {
                return ListView(
                  padding: EdgeInsets.all(padding),
                  children: [
                    _SaasHeader(snapshot: data),
                    const SizedBox(height: EnterpriseSpacing.md),
                    _CommercialPipeline(snapshot: data),
                    const SizedBox(height: EnterpriseSpacing.md),
                    _TenantList(
                      tenants: data.tenants,
                      onSuspend: (tenant) =>
                          _setTenantStatus(tenant, 'suspended'),
                      onReactivate: (tenant) =>
                          _setTenantStatus(tenant, 'active'),
                      onRenew: _renewTenant,
                      onSupport: _openSupportSession,
                    ),
                    const SizedBox(height: EnterpriseSpacing.md),
                    _SupportQueue(
                      supportCases: data.supportCases,
                      onClose: _closeSupportCase,
                    ),
                  ],
                );
              }
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: ListView(
                        children: [
                          _SaasHeader(snapshot: data),
                          const SizedBox(height: EnterpriseSpacing.md),
                          _TenantTable(
                            tenants: data.tenants,
                            onSuspend: (tenant) =>
                                _setTenantStatus(tenant, 'suspended'),
                            onReactivate: (tenant) =>
                                _setTenantStatus(tenant, 'active'),
                            onRenew: _renewTenant,
                            onSupport: _openSupportSession,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: EnterpriseSpacing.md),
                    SizedBox(
                      width: viewport == EnterpriseViewport.ultraWide
                          ? 420
                          : 360,
                      child: ListView(
                        children: [
                          _CommercialPipeline(snapshot: data),
                          const SizedBox(height: EnterpriseSpacing.md),
                          _SupportQueue(
                            supportCases: data.supportCases,
                            onClose: _closeSupportCase,
                          ),
                          const SizedBox(height: EnterpriseSpacing.md),
                          _ReleaseReadinessPanel(report: data.readiness),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SaasAdminSnapshot {
  const _SaasAdminSnapshot({
    required this.tenants,
    required this.supportCases,
    required this.readiness,
  });

  final List<_TenantControl> tenants;
  final List<_SupportCase> supportCases;
  final ReleaseReadinessReport readiness;

  int get suspendedTenants =>
      tenants.where((tenant) => tenant.status == 'suspended').length;

  int get activeTenants =>
      tenants.where((tenant) => tenant.status != 'suspended').length;

  int get openSupport =>
      supportCases.where((item) => item.status != 'closed').length;
}

class _TenantControl {
  const _TenantControl({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.country,
    required this.planId,
    required this.status,
    required this.expiresAt,
    required this.maxBranches,
    required this.maxDevices,
    required this.modules,
    required this.evaluation,
  });

  factory _TenantControl.fromRow(Map<String, Object?> row) {
    final modules = _decodeModules(row['modules_json']?.toString());
    final status = row['status']?.toString() ?? 'trial';
    final plan = SaaSPlan(
      id: row['plan_id']?.toString() ?? 'enterprise-local',
      name: _planName(row['plan_id']?.toString() ?? 'enterprise-local'),
      maxCompanies: 1,
      maxBranches: (row['max_branches'] as num?)?.toInt() ?? 1,
      maxDevices: (row['max_devices'] as num?)?.toInt() ?? 1,
      enabledModules: modules,
    );
    final expiresAt =
        DateTime.tryParse(row['expires_at']?.toString() ?? '') ??
        DateTime.now();
    final license = TenantLicense(
      tenantId: '${row['company_id'] ?? 0}',
      plan: plan,
      status: _licenseStatus(status),
      expiresAt: expiresAt,
      activeDevices: 1,
      activeBranches: 1,
    );
    return _TenantControl(
      id: (row['id'] as num?)?.toInt() ?? 0,
      companyId: (row['company_id'] as num?)?.toInt() ?? 0,
      companyName: row['company_name']?.toString() ?? 'Empresa local',
      country: row['country']?.toString() ?? 'Colombia',
      planId: plan.id,
      status: status,
      expiresAt: expiresAt,
      maxBranches: plan.maxBranches,
      maxDevices: plan.maxDevices,
      modules: modules,
      evaluation: const LicensePolicyService().evaluate(license),
    );
  }

  final int id;
  final int companyId;
  final String companyName;
  final String country;
  final String planId;
  final String status;
  final DateTime expiresAt;
  final int maxBranches;
  final int maxDevices;
  final Set<String> modules;
  final LicenseEvaluation evaluation;
}

class _SupportCase {
  const _SupportCase({
    required this.id,
    required this.companyId,
    required this.sessionCode,
    required this.status,
    required this.requestedBy,
    required this.createdAt,
    required this.expiresAt,
  });

  factory _SupportCase.fromRow(Map<String, Object?> row) {
    return _SupportCase(
      id: (row['id'] as num?)?.toInt() ?? 0,
      companyId: (row['company_id'] as num?)?.toInt() ?? 0,
      sessionCode: row['session_code']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
      requestedBy: row['requested_by']?.toString() ?? 'local',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
    );
  }

  final int id;
  final int companyId;
  final String sessionCode;
  final String status;
  final String requestedBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

class _SaasHeader extends StatelessWidget {
  const _SaasHeader({required this.snapshot});

  final _SaasAdminSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MerkaLogo(size: 42),
              const SizedBox(width: EnterpriseSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control comercial del software',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Licencias, soporte, renovaciones y continuidad del servicio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final width = compact
                  ? (constraints.maxWidth - EnterpriseSpacing.sm) / 2
                  : (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: EnterpriseSpacing.sm,
                runSpacing: EnterpriseSpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _AdminMetric(
                      label: 'Clientes activos',
                      value: '${snapshot.activeTenants}',
                      icon: Icons.domain,
                      color: AppBrand.success,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AdminMetric(
                      label: 'Suspendidos',
                      value: '${snapshot.suspendedTenants}',
                      icon: Icons.block,
                      color: AppBrand.error,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AdminMetric(
                      label: 'Soporte abierto',
                      value: '${snapshot.openSupport}',
                      icon: Icons.support_agent,
                      color: AppBrand.info,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AdminMetric(
                      label: 'Release',
                      value: snapshot.readiness.readyForPilot
                          ? 'Pilotable'
                          : 'Bloqueado',
                      icon: Icons.verified,
                      color: snapshot.readiness.readyForPilot
                          ? AppBrand.success
                          : AppBrand.warning,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: EnterpriseSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantTable extends StatelessWidget {
  const _TenantTable({
    required this.tenants,
    required this.onSuspend,
    required this.onReactivate,
    required this.onRenew,
    required this.onSupport,
  });

  final List<_TenantControl> tenants;
  final ValueChanged<_TenantControl> onSuspend;
  final ValueChanged<_TenantControl> onReactivate;
  final ValueChanged<_TenantControl> onRenew;
  final ValueChanged<_TenantControl> onSupport;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clientes SaaS', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EnterpriseSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Cliente')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Vence')),
                DataColumn(label: Text('Limites')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: [
                for (final tenant in tenants)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            tenant.companyName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(tenant.planId)),
                      DataCell(_LicenseStatusPill(tenant: tenant)),
                      DataCell(Text(_shortDate(tenant.expiresAt))),
                      DataCell(
                        Text(
                          '${tenant.maxBranches} sedes / ${tenant.maxDevices} equipos',
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Soporte',
                              onPressed: () => onSupport(tenant),
                              icon: const Icon(Icons.support_agent),
                            ),
                            IconButton(
                              tooltip: 'Renovar 30 dias',
                              onPressed: () => onRenew(tenant),
                              icon: const Icon(Icons.event_available),
                            ),
                            IconButton(
                              tooltip: tenant.status == 'suspended'
                                  ? 'Reactivar'
                                  : 'Suspender',
                              onPressed: tenant.status == 'suspended'
                                  ? () => onReactivate(tenant)
                                  : () => onSuspend(tenant),
                              icon: Icon(
                                tenant.status == 'suspended'
                                    ? Icons.play_circle
                                    : Icons.block,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantList extends StatelessWidget {
  const _TenantList({
    required this.tenants,
    required this.onSuspend,
    required this.onReactivate,
    required this.onRenew,
    required this.onSupport,
  });

  final List<_TenantControl> tenants;
  final ValueChanged<_TenantControl> onSuspend;
  final ValueChanged<_TenantControl> onReactivate;
  final ValueChanged<_TenantControl> onRenew;
  final ValueChanged<_TenantControl> onSupport;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clientes SaaS', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EnterpriseSpacing.sm),
          for (final tenant in tenants)
            Padding(
              padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EnterpriseRadii.md),
                ),
                child: ListTile(
                  title: Text(
                    tenant.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${tenant.planId} - vence ${_shortDate(tenant.expiresAt)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'support':
                          onSupport(tenant);
                        case 'renew':
                          onRenew(tenant);
                        case 'status':
                          tenant.status == 'suspended'
                              ? onReactivate(tenant)
                              : onSuspend(tenant);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'support',
                        child: Text('Abrir soporte'),
                      ),
                      const PopupMenuItem(
                        value: 'renew',
                        child: Text('Renovar'),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(
                          tenant.status == 'suspended'
                              ? 'Reactivar'
                              : 'Suspender',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LicenseStatusPill extends StatelessWidget {
  const _LicenseStatusPill({required this.tenant});

  final _TenantControl tenant;

  @override
  Widget build(BuildContext context) {
    final color = tenant.evaluation.allowed
        ? AppBrand.success
        : tenant.status == 'suspended'
        ? AppBrand.error
        : AppBrand.warning;
    return EnterpriseStatusPill(
      icon: tenant.evaluation.allowed ? Icons.check_circle : Icons.warning,
      label: tenant.evaluation.status.name,
      color: color,
    );
  }
}

class _CommercialPipeline extends StatelessWidget {
  const _CommercialPipeline({required this.snapshot});

  final _SaasAdminSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas y renovaciones',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          _PipelineRow(
            label: 'Leads activos',
            value: '${snapshot.tenants.length + 4}',
            color: AppBrand.info,
          ),
          _PipelineRow(
            label: 'Trials en conversion',
            value:
                '${snapshot.tenants.where((t) => t.status == 'trial').length}',
            color: AppBrand.warning,
          ),
          _PipelineRow(
            label: 'Renovaciones 30 dias',
            value:
                '${snapshot.tenants.where((t) => t.expiresAt.difference(DateTime.now()).inDays <= 30).length}',
            color: AppBrand.success,
          ),
          _PipelineRow(
            label: 'Riesgo por suspension',
            value: '${snapshot.suspendedTenants}',
            color: AppBrand.error,
          ),
        ],
      ),
    );
  }
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: EnterpriseSpacing.sm),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _SupportQueue extends StatelessWidget {
  const _SupportQueue({required this.supportCases, required this.onClose});

  final List<_SupportCase> supportCases;
  final ValueChanged<_SupportCase> onClose;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soporte tecnico',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          if (supportCases.isEmpty)
            Text(
              'No hay sesiones abiertas.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final item in supportCases.take(6))
              ListTile(
                dense: true,
                leading: Icon(
                  item.status == 'closed'
                      ? Icons.check_circle
                      : Icons.support_agent,
                  color: item.status == 'closed'
                      ? AppBrand.success
                      : AppBrand.info,
                ),
                title: Text(
                  item.sessionCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.status} - ${_shortDate(item.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: item.status == 'closed'
                    ? null
                    : IconButton(
                        tooltip: 'Cerrar soporte',
                        onPressed: () => onClose(item),
                        icon: const Icon(Icons.done),
                      ),
              ),
        ],
      ),
    );
  }
}

class _ReleaseReadinessPanel extends StatelessWidget {
  const _ReleaseReadinessPanel({required this.report});

  final ReleaseReadinessReport report;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Readiness comercial',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          for (final check in report.checks.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    check.ok ? Icons.check_circle : Icons.warning,
                    color: check.ok ? AppBrand.success : AppBrand.warning,
                    size: 18,
                  ),
                  const SizedBox(width: EnterpriseSpacing.sm),
                  Expanded(
                    child: Text(
                      check.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Set<String> _decodeModules(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const {};
    return decoded.map((item) => item.toString()).toSet();
  } on FormatException {
    return const {};
  }
}

LicenseStatus _licenseStatus(String status) {
  return switch (status) {
    'active' => LicenseStatus.active,
    'expired' => LicenseStatus.expired,
    'suspended' => LicenseStatus.suspended,
    _ => LicenseStatus.trial,
  };
}

String _planName(String planId) {
  return switch (planId) {
    'enterprise-local' => 'Enterprise Local',
    'enterprise' => 'Enterprise',
    'professional' => 'Professional',
    _ => planId,
  };
}

String _shortDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
