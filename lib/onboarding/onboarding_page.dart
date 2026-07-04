import 'package:flutter/material.dart';

import '../features/company_configuration_service.dart';
import '../features/company_template_service.dart';
import '../features/feature_key.dart';
import '../features/feature_registry.dart';
import '../models/company.dart';
import '../models/company_profile.dart';
import '../models/company_template.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final companyNameCtrl = TextEditingController(text: 'Mi empresa');
  final countryCtrl = TextEditingController(text: 'Colombia');
  final currencyCtrl = TextEditingController(text: 'COP');
  final timezoneCtrl = TextEditingController(text: 'America/Bogota');
  final taxRegimeCtrl = TextEditingController();
  final defaultTaxCtrl = TextEditingController(text: '19');
  final employeesCtrl = TextEditingController(text: '1-5');
  final branchesCtrl = TextEditingController(text: '1');
  final volumeCtrl = TextEditingController(text: 'Bajo');

  int currentStep = 0;
  bool vatEnabled = true;
  bool withholdingEnabled = false;
  bool saving = false;
  CompanyTemplate? selectedTemplate;
  List<CompanyTemplate> templates = [];
  late Map<String, bool> features;

  static const _steps = [
    _OnboardingStep('Empresa', Icons.domain),
    _OnboardingStep('Operacion', Icons.storefront),
    _OnboardingStep('Fiscal', Icons.receipt_long),
    _OnboardingStep('Escala', Icons.tune),
  ];

  @override
  void initState() {
    super.initState();
    features = FeatureRegistry.defaultFeatures();
    _loadTemplates();
  }

  @override
  void dispose() {
    companyNameCtrl.dispose();
    countryCtrl.dispose();
    currencyCtrl.dispose();
    timezoneCtrl.dispose();
    taxRegimeCtrl.dispose();
    defaultTaxCtrl.dispose();
    employeesCtrl.dispose();
    branchesCtrl.dispose();
    volumeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final loaded = await CompanyTemplateService.loadTemplates();
    if (!mounted) return;
    setState(() {
      templates = loaded;
      if (loaded.isNotEmpty) {
        selectedTemplate = loaded.first;
        _applyTemplate(loaded.first, notify: false);
      }
    });
  }

  void _applyTemplate(CompanyTemplate template, {bool notify = true}) {
    features = {...FeatureRegistry.defaultFeatures(), ...template.features};
    defaultTaxCtrl.text =
        template.settings['default_tax'] ?? defaultTaxCtrl.text;
    if (notify) setState(() => selectedTemplate = template);
  }

  void _toggle(String key, bool value) {
    setState(() {
      features[key] = value;
      if (value) {
        for (final dependency in FeatureRegistry.dependenciesOf(key)) {
          features[dependency] = true;
        }
      }
    });
  }

  Future<void> _finish() async {
    if (companyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe el nombre de la empresa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => saving = true);
    final company = Company(
      name: companyNameCtrl.text.trim(),
      country: countryCtrl.text.trim().isEmpty
          ? 'Colombia'
          : countryCtrl.text.trim(),
      currency: currencyCtrl.text.trim().isEmpty
          ? 'COP'
          : currencyCtrl.text.trim().toUpperCase(),
      timezone: timezoneCtrl.text.trim().isEmpty
          ? 'America/Bogota'
          : timezoneCtrl.text.trim(),
    );

    final profile = CompanyProfile(
      companyId: 0,
      employeeCount: employeesCtrl.text.trim(),
      branchCount: branchesCtrl.text.trim(),
      operationVolume: volumeCtrl.text.trim(),
      taxRegime: taxRegimeCtrl.text.trim(),
      vatEnabled: vatEnabled,
      withholdingEnabled: withholdingEnabled,
    );

    try {
      await CompanyConfigurationService.instance.saveOnboarding(
        company: company,
        profile: profile,
        features: features,
        settings: {
          'country': company.country,
          'currency': company.currency,
          'timezone': company.timezone,
          'vat_enabled': vatEnabled ? '1' : '0',
          'withholding_enabled': withholdingEnabled ? '1' : '0',
          'default_tax': vatEnabled ? defaultTaxCtrl.text.trim() : '0',
          'tax_regime': profile.taxRegime,
          'employees': profile.employeeCount,
          'branches': profile.branchCount,
          'operation_volume': profile.operationVolume,
        },
        template: selectedTemplate,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    setState(() => saving = false);
    widget.onFinished();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _featureSwitch(String key) {
    final definition = FeatureRegistry.definitions.firstWhere(
      (item) => item.key == key,
    );
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: features[key] ?? false,
      title: Text(definition.name),
      subtitle: Text(
        definition.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: (value) => _toggle(key, value),
    );
  }

  Widget _stepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(currentStep),
        child: switch (currentStep) {
          0 => _empresaStep(),
          1 => _operacionStep(),
          2 => _fiscalStep(),
          _ => _escalaStep(),
        },
      ),
    );
  }

  Widget _empresaStep() {
    return _Panel(
      title: 'Datos base',
      subtitle: 'Esta informacion alimenta comprobantes, moneda y reportes.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 620;
          final fields = [
            _field(companyNameCtrl, 'Nombre de la empresa', icon: Icons.domain),
            _field(countryCtrl, 'Pais', icon: Icons.public),
            _field(currencyCtrl, 'Moneda', icon: Icons.payments),
            _field(timezoneCtrl, 'Zona horaria', icon: Icons.schedule),
          ];
          if (compacto) {
            return Column(
              children: fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: field,
                    ),
                  )
                  .toList(),
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: fields
                .map(
                  (field) => SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: field,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _operacionStep() {
    final grupos = [
      [
        FeatureKey.pos,
        FeatureKey.inventory,
        FeatureKey.purchases,
        FeatureKey.cash,
      ],
      [
        FeatureKey.crm,
        FeatureKey.services,
        FeatureKey.production,
        FeatureKey.multiBranch,
      ],
      [
        FeatureKey.accounting,
        FeatureKey.treasury,
        FeatureKey.reports,
        FeatureKey.documents,
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Plantilla de negocio',
          subtitle: 'Elige un punto de partida y ajusta modulos despues.',
          child: templates.isEmpty
              ? const LinearProgressIndicator()
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: templates.map((template) {
                    final selected = selectedTemplate?.id == template.id;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(template.name),
                      avatar: Icon(
                        selected ? Icons.check_circle : Icons.business_center,
                        size: 18,
                      ),
                      onSelected: (_) => _applyTemplate(template),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Modulos activos',
          subtitle:
              'Estos interruptores definen que tarjetas aparecen en el menu principal.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: grupos
                    .expand((grupo) => grupo)
                    .map(
                      (key) =>
                          SizedBox(width: width, child: _featureSwitch(key)),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Vista previa del menu',
          subtitle: 'Asi quedara el centro de trabajo para esta empresa.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeatureRegistry.definitions.map((definition) {
              final active = features[definition.key] ?? false;
              return FilterChip(
                selected: active,
                onSelected: (value) => _toggle(definition.key, value),
                avatar: Icon(
                  active ? Icons.check_circle : Icons.remove_circle_outline,
                  size: 18,
                ),
                label: Text(definition.name),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _fiscalStep() {
    return _Panel(
      title: 'Impuestos y documentos',
      subtitle:
          'Define la base fiscal inicial para compras, ventas y reportes.',
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: vatEnabled,
            title: const Text('IVA habilitado'),
            subtitle: const Text('Permite calcular impuestos en documentos.'),
            onChanged: (value) => setState(() => vatEnabled = value),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: withholdingEnabled,
            title: const Text('Retenciones'),
            subtitle: const Text('Prepara reportes y parametros tributarios.'),
            onChanged: (value) => setState(() => withholdingEnabled = value),
          ),
          const Divider(),
          _featureSwitch(FeatureKey.electronicInvoice),
          const SizedBox(height: 10),
          _field(defaultTaxCtrl, 'IVA predeterminado (%)', icon: Icons.percent),
          const SizedBox(height: 10),
          _field(
            taxRegimeCtrl,
            'Regimen tributario',
            icon: Icons.account_balance,
          ),
        ],
      ),
    );
  }

  Widget _escalaStep() {
    return _Panel(
      title: 'Tamano operativo',
      subtitle: 'Estos datos ayudan a preparar permisos, reportes y modulos.',
      child: Column(
        children: [
          _QuickOptions(
            label: 'Empleados',
            controller: employeesCtrl,
            options: const ['1-5', '6-20', '21-50', '50+'],
          ),
          const SizedBox(height: 12),
          _QuickOptions(
            label: 'Sucursales',
            controller: branchesCtrl,
            options: const ['1', '2-3', '4-10', '10+'],
          ),
          const SizedBox(height: 12),
          _QuickOptions(
            label: 'Volumen operativo',
            controller: volumeCtrl,
            options: const ['Bajo', 'Medio', 'Alto'],
          ),
        ],
      ),
    );
  }

  void _continuar() {
    if (currentStep == _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => currentStep++);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == _steps.length - 1;
    final enabledCount = features.values.where((enabled) => enabled).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion inicial')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _Sidebar(
                            steps: _steps,
                            currentStep: currentStep,
                            enabledCount: enabledCount,
                            companyName: companyNameCtrl.text,
                            onStepSelected: (step) =>
                                setState(() => currentStep = step),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _content(isLast)),
                      ],
                    )
                  : Column(
                      children: [
                        _MobileProgress(
                          steps: _steps,
                          currentStep: currentStep,
                          enabledCount: enabledCount,
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _content(isLast)),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(bool isLast) {
    return Column(
      children: [
        Expanded(child: SingleChildScrollView(child: _stepContent())),
        const SizedBox(height: 12),
        Row(
          children: [
            if (currentStep > 0)
              TextButton.icon(
                onPressed: saving ? null : () => setState(() => currentStep--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Atras'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: saving ? null : _continuar,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Finalizar' : 'Continuar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.steps,
    required this.currentStep,
    required this.enabledCount,
    required this.companyName,
    required this.onStepSelected,
  });

  final List<_OnboardingStep> steps;
  final int currentStep;
  final int enabledCount;
  final String companyName;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              child: const Icon(Icons.rocket_launch),
            ),
            const SizedBox(height: 12),
            Text(
              companyName.trim().isEmpty ? 'Nueva empresa' : companyName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '$enabledCount modulos activos',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const Divider(height: 26),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final selected = index == currentStep;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: selected
                      ? Colors.green.shade700
                      : Colors.grey.shade100,
                  foregroundColor: selected ? Colors.white : Colors.black87,
                  child: Icon(step.icon, size: 17),
                ),
                title: Text(
                  step.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                onTap: () => onStepSelected(index),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MobileProgress extends StatelessWidget {
  const _MobileProgress({
    required this.steps,
    required this.currentStep,
    required this.enabledCount,
  });

  final List<_OnboardingStep> steps;
  final int currentStep;
  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps[currentStep].label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$enabledCount modulos activos'),
                ],
              ),
            ),
            Text('${currentStep + 1}/${steps.length}'),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickOptions extends StatefulWidget {
  const _QuickOptions({
    required this.label,
    required this.controller,
    required this.options,
  });

  final String label;
  final TextEditingController controller;
  final List<String> options;

  @override
  State<_QuickOptions> createState() => _QuickOptionsState();
}

class _QuickOptionsState extends State<_QuickOptions> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: widget.options.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: widget.controller.text == option,
              onSelected: (_) {
                setState(() => widget.controller.text = option);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
