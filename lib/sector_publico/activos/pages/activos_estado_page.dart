/// Página de Activos del Estado
/// NICSP 17 + FUT
library;

import 'package:flutter/material.dart';

class ActivosEstadoPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const ActivosEstadoPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<ActivosEstadoPage> createState() => _ActivosEstadoPageState();
}

class _ActivosEstadoPageState extends State<ActivosEstadoPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Activos',
    'FUT',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activos del Estado'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildActivosTab(),
          _buildFUTTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Activos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'FUT',
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

  Widget _buildActivosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Activos del Estado',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Gestión según NICSP 17'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarActivo(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Activo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFUTTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'FUT',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Fondo de Unidad de Tesorería'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearFUT(),
            icon: const Icon(Icons.add),
            label: const Text('Crear FUT'),
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
        _registrarActivo();
        break;
      case 1:
        _crearFUT();
        break;
    }
  }

  void _registrarActivo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Activo'),
        content: const Text('Formulario de registro de activo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activo registrado exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _crearFUT() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear FUT'),
        content: const Text('Formulario de creación de FUT'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('FUT creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
