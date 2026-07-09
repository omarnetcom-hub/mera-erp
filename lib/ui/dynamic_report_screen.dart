import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

class DynamicReportScreen extends StatefulWidget {
  const DynamicReportScreen({super.key});

  @override
  State<DynamicReportScreen> createState() => _DynamicReportScreenState();
}

class _DynamicReportScreenState extends State<DynamicReportScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedTable;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String? _groupBy;
  final Map<String, dynamic> _filters = {};
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];
  String? _errorMessage;

  final List<String> _availableTables = [
    'ventas',
    'compras',
    'productos',
    'clientes',
    'proveedores',
    'cuentas_por_cobrar',
    'cuentas_por_pagar',
    'movimientos_inventario',
    'cierres_caja',
  ];

  final List<String> _groupByOptions = [
    'cliente',
    'producto',
    'fecha',
    'metodo_pago',
    'categoria',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Dinámicos'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          if (_reportData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Exportar CSV',
              onPressed: _exportToCSV,
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
                        'Configuración del Reporte',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Tabla',
                          prefixIcon: Icon(Icons.table_chart),
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedTable,
                        items: _availableTables.map((table) {
                          return DropdownMenuItem(
                            value: table,
                            child: Text(table.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTable = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Seleccione una tabla';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Fecha Desde',
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _fechaDesde = null;
                                    });
                                  },
                                ),
                              ),
                              readOnly: true,
                              controller: TextEditingController(
                                text: _fechaDesde != null
                                    ? DateFormat('yyyy-MM-dd').format(_fechaDesde!)
                                    : '',
                              ),
                              onTap: () => _selectDate(context, true),
                              validator: (value) {
                                if (_fechaDesde == null) {
                                  return 'Seleccione fecha desde';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Fecha Hasta',
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _fechaHasta = null;
                                    });
                                  },
                                ),
                              ),
                              readOnly: true,
                              controller: TextEditingController(
                                text: _fechaHasta != null
                                    ? DateFormat('yyyy-MM-dd').format(_fechaHasta!)
                                    : '',
                              ),
                              onTap: () => _selectDate(context, false),
                              validator: (value) {
                                if (_fechaHasta == null) {
                                  return 'Seleccione fecha hasta';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Agrupar Por (Opcional)',
                          prefixIcon: Icon(Icons.group_work),
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _groupBy,
                        items: _groupByOptions.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _groupBy = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generarReporte,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Generar Reporte'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
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
              else if (_reportData.isNotEmpty)
                _buildDataTable()
              else
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.description,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Configure los filtros y genere un reporte',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fechaDesde = picked;
        } else {
          _fechaHasta = picked;
        }
      });
    }
  }

  Future<void> _generarReporte() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTable == null) {
      setState(() {
        _errorMessage = 'Seleccione una tabla';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _reportData = [];
    });

    try {
      final db = DatabaseHelper.instance;
      final data = await db.generarReporteDinamico(
        tabla: _selectedTable!,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        groupBy: _groupBy,
        filters: _filters,
      );

      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildDataTable() {
    if (_reportData.isEmpty) {
      return const SizedBox.shrink();
    }

    final columns = _reportData.first.keys.toList();

    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Resultados: ${_reportData.length} registros',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _selectedTable?.toUpperCase() ?? '',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns.map((column) {
                return DataColumn(
                  label: Text(
                    column.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              rows: _reportData.map((row) {
                return DataRow(
                  cells: columns.map((column) {
                    final value = row[column]?.toString() ?? '';
                    return DataCell(
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    if (_reportData.isEmpty) return;

    try {
      final columns = _reportData.first.keys.toList();
      final csv = StringBuffer();

      // Header
      csv.writeln(columns.join(','));

      // Data
      for (final row in _reportData) {
        final values = columns.map((column) {
          final value = row[column]?.toString() ?? '';
          // Escape quotes and wrap in quotes if contains comma
          final escaped = value.replaceAll('"', '""');
          if (escaped.contains(',') || escaped.contains('"')) {
            return '"$escaped"';
          }
          return escaped;
        }).join(',');
        csv.writeln(values);
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV copiado al portapapeles'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
