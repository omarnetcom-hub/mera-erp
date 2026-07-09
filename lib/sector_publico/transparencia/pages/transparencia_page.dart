/// Página de Transparencia
/// Transparencia + Control Disciplinario + Consolidación NICSP 40
library;

import 'package:flutter/material.dart';

class TransparenciaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const TransparenciaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<TransparenciaPage> createState() => _TransparenciaPageState();
}

class _TransparenciaPageState extends State<TransparenciaPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Transparencia',
    'Disciplinario',
    'NICSP 40',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transparencia'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildTransparenciaTab(),
          _buildDisciplinarioTab(),
          _buildNICSP40Tab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility),
            label: 'Transparencia',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Disciplinario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'NICSP 40',
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

  Widget _buildTransparenciaTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Reportes de Transparencia',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Ley 1712 de 2014'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearReporte(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Reporte'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplinarioTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Control Disciplinario',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Código Disciplinario Único'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _iniciarProceso(),
            icon: const Icon(Icons.add),
            label: const Text('Iniciar Proceso'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNICSP40Tab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Consolidación NICSP 40',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Información a revelar sobre transferencias'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarTransferencia(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Transferencia'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _generarReporte(),
            icon: const Icon(Icons.assessment),
            label: const Text('Generar Reporte'),
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
        _crearReporte();
        break;
      case 1:
        _iniciarProceso();
        break;
      case 2:
        _registrarTransferencia();
        break;
    }
  }

  void _crearReporte() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Reporte de Transparencia'),
        content: const Text('Formulario de creación de reporte'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _iniciarProceso() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Proceso Disciplinario'),
        content: const Text('Formulario de inicio de proceso disciplinario'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proceso iniciado exitosamente')),
              );
            },
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
  }

  void _registrarTransferencia() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Transferencia NICSP 40'),
        content: const Text('Formulario de registro de transferencia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transferencia registrada exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _generarReporte() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Reporte NICSP 40'),
        content: const Text('Generará el reporte consolidado de transferencias'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte generado exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }
}
