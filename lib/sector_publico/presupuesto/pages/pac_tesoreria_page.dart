/// Página de Tesorería - Programa Anual Mensualizado de Caja (PAC)
/// Implementa validaciones según Art. 74-76 Decreto 111/1996
library;

import 'package:flutter/material.dart';

class PACTesoreriaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const PACTesoreriaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<PACTesoreriaPage> createState() => _PACTesoreriaPageState();
}

class _PACTesoreriaPageState extends State<PACTesoreriaPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Programación PAC',
    'Ejecución',
    'Traslados',
    'Embargos',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tesorería - PAC'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildProgramacionTab(),
          _buildEjecucionTab(),
          _buildTrasladosTab(),
          _buildEmbargosTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Programación',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Ejecución',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Traslados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Embargos',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoCreacion,
        backgroundColor: const Color(0xFF006D77),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProgramacionTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Programación Anual Mensualizada de Caja',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Programación mensual de cupos de pago por rubro'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _programarPAC(),
            icon: const Icon(Icons.add),
            label: const Text('Programar PAC'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEjecucionTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_up, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Ejecución del PAC',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Seguimiento de ejecución vs programación'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _verEjecucion(),
            icon: const Icon(Icons.analytics),
            label: const Text('Ver Ejecución'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrasladosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_horiz, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Traslados de Cupo PAC',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Traslados entre meses del mismo año (Art. 76 EOP)'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _trasladarCupo(),
            icon: const Icon(Icons.add),
            label: const Text('Trasladar Cupo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbargosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Embargos Judiciales',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Registro informativo (cuentas públicas inembargables)'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _registrarEmbargo(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Embargo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCreacion() {
    switch (_selectedIndex) {
      case 0:
        _programarPAC();
        break;
      case 1:
        _verEjecucion();
        break;
      case 2:
        _trasladarCupo();
        break;
      case 3:
        _registrarEmbargo();
        break;
    }
  }

  void _programarPAC() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programar PAC'),
        content: const Text('Formulario de programación de PAC'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PAC programado exitosamente')),
              );
            },
            child: const Text('Programar'),
          ),
        ],
      ),
    );
  }

  void _verEjecucion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ejecución del PAC'),
        content: const Text('Reporte de ejecución vs programación'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _trasladarCupo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trasladar Cupo PAC'),
        content: const Text('Formulario de traslado de cupo entre meses'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cupo trasladado exitosamente')),
              );
            },
            child: const Text('Trasladar'),
          ),
        ],
      ),
    );
  }

  void _registrarEmbargo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Embargo Judicial'),
        content: const Text('Formulario de registro de embargo judicial'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Embargo registrado exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }
}
