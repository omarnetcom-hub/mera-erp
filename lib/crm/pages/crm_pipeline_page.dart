import 'package:flutter/material.dart';

import '../../core/commands/command_registry.dart';
import '../application/crm_opportunity_service.dart';
import '../domain/crm_opportunity.dart';
import 'crm_account_page.dart';

class CrmPipelinePage extends StatefulWidget {
  const CrmPipelinePage({super.key, this.service});

  final CrmOpportunityService? service;

  @override
  State<CrmPipelinePage> createState() => _CrmPipelinePageState();
}

class _CrmPipelinePageState extends State<CrmPipelinePage> {
  late final CrmOpportunityService _service;
  late Future<List<CrmOpportunity>> _opportunities;
  late final String _commandOwner;
  int? _assignedUserFilter;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CrmOpportunityService();
    _commandOwner = 'crm.pipeline:${identityHashCode(this)}';
    _reload();
  }

  @override
  void dispose() {
    CommandRegistry.instance.clearContext(_commandOwner);
    super.dispose();
  }

  void _reload() {
    _opportunities = _service.list();
  }

  Future<void> _move(CrmOpportunity opportunity, CrmSalesStage stage) async {
    try {
      await _service.moveToStage(opportunity.id, stage);
      if (mounted) setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo mover la oportunidad: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM - Pipeline'),
        actions: [
          FutureBuilder<List<CrmOpportunity>>(
            future: _opportunities,
            builder: (context, snapshot) {
              final users =
                  (snapshot.data ?? const <CrmOpportunity>[])
                      .map((item) => item.assignedUserId)
                      .whereType<int>()
                      .toSet()
                      .toList()
                    ..sort();
              return DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _assignedUserFilter,
                  hint: const Text('Vendedor'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ...users.map(
                      (userId) => DropdownMenuItem<int?>(
                        value: userId,
                        child: Text('Usuario $userId'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _assignedUserFilter = value),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Actualizar pipeline',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_reload),
          ),
        ],
      ),
      body: FutureBuilder<List<CrmOpportunity>>(
        future: _opportunities,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudo cargar el pipeline: ${snapshot.error}'),
            );
          }
          final opportunities = (snapshot.data ?? const <CrmOpportunity>[])
              .where(
                (item) =>
                    _assignedUserFilter == null ||
                    item.assignedUserId == _assignedUserFilter,
              )
              .toList();
          return _PipelineBoard(
            opportunities: opportunities,
            onMove: _move,
            onSelectOpportunity: (opportunity) =>
                _activateOpportunityContext(context, opportunity),
            onOpenAccount: (id) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CrmAccountPage(accountId: id)),
            ),
          );
        },
      ),
    );
  }

  void _activateOpportunityContext(
    BuildContext context,
    CrmOpportunity opportunity,
  ) {
    final stages = CrmSalesStage.values;
    final currentIndex = stages.indexOf(opportunity.salesStage);
    final nextStage = currentIndex >= 0 && currentIndex < stages.length - 2
        ? stages[currentIndex + 1]
        : null;
    final actions = <String, CommandHandler>{};
    if (nextStage != null) {
      actions['advance'] = (commandContext, _) => _move(opportunity, nextStage);
    }
    CommandRegistry.instance.setContext(
      CommandContext(
        moduleId: 'crm_pipeline',
        recordType: 'crm_opportunity',
        recordId: opportunity.id,
        label: opportunity.name,
        ownerId: _commandOwner,
        actions: actions,
      ),
    );
  }
}

class _PipelineBoard extends StatelessWidget {
  const _PipelineBoard({
    required this.opportunities,
    required this.onMove,
    required this.onSelectOpportunity,
    required this.onOpenAccount,
  });

  final List<CrmOpportunity> opportunities;
  final Future<void> Function(CrmOpportunity, CrmSalesStage) onMove;
  final ValueChanged<CrmOpportunity> onSelectOpportunity;
  final ValueChanged<int> onOpenAccount;

  String _stageTitle(CrmSalesStage stage) {
    switch (stage) {
      case CrmSalesStage.prospecting:
        return 'Prospecting';
      case CrmSalesStage.qualification:
        return 'Qualification';
      case CrmSalesStage.needsAnalysis:
        return 'Needs Analysis';
      case CrmSalesStage.valueProposition:
        return 'Value Proposition';
      case CrmSalesStage.negotiationReview:
        return 'Negotiation / Review';
      case CrmSalesStage.closedWon:
        return 'Closed Won';
      case CrmSalesStage.closedLost:
        return 'Closed Lost';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 1500 ? 220.0 : 260.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: CrmSalesStage.values.map((stage) {
              final items = opportunities
                  .where((opportunity) => opportunity.salesStage == stage)
                  .toList();
              return SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _StageColumn(
                    title: _stageTitle(stage),
                    probability: stage.probability,
                    stage: stage,
                    opportunities: items,
                    onMove: onMove,
                    onSelectOpportunity: onSelectOpportunity,
                    onOpenAccount: onOpenAccount,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.title,
    required this.probability,
    required this.stage,
    required this.opportunities,
    required this.onMove,
    required this.onSelectOpportunity,
    required this.onOpenAccount,
  });

  final String title;
  final int probability;
  final CrmSalesStage stage;
  final List<CrmOpportunity> opportunities;
  final Future<void> Function(CrmOpportunity, CrmSalesStage) onMove;
  final ValueChanged<CrmOpportunity> onSelectOpportunity;
  final ValueChanged<int> onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CrmOpportunity>(
      onWillAcceptWithDetails: (details) => details.data.salesStage != stage,
      onAcceptWithDetails: (details) => onMove(details.data, stage),
      builder: (context, candidates, rejected) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: candidates.isNotEmpty
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text('$probability% probability'),
                const SizedBox(height: 8),
                if (opportunities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('Suelta aqui una oportunidad'),
                  )
                else
                  ...opportunities.map(
                    (opportunity) => Draggable<CrmOpportunity>(
                      data: opportunity,
                      feedback: Material(
                        elevation: 4,
                        child: SizedBox(
                          width: 220,
                          child: ListTile(title: Text(opportunity.name)),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: .35,
                        child: _OpportunityCard(
                          opportunity: opportunity,
                          onSelectOpportunity: onSelectOpportunity,
                          onOpenAccount: onOpenAccount,
                        ),
                      ),
                      child: _OpportunityCard(
                        opportunity: opportunity,
                        onSelectOpportunity: onSelectOpportunity,
                        onOpenAccount: onOpenAccount,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.onSelectOpportunity,
    required this.onOpenAccount,
  });

  final CrmOpportunity opportunity;
  final ValueChanged<CrmOpportunity> onSelectOpportunity;
  final ValueChanged<int> onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          onSelectOpportunity(opportunity);
          onOpenAccount(opportunity.accountId);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                opportunity.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(opportunity.accountName),
              Text(opportunity.amount.format()),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: opportunity.effectiveProbability / 100,
              ),
              Text('${opportunity.effectiveProbability}% probable'),
            ],
          ),
        ),
      ),
    );
  }
}
