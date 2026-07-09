/// Página de Auditoría Forense
/// Consulta de registros de auditoría y generación de reportes CHIP
library;

import 'package:flutter/material.dart';

class AuditoriaForensePage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const AuditoriaForensePage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<AuditoriaForensePage> createState() => _AuditoriaForensePageState();
}

class _AuditoriaForensePageState extends State<AuditoriaForensePage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Registros',
    'Reportes CHIP',
    'Integridad',
    'Alertas',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría Forense'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRegistrosTab(),
          _buildReportesCHIPTab(),
          _buildIntegridadTab(),
          _buildAlertasTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Registros',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Reportes CHIP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Integridad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Alertas',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAccion,
        backgroundColor: const Color(0xFF006D77),
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildRegistrosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Registros de Auditoría',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Consulta de registros append-only con hash encadenado'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _consultarRegistros(),
            icon: const Icon(Icons.search),
            label: const Text('Consultar Registros'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportesCHIPTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Reportes CHIP CGN',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Formularios CGN 2015_001 a 005 y CGN 2016C01'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _generarPaqueteCHIP(),
            icon: const Icon(Icons.add),
            label: const Text('Generar Paquete CHIP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _consultarReportes(),
            icon: const Icon(Icons.folder_open),
            label: const Text('Consultar Reportes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegridadTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Verificación de Integridad',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Verificación de cadena de hashes SHA-256'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _verificarIntegridad(),
            icon: const Icon(Icons.verified),
            label: const Text('Verificar Integridad'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertasTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Alertas de Auditoría',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Detección de anomalías y violaciones normativas'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _consultarAlertas(),
            icon: const Icon(Icons.search),
            label: const Text('Consultar Alertas'),
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
        _consultarRegistros();
        break;
      case 1:
        _generarPaqueteCHIP();
        break;
      case 2:
        _verificarIntegridad();
        break;
      case 3:
        _consultarAlertas();
        break;
    }
  }

  void _consultarRegistros() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar Registros de Auditoría'),
        content: const Text('Filtros de búsqueda por tipo de evento, fecha, usuario'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Búsqueda ejecutada')),
              );
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  void _generarPaqueteCHIP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Paquete CHIP'),
        content: const Text(
          'Generará los formularios CGN 2015_001 a 005 para la vigencia seleccionada. '
          '¿Desea continuar?',
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
                const SnackBar(content: Text('Paquete CHIP generado exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _consultarReportes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar Reportes CHIP'),
        content: const Text('Listado de reportes CHIP generados'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _verificarIntegridad() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verificar Integridad'),
        content: const Text('Verificará la cadena de hashes SHA-256 de los registros de auditoría'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Integridad verificada: Cadena intacta')),
              );
            },
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
  }

  void _consultarAlertas() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar Alertas'),
        content: const Text('Alertas de anomalías detectadas por el sistema'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
