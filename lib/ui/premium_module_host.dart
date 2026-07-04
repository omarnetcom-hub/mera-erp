import 'package:flutter/material.dart';

import '../features/module_definition.dart';
import '../logo_widget.dart';
import 'enterprise_design_system.dart';

class PremiumModuleHost extends StatefulWidget {
  const PremiumModuleHost({
    super.key,
    required this.module,
    required this.childBuilder,
  });

  final ModuleDefinition module;
  final WidgetBuilder childBuilder;

  @override
  State<PremiumModuleHost> createState() => _PremiumModuleHostState();
}

class _PremiumModuleHostState extends State<PremiumModuleHost> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ModuleExperienceProfile.forModule(widget.module);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.title),
        actions: [
          IconButton(
            tooltip: 'Buscar en el modulo',
            onPressed: () => setState(() => _index = 1),
            icon: const Icon(Icons.manage_search),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = EnterpriseBreakpoints.fromWidth(
            constraints.maxWidth,
          );
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  viewport.isMobile ? 12 : 18,
                  8,
                  viewport.isMobile ? 12 : 18,
                  0,
                ),
                child: _ModuleTabSelector(
                  index: _index,
                  onChanged: (value) => setState(() => _index = value),
                ),
              ),
              Expanded(
                child: _index == 0
                    ? _ModuleExecutiveView(
                        module: widget.module,
                        profile: profile,
                        viewport: viewport,
                        onOperate: () => setState(() => _index = 1),
                      )
                    : widget.childBuilder(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleTabSelector extends StatelessWidget {
  const _ModuleTabSelector({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            icon: Icon(Icons.dashboard_customize),
            label: Text('Vista ejecutiva'),
          ),
          ButtonSegment(
            value: 1,
            icon: Icon(Icons.edit_note),
            label: Text('Operacion'),
          ),
        ],
        selected: {index},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _ModuleExecutiveView extends StatelessWidget {
  const _ModuleExecutiveView({
    required this.module,
    required this.profile,
    required this.viewport,
    required this.onOperate,
  });

  final ModuleDefinition module;
  final ModuleExperienceProfile profile;
  final EnterpriseViewport viewport;
  final VoidCallback onOperate;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        viewport.isMobile ? 12 : 18,
        12,
        viewport.isMobile ? 12 : 18,
        24,
      ),
      children: [
        _PremiumModuleHeader(
          module: module,
          profile: profile,
          onOperate: onOperate,
        ),
        const SizedBox(height: EnterpriseSpacing.md),
        _KpiGrid(metrics: profile.metrics, viewport: viewport),
        const SizedBox(height: EnterpriseSpacing.md),
        if (viewport.isMobile) ...[
          _QuickActionsPanel(profile: profile, onOperate: onOperate),
          const SizedBox(height: EnterpriseSpacing.md),
          _AlertsPanel(profile: profile),
          const SizedBox(height: EnterpriseSpacing.md),
          _RecentActivityPanel(profile: profile),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _RecentActivityPanel(profile: profile),
                    const SizedBox(height: EnterpriseSpacing.md),
                    _ModuleInsightsPanel(profile: profile),
                  ],
                ),
              ),
              const SizedBox(width: EnterpriseSpacing.md),
              SizedBox(
                width: viewport == EnterpriseViewport.ultraWide ? 420 : 360,
                child: Column(
                  children: [
                    _QuickActionsPanel(profile: profile, onOperate: onOperate),
                    const SizedBox(height: EnterpriseSpacing.md),
                    _AlertsPanel(profile: profile),
                    const SizedBox(height: EnterpriseSpacing.md),
                    _FrequentAccessPanel(
                      profile: profile,
                      onOperate: onOperate,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
    return content;
  }
}

class _PremiumModuleHeader extends StatelessWidget {
  const _PremiumModuleHeader({
    required this.module,
    required this.profile,
    required this.onOperate,
  });

  final ModuleDefinition module;
  final ModuleExperienceProfile profile;
  final VoidCallback onOperate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: module.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(EnterpriseRadii.lg),
              border: Border.all(color: module.color.withValues(alpha: 0.28)),
            ),
            child: Icon(module.icon, color: module.color, size: 28),
          ),
          const SizedBox(width: EnterpriseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: EnterpriseSpacing.xs),
                Text(
                  profile.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: EnterpriseSpacing.md),
                Wrap(
                  spacing: EnterpriseSpacing.sm,
                  runSpacing: EnterpriseSpacing.sm,
                  children: [
                    EnterpriseStatusPill(
                      icon: profile.healthIcon,
                      label: profile.health,
                      color: profile.healthColor,
                    ),
                    EnterpriseStatusPill(
                      icon: Icons.sync,
                      label: 'Sync listo',
                      color: AppBrand.success,
                    ),
                    EnterpriseStatusPill(
                      icon: Icons.verified_user,
                      label: 'Auditado',
                      color: colors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EnterpriseSpacing.md),
          FilledButton.icon(
            onPressed: onOperate,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Operar'),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.metrics, required this.viewport});

  final List<ModuleKpi> metrics;
  final EnterpriseViewport viewport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = viewport.isMobile
            ? 2
            : constraints.maxWidth >= 1300
            ? 4
            : constraints.maxWidth >= 900
            ? 3
            : 2;
        final width =
            (constraints.maxWidth - ((columns - 1) * EnterpriseSpacing.sm)) /
            columns;
        return Wrap(
          spacing: EnterpriseSpacing.sm,
          runSpacing: EnterpriseSpacing.sm,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _KpiCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.metric});

  final ModuleKpi metric;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: metric.color, size: 20),
              const Spacer(),
              Icon(
                metric.trendUp ? Icons.trending_up : Icons.trending_flat,
                color: metric.trendUp ? AppBrand.success : AppBrand.muted,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: EnterpriseSpacing.xs),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({required this.profile, required this.onOperate});

  final ModuleExperienceProfile profile;
  final VoidCallback onOperate;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones rapidas',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          for (final action in profile.quickActions)
            _ActionTile(
              icon: action.icon,
              color: action.color,
              title: action.label,
              detail: action.detail,
              onTap: onOperate,
            ),
        ],
      ),
    );
  }
}

