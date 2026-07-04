import 'package:flutter/material.dart';

import 'db_helper.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  List<Map<String, dynamic>> clientes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DatabaseHelper.disableAutoLoadsForTests) {
        Future.microtask(_cargar);
      }
    });
  }

  Future<void> _cargar() async {
    final data = await DatabaseHelper.instance.obtenerClientes();
    if (!mounted) return;
    setState(() => clientes = data);
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? cliente]) async {
    final nombreCtrl = TextEditingController(
      text: cliente?['nombre']?.toString() ?? '',
    );
    final documentoCtrl = TextEditingController(
      text: cliente?['documento']?.toString() ?? '',
    );
    final telefonoCtrl = TextEditingController(
      text: cliente?['telefono']?.toString() ?? '',
    );
    final direccionCtrl = TextEditingController(
      text: cliente?['direccion']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: cliente?['email']?.toString() ?? '',
    );

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(cliente == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: documentoCtrl,
                decoration: const InputDecoration(labelText: 'Documento/NIT'),
              ),
              TextField(
                controller: telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextField(
                controller: direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;

              final datos = {
                'nombre': nombre,
                'documento': documentoCtrl.text.trim(),
                'telefono': telefonoCtrl.text.trim(),
                'direccion': direccionCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'estado': 'activo',
                'fecha': DateTime.now().toIso8601String(),
              };

              if (cliente == null) {
                await DatabaseHelper.instance.insertarCliente(datos);
              } else {
                await DatabaseHelper.instance.actualizarCliente(
                  cliente['id'] as int,
                  datos,
                );
              }

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado == true) {
      await _cargar();
    }
  }

  Future<void> _eliminar(int id) async {
    await DatabaseHelper.instance.eliminarCliente(id);
    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'ELIMINAR_CLIENTE',
      entidad: 'clientes',
      entidadId: id,
      detalle: 'Cliente eliminado',
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.person_add),
        label: const Text('Cliente'),
      ),
      body: clientes.isEmpty
          ? const Center(child: Text('No hay clientes registrados'))
          : ListView.builder(
              itemCount: clientes.length,
              itemBuilder: (context, index) {
                final c = clientes[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c['nombre']?.toString() ?? ''),
                    subtitle: Text(
                      [c['documento'], c['telefono'], c['email']]
                          .where((v) => v != null && v.toString().isNotEmpty)
                          .join(' · '),
                    ),
                    onTap: () => _abrirFormulario(c),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _eliminar(c['id'] as int),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
