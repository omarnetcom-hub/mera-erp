import 'package:flutter/material.dart';

import 'db_helper.dart';

class EmpresasPage extends StatefulWidget {
  const EmpresasPage({super.key});

  @override
  State<EmpresasPage> createState() => _EmpresasPageState();
}

class _EmpresasPageState extends State<EmpresasPage> {
  List<Map<String, dynamic>> empresas = [];
  Map<String, dynamic> activa = const {};

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
    final data = await DatabaseHelper.instance.obtenerEmpresas();
    final empresaActiva = await DatabaseHelper.instance.obtenerEmpresaConfig();
    if (!mounted) return;
    setState(() {
      empresas = data;
      activa = empresaActiva;
    });
  }

  Future<void> _nueva({Map<String, dynamic>? empresa}) async {
    final nombreCtrl = TextEditingController(text: empresa?['nombre']?.toString() ?? '');
    final nitCtrl = TextEditingController(text: empresa?['nit']?.toString() ?? '');
    final ciudadCtrl = TextEditingController(text: empresa?['ciudad']?.toString() ?? '');
    final monedaCtrl = TextEditingController(text: empresa?['moneda']?.toString() ?? 'COP');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(empresa == null ? 'Nueva empresa' : 'Editar empresa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: nitCtrl,
                decoration: const InputDecoration(labelText: 'NIT / documento'),
              ),
              TextField(
                controller: ciudadCtrl,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              TextField(
                controller: monedaCtrl,
                decoration: const InputDecoration(labelText: 'Moneda'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              if (empresa == null) {
                await DatabaseHelper.instance.guardarEmpresa({
                  'nombre': nombreCtrl.text.trim(),
                  'nit': nitCtrl.text.trim(),
                  'ciudad': ciudadCtrl.text.trim(),
                  'moneda': monedaCtrl.text.trim().isEmpty
                      ? 'COP'
                      : monedaCtrl.text.trim(),
                });
              } else {
                await DatabaseHelper.instance.actualizarEmpresa(
                  empresa['id'] as int,
                  {
                    'nombre': nombreCtrl.text.trim(),
                    'nit': nitCtrl.text.trim(),
                    'ciudad': ciudadCtrl.text.trim(),
                    'moneda': monedaCtrl.text.trim().isEmpty
                        ? 'COP'
                        : monedaCtrl.text.trim(),
                  },
                );
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true) await _cargar();
  }

  Future<void> _seleccionar(Map<String, dynamic> empresa) async {
    await DatabaseHelper.instance.seleccionarEmpresa(empresa);
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Empresa activa: ${empresa['nombre']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreActivo = activa['nombre']?.toString() ?? 'MerkaERP';
    return Scaffold(
      appBar: AppBar(title: const Text('Empresas y Sucursales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nueva(),
        icon: const Icon(Icons.add_business),
        label: const Text('Empresa'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.domain),
              title: const Text('Empresa activa'),
              subtitle: Text(nombreActivo),
            ),
          ),
          const SizedBox(height: 8),
          if (empresas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay empresas adicionales. El perfil actual se administra en Configuración.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...empresas.map(
              (empresa) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      (empresa['nombre']?.toString() ?? 'E')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(empresa['nombre']?.toString() ?? ''),
                  subtitle: Text(
                    'NIT: ${empresa['nit'] ?? ''} · ${empresa['ciudad'] ?? ''} · ${empresa['moneda'] ?? 'COP'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _nueva(empresa: empresa),
                        tooltip: 'Editar empresa',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Eliminar empresa'),
                              content: const Text('¿Está seguro de eliminar esta empresa?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await DatabaseHelper.instance.eliminarEmpresa(empresa['id'] as int);
                            await _cargar();
                          }
                        },
                        tooltip: 'Eliminar empresa',
                      ),
                      FilledButton.tonal(
                        onPressed: () => _seleccionar(empresa),
                        child: const Text('Usar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
