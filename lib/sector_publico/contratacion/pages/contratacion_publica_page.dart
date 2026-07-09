/// Página de Contratación Pública
/// Ley 80 de 1993 + SECOP II
library;

import 'package:flutter/material.dart';

class ContratacionPublicaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const ContratacionPublicaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<ContratacionPublicaPage> createState() => _ContratacionPublicaPageState();
}

class _ContratacionPublicaPageState extends State<ContratacionPublicaPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Procesos',
    'Contratos',
    'Pólizas',
    'SECOP II',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratación Pública'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildProcesosTab(),
          _buildContratosTab(),
          _buildPolizasTab(),
          _buildSECOPTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Procesos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Contratos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Pólizas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload),
            label: 'SECOP II',
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

  Widget _buildProcesosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Procesos de Contratación',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Gestión de procesos según Ley 80/1993'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearProceso(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Proceso'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContratosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Contratos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Requiere CDP y RP (Ley 80/1993 Art. 41)'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearContrato(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Contrato'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolizasTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Pólizas de Garantía',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Pólizas obligatorias según tipo de contrato'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarPoliza(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Póliza'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSECOPTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'SECOP II',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Sistema Electrónico de Contratación Pública'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _publicarSECOP(),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Publicar en SECOP II'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _sincronizarSECOP(),
            icon: const Icon(Icons.sync),
            label: const Text('Sincronizar'),
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
        _crearProceso();
        break;
      case 1:
        _crearContrato();
        break;
      case 2:
        _registrarPoliza();
        break;
      case 3:
        _publicarSECOP();
        break;
    }
  }

  void _crearProceso() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Proceso de Contratación'),
        content: const Text('Formulario de creación de proceso'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proceso creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _crearContrato() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Contrato'),
        content: const Text(
          'NOTA: Requiere CDP y RP asociados (Ley 80/1993 Art. 41)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contrato creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _registrarPoliza() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Póliza de Garantía'),
        content: const Text('Formulario de registro de póliza'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Póliza registrada exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _publicarSECOP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicar en SECOP II'),
        content: const Text(
          'Publicará el proceso en el Sistema Electrónico de Contratación Pública. '
          'Todos los procesos deben publicarse en SECOP II.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proceso publicado en SECOP II')),
              );
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  void _sincronizarSECOP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sincronizar con SECOP II'),
        content: const Text('Sincronizará los contratos con SECOP II'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronización completada')),
              );
            },
            child: const Text('Sincronizar'),
          ),
        ],
      ),
    );
  }
}
