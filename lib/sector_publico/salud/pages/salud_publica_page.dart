/// Página de Salud Pública
/// RIPS + EPS + Glosas
library;

import 'package:flutter/material.dart';

class SaludPublicaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const SaludPublicaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<SaludPublicaPage> createState() => _SaludPublicaPageState();
}

class _SaludPublicaPageState extends State<SaludPublicaPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'RIPS',
    'Glosas',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salud Pública'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRIPSTab(),
          _buildGlosasTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'RIPS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Glosas',
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

  Widget _buildRIPSTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'RIPS',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Registros Individuales de Prestación de Servicios'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarRIPS(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar RIPS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _generarArchivoPlano(),
            icon: const Icon(Icons.file_download),
            label: const Text('Generar Archivo Plano'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlosasTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Glosas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Gestión de glosas por parte de EPS'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _generarGlosa(),
            icon: const Icon(Icons.add),
            label: const Text('Generar Glosa'),
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
        _registrarRIPS();
        break;
      case 1:
        _generarGlosa();
        break;
    }
  }

  void _registrarRIPS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar RIPS'),
        content: const Text('Formulario de registro RIPS'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('RIPS registrado exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _generarArchivoPlano() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Archivo Plano RIPS'),
        content: const Text('Generará archivo plano para envío a EPS'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Archivo plano generado')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _generarGlosa() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Glosa'),
        content: const Text('Formulario de generación de glosa'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Glosa generada exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }
}
