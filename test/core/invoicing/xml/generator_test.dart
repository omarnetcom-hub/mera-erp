import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/core/invoicing/xml/generator.dart';

void main() {
  test('CUFE presente cuando se pasa', () {
    final invoiceData = {
      'invoice_number': 'FE-000001',
      'issue_date': '2026-07-11T15:22:24',
      'supplier': {'nit': '900123456', 'name': 'Mi Empresa'},
      'customer': {'nit': '123456789', 'name': 'Cliente Prueba'},
      'lines': [
        {'id': 1, 'quantity': 1, 'total': 100, 'unit_price': 100, 'description': 'Prod'},
      ],
      'subtotal': 100,
      'total': 119,
    };
    final xml = XmlInvoiceGenerator.generateInvoiceXml(cufe: 'ABCDEF123', invoiceData: invoiceData);
    expect(xml.contains('<cbc:UUID schemeID="CUFE">ABCDEF123</cbc:UUID>'), isTrue);
  });

  test('CUFE ausente cuando es null', () {
    final invoiceData = {
      'invoice_number': 'FE-000002',
      'issue_date': '2026-07-11T15:22:24',
      'supplier': {'nit': '900123456', 'name': 'Mi Empresa'},
      'customer': {'nit': '123456789', 'name': 'Cliente Prueba'},
      'lines': [],
      'subtotal': 0,
      'total': 0,
    };
    final xml = XmlInvoiceGenerator.generateInvoiceXml(cufe: null, invoiceData: invoiceData);
    expect(xml.contains('cbc:UUID schemeID="CUFE"'), isFalse);
  });

  test('Estructura UBL básica presente', () {
    final invoiceData = {
      'invoice_number': 'FE-000003',
      'issue_date': '2026-07-11',
    };
    final xml = XmlInvoiceGenerator.generateInvoiceXml(cufe: null, invoiceData: invoiceData);
    expect(xml.contains('xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"'), isTrue);
    expect(xml.contains('<cbc:ID>FE-000003</cbc:ID>'), isTrue);
    expect(xml.contains('<cbc:IssueDate>2026-07-11'), isTrue);
  });
}