class _FrequentAccessPanel extends StatelessWidget {
  const _FrequentAccessPanel({required this.profile, required this.onOperate});

  final ModuleExperienceProfile profile;
  final VoidCallback onOperate;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos frecuentes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          Wrap(
            spacing: EnterpriseSpacing.sm,
            runSpacing: EnterpriseSpacing.sm,
            children: [
              for (final access in profile.frequentAccess)
                ActionChip(
                  avatar: Icon(access.icon, size: 16, color: access.color),
                  label: Text(access.label),
                  onPressed: onOperate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.profile});

  final ModuleExperienceProfile profile;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alertas', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: EnterpriseSpacing.sm),
          for (final alert in profile.alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
              child: Row(
                children: [
                  Icon(alert.icon, color: alert.color, size: 18),
                  const SizedBox(width: EnterpriseSpacing.sm),
                  Expanded(
                    child: Text(
                      alert.text,
                      maxLines: 2,
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

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.profile});

  final ModuleExperienceProfile profile;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividad reciente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          for (final item in profile.recentActivity)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: item.color.withValues(alpha: 0.12),
                foregroundColor: item.color,
                child: Icon(item.icon, size: 18),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                item.timeLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleInsightsPanel extends StatelessWidget {
  const _ModuleInsightsPanel({required this.profile});

  final ModuleExperienceProfile profile;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendencia operativa',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < profile.trend.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FractionallySizedBox(
                        heightFactor: profile.trend[i],
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: profile.trendColor.withValues(
                              alpha: 0.24 + (i * 0.055).clamp(0, 0.45),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          Text(profile.insight, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
      child: Material(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class ModuleExperienceProfile {
  const ModuleExperienceProfile({
    required this.summary,
    required this.health,
    required this.healthIcon,
    required this.healthColor,
    required this.metrics,
    required this.quickActions,
    required this.frequentAccess,
    required this.alerts,
    required this.recentActivity,
    required this.trend,
    required this.trendColor,
    required this.insight,
  });

  final String summary;
  final String health;
  final IconData healthIcon;
  final Color healthColor;
  final List<ModuleKpi> metrics;
  final List<ModuleAction> quickActions;
  final List<ModuleAction> frequentAccess;
  final List<ModuleAlert> alerts;
  final List<ModuleActivity> recentActivity;
  final List<double> trend;
  final Color trendColor;
  final String insight;

  static ModuleExperienceProfile forModule(ModuleDefinition module) {
    return switch (module.id) {
      'sales' => _sales(module),
      'purchases' => _purchases(module),
      'inventory' => _inventory(module),
      'cash' ||
      'receivables' ||
      'payables' ||
      'reconciliation' => _finance(module),
      'reports' ||
      'tax_reports' ||
      'financial_statements' => _reporting(module),
      'clients' || 'suppliers' => _relationship(module),
      _ => _default(module),
    };
  }

  static ModuleExperienceProfile _sales(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Gestion comercial integrada con POS, facturacion, cartera, impuestos e inventario.',
      metrics: [
        _kpi('Ventas del dia', r'$ 0', Icons.today, AppBrand.success, true),
        _kpi(
          'Ventas del mes',
          r'$ 0',
          Icons.calendar_month,
          module.color,
          true,
        ),
        _kpi(
          'Facturas pendientes',
          '0',
          Icons.pending_actions,
          AppBrand.warning,
          false,
        ),
        _kpi(
          'Ticket promedio',
          r'$ 0',
          Icons.receipt_long,
          AppBrand.info,
          true,
        ),
      ],
      quick: [
        _action(
          'Nueva venta',
          'POS, factura o documento comercial',
          Icons.point_of_sale,
          module.color,
        ),
        _action(
          'Ver cartera',
          'Saldos, promesas y pagos parciales',
          Icons.request_quote,
          AppBrand.info,
        ),
        _action(
          'Analizar ventas',
          'Tendencias por sucursal y periodo',
          Icons.insights,
          AppBrand.success,
        ),
      ],
      alerts: [
        _alert(
          'Facturas pendientes de seguimiento comercial.',
          Icons.warning_amber,
          AppBrand.warning,
        ),
        _alert(
          'Inventario y cartera se actualizan al operar.',
          Icons.sync,
          AppBrand.success,
        ),
      ],
      insight:
          'La vista comercial esta lista para operar ventas, cobros y analitica sin salir del modulo.',
    );
  }

  static ModuleExperienceProfile _purchases(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Procurement enterprise para requisiciones, ordenes, recepciones, facturas proveedor y aprobaciones.',
      metrics: [
        _kpi('Compras del mes', r'$ 0', Icons.shopping_bag, module.color, true),
        _kpi(
          'Ordenes abiertas',
          '0',
          Icons.assignment,
          AppBrand.warning,
          false,
        ),
        _kpi(
          'Recepciones pendientes',
          '0',
          Icons.local_shipping,
          AppBrand.info,
          false,
        ),
        _kpi('Aprobaciones SLA', 'OK', Icons.approval, AppBrand.success, true),
      ],
      quick: [
        _action(
          'Crear compra',
          'Orden, recepcion o factura proveedor',
          Icons.add_business,
          module.color,
        ),
        _action(
          'Aprobar orden',
          'Revisar flujos multinivel y SLA',
          Icons.approval,
          AppBrand.warning,
        ),
        _action(
          'Validar recepcion',
          'Stock y factura proveedor',
          Icons.inventory,
          AppBrand.info,
        ),
      ],
      alerts: [
        _alert(
          'Revisar recepciones parciales antes del cierre.',
          Icons.local_shipping,
          AppBrand.warning,
        ),
        _alert(
          'Las compras impactan inventario, AP e impuestos.',
          Icons.account_tree,
          AppBrand.success,
        ),
      ],
      insight:
          'Compras concentra abastecimiento, inventario y cuentas por pagar bajo control auditado.',
    );
  }

  static ModuleExperienceProfile _inventory(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Control warehouse-aware de productos, existencias, costos, rotacion y reposicion.',
      metrics: [
        _kpi('Valor inventario', r'$ 0', Icons.inventory_2, module.color, true),
        _kpi(
          'Agotados',
          '0',
          Icons.remove_shopping_cart,
          AppBrand.error,
          false,
        ),
        _kpi('Rotacion', 'Normal', Icons.autorenew, AppBrand.info, true),
        _kpi('Stock bajo', '0', Icons.trending_down, AppBrand.warning, false),
      ],
      quick: [
        _action(
          'Agregar producto',
          'Catalogo, precio, costo e impuesto',
          Icons.add_box,
          module.color,
        ),
        _action(
          'Revisar stock',
          'Existencias y alertas por bodega',
          Icons.fact_check,
          AppBrand.info,
        ),
        _action(
          'Reposicion',
          'Sugerencias y compras relacionadas',
          Icons.reorder,
          AppBrand.success,
        ),
      ],
      alerts: [
        _alert(
          'Los productos sin stock se excluyen de ventas POS.',
          Icons.info,
          AppBrand.info,
        ),
        _alert(
          'Mantener costos actualizados mejora reportes financieros.',
          Icons.account_balance,
          AppBrand.warning,
        ),
      ],
      insight:
          'Inventario se conecta con ventas, compras y contabilidad para control de margen.',
    );
  }

  static ModuleExperienceProfile _finance(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Operacion financiera para caja, bancos, cartera, pagos, conciliacion y flujo de efectivo.',
      metrics: [
        _kpi(
          'Caja actual',
          r'$ 0',
          Icons.account_balance_wallet,
          AppBrand.success,
          true,
        ),
        _kpi('Bancos', r'$ 0', Icons.account_balance, module.color, true),
        _kpi('Cartera', r'$ 0', Icons.request_quote, AppBrand.info, false),
        _kpi(
          'Cuentas por pagar',
          r'$ 0',
          Icons.payments,
          AppBrand.warning,
          false,
        ),
      ],
      quick: [
        _action(
          'Registrar movimiento',
          'Caja, bancos o transferencia',
          Icons.swap_horiz,
          module.color,
        ),
        _action(
          'Aplicar pago',
          'Cobros, pagos y conciliacion',
          Icons.payments,
          AppBrand.success,
        ),
        _action(
          'Ver vencimientos',
          'Aging y proyeccion de caja',
          Icons.schedule,
          AppBrand.warning,
        ),
      ],
      alerts: [
        _alert(
          'Revisar vencimientos y operaciones sin conciliar.',
          Icons.rule,
          AppBrand.warning,
        ),
        _alert(
          'Todo movimiento financiero genera auditoria.',
          Icons.verified_user,
          AppBrand.success,
        ),
      ],
      insight:
          'Finanzas consolida liquidez, obligaciones y trazabilidad para decisiones diarias.',
    );
  }

  static ModuleExperienceProfile _reporting(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Reporting ejecutivo con filtros, estados, fiscalidad, exportes y lectura gerencial.',
      metrics: [
        _kpi('Reportes listos', 'OK', Icons.fact_check, AppBrand.success, true),
        _kpi('Exportes', 'Excel/PDF', Icons.file_download, module.color, true),
        _kpi('Fiscal', 'Activo', Icons.gavel, AppBrand.warning, false),
        _kpi('BI-ready', 'Si', Icons.query_stats, AppBrand.info, true),
      ],
      quick: [
        _action(
          'Generar reporte',
          'Estados, fiscal o gestion',
          Icons.bar_chart,
          module.color,
        ),
        _action(
          'Exportar',
          'Excel, PDF y soporte documental',
          Icons.download,
          AppBrand.success,
        ),
        _action(
          'Filtrar datos',
          'Periodo, sucursal y centro de costo',
          Icons.filter_alt,
          AppBrand.info,
        ),
      ],
      alerts: [
        _alert(
          'Validar periodo contable antes de exportar reportes oficiales.',
          Icons.event_busy,
          AppBrand.warning,
        ),
      ],
      insight:
          'Reporting conecta operacion y finanzas para lectura ejecutiva consistente.',
    );
  }

  static ModuleExperienceProfile _relationship(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Gestion de relaciones, contactos, saldos, seguimiento y trazabilidad comercial.',
      metrics: [
        _kpi('Activos', '0', Icons.people, module.color, true),
        _kpi('Seguimientos', '0', Icons.task_alt, AppBrand.info, false),
        _kpi('Riesgo', 'Bajo', Icons.shield, AppBrand.success, true),
        _kpi('Actividad', 'Normal', Icons.timeline, AppBrand.warning, true),
      ],
      quick: [
        _action(
          'Crear registro',
          'Cliente, proveedor o contacto',
          Icons.person_add,
          module.color,
        ),
        _action(
          'Ver historial',
          'Compras, ventas, saldos y documentos',
          Icons.history,
          AppBrand.info,
        ),
        _action(
          'Seguimiento',
          'Tareas, llamadas y notas',
          Icons.event_note,
          AppBrand.success,
        ),
      ],
      alerts: [
        _alert(
          'Mantener datos fiscales completos evita errores documentales.',
          Icons.badge,
          AppBrand.warning,
        ),
      ],
      insight:
          'La informacion relacional alimenta ventas, compras, cartera y auditoria.',
    );
  }

  static ModuleExperienceProfile _default(ModuleDefinition module) {
    return _base(
      module: module,
      summary:
          'Modulo enterprise integrado a permisos, auditoria, sincronizacion y experiencia multi-dispositivo.',
      metrics: [
        _kpi('Estado', 'Activo', Icons.verified, module.color, true),
        _kpi('Auditoria', 'On', Icons.history, AppBrand.success, true),
        _kpi('Sync', 'Listo', Icons.sync, AppBrand.info, true),
        _kpi('Alertas', '0', Icons.notifications_none, AppBrand.warning, false),
      ],
      quick: [
        _action(
          'Operar modulo',
          'Abrir pantalla funcional completa',
          Icons.play_arrow,
          module.color,
        ),
        _action(
          'Revisar datos',
          'Consultar registros y estados',
          Icons.manage_search,
          AppBrand.info,
        ),
        _action(
          'Exportar soporte',
          'Reportes y evidencia operativa',
          Icons.ios_share,
          AppBrand.success,
        ),
      ],
      alerts: [
        _alert(
          'Modulo conectado a la plataforma ERP.',
          Icons.hub,
          AppBrand.info,
        ),
      ],
      insight:
          'La experiencia del modulo mantiene consistencia visual y operativa del ERP.',
    );
  }

  static ModuleExperienceProfile _base({
    required ModuleDefinition module,
    required String summary,
    required List<ModuleKpi> metrics,
    required List<ModuleAction> quick,
    required List<ModuleAlert> alerts,
    required String insight,
  }) {
    return ModuleExperienceProfile(
      summary: summary,
      health: 'Operacion saludable',
      healthIcon: Icons.health_and_safety,
      healthColor: AppBrand.success,
      metrics: metrics,
      quickActions: quick,
      frequentAccess: quick.take(3).toList(),
      alerts: alerts,
      recentActivity: [
        ModuleActivity(
          title: 'Modulo abierto',
          detail: 'Workspace ejecutivo preparado para ${module.title}.',
          timeLabel: 'Ahora',
          icon: Icons.open_in_new,
          color: module.color,
        ),
        ModuleActivity(
          title: 'Auditoria activa',
          detail: 'Las acciones sensibles conservan trazabilidad.',
          timeLabel: 'Hoy',
          icon: Icons.verified_user,
          color: AppBrand.success,
        ),
        ModuleActivity(
          title: 'Sync preparado',
          detail: 'Cambios listos para replicacion incremental.',
          timeLabel: 'Hoy',
          icon: Icons.sync,
          color: AppBrand.info,
        ),
      ],
      trend: const [0.42, 0.58, 0.48, 0.72, 0.64, 0.82, 0.76, 0.9],
      trendColor: module.color,
      insight: insight,
    );
  }

  static ModuleKpi _kpi(
    String label,
    String value,
    IconData icon,
    Color color,
    bool trendUp,
  ) {
    return ModuleKpi(
      label: label,
      value: value,
      icon: icon,
      color: color,
      trendUp: trendUp,
    );
  }

  static ModuleAction _action(
    String label,
    String detail,
    IconData icon,
    Color color,
  ) {
    return ModuleAction(label: label, detail: detail, icon: icon, color: color);
  }

  static ModuleAlert _alert(String text, IconData icon, Color color) {
    return ModuleAlert(text: text, icon: icon, color: color);
  }
}

class ModuleKpi {
  const ModuleKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trendUp,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool trendUp;
}

class ModuleAction {
  const ModuleAction({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;
}

class ModuleAlert {
  const ModuleAlert({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;
}

class ModuleActivity {
  const ModuleActivity({
    required this.title,
    required this.detail,
    required this.timeLabel,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final String timeLabel;
  final IconData icon;
  final Color color;
}
