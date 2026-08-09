import 'package:flutter/material.dart';

import '../application/crm_account_service.dart';
import '../application/crm_contact_service.dart';
import '../application/crm_interaction_service.dart';
import '../application/crm_opportunity_service.dart';
import '../domain/crm_account.dart';
import '../domain/crm_contact.dart';
import '../domain/crm_opportunity.dart';
import '../domain/customer_interaction.dart';

class CrmAccountsPage extends StatelessWidget {
  const CrmAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas CRM')),
      body: FutureBuilder<List<CrmAccount>>(
        future: CrmAccountService().list(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final accounts = snapshot.data ?? const <CrmAccount>[];
          if (accounts.isEmpty) {
            return const Center(child: Text('Sin cuentas CRM'));
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                leading: const Icon(Icons.business),
                title: Text(account.name),
                subtitle: Text(
                  account.email ?? account.phone ?? 'Sin contacto',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CrmAccountPage(accountId: account.id!),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CrmAccountPage extends StatefulWidget {
  const CrmAccountPage({super.key, required this.accountId});

  final int accountId;

  @override
  State<CrmAccountPage> createState() => _CrmAccountPageState();
}

class _CrmAccountPageState extends State<CrmAccountPage> {
  late Future<_AccountHistory> _history;

  @override
  void initState() {
    super.initState();
    _history = _load();
  }

  Future<_AccountHistory> _load() async {
    final accountService = CrmAccountService();
    final account = await accountService.findById(widget.accountId);
    if (account == null) throw StateError('La cuenta CRM no existe.');
    final contacts = await CrmContactService().listForAccount(widget.accountId);
    final interactions = await CrmInteractionService().listForCustomer(
      widget.accountId,
    );
    final opportunities = await CrmOpportunityService().listForAccount(
      widget.accountId,
    );
    return _AccountHistory(account, contacts, interactions, opportunities);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha de cuenta')),
      body: FutureBuilder<_AccountHistory>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data.account.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(data.account.email ?? 'Sin correo'),
              const SizedBox(height: 16),
              _section('Contactos', data.contacts.map(_contactTile).toList()),
              _section(
                'Oportunidades',
                data.opportunities.map(_opportunityTile).toList(),
              ),
              _section(
                'Historial de interacciones',
                data.interactions.map(_interactionTile).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title),
      children: children.isEmpty
          ? [const ListTile(title: Text('Sin registros'))]
          : children,
    );
  }

  Widget _contactTile(CrmContact contact) => ListTile(
    leading: const Icon(Icons.person_outline),
    title: Text('${contact.firstName} ${contact.lastName}'.trim()),
    subtitle: Text(contact.email ?? contact.phoneMobile ?? 'Sin datos'),
  );

  Widget _opportunityTile(CrmOpportunity opportunity) => ListTile(
    leading: const Icon(Icons.trending_up),
    title: Text(opportunity.name),
    subtitle: Text(
      '${opportunity.salesStage.value} - ${opportunity.amount.format()}',
    ),
    trailing: Text('${opportunity.effectiveProbability}%'),
  );

  Widget _interactionTile(CustomerInteraction interaction) => ListTile(
    leading: const Icon(Icons.history),
    title: Text(interaction.subject),
    subtitle: Text(
      '${interaction.interactionType} - ${interaction.interactionDate}',
    ),
  );
}

class _AccountHistory {
  const _AccountHistory(
    this.account,
    this.contacts,
    this.interactions,
    this.opportunities,
  );

  final CrmAccount account;
  final List<CrmContact> contacts;
  final List<CustomerInteraction> interactions;
  final List<CrmOpportunity> opportunities;
}
