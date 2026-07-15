class XmlInvoiceGenerator {
  /// Generates a minimal UBL-like Invoice XML for DIAN export.
  ///
  /// - cufe: optional; if provided, inserts a UUID element for the CUFE (e.g. the
  ///   UBL element with local name cbc:UUID and attribute schemeID="CUFE")
  ///   immediately after the IssueDate element. If null, that tag is omitted.
  /// - invoiceData: expected keys: invoice_number, issue_date (ISO string or DateTime),
  ///   supplier (Map), customer (Map), lines (List<Map>), subtotal, total, type_code.
  /// - nowForIssueDate: if provided, used to fill IssueDate when invoiceData lacks it.
  ///
  /// This function is pure: no I/O, no use of UI, state, or navigation.
  static String generateInvoiceXml({
    String? cufe,
    required Map<String, dynamic> invoiceData,
    DateTime? nowForIssueDate,
  }) {
    final sb = StringBuffer();

    final id = invoiceData['invoice_number']?.toString() ?? '';
    String issueDate;
    final issueRaw = invoiceData['issue_date'];
    if (issueRaw == null) {
      issueDate = (nowForIssueDate ?? DateTime.now()).toIso8601String();
    } else if (issueRaw is DateTime) {
      issueDate = issueRaw.toIso8601String();
    } else {
      issueDate = issueRaw.toString();
    }

    final typeCode = invoiceData['type_code']?.toString() ?? '01';

    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"');
    sb.writeln('         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"');
    sb.writeln('         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">');
    sb.writeln('  <cbc:UBLVersionID>UBL 2.1</cbc:UBLVersionID>');
    sb.writeln('  <cbc:CustomizationID>DIAN 2.1: Factura Electrónica de Venta</cbc:CustomizationID>');
    sb.writeln('  <cbc:ID>$id</cbc:ID>');
    sb.writeln('  <cbc:IssueDate>$issueDate</cbc:IssueDate>');
    if (cufe != null) {
      sb.writeln('  <cbc:UUID schemeID="CUFE">$cufe</cbc:UUID>');
    }
    sb.writeln('  <cbc:InvoiceTypeCode>$typeCode</cbc:InvoiceTypeCode>');

    // Supplier
    if (invoiceData['supplier'] != null) {
      final supplier = invoiceData['supplier'] as Map<String, dynamic>;
      sb.writeln('  <cac:AccountingSupplierParty>');
      sb.writeln('    <cbc:ID>${supplier['nit'] ?? ''}</cbc:ID>');
      sb.writeln('    <cac:Party>');
      sb.writeln('      <cac:PartyLegalEntity>');
      sb.writeln('        <cbc:RegistrationName>${supplier['name'] ?? ''}</cbc:RegistrationName>');
      sb.writeln('      </cac:PartyLegalEntity>');
      sb.writeln('    </cac:Party>');
      sb.writeln('  </cac:AccountingSupplierParty>');
    }

    // Customer
    if (invoiceData['customer'] != null) {
      final customer = invoiceData['customer'] as Map<String, dynamic>;
      sb.writeln('  <cac:AccountingCustomerParty>');
      sb.writeln('    <cbc:ID>${customer['nit'] ?? ''}</cbc:ID>');
      sb.writeln('    <cac:Party>');
      sb.writeln('      <cac:PartyLegalEntity>');
      sb.writeln('        <cbc:RegistrationName>${customer['name'] ?? ''}</cbc:RegistrationName>');
      sb.writeln('      </cac:PartyLegalEntity>');
      sb.writeln('    </cac:Party>');
      sb.writeln('  </cac:AccountingCustomerParty>');
    }

    // Lines
    if (invoiceData['lines'] != null) {
      final lines = invoiceData['lines'] as List<dynamic>;
      for (final line in lines) {
        final l = line as Map<String, dynamic>;
        sb.writeln('  <cac:InvoiceLine>');
        sb.writeln('    <cbc:ID>${l['id'] ?? ''}</cbc:ID>');
        sb.writeln('    <cbc:InvoicedQuantity unitCode="${l['unit_code'] ?? 'NIU'}">${l['quantity'] ?? 0}</cbc:InvoicedQuantity>');
        sb.writeln('    <cbc:LineExtensionAmount>${l['total'] ?? 0}</cbc:LineExtensionAmount>');
        sb.writeln('    <cac:Item>');
        sb.writeln('      <cbc:Description>${l['description'] ?? ''}</cbc:Description>');
        sb.writeln('    </cac:Item>');
        sb.writeln('    <cac:Price>');
        sb.writeln('      <cbc:PriceAmount>${l['unit_price'] ?? 0}</cbc:PriceAmount>');
        sb.writeln('    </cac:Price>');
        sb.writeln('  </cac:InvoiceLine>');
      }
    }

    // Totals
    sb.writeln('  <cac:LegalMonetaryTotal>');
    sb.writeln('    <cbc:LineExtensionAmount>${invoiceData['subtotal'] ?? 0}</cbc:LineExtensionAmount>');
    sb.writeln('    <cbc:TaxExclusiveAmount>${invoiceData['subtotal'] ?? 0}</cbc:TaxExclusiveAmount>');
    sb.writeln('    <cbc:TaxInclusiveAmount>${invoiceData['total'] ?? 0}</cbc:TaxInclusiveAmount>');
    sb.writeln('    <cbc:PayableAmount>${invoiceData['total'] ?? 0}</cbc:PayableAmount>');
    sb.writeln('  </cac:LegalMonetaryTotal>');

    sb.writeln('</Invoice>');

    return sb.toString();
  }
}
