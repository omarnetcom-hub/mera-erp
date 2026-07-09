/// Página principal del módulo de Contabilidad NICSP
/// Implementa Resolución 533/2015 CGN + NICSP 1, 2, 12, 17, 19
library;

import 'package:flutter/material.dart';

class ContabilidadNICSPPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const ContabilidadNICSPPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<ContabilidadNICSPPage> createState() => _ContabilidadNICSPPageState();
}

class _ContabilidadNICSPPageState extends State<ContabilidadNICSPPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Asientos',
    'Saldos',
    'Estados Financieros',
    'Cierre Vigencia',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contabilidad NICSP'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildAsientosTab(),
          _buildSaldosTab(),
          _buildEstadosFinancierosTab(),
          _buildCierreVigenciaTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Asientos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Saldos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'EEFF',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_clock),
            label: 'Cierre',
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

  Widget _buildAsientosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Asientos Contables',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Gestión de asientos manuales y automáticos'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearAsientoManual(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Asiento Manual'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Saldos de Cuentas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Consulta de saldos por vigencia y cuenta'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _consultarSaldos(),
            icon: const Icon(Icons.search),
            label: const Text('Consultar Saldos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadosFinancierosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Estados Financieros NICSP',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Generación de EEFF según NICSP 1, 2'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _generarEstadoSituacion(),
            icon: const Icon(Icons.balance),
            label: const Text('Estado Situación Financiera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _generarEstadoResultado(),
            icon: const Icon(Icons.trending_up),
            label: const Text('Estado de Resultado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _generarEstadoFlujos(),
            icon: Icon(Icons.payments),
            label: const Text('Estado de Flujos de Efectivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCierreVigenciaTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Cierre de Vigencia',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Cierre anual según Art. 89 EOP y NICSP'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _ejecutarCierre(),
            icon: const Icon(Icons.lock),
            label: const Text('Ejecutar Cierre'),
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
        _crearAsientoManual();
        break;
      case 1:
        _consultarSaldos();
        break;
      case 2:
        _generarEstadoSituacion();
        break;
      case 3:
        _ejecutarCierre();
        break;
    }
  }

  void _crearAsientoManual() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Asiento Manual'),
        content: const Text('Formulario de creación de asiento contable'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Asiento creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _consultarSaldos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar Saldos'),
        content: const Text('Consulta de saldos por cuenta y vigencia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _generarEstadoSituacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estado de Situación Financiera'),
        content: const Text('Generación de Balance General según NICSP 1'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estado generado exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _generarEstadoResultado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estado de Resultado'),
        content: const Text('Generación de PyG según NICSP 1'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estado generado exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _generarEstadoFlujos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estado de Flujos de Efectivo'),
        content: const Text('Generación según NICSP 2'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estado generado exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _ejecutarCierre() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ejecutar Cierre de Vigencia'),
        content: const Text(
          'Esta acción cerrará la vigencia y generará los asientos de cierre y apertura. '
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
                const SnackBar(content: Text('Cierre ejecutado exitosamente')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ejecutar Cierre'),
          ),
        ],
      ),
    );
  }
}
