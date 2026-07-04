import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Diálogo con opciones de salida para documentos PDF.
class PdfOutputDialog {
  static Future<void> mostrar({
    required BuildContext context,
    required String titulo,
    required Future<Uint8List> Function() generarBytes,
    String? emailDestino,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: const Text('Seleccione cómo desea procesar el documento PDF:'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir'),
            onPressed: () async {
              Navigator.pop(ctx);
              final bytes = await generarBytes();
              await Printing.layoutPdf(onLayout: (_) async => bytes);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.email),
            label: const Text('Enviar correo'),
            onPressed: () async {
              Navigator.pop(ctx);
              if (!context.mounted) return;
              await _simularCorreo(context, emailDestino);
              final bytes = await generarBytes();
              await Printing.sharePdf(bytes: bytes, filename: 'documento.pdf');
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Visualizar'),
            onPressed: () async {
              Navigator.pop(ctx);
              final bytes = await generarBytes();
              await Printing.layoutPdf(onLayout: (_) async => bytes);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _simularCorreo(BuildContext context, String? email) async {
    final ctrl = TextEditingController(text: email ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar por correo'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Correo destinatario',
            prefixIcon: Icon(Icons.email),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF preparado para envío a ${ctrl.text.trim()}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
