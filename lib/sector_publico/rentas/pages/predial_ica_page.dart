/// Página de Rentas - Predial e ICA
/// Impuesto Predial + Industria y Comercio + Intereses Moratorios + Cobro Coactivo
library;

import 'package:flutter/material.dart';

class PredialICAPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const PredialICAPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<PredialICAPage> createState() => _PredialICAPageState();
}

class _PredialICAPageState extends State<PredialICAPage> {
  int _selectedIndex = 0;
  final List<String> _titulos = [
    'Predios',
    'Liquidaciones',
    'Acuerdos de Pago',
    'Cobro Coactivo',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentas - Predial e ICA'),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildPrediosTab(),
          _buildLiquidacionesTab(),
          _buildAcuerdosTab(),
          _buildCobroCoactivoTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Predios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Liquidaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handshake),
            label: 'Acuerdos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Cobro Coactivo',
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

  Widget _buildPrediosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Gestión de Predios',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Carga de catastro IGAC y gestión de predios'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _cargarCatastro(),
            icon: const Icon(Icons.upload_file),
            label: const Text('Cargar Catastro IGAC'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _registrarPredio(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Predio'),
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
          const Icon(Icons.receipt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Liquidaciones Prediales',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Liquidación masiva e individual según Ley 44/1990'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _liquidacionMasiva(),
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Liquidación Masiva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _liquidarPredio(),
            icon: const Icon(Icons.add),
            label: const Text('Liquidar Predio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcuerdosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.handshake, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Acuerdos de Pago',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Acuerdos de pago para deudores morosos (ET Art. 814)'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _crearAcuerdo(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Acuerdo de Pago'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCobroCoactivoTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Cobro Coactivo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Las 6 etapas del cobro coactivo con plazos legales'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _iniciarCobroCoactivo(),
            icon: const Icon(Icons.gavel),
            label: const Text('Iniciar Cobro Coactivo'),
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
        _registrarPredio();
        break;
      case 1:
        _liquidarPredio();
        break;
      case 2:
        _crearAcuerdo();
        break;
      case 3:
        _iniciarCobroCoactivo();
        break;
    }
  }

  void _cargarCatastro() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cargar Catastro IGAC'),
        content: const Text('Carga masiva de predios desde archivo IGAC'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Catastro cargado exitosamente')),
              );
            },
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
  }

  void _registrarPredio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Predio'),
        content: const Text('Formulario de registro de predio'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Predio registrado exitosamente')),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _liquidacionMasiva() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liquidación Masiva'),
        content: const Text(
          'Generará liquidaciones para todos los predios activos de la vigencia. '
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
                const SnackBar(content: Text('Liquidación masiva generada exitosamente')),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _liquidarPredio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liquidar Predio'),
        content: const Text('Formulario de liquidación individual'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Liquidación generada exitosamente')),
              );
            },
            child: const Text('Liquidar'),
          ),
        ],
      ),
    );
  }

  void _crearAcuerdo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Acuerdo de Pago'),
        content: const Text(
          'NOTA: Al firmar el acuerdo, el deudor pierde el derecho a prescripción '
          '(ET Art. 814). ¿Desea continuar?',
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
                const SnackBar(content: Text('Acuerdo de pago creado exitosamente')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _iniciarCobroCoactivo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Cobro Coactivo'),
        content: const Text('Formulario de inicio de proceso de cobro coactivo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proceso de cobro coactivo iniciado')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
  }
}
