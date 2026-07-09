import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _htmlContentController = TextEditingController();
  final _subjectController = TextEditingController();
  
  String? _selectedType;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _previewContent;

  final List<String> _templateTypes = [
    'email',
    'pdf_invoice',
    'pdf_quote',
    'pdf_receipt',
  ];

  final List<String> _availableTags = [
    '{{cliente_nombre}}',
    '{{cliente_nit}}',
    '{{cliente_direccion}}',
    '{{cliente_telefono}}',
    '{{cliente_email}}',
    '{{factura_numero}}',
    '{{factura_fecha}}',
    '{{factura_total}}',
    '{{factura_subtotal}}',
    '{{factura_impuesto}}',
    '{{empresa_nombre}}',
    '{{empresa_nit}}',
    '{{empresa_direccion}}',
    '{{empresa_telefono}}',
    '{{empresa_email}}',
    '{{vendedor_nombre}}',
    '{{metodo_pago}}',
  ];

  @override
  void dispose() {
    _htmlContentController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _guardarTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedType == null) {
      setState(() {
        _errorMessage = 'Seleccione un tipo de template';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      final companyId = await dbHelper.obtenerEmpresaActivaId();

      // Insertar o actualizar template
      await db.insert(
        'templates',
        {
          'company_id': companyId,
          'type': _selectedType,
          'html_content': _htmlContentController.text,
          'subject': _subjectController.text,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _generarPreview() async {
    if (_selectedType == null || _htmlContentController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Seleccione un tipo y complete el contenido HTML';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = DatabaseHelper.instance;
      
      // Datos de ejemplo para el preview
      final datosEjemplo = {
        'cliente_nombre': 'Juan Pérez',
        'cliente_nit': '123456789',
        'cliente_direccion': 'Calle 123 #45-67',
        'cliente_telefono': '3001234567',
        'cliente_email': 'juan.perez@email.com',
        'factura_numero': 'FV-001',
        'factura_fecha': DateTime.now().toIso8601String(),
        'factura_total': '150000.00',
        'factura_subtotal': '125000.00',
        'factura_impuesto': '25000.00',
        'empresa_nombre': 'Mi Empresa SAS',
        'empresa_nit': '900123456',
        'empresa_direccion': 'Carrera 7 #14-28',
        'empresa_telefono': '6011234567',
        'empresa_email': 'info@miempresa.com',
        'vendedor_nombre': 'María García',
        'metodo_pago': 'Efectivo',
      };

      final rendered = await db.renderizarTemplate(_selectedType!, datosEjemplo);

      setState(() {
        _previewContent = rendered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _insertTag(String tag) {
    final text = _htmlContentController.text;
    final selection = _htmlContentController.selection;
    final cursorPosition = selection.baseOffset;

    final newText = text.replaceRange(
      cursorPosition,
      cursorPosition,
      tag,
    );

    _htmlContentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorPosition + tag.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de Templates'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Generar Preview',
            onPressed: _isLoading ? null : _generarPreview,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración del Template',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Template',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedType,
                        items: _templateTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Seleccione un tipo de template';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Asunto (para emails)',
                          prefixIcon: Icon(Icons.subject),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _htmlContentController,
                        decoration: const InputDecoration(
                          labelText: 'Contenido HTML',
                          prefixIcon: Icon(Icons.code),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 15,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese el contenido HTML';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tags Disponibles:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          return ActionChip(
                            label: Text(tag),
                            onPressed: () => _insertTag(tag),
                            backgroundColor: Colors.blue.shade100,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _guardarTemplate,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Template'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_previewContent != null)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview, color: Colors.blue),
                            const SizedBox(width: 12),
                            Text(
                              'Preview del Template',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(_previewContent!),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
