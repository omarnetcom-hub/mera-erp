part of '../../main.dart';

class _WorkspaceSection {
  const _WorkspaceSection({
    required this.label,
    required this.icon,
    required this.modules,
  });

  final String label;
  final IconData icon;
  final List<ModuleDefinition> modules;
}

enum _WorkspaceMode { dashboard, sales, operations, finance }

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.sections,
    required this.favoriteModules,
    required this.recentModules,
    required this.viewport,
    required this.mode,
    required this.onModeChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.favoriteIds,
    required this.onCommandPalette,
    required this.onCopilot,
    required this.onNotifications,
  });

  final List<_WorkspaceSection> sections;
  final List<ModuleDefinition> favoriteModules;
  final List<ModuleDefinition> recentModules;
  final EnterpriseViewport viewport;
  final _WorkspaceMode mode;
  final ValueChanged<_WorkspaceMode> onModeChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ModuleDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;
  final Set<String> favoriteIds;
  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    if (viewport.isMobile) {
      return _MobileWorkspace(
        sections: sections,
        favoriteModules: favoriteModules,
        recentModules: recentModules,
        searchController: searchController,
        onSearchChanged: onSearchChanged,
        onOpen: onOpen,
        onToggleFavorite: onToggleFavorite,
        favoriteIds: favoriteIds,
        onCommandPalette: onCommandPalette,
        onCopilot: onCopilot,
        onNotifications: onNotifications,
      );
    }

    return _DesktopWorkspace(
      sections: sections,
      favoriteModules: favoriteModules,
      recentModules: recentModules,
      viewport: viewport,
      mode: mode,
      onModeChanged: onModeChanged,
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      onOpen: onOpen,
      onToggleFavorite: onToggleFavorite,
      favoriteIds: favoriteIds,
      onCommandPalette: onCommandPalette,
      onCopilot: onCopilot,
      onNotifications: onNotifications,
    );
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.sections,
    required this.favoriteModules,
    required this.recentModules,
    required this.viewport,
    required this.mode,
    required this.onModeChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.favoriteIds,
    required this.onCommandPalette,
    required this.onCopilot,
    required this.onNotifications,
  });

  final List<_WorkspaceSection> sections;
  final List<ModuleDefinition> favoriteModules;
  final List<ModuleDefinition> recentModules;
  final EnterpriseViewport viewport;
  final _WorkspaceMode mode;
  final ValueChanged<_WorkspaceMode> onModeChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ModuleDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;
  final Set<String> favoriteIds;
  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final padding = viewport == EnterpriseViewport.ultraWide ? 24.0 : 16.0;
    final query = searchController.text.trim();
    final modules = sections.expand((section) => section.modules).toList();
    final searchResults = query.isEmpty
        ? const <ModuleDefinition>[]
        : modules.where((module) {
            final haystack =
                '${module.title} ${module.id} ${_moduleSubtitle(module.id)}'
                    .toLowerCase();
            return haystack.contains(query.toLowerCase());
          }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 10, padding, 12),
      child: Column(
        children: [
          _EnterpriseTopBar(
            searchController: searchController,
            mode: mode,
            onModeChanged: onModeChanged,
            favoriteModules: favoriteModules,
            recentModules: recentModules,
            onSearchChanged: onSearchChanged,
            onOpen: onOpen,
            onCommandPalette: onCommandPalette,
            onCopilot: onCopilot,
            onNotifications: onNotifications,
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          Expanded(
            child: query.isNotEmpty
                ? _DesktopSearchResults(
                    query: query,
                    modules: searchResults,
                    favoriteIds: favoriteIds,
                    onOpen: onOpen,
                    onToggleFavorite: onToggleFavorite,
                    onCommandPalette: onCommandPalette,
                  )
                : ListView(
                    children: [
                      _ModeWorkspace(
                        mode: mode,
                        modules: modules,
                        onOpen: onOpen,
                        onCommandPalette: onCommandPalette,
                        onCopilot: onCopilot,
                        onNotifications: onNotifications,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: EnterpriseSpacing.xs),
          Text(
            '${AppBrand.name} v1.0 - escritorio contable',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MobileWorkspace extends StatelessWidget {
  const _MobileWorkspace({
    required this.sections,
    required this.favoriteModules,
    required this.recentModules,
    required this.searchController,
    required this.onSearchChanged,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.favoriteIds,
    required this.onCommandPalette,
    required this.onCopilot,
    required this.onNotifications,
  });

  final List<_WorkspaceSection> sections;
  final List<ModuleDefinition> favoriteModules;
  final List<ModuleDefinition> recentModules;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ModuleDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;
  final Set<String> favoriteIds;
  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();
    final resultModules = sections
        .expand((section) => section.modules)
        .take(query.isEmpty ? 0 : 12)
        .toList();
    final primaryModules = favoriteModules.isNotEmpty
        ? favoriteModules.take(4).toList()
        : sections.expand((section) => section.modules).take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      children: [
        _MobileWorkspaceHero(
          onOpenDrawer: () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: EnterpriseSpacing.md),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar cliente, compra, venta o reporte',
            suffixIcon: query.isEmpty
                ? IconButton(
                    tooltip: 'Command Palette',
                    onPressed: onCommandPalette,
                    icon: const Icon(Icons.keyboard_command_key),
                  )
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: EnterpriseSpacing.md),
        if (query.isNotEmpty) ...[
          const _SectionHeading(label: 'Resultados', icon: Icons.manage_search),
          const SizedBox(height: EnterpriseSpacing.sm),
          if (resultModules.isEmpty)
            const _ShellEmptyState(
              icon: Icons.search_off,
              title: 'Sin resultados',
              detail: 'Prueba con ventas, compras, cartera o reportes.',
            )
          else
            for (final module in resultModules)
              Padding(
                padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
                child: _MobileModuleCard(
                  module: module,
                  favorite: favoriteIds.contains(module.id),
                  onTap: () => onOpen(module),
                  onFavorite: () => onToggleFavorite(module.id),
                ),
              ),
        ] else ...[
          _MobileActionGrid(
            onCommandPalette: onCommandPalette,
            onCopilot: onCopilot,
            onNotifications: onNotifications,
            onOpenModules: () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(height: EnterpriseSpacing.lg),
          const _SectionHeading(label: 'Favoritos', icon: Icons.star),
          const SizedBox(height: EnterpriseSpacing.sm),
          for (final module in primaryModules)
            Padding(
              padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
              child: _MobileModuleCard(
                module: module,
                favorite: favoriteIds.contains(module.id),
                onTap: () => onOpen(module),
                onFavorite: () => onToggleFavorite(module.id),
              ),
            ),
          if (recentModules.isNotEmpty) ...[
            const SizedBox(height: EnterpriseSpacing.md),
            const _SectionHeading(label: 'Recientes', icon: Icons.history),
            const SizedBox(height: EnterpriseSpacing.sm),
            for (final module in recentModules.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
                child: _MobileModuleCard(
                  module: module,
                  favorite: favoriteIds.contains(module.id),
                  onTap: () => onOpen(module),
                  onFavorite: () => onToggleFavorite(module.id),
                ),
              ),
          ],
          const SizedBox(height: EnterpriseSpacing.md),
          _MobileAttentionPanel(
            onNotifications: onNotifications,
            onCopilot: onCopilot,
          ),
        ],
      ],
    );
  }
}

class _MobileWorkspaceHero extends StatelessWidget {
  const _MobileWorkspaceHero({required this.onOpenDrawer});

  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final company = CompanyConfigurationService.instance.cached?.companyName;
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MerkaLogo(size: 34),
              const SizedBox(width: EnterpriseSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${AppSession.nombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      company ?? 'Tenant local',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Modulos',
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu_open),
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          Wrap(
            spacing: EnterpriseSpacing.sm,
            runSpacing: EnterpriseSpacing.sm,
            children: [
              EnterpriseStatusPill(
                icon: Icons.approval,
                label: 'Aprobaciones',
                color: AppBrand.warning,
              ),
              EnterpriseStatusPill(
                icon: Icons.sync,
                label: 'Sync local',
                color: AppBrand.success,
              ),
              EnterpriseStatusPill(
                icon: Icons.auto_awesome,
                label: 'Copilot listo',
                color: AppBrand.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileActionGrid extends StatelessWidget {
  const _MobileActionGrid({
    required this.onCommandPalette,
    required this.onCopilot,
    required this.onNotifications,
    required this.onOpenModules,
  });

  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;
  final VoidCallback onNotifications;
  final VoidCallback onOpenModules;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: EnterpriseSpacing.sm,
      mainAxisSpacing: EnterpriseSpacing.sm,
      childAspectRatio: 1.72,
      children: [
        _MobileActionButton(
          icon: Icons.search,
          label: 'Buscar',
          color: AppBrand.secondary,
          onTap: onCommandPalette,
        ),
        _MobileActionButton(
          icon: Icons.auto_awesome,
          label: 'Copilot',
          color: AppBrand.accent,
          onTap: onCopilot,
        ),
        _MobileActionButton(
          icon: Icons.notifications_none,
          label: 'Alertas',
          color: AppBrand.warning,
          onTap: onNotifications,
        ),
        _MobileActionButton(
          icon: Icons.apps,
          label: 'Modulos',
          color: AppBrand.success,
          onTap: onOpenModules,
        ),
      ],
    );
  }
}

class _MobileActionButton extends StatelessWidget {
  const _MobileActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(EnterpriseSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: EnterpriseSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileAttentionPanel extends StatelessWidget {
  const _MobileAttentionPanel({
    required this.onNotifications,
    required this.onCopilot,
  });

  final VoidCallback onNotifications;
  final VoidCallback onCopilot;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para revisar hoy',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          _MobileQuickActionTile(
            icon: Icons.schedule,
            color: AppBrand.warning,
            title: 'Vencimientos y aprobaciones',
            detail: 'Pagos, cartera, impuestos y escalaciones.',
            onTap: onNotifications,
          ),
          _MobileQuickActionTile(
            icon: Icons.insights,
            color: AppBrand.info,
            title: 'Pedir resumen operativo',
            detail: 'Copilot puede resumir flujo de caja y pendientes.',
            onTap: onCopilot,
          ),
        ],
      ),
    );
  }
}

class _MobileQuickActionTile extends StatelessWidget {
  const _MobileQuickActionTile({
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
          side: BorderSide(color: color.withValues(alpha: 0.24)),
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AccountingCommandCenter extends StatelessWidget {
  const _AccountingCommandCenter({
    required this.modules,
    required this.onOpen,
    required this.onCommandPalette,
    required this.onCopilot,
  });

  final List<ModuleDefinition> modules;
  final ValueChanged<ModuleDefinition> onOpen;
  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;

  ModuleDefinition? _find(String id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final company = CompanyConfigurationService.instance.cached?.companyName;
    return EnterprisePanel(
      padding: const EdgeInsets.all(EnterpriseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de trabajo contable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: EnterpriseSpacing.xs),
                    Text(
                      '${company ?? 'Tenant local'} - sesion ${AppSession.nombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCommandPalette,
                icon: const Icon(Icons.keyboard_command_key),
                label: const Text('Comando'),
              ),
              const SizedBox(width: EnterpriseSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Copilot',
                onPressed: onCopilot,
                icon: const Icon(Icons.auto_awesome),
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          Text(
            'Acciones principales',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: EnterpriseSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = width >= 900
                  ? (width - 32) / 5
                  : width >= 620
                  ? (width - 16) / 3
                  : width;
              final workflows = <_DesktopWorkflow>[
                _DesktopWorkflow(
                  title: 'Vender',
                  detail: 'Factura, POS y cartera',
                  icon: Icons.point_of_sale,
                  color: AppBrand.secondary,
                  module: _find('sales'),
                ),
                _DesktopWorkflow(
                  title: 'Comprar',
                  detail: 'Orden, recepcion y AP',
                  icon: Icons.shopping_bag,
                  color: AppBrand.success,
                  module: _find('purchases'),
                ),
                _DesktopWorkflow(
                  title: 'Cobrar',
                  detail: 'Aplicar pagos y aging',
                  icon: Icons.request_quote,
                  color: AppBrand.info,
                  module: _find('receivables'),
                ),
                _DesktopWorkflow(
                  title: 'Pagar',
                  detail: 'Agenda y tesoreria',
                  icon: Icons.payments,
                  color: AppBrand.warning,
                  module: _find('payables'),
                ),
                _DesktopWorkflow(
                  title: 'Reportar',
                  detail: 'BI, fiscal y exportes',
                  icon: Icons.bar_chart,
                  color: const Color(0xFF7B2CBF),
                  module: _find('reports'),
                ),
              ];
              return Wrap(
                spacing: EnterpriseSpacing.sm,
                runSpacing: EnterpriseSpacing.sm,
                children: [
                  for (final workflow in workflows)
                    SizedBox(
                      width: itemWidth,
                      child: _DesktopWorkflowButton(
                        workflow: workflow,
                        onOpen: onOpen,
                        onFallback: onCommandPalette,
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

class _DesktopWorkflow {
  const _DesktopWorkflow({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.module,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final ModuleDefinition? module;
}

class _DesktopWorkflowButton extends StatelessWidget {
  const _DesktopWorkflowButton({
    required this.workflow,
    required this.onOpen,
    required this.onFallback,
  });

  final _DesktopWorkflow workflow;
  final ValueChanged<ModuleDefinition> onOpen;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.42),
        ),
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        onTap: () {
          final module = workflow.module;
          if (module == null) {
            onFallback();
          } else {
            onOpen(module);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(EnterpriseSpacing.md),
          child: Row(
            children: [
              Icon(workflow.icon, color: workflow.color, size: 22),
              const SizedBox(width: EnterpriseSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workflow.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      workflow.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopModuleDirectory extends StatelessWidget {
  const _DesktopModuleDirectory({
    required this.sections,
    required this.favoriteIds,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final List<_WorkspaceSection> sections;
  final Set<String> favoriteIds;
  final ValueChanged<ModuleDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Directorio de areas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                'Usa el sidebar para abrir todo',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980 ? 2 : 1;
              final width =
                  (constraints.maxWidth -
                      (columns - 1) * EnterpriseSpacing.sm) /
                  columns;
              return Wrap(
                spacing: EnterpriseSpacing.sm,
                runSpacing: EnterpriseSpacing.sm,
                children: [
                  for (final section in sections)
                    SizedBox(
                      width: width,
                      child: _DesktopModuleGroup(
                        section: section,
                        favoriteIds: favoriteIds,
                        onOpen: onOpen,
                        onToggleFavorite: onToggleFavorite,
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

class _DesktopModuleGroup extends StatelessWidget {
  const _DesktopModuleGroup({
    required this.section,
    required this.favoriteIds,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final _WorkspaceSection section;
  final Set<String> favoriteIds;
  final ValueChanged<ModuleDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: section.label == 'Operacion',
      leading: Icon(
        section.icon,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: Text(section.label),
      subtitle: Text('${section.modules.length} modulos disponibles'),
      children: [
        for (final module in section.modules)
          ListTile(
            dense: true,
            leading: Icon(module.icon, color: module.color, size: 20),
            title: Text(
              module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _moduleSubtitle(module.id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: favoriteIds.contains(module.id)
                  ? 'Quitar favorito'
                  : 'Favorito',
              onPressed: () => onToggleFavorite(module.id),
              icon: Icon(
                favoriteIds.contains(module.id)
                    ? Icons.star
                    : Icons.star_border,
                color: favoriteIds.contains(module.id)
                    ? AppBrand.warning
                    : AppBrand.muted,
              ),
            ),
            onTap: () => onOpen(module),
          ),
      ],
    );
  }
}

class _DesktopSearchResults extends StatelessWidget {
  const _DesktopSearchResults({
    required this.query,
    required this.modules,
    required this.favoriteIds,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onCommandPalette,
  });

  final String query;
  final List<ModuleDefinition> modules;
  final Set<String> favoriteIds;
  final ValueChanged<ModuleDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onCommandPalette;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Resultados para "$query"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onCommandPalette,
                icon: const Icon(Icons.keyboard_command_key),
                label: const Text('Paleta'),
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          Expanded(
            child: modules.isEmpty
                ? const _ShellEmptyState(
                    icon: Icons.search_off,
                    title: 'Sin resultados',
                    detail: 'Prueba con ventas, cartera, bancos o soporte.',
                  )
                : ListView.separated(
                    itemCount: modules.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final module = modules[index];
                      return ListTile(
                        leading: Icon(module.icon, color: module.color),
                        title: Text(module.title),
                        subtitle: Text(
                          _moduleSubtitle(module.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: favoriteIds.contains(module.id)
                              ? 'Quitar favorito'
                              : 'Favorito',
                          onPressed: () => onToggleFavorite(module.id),
                          icon: Icon(
                            favoriteIds.contains(module.id)
                                ? Icons.star
                                : Icons.star_border,
                          ),
                        ),
                        onTap: () => onOpen(module),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceModeSelector extends StatelessWidget {
  const _WorkspaceModeSelector({required this.mode, required this.onChanged});

  final _WorkspaceMode mode;
  final ValueChanged<_WorkspaceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_WorkspaceMode.dashboard, PhosphorIcons.house(), 'Dashboard'),
      (_WorkspaceMode.sales, PhosphorIcons.shoppingCart(), 'Ventas'),
      (_WorkspaceMode.operations, PhosphorIcons.cube(), 'Operaciones'),
      (_WorkspaceMode.finance, PhosphorIcons.chartBar(), 'Finanzas'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                avatar: Icon(
                  item.$2,
                  size: 16,
                  color: item.$1 == mode
                      ? Colors.white
                      : const Color(0xFF4B5563),
                ),
                label: Text(item.$3),
                selected: item.$1 == mode,
                showCheckmark: false,
                selectedColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(
                  color: item.$1 == mode
                      ? Colors.white
                      : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeWorkspace extends StatelessWidget {
  const _ModeWorkspace({
    required this.mode,
    required this.modules,
    required this.onOpen,
    required this.onCommandPalette,
    required this.onCopilot,
    required this.onNotifications,
  });

  final _WorkspaceMode mode;
  final List<ModuleDefinition> modules;
  final ValueChanged<ModuleDefinition> onOpen;
  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    ModuleDefinition? find(String id) {
      for (final module in modules) {
        if (module.id == id) return module;
      }
      return null;
    }

    switch (mode) {
      case _WorkspaceMode.dashboard:
        return _DashboardModePanel(
          onNotifications: onNotifications,
          onCopilot: onCopilot,
        );
      case _WorkspaceMode.sales:
        return SalesModePanel(
          onCopilot: onCopilot,
        );
      case _WorkspaceMode.operations:
        return OperationsModePanel(
          onOpenInventory: () {
            final module = find('inventory');
            if (module != null) onOpen(module);
          },
          onOpenPurchases: () {
            final module = find('purchases');
            if (module != null) onOpen(module);
          },
          onNotifications: onNotifications,
        );
      case _WorkspaceMode.finance:
        return FinanceModePanel(
          onOpenReceivables: () {
            final module = find('receivables');
            if (module != null) onOpen(module);
          },
          onOpenPayables: () {
            final module = find('payables');
            if (module != null) onOpen(module);
          },
          onOpenCash: () {
            final module = find('cash');
            if (module != null) onOpen(module);
          },
          onCommandPalette: onCommandPalette,
        );
    }
  }
}

class _DashboardModePanel extends StatefulWidget {
  const _DashboardModePanel({
    required this.onNotifications,
    required this.onCopilot,
  });

  final VoidCallback onNotifications;
  final VoidCallback onCopilot;

  @override
  State<_DashboardModePanel> createState() => _DashboardModePanelState();
}

class _DashboardModePanelState extends State<_DashboardModePanel> {
  static const _allKpis = {
    'sales': 'Ventas hoy',
    'stock': 'Stock critico',
    'receivables': 'Cartera vencida',
    'cash': 'Flujo de caja',
  };

  Set<String> _visibleKpis = _allKpis.keys.toSet();

  @override
  void initState() {
    super.initState();
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _loadVisibleKpis();
    }
  }

  Future<void> _loadVisibleKpis() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'preferencias_usuario',
      where: 'usuario = ? AND clave = ?',
      whereArgs: [AppSession.nombre, 'dashboard_widgets'],
      limit: 1,
    );
    if (!mounted || rows.isEmpty) return;
    final values = rows.first['valor']
        ?.toString()
        .split(',')
        .where(_allKpis.containsKey)
        .toSet();
    if (values == null || values.isEmpty) return;
    setState(() => _visibleKpis = values);
  }

  Future<void> _toggleKpi(String key) async {
    final next = {..._visibleKpis};
    if (next.contains(key)) {
      if (next.length == 1) return;
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() => _visibleKpis = next);
    final db = await DatabaseHelper.instance.database;
    await db.insert('preferencias_usuario', {
      'usuario': AppSession.nombre,
      'clave': 'dashboard_widgets',
      'valor': next.join(','),
      'actualizado_en': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: MerkaIntelligenceService().dashboardSnapshot(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return EnterprisePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeHeader(
                icon: PhosphorIcons.house(),
                title: 'Dashboard',
                detail:
                    'Vista ejecutiva con ventas, inventario, cartera y flujo de caja.',
              ),
              const SizedBox(height: 16),
              if (data == null)
                const LinearProgressIndicator()
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _allKpis.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _visibleKpis.contains(entry.key),
                        onSelected: (_) => _toggleKpi(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (_visibleKpis.contains('sales'))
                      _DashboardKpi(
                        label: 'Ventas hoy',
                        value: _moneyCompact(data.salesToday),
                        icon: PhosphorIcons.shoppingCart(),
                        color: const Color(0xFF2563EB),
                      ),
                    if (_visibleKpis.contains('stock'))
                      _DashboardKpi(
                        label: 'Stock critico',
                        value: '${data.criticalStock}',
                        icon: PhosphorIcons.warningCircle(),
                        color: const Color(0xFFEF4444),
                      ),
                    if (_visibleKpis.contains('receivables'))
                      _DashboardKpi(
                        label: 'Cartera vencida',
                        value: _moneyCompact(data.overdueReceivables),
                        icon: PhosphorIcons.wallet(),
                        color: const Color(0xFFF59E0B),
                      ),
                    if (_visibleKpis.contains('cash'))
                      _DashboardKpi(
                        label: 'Flujo de caja',
                        value: _moneyCompact(data.cashFlow),
                        icon: PhosphorIcons.coins(),
                        color: const Color(0xFF10B981),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final charts = [
                      _MiniChartPanel(
                        title: 'Ventas ultimos 7 dias',
                        values: data.salesLast7Days,
                        color: const Color(0xFF2563EB),
                      ),
                      _MiniChartPanel(
                        title: 'Ingresos vs gastos del mes',
                        values: [data.incomeMonth, data.expenseMonth],
                        color: const Color(0xFF10B981),
                        secondColor: const Color(0xFFEF4444),
                      ),
                    ];
                    return compact
                        ? Column(
                            children: [
                              charts[0],
                              const SizedBox(height: 12),
                              charts[1],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: charts[0]),
                              const SizedBox(width: 12),
                              Expanded(child: charts[1]),
                            ],
                          );
                  },
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Acciones principales',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                    _ModeAction(
                      icon: PhosphorIcons.bell(),
                      label: 'Ver alertas',
                      color: const Color(0xFFF59E0B),
                      onTap: widget.onNotifications,
                    ),
                    _ModeAction(
                      icon: PhosphorIcons.brain(),
                      label: 'Preguntar al Copilot',
                      color: const Color(0xFF2563EB),
                      onTap: widget.onCopilot,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeHeader extends StatelessWidget {
  const _ModeHeader({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeAction extends StatelessWidget {
  const _ModeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

class _DashboardKpi extends StatelessWidget {
  const _DashboardKpi({
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
    return SizedBox(
      width: 210,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChartPanel extends StatelessWidget {
  const _MiniChartPanel({
    required this.title,
    required this.values,
    required this.color,
    this.secondColor,
  });

  final String title;
  final List<double> values;
  final Color color;
  final Color? secondColor;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(
      1,
      (max, item) => item > max ? item : max,
    );
    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FractionallySizedBox(
                        heightFactor: (values[i] / maxValue).clamp(0.05, 1),
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i == 1 && secondColor != null
                                ? secondColor
                                : color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
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

String _moneyCompact(double value) {
  final rounded = value.round().toString();
  return '\$${rounded.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

class _EnterpriseTopBar extends StatelessWidget {
  const _EnterpriseTopBar({
    required this.searchController,
    required this.mode,
    required this.onModeChanged,
    required this.favoriteModules,
    required this.recentModules,
    required this.onSearchChanged,
    required this.onOpen,
    required this.onCommandPalette,
    required this.onCopilot,
    required this.onNotifications,
  });

  final TextEditingController searchController;
  final _WorkspaceMode mode;
  final ValueChanged<_WorkspaceMode> onModeChanged;
  final List<ModuleDefinition> favoriteModules;
  final List<ModuleDefinition> recentModules;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ModuleDefinition> onOpen;
  final VoidCallback onCommandPalette;
  final VoidCallback onCopilot;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final company = CompanyConfigurationService.instance.cached?.companyName;
    return EnterprisePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Wrap(
            spacing: EnterpriseSpacing.md,
            runSpacing: EnterpriseSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de trabajo contable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: EnterpriseSpacing.xs),
                    Text(
                      company == null ? 'Tenant local' : 'Tenant: $company',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 360,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search global',
                    suffixIcon: searchController.text.isEmpty
                        ? IconButton(
                            tooltip: 'Abrir Command Palette',
                            onPressed: onCommandPalette,
                            icon: const Icon(Icons.keyboard_command_key),
                          )
                        : IconButton(
                            tooltip: 'Limpiar busqueda',
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              _WorkspaceModeSelector(mode: mode, onChanged: onModeChanged),
              const _SyncIndicator(),
              _TopBarButton(
                icon: Icons.keyboard_command_key,
                label: 'Comandos',
                onTap: onCommandPalette,
              ),
              _TopBarButton(
                icon: Icons.auto_awesome,
                label: 'Copilot',
                onTap: onCopilot,
              ),
              _TopBarButton(
                icon: Icons.notifications_none,
                label: 'Alertas',
                onTap: onNotifications,
              ),
              if (!compact)
                _MiniModuleRail(
                  label: 'Recientes',
                  modules: recentModules,
                  fallback: favoriteModules,
                  onOpen: onOpen,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SyncIndicator extends StatefulWidget {
  const _SyncIndicator();

  @override
  State<_SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<_SyncIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _repository = const SqliteSyncRepository();
  SyncStatusSnapshot? _snapshot;
  bool _isSyncing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _loadStatus();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadStatus());
    } else {
      _snapshot = const SyncStatusSnapshot(
        pendingOutbox: 0,
        pendingInbox: 0,
        conflicts: 0,
        lastPushAt: null,
        lastPullAt: null,
        online: true,
      );
    }
  }

  Future<void> _loadStatus() async {
    try {
      final snap = await _repository.status();
      if (mounted) {
        setState(() {
          _snapshot = snap;
        });
      }
    } catch (_) {
      // Ignore database initialization timing issues
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _forceSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });
    // Simulate push/pull action (or call real orchestrator if any)
    await Future.delayed(const Duration(seconds: 2));
    await _loadStatus();
    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    final hasConflicts = snap != null && snap.conflicts > 0;
    final hasPending = snap != null && snap.pendingOutbox > 0;

    Color color;
    IconData icon;
    String text;

    if (_isSyncing) {
      color = Colors.blue;
      icon = Icons.sync;
      text = 'Sincronizando...';
    } else if (hasConflicts) {
      color = Colors.red;
      icon = Icons.warning;
      text = 'Conflictos (${snap.conflicts})';
    } else if (hasPending) {
      color = Colors.orange;
      icon = Icons.cloud_queue;
      text = 'Pendientes (${snap.pendingOutbox})';
    } else {
      color = Colors.green;
      icon = Icons.cloud_done;
      text = 'Offline-First Activo';
    }

    return InkWell(
      onTap: _forceSync,
      borderRadius: BorderRadius.circular(EnterpriseSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(EnterpriseSpacing.sm),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isSyncing
                ? AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Icon(
                        icon,
                        size: 16,
                        color: Color.lerp(color, color.withValues(alpha: 0.3), _controller.value),
                      );
                    },
                  )
                : Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniModuleRail extends StatelessWidget {
  const _MiniModuleRail({
    required this.label,
    required this.modules,
    required this.fallback,
    required this.onOpen,
  });

  final String label;
  final List<ModuleDefinition> modules;
  final List<ModuleDefinition> fallback;
  final ValueChanged<ModuleDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = modules.isEmpty ? fallback : modules;
    if (items.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Wrap(
        spacing: EnterpriseSpacing.sm,
        runSpacing: EnterpriseSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          for (final module in items.take(3))
            ActionChip(
              avatar: Icon(module.icon, size: 16, color: module.color),
              label: Text(module.title, overflow: TextOverflow.ellipsis),
              onPressed: () => onOpen(module),
            ),
        ],
      ),
    );
  }
}

class _EnterpriseSidebar extends StatelessWidget {
  const _EnterpriseSidebar({
    required this.sections,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onOpen,
  });

  final List<_WorkspaceSection> sections;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<ModuleDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 74.0 : 264.0;
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      margin: const EdgeInsets.fromLTRB(12, 10, 0, 12),
      padding: const EdgeInsets.all(EnterpriseSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(EnterpriseRadii.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const MerkaLogo(size: 34),
              if (!collapsed) ...[
                const SizedBox(width: EnterpriseSpacing.sm),
                Expanded(
                  child: Text(
                    'Workspace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
              IconButton(
                tooltip: collapsed ? 'Expandir sidebar' : 'Colapsar sidebar',
                onPressed: onToggleCollapsed,
                icon: Icon(
                  collapsed ? Icons.chevron_right : Icons.chevron_left,
                ),
              ),
            ],
          ),
          const SizedBox(height: EnterpriseSpacing.md),
          Expanded(
            child: ListView(
              children: [
                for (final section in sections) ...[
                  _SidebarGroupLabel(
                    label: section.label,
                    collapsed: collapsed,
                  ),
                  for (final module in section.modules)
                    _SidebarModuleButton(
                      module: module,
                      collapsed: collapsed,
                      onTap: () => onOpen(module),
                    ),
                  const SizedBox(height: EnterpriseSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileModuleDrawer extends StatelessWidget {
  const _MobileModuleDrawer({
    required this.sections,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onOpen,
    required this.onLogout,
  });

  final List<_WorkspaceSection> sections;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<ModuleDefinition> onOpen;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final company = CompanyConfigurationService.instance.cached?.companyName;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(EnterpriseSpacing.lg),
              child: Row(
                children: [
                  const MerkaLogo(size: 38),
                  const SizedBox(width: EnterpriseSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppBrand.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          company ?? 'Tenant local',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final section in sections) ...[
                    _SidebarGroupLabel(label: section.label, collapsed: false),
                    for (final module in section.modules)
                      _MobileDrawerModuleTile(
                        module: module,
                        favorite: favoriteIds.contains(module.id),
                        onFavorite: () => onToggleFavorite(module.id),
                        onOpen: () {
                          Navigator.pop(context);
                          onOpen(module);
                        },
                      ),
                    const SizedBox(height: EnterpriseSpacing.sm),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(EnterpriseSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesion'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawerModuleTile extends StatelessWidget {
  const _MobileDrawerModuleTile({
    required this.module,
    required this.favorite,
    required this.onFavorite,
    required this.onOpen,
  });

  final ModuleDefinition module;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(module.icon, color: module.color, size: 20),
      title: Text(
        module.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _moduleSubtitle(module.id),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: favorite ? 'Quitar favorito' : 'Favorito',
        onPressed: onFavorite,
        icon: Icon(
          favorite ? Icons.star : Icons.star_border,
          color: favorite ? AppBrand.warning : AppBrand.muted,
        ),
      ),
      onTap: onOpen,
    );
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel({required this.label, required this.collapsed});

  final String label;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) return const SizedBox(height: EnterpriseSpacing.sm);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _SidebarModuleButton extends StatelessWidget {
  const _SidebarModuleButton({
    required this.module,
    required this.collapsed,
    required this.onTap,
  });

  final ModuleDefinition module;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: module.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Icon(module.icon, size: 19, color: module.color),
              if (!collapsed) ...[
                const SizedBox(width: EnterpriseSpacing.sm),
                Expanded(
                  child: Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: EnterpriseSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _MobileModuleCard extends StatelessWidget {
  const _MobileModuleCard({
    required this.module,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });

  final ModuleDefinition module;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outline.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(EnterpriseSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EnterpriseRadii.md),
                ),
                child: Icon(module.icon, color: module.color),
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
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: EnterpriseSpacing.xs),
                    Text(
                      _moduleSubtitle(module.id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite ? 'Quitar de favoritos' : 'Favorito',
                onPressed: onFavorite,
                icon: Icon(
                  favorite ? Icons.star : Icons.star_border,
                  color: favorite ? AppBrand.warning : AppBrand.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellEmptyState extends StatelessWidget {
  const _ShellEmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: EnterpriseSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: EnterpriseSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCommand {
  const _WorkspaceCommand({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.module,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final ModuleDefinition module;
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.module,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final ModuleDefinition module;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final _NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EnterpriseSpacing.sm),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.55),
          ),
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
        child: ListTile(
          minVerticalPadding: EnterpriseSpacing.md,
          leading: CircleAvatar(
            backgroundColor: item.color.withValues(alpha: 0.12),
            foregroundColor: item.color,
            child: Icon(item.icon),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            item.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

String _moduleSubtitle(String moduleId) {
  return switch (moduleId) {
    'cash' => 'Tesoreria operativa, cierres y movimientos de caja.',
    'sales' => 'Cotizaciones, pedidos, POS, facturacion y cartera.',
    'purchases' => 'Requisiciones, RFQ, ordenes, recepciones y facturas.',
    'inventory' => 'Stock, bodegas, reservas y movimientos warehouse-aware.',
    'clients' => 'CRM, clientes, riesgos, actividades y seguimiento.',
    'suppliers' => 'Proveedores, balances, documentos y condiciones.',
    'accounting' => 'Diario, mayor, politicas contables y cierres.',
    'receivables' => 'Aging, cobros, promesas, limites y bloqueos.',
    'payables' => 'Programacion de pagos, matching y cash forecasting.',
    'vouchers' => 'Comprobantes, trazabilidad y soporte documental.',
    'periods' => 'Periodos contables, bloqueos y gobierno financiero.',
    'financial_statements' => 'Balance, PYG, flujo y reportes oficiales.',
    'reports' => 'BI-ready reporting, filtros, exports y dashboards.',
    'tax_reports' => 'Tax engine, retenciones, exenciones y reportes fiscales.',
    'reconciliation' => 'Conciliacion bancaria, matching y auditoria.',
    'bank_statements' => 'Importacion de extractos y movimientos bancarios.',
    'budgets' => 'Presupuestos, control de gasto y validaciones.',
    'cash_closings' => 'Cierres de caja, turnos y auditoria sensible.',
    'erp_readiness' => 'Dashboard ejecutivo enterprise de todos los contextos.',
    'manual' => 'Documentacion operativa y guias de proceso.',
    'companies' => 'Tenant, empresa, sucursales y configuracion base.',
    'electronic_invoice' =>
      'Facturacion electronica y cumplimiento tributario.',
    'receipts' => 'Recibos, aplicaciones y soporte de pagos.',
    'payroll' => 'Nomina, empleados y obligaciones laborales.',
    'fixed_assets' => 'Activos, depreciacion, deterioros y disposiciones.',
    'attachments' => 'Adjuntos, evidencia y documentacion transversal.',
    'users' => 'Usuarios, roles, permisos y aislamiento tenant.',
    'audit' => 'Auditoria, eventos, trazabilidad y acciones sensibles.',
    'backups' => 'Respaldos, recuperacion y continuidad operativa.',
    'licensing' => 'Gestion de licencias empresariales, claves y HWID.',
    'settings' => 'Configuracion, modulos, seguridad y parametros.',
    _ => 'Modulo enterprise integrado al workspace ERP.',
  };
}
