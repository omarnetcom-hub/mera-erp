/// Página de Nómina Pública
/// PILA + Retroactivos
library;

import 'package:flutter/material.dart';

class NominaPublicaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const NominaPublicaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<NominaPublicaPage> createState() => _NominaPublicaPageState();
}

class _NominaPublicaPageState extends State<NominaPublicaPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Empleados',
    'Liquidaciones',
    'Retroactivos',
    'PILA',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nómina Pública'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildEmpleadosTab(),
          _buildLiquidacionesTab(),
          _buildRetroactivosTab(),
          _buildPILATab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Empleados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Liquidaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Retroactivos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'PILA',
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

  Widget _buildEmpleadosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Gestión de Empleados',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Registro de empleados públicos'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarEmpleado(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Empleado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidacionesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Liquidaciones de Nómina',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Cálculo con aportes parafiscales'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _liquidarNomina(),
            icon: const Icon(Icons.add),
            label: const Text('Liquidar Nómina'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroactivosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Retroactivos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Cálculo por ajustes salariales o sentencias'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _calcularRetroactivo(),
            icon: const Icon(Icons.add),
            label: const Text('Calcular Retroactivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPILATab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'PILA',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Planilla Integrada de Liquidación de Aportes'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _generarReportePILA(),
            icon: const Icon(Icons.description),
            label: const Text('Generar Reporte PILA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _exportarFormatoPlano(),
            icon: const Icon(Icons.file_download),
            label: const Text('Exportar Formato Plano'),
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
        _registrarEmpleado();
        break;
      case 1:
        _liquidarNomina();
        break;
      case 2:
        _calcularRetroactivo();
        break;
      case 3:
        _generarReportePILA();
        break;
    }
  }

  void _registrarEmpleado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Empleado'),
        content: const Text('Formulario de registro de empleado'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Empleado registrado exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _liquidarNomina() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liquidar Nómina'),
        content: const Text('Formulario de liquidación de nómina'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nómina liquidada exitosamente')),
              );
            },
            child: const Text('Liquidar'),
          ),
        ],
      ),
    );
  }

  void _calcularRetroactivo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calcular Retroactivo'),
        content: const Text('Formulario de cálculo de retroactivo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Retroactivo calculado exitosamente')),
              );
            },
            child: const Text('Calcular'),
          ),
        ],
      ),
    );
  }

  void _generarReportePILA() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Reporte PILA'),
        content: const Text('Generará el reporte de aportes para el periodo seleccionado'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte PILA generado exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _exportarFormatoPlano() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Formato Plano'),
        content: const Text('Exportará el formato plano para PILA'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Formato plano exportado')),
              );
            },
            child: const Text('Exportar'),
          ),
        ],
      ),
    );
  }
}
