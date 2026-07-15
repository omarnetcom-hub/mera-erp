// ============================================================
// export_service.dart
// Servicio de exportación a formatos contables
// ============================================================

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../invoicing/xml/generator.dart';

class ExportService {
  static final ExportService instance = ExportService._internal();
  
  ExportService._internal();
  
  /// Exporta datos a formato CSV
  Future<File> exportToCSV(
    String filename,
    List<Map<String, dynamic>> data,
    List<String> columns,
  ) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln(columns.join(','));
    
    // Data rows
    for (final row in data) {
      final values = columns.map((col) {
        final value = row[col]?.toString() ?? '';
        // Escapar comas y comillas
        final escaped = value.replaceAll('"', '""');
        return '"$escaped"';
      }).join(',');
      buffer.writeln(values);
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.csv');
    await file.writeAsString(buffer.toString());
    
    return file;
  }
  
  /// Exporta datos a formato Excel (XLSX)
  Future<File> exportToExcel(
    String filename,
    List<Map<String, dynamic>> data,
    String sheetName,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    
    if (data.isEmpty) {
      sheet.appendRow([TextCellValue('No hay datos')]);
    } else {
      // Header
      final headers = data.first.keys.toList();
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      
      // Data rows
      for (final row in data) {
        final values = headers.map((key) => TextCellValue(row[key]?.toString() ?? '')).toList();
        sheet.appendRow(values);
      }
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.xlsx');
    final bytes = excel.encode();
    await file.writeAsBytes(bytes!);
    
    return file;
  }
  
  /// Exporta datos a formato XML DIAN (Colombia)
  Future<File> exportToXMLDIAN(
    String filename,
    Map<String, dynamic> invoiceData,
    {String? cufe}
  ) async {
    // Delegar la generación de contenido XML al generador puro
    final xml = XmlInvoiceGenerator.generateInvoiceXml(cufe: cufe, invoiceData: invoiceData);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.xml');
    await file.writeAsString(xml);

    return file;
  }
  
  /// Exporta reporte financiero a Excel con formato corporativo
  Future<File> exportFinancialReport(
    String filename,
    Map<String, dynamic> reportData,
  ) async {
    final excel = Excel.createExcel();
    
    // Configurar estilos
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('FF006D77'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FFE0F7FA'),
      horizontalAlign: HorizontalAlign.Right,
    );
    
    // Hoja de resumen
    final summarySheet = excel['Resumen'];
    summarySheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Reporte Financiero');
    summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
    
    summarySheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Fecha');
    summarySheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(reportData['date']?.toString() ?? '');
    
    summarySheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Empresa');
    summarySheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(reportData['company']?.toString() ?? '');
    
    // Ventas
    if (reportData['sales'] != null) {
      final salesSheet = excel['Ventas'];
      salesSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Ventas');
      salesSheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
      
      salesSheet.appendRow([
        TextCellValue('Producto'),
        TextCellValue('Cantidad'),
        TextCellValue('Precio Unitario'),
        TextCellValue('Total')
      ]);
      
      final sales = reportData['sales'] as List<Map<String, dynamic>>;
      for (final sale in sales) {
        salesSheet.appendRow([
          TextCellValue(sale['product']?.toString() ?? ''),
          IntCellValue(int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0),
          DoubleCellValue((sale['unit_price'] as num?)?.toDouble() ?? 0.0),
          DoubleCellValue((sale['total'] as num?)?.toDouble() ?? 0.0),
        ]);
      }
      
      // Total
      final totalRow = salesSheet.maxRows + 1;
      salesSheet.cell(CellIndex.indexByString('A$totalRow')).value = TextCellValue('Total');
      salesSheet.cell(CellIndex.indexByString('A$totalRow')).cellStyle = totalStyle;
      salesSheet.cell(CellIndex.indexByString('D$totalRow')).value = DoubleCellValue((reportData['total_sales'] as num?)?.toDouble() ?? 0.0);
      salesSheet.cell(CellIndex.indexByString('D$totalRow')).cellStyle = totalStyle;
    }
    
    // Gastos
    if (reportData['expenses'] != null) {
      final expensesSheet = excel['Gastos'];
      expensesSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Gastos');
      expensesSheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
      
      expensesSheet.appendRow([
        TextCellValue('Concepto'),
        TextCellValue('Categoría'),
        TextCellValue('Monto'),
        TextCellValue('Fecha')
      ]);
      
      final expenses = reportData['expenses'] as List<Map<String, dynamic>>;
      for (final expense in expenses) {
        expensesSheet.appendRow([
          TextCellValue(expense['concept']?.toString() ?? ''),
          TextCellValue(expense['category']?.toString() ?? ''),
          DoubleCellValue((expense['amount'] as num?)?.toDouble() ?? 0.0),
          TextCellValue(expense['date']?.toString() ?? ''),
        ]);
      }
      
      // Total
      final totalRow = expensesSheet.maxRows + 1;
      expensesSheet.cell(CellIndex.indexByString('A$totalRow')).value = TextCellValue('Total');
      expensesSheet.cell(CellIndex.indexByString('A$totalRow')).cellStyle = totalStyle;
      expensesSheet.cell(CellIndex.indexByString('C$totalRow')).value = DoubleCellValue((reportData['total_expenses'] as num?)?.toDouble() ?? 0.0);
      expensesSheet.cell(CellIndex.indexByString('C$totalRow')).cellStyle = totalStyle;
    }
    
    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.xlsx');
    final bytes = excel.encode();
    await file.writeAsBytes(bytes!);
    
    return file;
  }
  
  /// Comparte un archivo exportado
  Future<void> shareFile(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'Archivo exportado desde MerkaERP',
    );
  }
  
  /// Exporta inventario a CSV
  Future<File> exportInventoryToCSV(List<Map<String, dynamic>> inventory) async {
    final columns = [
      'id',
      'nombre',
      'codigo_barras',
      'stock',
      'costo',
      'precio',
      'impuesto_pct',
    ];
    
    return exportToCSV('inventario', inventory, columns);
  }
  
  /// Exporta ventas a CSV
  Future<File> exportSalesToCSV(List<Map<String, dynamic>> sales) async {
    final columns = [
      'id',
      'fecha',
      'producto',
      'cantidad',
      'precio_unitario',
      'total',
      'metodo_pago',
      'estado',
    ];
    
    return exportToCSV('ventas', sales, columns);
  }
  
  /// Exporta clientes a CSV
  Future<File> exportCustomersToCSV(List<Map<String, dynamic>> customers) async {
    final columns = [
      'id',
      'nombre',
      'identificacion',
      'direccion',
      'telefono',
      'email',
    ];
    
    return exportToCSV('clientes', customers, columns);
  }
}
