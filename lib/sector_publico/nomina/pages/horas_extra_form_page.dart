/// Página de Formulario Horas Extra
/// Formulario funcional para registro de horas extra y recargos
library;

import 'package:flutter/material.dart';
import '../services/horas_extra_service.dart';

class HorasExtraFormPage extends StatefulWidget {
  final HorasExtraService horasExtraService;
  final String entidadId;
  final String usuarioId;

  const HorasExtraFormPage({
    super.key,
    required this.horasExtraService,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<HorasExtraFormPage> createState() => _HorasExtraFormPageState();
}

class _HorasExtraFormPageState extends State<HorasExtraFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _empleadoIdController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  TipoHoraExtra? _tipoHoraExtra;
  double _cantidadHoras = 0;
  double _valorHora = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _empleadoIdController.dispose();
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _registrarHorasExtra() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.horasExtraService.registrarHorasExtra(
        entidadId: widget.entidadId,
        usuarioId: widget.usuarioId,
        empleadoId: _empleadoIdController.text,
        fecha: DateTime.parse(_fechaController.text),
        tipoHoraExtra: _tipoHoraExtra!,
        cantidadHoras: _cantidadHoras,
        valorHora: _valorHora,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horas extra registradas exitosamente')),
        );
        _limpiarFormulario();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _limpiarFormulario() {
    _empleadoIdController.clear();
    _fechaController.clear();
    _tipoHoraExtra = null;
    _cantidadHoras = 0;
    _valorHora = 0;
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Horas Extra'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información del Registro',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _empleadoIdController,
                        decoration: const InputDecoration(
                          labelText: 'ID del Empleado',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese el ID del empleado';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fechaController,
                        decoration: const InputDecoration(
                          labelText: 'Fecha (YYYY-MM-DD)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese la fecha';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TipoHoraExtra>(
                        initialValue: _tipoHoraExtra,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Hora Extra',
                          border: OutlineInputBorder(),
                        ),
                        items: TipoHoraExtra.values.map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Text(_obtenerNombreTipo(tipo)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _tipoHoraExtra = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Seleccione el tipo de hora extra';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Cantidad de Horas: ${_cantidadHoras.toStringAsFixed(1)}'),
                      Slider(
                        value: _cantidadHoras,
                        min: 0,
                        max: 12,
                        divisions: 24,
                        label: '${_cantidadHoras.toStringAsFixed(1)}h',
                        onChanged: (value) {
                          setState(() {
                            _cantidadHoras = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Valor por Hora: \$${_valorHora.toStringAsFixed(0)}'),
                      Slider(
                        value: _valorHora,
                        min: 0,
                        max: 100000,
                        divisions: 100,
                        label: '\$${_valorHora.toStringAsFixed(0)}',
                        onChanged: (value) {
                          setState(() {
                            _valorHora = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_tipoHoraExtra != null && _cantidadHoras > 0 && _valorHora > 0)
                        Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cálculo Estimado',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text('Recargo: ${_obtenerRecargo(_tipoHoraExtra!)}%'),
                                Text('Valor Base: \$${(_cantidadHoras * _valorHora).toStringAsFixed(0)}'),
                                Text('Valor Total: \$${(_cantidadHoras * _valorHora * (1 + _obtenerRecargo(_tipoHoraExtra!) / 100)).toStringAsFixed(0)}'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _registrarHorasExtra,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Registrar Horas Extra'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _obtenerNombreTipo(TipoHoraExtra tipo) {
    switch (tipo) {
      case TipoHoraExtra.recargoNocturno:
        return 'Recargo Nocturno (9:00 PM - 6:00 AM)';
      case TipoHoraExtra.recargoDominical:
        return 'Recargo Dominical';
      case TipoHoraExtra.recargoFestivo:
        return 'Recargo Festivo';
      case TipoHoraExtra.extraDiurna:
        return 'Hora Extra Diurna';
      case TipoHoraExtra.extraNocturna:
        return 'Hora Extra Nocturna';
      case TipoHoraExtra.extraDominical:
        return 'Hora Extra Dominical';
      case TipoHoraExtra.extraFestivo:
        return 'Hora Extra Festiva';
    }
  }

  double _obtenerRecargo(TipoHoraExtra tipo) {
    switch (tipo) {
      case TipoHoraExtra.recargoNocturno:
        return 0.35;
      case TipoHoraExtra.recargoDominical:
        return 0.75;
      case TipoHoraExtra.recargoFestivo:
        return 0.75;
      case TipoHoraExtra.extraDiurna:
        return 0.25;
      case TipoHoraExtra.extraNocturna:
        return 0.75;
      case TipoHoraExtra.extraDominical:
        return 1.75;
      case TipoHoraExtra.extraFestivo:
        return 1.75;
    }
  }
}
