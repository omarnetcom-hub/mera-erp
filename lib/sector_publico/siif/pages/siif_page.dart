/// Página de SIIF Nación (Ministerio de Hacienda y Crédito Público)
/// Consolidación y exportación de reportes presupuestales y financieros mensuales
library;

import 'package:flutter/material.dart';
import '../../../../db_helper.dart';
import '../../security/auditoria_service.dart';
import '../services/siif_service.dart';
import '../models/reporte_siif.dart';

class SIIFPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const SIIFPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<SIIFPage> createState() => _SIIFPageState();
}

class _SIIFPageState extends State<SIIFPage> {
  bool _cargando = true;
  SIIFService? _siifService;
  List<ReporteSIIF> _reportes = [];

  @override
  void initState() {
    super.initState();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    setState(() => _cargando = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final auditoria = AuditoriaService(db);
      _siifService = SIIFService(db: db, auditoriaService: auditoria);
      await _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar SIIF Nación: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarDatos() async {
    if (_siifService == null) return;
    try {
      final list = await _siifService!.consultarReportes(entidadId: widget.entidadId);
      setState(() {
        _reportes = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reportes SIIF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIIF Nación (MinHacienda)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSIIFBanner(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReportePresupuestoDialog,
                          icon: Icon(Icons.account_balance),
                          label: const Text('Reporte Presupuesto'),
                          style: ElevatedButton.
        $full = /// Página de SIIF Nación (Ministerio de Hacienda y Crédito Público)
/// Consolidación y exportación de reportes presupuestales y financieros mensuales
library;

import 'package:flutter/material.dart';
import '../../../../db_helper.dart';
import '../../security/auditoria_service.dart';
import '../services/siif_service.dart';
import '../models/reporte_siif.dart';

class SIIFPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const SIIFPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<SIIFPage> createState() => _SIIFPageState();
}

class _SIIFPageState extends State<SIIFPage> {
  bool _cargando = true;
  SIIFService? _siifService;
  List<ReporteSIIF> _reportes = [];

  @override
  void initState() {
    super.initState();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    setState(() => _cargando = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final auditoria = AuditoriaService(db);
      _siifService = SIIFService(db: db, auditoriaService: auditoria);
      await _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar SIIF Nación: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarDatos() async {
    if (_siifService == null) return;
    try {
      final list = await _siifService!.consultarReportes(entidadId: widget.entidadId);
      setState(() {
        _reportes = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reportes SIIF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIIF Nación (MinHacienda)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSIIFBanner(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReportePresupuestoDialog,
                          icon: Icon(Icons.account_balance),
                          label: const Text('Reporte Presupuesto'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context, foregroundColor: Colors.white).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReporteTesoreriaDialog,
                          icon: Icon(Icons.payments),
                          label: const Text('Reporte Tesorería'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context, foregroundColor: Colors.white).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
.Value
        # Si ya tiene foregroundColor justo despu�s, no tocar
        if ($full -match "foregroundColor") { return $full }
        # Si termina con ), agregar foregroundColor antes del cierre
        if ($full -match '\).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReporteTesoreriaDialog,
                          icon: Icon(Icons.payments),
                          label: const Text('Reporte Tesorería'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context, foregroundColor: Colors.white).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
) {
            return $full -replace '\).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReporteTesoreriaDialog,
                          icon: Icon(Icons.payments),
                          label: const Text('Reporte Tesorería'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context, foregroundColor: Colors.white).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
, ', foregroundColor: Colors.white)'
        }
        return $full
    .colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReporteTesoreriaDialog,
                          icon: Icon(Icons.payments),
                          label: const Text('Reporte Tesorería'),
                          style: ElevatedButton.
        $full = /// Página de SIIF Nación (Ministerio de Hacienda y Crédito Público)
/// Consolidación y exportación de reportes presupuestales y financieros mensuales
library;

import 'package:flutter/material.dart';
import '../../../../db_helper.dart';
import '../../security/auditoria_service.dart';
import '../services/siif_service.dart';
import '../models/reporte_siif.dart';

class SIIFPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const SIIFPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<SIIFPage> createState() => _SIIFPageState();
}

class _SIIFPageState extends State<SIIFPage> {
  bool _cargando = true;
  SIIFService? _siifService;
  List<ReporteSIIF> _reportes = [];

  @override
  void initState() {
    super.initState();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    setState(() => _cargando = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final auditoria = AuditoriaService(db);
      _siifService = SIIFService(db: db, auditoriaService: auditoria);
      await _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar SIIF Nación: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarDatos() async {
    if (_siifService == null) return;
    try {
      final list = await _siifService!.consultarReportes(entidadId: widget.entidadId);
      setState(() {
        _reportes = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reportes SIIF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIIF Nación (MinHacienda)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSIIFBanner(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReportePresupuestoDialog,
                          icon: Icon(Icons.account_balance),
                          label: const Text('Reporte Presupuesto'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context, foregroundColor: Colors.white).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generarReporteTesoreriaDialog,
                          icon: Icon(Icons.payments),
                          label: const Text('Reporte Tesorería'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context, foregroundColor: Colors.white).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
.Value
        # Si ya tiene foregroundColor justo despu�s, no tocar
        if ($full -match "foregroundColor") { return $full }
        # Si termina con ), agregar foregroundColor antes del cierre
        if ($full -match '\).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
) {
            return $full -replace '\).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
, ', foregroundColor: Colors.white)'
        }
        return $full
    .colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Reportes SIIF Nación', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              const Text('Generación e integración mensual para el Ministerio de Hacienda'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final r = _reportes[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.description, color: Colors.white),
                                ),
                                title: Text('${r.nombreReporte} - Mes: ${r.mes} / ${r.vigencia}', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Fecha: ${r.fechaGeneracion.toString().substring(0, 16)} | Estado: ${r.estado}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _exportarPlano(r.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSIIFBanner() {
    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Módulo oficial de integración mensual SIIF Nación II (MHCP). '
              'Genera la estructura de intercambio de Presupuesto y Tesorería en formato plano .txt.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReportePresupuestoDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Presupuesto SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReportePresupuestoMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Presupuestal SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _generarReporteTesoreriaDialog() {
    if (_siifService == null) return;
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int mesSeleccionado = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Reporte Tesorería SIIF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vigenciaCtrl,
                decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mesSeleccionado,
                decoration: const InputDecoration(labelText: 'Mes a Reportar'),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('Mes $m - ${_nombreMes(m)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => mesSeleccionado = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (vigenciaCtrl.text.isEmpty) return;
                try {
                  final rep = await _siifService!.generarReporteTesoreriaMensual(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    mes: mesSeleccionado,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte Tesorería SIIF generado (#${rep.id.substring(0, 8)})')),
                    );
                  }
                  _cargarDatos();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlano(String reporteId) async {
    if (_siifService == null) return;
    try {
      final plano = await _siifService!.exportarAPlano(reporteId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archivo Plano SIIF Nación (.txt)'),
            content: SingleChildScrollView(
              child: SelectableText(plano),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar plano: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombreMes(int m) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[m - 1];
  }
}
