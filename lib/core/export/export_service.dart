// ============================================================
// export_service.dart
// Servicio de exportación a formatos contables
// ============================================================

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  ) async {
    final buffer = StringBuffer();
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2">');
    buffer.writeln('  <cbc:ID>${invoiceData['invoice_number'] ?? ''}</cbc:ID>');
    buffer.writeln('  <cbc:IssueDate>${invoiceData['issue_date'] ?? ''}</cbc:IssueDate>');
    buffer.writeln('  <cbc:InvoiceTypeCode>${invoiceData['type_code'] ?? '01'}</cbc:InvoiceTypeCode>');
    
    // Supplier
    if (invoiceData['supplier'] != null) {
      final supplier = invoiceData['supplier'] as Map<String, dynamic>;
      buffer.writeln('  <AccountingSupplierParty>');
      buffer.writeln('    <cbc:ID>${supplier['nit'] ?? ''}</cbc:ID>');
      buffer.writeln('    <Party>');
      buffer.writeln('      <PartyLegalEntity>');
      buffer.writeln('        <cbc:RegistrationName>${supplier['name'] ?? ''}</cbc:RegistrationName>');
      buffer.writeln('      </PartyLegalEntity>');
      buffer.writeln('    </Party>');
      buffer.writeln('  </AccountingSupplierParty>');
    }
    
    // Customer
    if (invoiceData['customer'] != null) {
      final customer = invoiceData['customer'] as Map<String, dynamic>;
      buffer.writeln('  <AccountingCustomerParty>');
      buffer.writeln('    <cbc:ID>${customer['nit'] ?? ''}</cbc:ID>');
      buffer.writeln('    <Party>');
      buffer.writeln('      <PartyLegalEntity>');
      buffer.writeln('        <cbc:RegistrationName>${customer['name'] ?? ''}</cbc:RegistrationName>');
      buffer.writeln('      </PartyLegalEntity>');
      buffer.writeln('    </Party>');
      buffer.writeln('  </AccountingCustomerParty>');
    }
    
    // Lines
    if (invoiceData['lines'] != null) {
      final lines = invoiceData['lines'] as List<Map<String, dynamic>>;
      buffer.writeln('  <InvoiceLine>');
      
      for (final line in lines) {
        buffer.writeln('    <ID>${line['id'] ?? ''}</ID>');
        buffer.writeln('    <InvoicedQuantity unitCode="${line['unit_code'] ?? 'NIU'}">${line['quantity'] ?? 0}</InvoicedQuantity>');
        buffer.writeln('    <LineExtensionAmount>${line['total'] ?? 0}</LineExtensionAmount>');
        buffer.writeln('    <Item>');
        buffer.writeln('      <Description>${line['description'] ?? ''}</Description>');
        buffer.writeln('    </Item>');
        buffer.writeln('    <Price>');
        buffer.writeln('      <PriceAmount>${line['unit_price'] ?? 0}</PriceAmount>');
        buffer.writeln('    </Price>');
      }
      
      buffer.writeln('  </InvoiceLine>');
    }
    
    // Totals
    buffer.writeln('  <LegalMonetaryTotal>');
    buffer.writeln('    <LineExtensionAmount>${invoiceData['subtotal'] ?? 0}</LineExtensionAmount>');
    buffer.writeln('    <TaxExclusiveAmount>${invoiceData['subtotal'] ?? 0}</TaxExclusiveAmount>');
    buffer.writeln('    <TaxInclusiveAmount>${invoiceData['total'] ?? 0}</TaxInclusiveAmount>');
    buffer.writeln('    <PayableAmount>${invoiceData['total'] ?? 0}</PayableAmount>');
    buffer.writeln('  </LegalMonetaryTotal>');
    
    buffer.writeln('</Invoice>');
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.xml');
    await file.writeAsString(buffer.toString());
    
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
