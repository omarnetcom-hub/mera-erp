import 'dart:io';

import 'package:flutter/material.dart';

import 'db_helper.dart';

class RespaldosPage extends StatefulWidget {
  const RespaldosPage({super.key});

  @override
  State<RespaldosPage> createState() => _RespaldosPageState();
}

class _RespaldosPageState extends State<RespaldosPage> {
  List<File> respaldos = [];
  bool cargando = true;

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
    final data = await DatabaseHelper.instance.obtenerRespaldos();
    if (!mounted) return;
    setState(() {
      respaldos = data;
      cargando = false;
    });
  }

  Future<void> _crearRespaldo() async {
    setState(() => cargando = true);
    final archivo = await DatabaseHelper.instance.crearRespaldo();
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Respaldo creado: ${archivo.uri.pathSegments.last}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _compartir(File archivo) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Respaldo disponible en: ${archivo.path}')),
    );
  }

  Future<void> _restaurar(File archivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'Esta acción reemplaza la base de datos actual por el respaldo seleccionado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => cargando = true);
    await DatabaseHelper.instance.restaurarRespaldo(archivo.path);
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Respaldo restaurado'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _tamano(File archivo) {
    final bytes = archivo.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: cargando ? null : _crearRespaldo,
        icon: const Icon(Icons.backup),
        label: const Text('Crear'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : respaldos.isEmpty
          ? const Center(child: Text('No hay respaldos creados'))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                itemCount: respaldos.length,
                itemBuilder: (context, index) {
                  final archivo = respaldos[index];
                  final stat = archivo.statSync();

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.storage),
                      title: Text(archivo.uri.pathSegments.last),
                      subtitle: Text('${stat.modified}\n${_tamano(archivo)}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'compartir') _compartir(archivo);
                          if (value == 'restaurar') _restaurar(archivo);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'compartir',
                            child: Text('Compartir'),
                          ),
                          PopupMenuItem(
                            value: 'restaurar',
                            child: Text('Restaurar'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
