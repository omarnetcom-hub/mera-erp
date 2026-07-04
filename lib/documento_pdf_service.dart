import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'db_helper.dart';
import 'pdf_output_dialog.dart';

class DocumentoPdfService {
  const DocumentoPdfService._();

  static Future<File> crearFacturaVenta(Map<String, dynamic> venta) async {
    final empresa = await DatabaseHelper.instance.obtenerEmpresaConfig();
    final detalle = await DatabaseHelper.instance.obtenerDetalleVenta(
      (venta['id'] as num).toInt(),
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          _encabezadoEmpresa(empresa, 'Factura POS #${venta['id']}'),
          pw.SizedBox(height: 12),
          _bloqueDatos([
            ['Fecha', _fecha(venta['fecha']?.toString() ?? '')],
            ['Cliente', venta['cliente']?.toString() ?? 'Cliente general'],
            ['Estado', venta['estado']?.toString() ?? 'emitida'],
          ]),
          pw.SizedBox(height: 14),
          _tablaProductos(
            detalle.map((item) {
              final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
              final precio = (item['precio_unitario'] as num?)?.toDouble() ?? 0;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
              return [
                item['producto']?.toString() ?? '',
                _cantidad(cantidad),
                _moneda(precio),
                _moneda(subtotal),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          _totales(
            subtotal: (venta['subtotal'] as num?)?.toDouble() ?? 0,
            impuesto: (venta['impuesto_total'] as num?)?.toDouble() ?? 0,
            total: (venta['total'] as num?)?.toDouble() ?? 0,
          ),
        ],
      ),
    );

    return _guardarPdf(pdf, 'factura_pos_${venta['id']}.pdf');
  }

  static Future<File> crearComprobanteCompra(
    Map<String, dynamic> compra,
  ) async {
    final empresa = await DatabaseHelper.instance.obtenerEmpresaConfig();
    final detalle = await DatabaseHelper.instance.obtenerDetalleCompra(
      (compra['id'] as num).toInt(),
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          _encabezadoEmpresa(empresa, 'Comprobante de compra #${compra['id']}'),
          pw.SizedBox(height: 12),
          _bloqueDatos([
            ['Fecha', _fecha(compra['fecha']?.toString() ?? '')],
            ['Proveedor', compra['proveedor']?.toString() ?? 'Sin proveedor'],
            ['Factura proveedor', compra['numero_factura']?.toString() ?? '-'],
            ['Estado', compra['estado']?.toString() ?? ''],
          ]),
          pw.SizedBox(height: 14),
          _tablaProductos(
            detalle.map((item) {
              final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
              final costo = (item['costo_unitario'] as num?)?.toDouble() ?? 0;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
              return [
                item['producto']?.toString() ?? '',
                _cantidad(cantidad),
                _moneda(costo),
                _moneda(subtotal),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          _totales(
            subtotal: (compra['subtotal'] as num?)?.toDouble() ?? 0,
            impuesto: (compra['impuesto_total'] as num?)?.toDouble() ?? 0,
            total: (compra['total'] as num?)?.toDouble() ?? 0,
          ),
        ],
      ),
    );

    return _guardarPdf(pdf, 'comprobante_compra_${compra['id']}.pdf');
  }

  static Future<File> crearComprobanteContable(
    Map<String, dynamic> comprobante,
  ) async {
    final empresa = await DatabaseHelper.instance.obtenerEmpresaConfig();
    final detalle = await DatabaseHelper.instance.obtenerDetalleComprobante(
      (comprobante['id'] as num).toInt(),
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          _encabezadoEmpresa(
            empresa,
            'Comprobante ${comprobante['consecutivo']}',
          ),
          pw.SizedBox(height: 12),
          _bloqueDatos([
            ['Fecha', _fecha(comprobante['fecha']?.toString() ?? '')],
            ['Tipo', comprobante['tipo']?.toString() ?? ''],
            ['Concepto', comprobante['concepto']?.toString() ?? ''],
            ['Tercero', comprobante['tercero']?.toString() ?? '-'],
            ['Estado', comprobante['estado']?.toString() ?? ''],
          ]),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Cuenta', 'Descripcion', 'Debito', 'Credito'],
            data: detalle.map((linea) {
              return [
                '${linea['codigo']} ${linea['cuenta']}',
                linea['descripcion']?.toString() ?? '',
                _moneda((linea['debito'] as num?)?.toDouble() ?? 0),
                _moneda((linea['credito'] as num?)?.toDouble() ?? 0),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8F3E5),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${_moneda((comprobante['total'] as num?)?.toDouble() ?? 0)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );

    return _guardarPdf(pdf, 'comprobante_${comprobante['consecutivo']}.pdf');
  }

  static Future<void> compartir(File archivo, String asunto) async {
    await Printing.sharePdf(
      bytes: await archivo.readAsBytes(),
      filename: archivo.uri.pathSegments.last,
    );
  }

  static Future<void> imprimir(File archivo) async {
    await Printing.layoutPdf(onLayout: (_) async => archivo.readAsBytes());
  }

  /// Muestra diálogo Imprimir / Correo / Visualizar para un PDF guardado.
  static Future<void> mostrarOpcionesSalida(
    BuildContext context,
    File archivo, {
    String titulo = 'Documento PDF',
    String? emailDestino,
  }) async {
    await PdfOutputDialog.mostrar(
      context: context,
      titulo: titulo,
      emailDestino: emailDestino,
      generarBytes: () async => archivo.readAsBytes(),
    );
  }

  static pw.Widget _encabezadoEmpresa(
    Map<String, dynamic> empresa,
    String documento,
  ) {
    final nombre = empresa['nombre']?.toString().trim().isEmpty ?? true
        ? 'MerkaERP'
        : empresa['nombre'].toString();
    final logoPath = empresa['logo_path']?.toString() ?? '';
    pw.ImageProvider? logo;
    if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
      logo = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Image(logo, width: 56, height: 56, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 10),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  nombre,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if ((empresa['nit'] ?? '').toString().isNotEmpty)
                  pw.Text('NIT/Doc: ${empresa['nit']}'),
                if ((empresa['regimen'] ?? '').toString().isNotEmpty)
                  pw.Text('Regimen: ${empresa['regimen']}'),
                if ((empresa['direccion'] ?? '').toString().isNotEmpty)
                  pw.Text('Direccion: ${empresa['direccion']}'),
                if ((empresa['telefono'] ?? '').toString().isNotEmpty)
                  pw.Text('Telefono: ${empresa['telefono']}'),
                if ((empresa['email'] ?? '').toString().isNotEmpty)
                  pw.Text('Email: ${empresa['email']}'),
                if ((empresa['ciudad'] ?? '').toString().isNotEmpty)
                  pw.Text('Ciudad: ${empresa['ciudad']}'),
              ],
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.green800),
          ),
          child: pw.Text(
            documento,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _bloqueDatos(List<List<String>> filas) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF7F7F7),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: filas
            .map(
              (fila) => pw.Row(
                children: [
                  pw.SizedBox(
                    width: 95,
                    child: pw.Text(
                      fila[0],
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(child: pw.Text(fila[1])),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  static pw.Widget _tablaProductos(List<List<String>> data) {
    return pw.TableHelper.fromTextArray(
      headers: ['Producto', 'Cant.', 'Valor unit.', 'Subtotal'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE8F3E5),
      ),
    );
  }

  static pw.Widget _totales({
    required double subtotal,
    required double impuesto,
    required double total,
  }) {
    pw.Widget row(String label, String value, {bool strong = false}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.right,
              style: strong
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                  : null,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: strong
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                  : null,
            ),
          ),
        ],
      );
    }

    return pw.Column(
      children: [
        row('Subtotal', _moneda(subtotal)),
        row('Impuesto', _moneda(impuesto)),
        row('Total', _moneda(total), strong: true),
      ],
    );
  }

  static Future<File> _guardarPdf(pw.Document pdf, String nombre) async {
    final dir = await getTemporaryDirectory();
    final archivo = File(p.join(dir.path, nombre));
    await archivo.writeAsBytes(await pdf.save());
    return archivo;
  }

  static String _moneda(double valor) => '\$${valor.toStringAsFixed(2)}';

  static String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toString();

  static String _fecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String pad(int n) => n.toString().padLeft(2, '0');
      return '${pad(dt.day)}/${pad(dt.month)}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }
}
