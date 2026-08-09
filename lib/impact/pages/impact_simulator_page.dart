import 'package:flutter/material.dart';

import '../../ui/merka_theme_tokens.dart';
import '../application/impact_simulator_service.dart';
import '../domain/impact_scenario.dart';

class ImpactSimulatorPage extends StatefulWidget {
  const ImpactSimulatorPage({super.key, this.service});

  final ImpactSimulatorService? service;

  @override
  State<ImpactSimulatorPage> createState() => _ImpactSimulatorPageState();
}

class _ImpactSimulatorPageState extends State<ImpactSimulatorPage> {
  late final ImpactSimulatorService _service;
  late Future<ImpactSnapshot> _snapshot;
  int _upliftPercent = 20;
  Future<List<ImpactScenario>>? _scenarios;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ImpactSimulatorService();
    _snapshot = _service.snapshot();
    _scenarios = _service.listScenarios();
  }

  void _reloadScenarios() {
    setState(() => _scenarios = _service.listScenarios());
  }

  Future<void> _saveScenario(
    ImpactSnapshot snapshot,
    ImpactResult result,
  ) async {
    final controller = TextEditingController(
      text: 'Escenario +$_upliftPercent%',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guardar escenario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _service.saveScenario(name: name, snapshot: snapshot, result: result);
    if (!mounted) return;
    _reloadScenarios();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escenario guardado en el libro local.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de impacto')),
      body: FutureBuilder<ImpactSnapshot>(
        future: _snapshot,
        builder: (context, snapshotState) {
          if (snapshotState.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshotState.hasError) {
            return Center(
              child: Text(
                'No se pudo cargar el snapshot: ${snapshotState.error}',
              ),
            );
          }
          final snapshot = snapshotState.data!;
          final result = _service.calculate(
            snapshot: snapshot,
            upliftPercent: _upliftPercent,
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSnapshot(snapshot),
              const SizedBox(height: 16),
              _buildControl(snapshot, result),
              const SizedBox(height: 16),
              _buildResult(result),
              const SizedBox(height: 20),
              _buildScenarioBook(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSnapshot(ImpactSnapshot snapshot) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        children: [
          _metric(
            'CRM ganado',
            '${snapshot.closedWonValue.format()} (${snapshot.closedWonCount})',
          ),
          _metric('Headcount activo', '${snapshot.activeHeadcount}'),
          _metric('Costo base HRM', snapshot.activeBasePayroll.format()),
          _metric('Workstations', '${snapshot.workstationCount}'),
          _metric(
            'Capacidad diaria',
            '${snapshot.availableHoursPerDay.toStringAsFixed(2)} h',
          ),
        ],
      ),
    ),
  );

  Widget _buildControl(ImpactSnapshot snapshot, ImpactResult result) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aumento de oportunidades ganadas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _upliftPercent.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '+$_upliftPercent%',
            onChanged: (value) =>
                setState(() => _upliftPercent = value.round()),
          ),
          Text(
            '+$_upliftPercent%',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(snapshot.capacityNote),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _saveScenario(snapshot, result),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Guardar escenario'),
          ),
        ],
      ),
    ),
  );

  Widget _buildResult(ImpactResult result) {
    final unknown =
        result.capacityStatus != 'configurada_sin_modelo_de_demanda_por_unidad';
    final color = unknown ? MerkaThemeTokens.warning : MerkaThemeTokens.success;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  unknown ? Icons.help_outline : Icons.check_circle_outline,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  result.capacityStatus == 'capacidad_no_configurada'
                      ? 'Capacidad: no configurada'
                      : result.capacityStatus == 'parcialmente_configurada'
                      ? 'Capacidad: configuracion parcial'
                      : 'Capacidad: configurada',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Proyección ganada: ${result.projectedClosedWonValue.format()}',
            ),
            Text(
              'Demanda incremental proxy: ${result.incrementalDemandProxy.format()}',
            ),
            const SizedBox(height: 12),
            Text('Fórmula: ${result.formula}'),
            for (final warning in result.warnings) Text('Nota: $warning'),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioBook() => FutureBuilder<List<ImpactScenario>>(
    future: _scenarios,
    builder: (context, snapshot) {
      final scenarios = snapshot.data ?? const <ImpactScenario>[];
      return Card(
        child: ExpansionTile(
          title: const Text('Libro de escenarios'),
          subtitle: Text('${scenarios.length} simulaciones locales'),
          children: scenarios
              .map(
                (scenario) => ListTile(
                  title: Text(scenario.name),
                  subtitle: Text(
                    '+${scenario.upliftPercent}% · ${scenario.result.capacityStatus}\n'
                    '${scenario.result.formula}',
                  ),
                  trailing: const Icon(Icons.verified_outlined),
                ),
              )
              .toList(),
        ),
      );
    },
  );

  Widget _metric(String label, String value) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 150),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: MerkaThemeTokens.graphite600,
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
