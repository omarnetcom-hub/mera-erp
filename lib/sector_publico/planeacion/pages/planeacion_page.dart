/// Página de Planeación
/// Banco de Proyectos MGA + PDT
library;

import 'package:flutter/material.dart';

class PlaneacionPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const PlaneacionPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<PlaneacionPage> createState() => _PlaneacionPageState();
}

class _PlaneacionPageState extends State<PlaneacionPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Proyectos MGA',
    'PDT',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planeación'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildProyectosMGATab(),
          _buildPDTTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree),
            label: 'Proyectos MGA',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'PDT',
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

  Widget _buildProyectosMGATab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_tree, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Banco de Proyectos MGA',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Metodología General Ajustada - DNP'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarProyecto(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Proyecto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPDTTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Plan de Desarrollo Territorial',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('PDT - Planificación 4 años'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearPDT(),
            icon: const Icon(Icons.add),
            label: const Text('Crear PDT'),
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
        _registrarProyecto();
        break;
      case 1:
        _crearPDT();
        break;
    }
  }

  void _registrarProyecto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Proyecto MGA'),
        content: const Text('Formulario de registro en BPIN'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proyecto registrado en BPIN')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _crearPDT() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear PDT'),
        content: const Text('Formulario de creación de Plan de Desarrollo Territorial'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDT creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
