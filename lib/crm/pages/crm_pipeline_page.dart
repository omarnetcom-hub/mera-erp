import 'package:flutter/material.dart';

import '../application/crm_opportunity_service.dart';
import '../domain/crm_opportunity.dart';

class CrmPipelinePage extends StatefulWidget {
  const CrmPipelinePage({super.key, this.service});

  final CrmOpportunityService? service;

  @override
  State<CrmPipelinePage> createState() => _CrmPipelinePageState();
}

class _CrmPipelinePageState extends State<CrmPipelinePage> {
  late final CrmOpportunityService _service;
  late Future<List<CrmOpportunity>> _opportunities;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CrmOpportunityService();
    _reload();
  }

  void _reload() {
    _opportunities = _service.list();
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM - Pipeline'),
        actions: [
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
          final opportunities = snapshot.data ?? const <CrmOpportunity>[];
          return _PipelineBoard(
            opportunities: opportunities,
            stageTitle: _stageTitle,
          );
        },
      ),
    );
  }
}

class _PipelineBoard extends StatelessWidget {
  const _PipelineBoard({required this.opportunities, required this.stageTitle});

  final List<CrmOpportunity> opportunities;
  final String Function(CrmSalesStage) stageTitle;

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
                    title: stageTitle(stage),
                    probability: stage.probability,
                    opportunities: items,
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
    required this.opportunities,
  });

  final String title;
  final int probability;
  final List<CrmOpportunity> opportunities;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                child: Text('Sin oportunidades'),
              )
            else
              ...opportunities.map(
                (opportunity) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(opportunity.name),
                    subtitle: Text(
                      '${opportunity.accountName}\n${opportunity.amount.format()}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
