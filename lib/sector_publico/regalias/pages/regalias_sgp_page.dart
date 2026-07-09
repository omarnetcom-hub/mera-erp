/// Página de Regalías y SGP
/// SGR + SGP
library;

import 'package:flutter/material.dart';

class RegaliasSGPPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const RegaliasSGPPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<RegaliasSGPPage> createState() => _RegaliasSGPPageState();
}

class _RegaliasSGPPageState extends State<RegaliasSGPPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Regalías',
    'SGP',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regalías y SGP'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRegaliasTab(),
          _buildSGPTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Regalías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'SGP',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAccion,
        backgroundColor: const Color(0xFF006D77),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRegaliasTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monetization_on, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Regalías (SGR)',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Sistema General de Regalías - Ley 141/1993'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _estimarRegalia(),
            icon: const Icon(Icons.add),
            label: const Text('Estimar Regalía'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSGPTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'SGP',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Sistema General de Participaciones - Ley 1176/2007'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _asignarSGP(),
            icon: const Icon(Icons.add),
            label: const Text('Asignar SGP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAccion() {
    switch (_selectedIndex) {
      case 0:
        _estimarRegalia();
        break;
      case 1:
        _asignarSGP();
        break;
    }
  }

  void _estimarRegalia() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estimar Regalía'),
        content: const Text('Formulario de estimación de regalía'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Regalía estimada exitosamente')),
              );
            },
            child: const Text('Estimar'),
          ),
        ],
      ),
    );
  }

  void _asignarSGP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar SGP'),
        content: const Text('Formulario de asignación de SGP'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SGP asignado exitosamente')),
              );
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }
}
