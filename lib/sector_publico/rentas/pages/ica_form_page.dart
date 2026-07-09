/// Página de Formulario ICA
/// Formulario funcional para registro de censo y declaración ICA
library;

import 'package:flutter/material.dart';
import '../services/ica_service.dart';

class ICAFormPage extends StatefulWidget {
  final ICAService icaService;
  final String entidadId;
  final String usuarioId;

  const ICAFormPage({
    super.key,
    required this.icaService,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<ICAFormPage> createState() => _ICAFormPageState();
}

class _ICAFormPageState extends State<ICAFormPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _censoFormKey = GlobalKey<FormState>();
  final _declaracionFormKey = GlobalKey<FormState>();

  // Censo
  final TextEditingController _nitController = TextEditingController();
  final TextEditingController _razonSocialController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _actividadController = TextEditingController();
  TipoActividadICA? _tipoActividad;
  double _ingresosAnuales = 0;
  bool _isLoadingCenso = false;
  String? _contribuyenteId; // Guardado del registro de censo
 
  // Declaración
  final TextEditingController _periodoController = TextEditingController();
  double _baseGravable = 0;
  double _ingresosNoGravables = 0;
  double _ingresosExentos = 0;
  bool _isLoadingDeclaracion = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nitController.dispose();
    _razonSocialController.dispose();
    _direccionController.dispose();
    _actividadController.dispose();
    _periodoController.dispose();
    super.dispose();
  }

  Future<void> _registrarCenso() async {
    if (!_censoFormKey.currentState!.validate()) return;

    setState(() {
      _isLoadingCenso = true;
    });

    try {
      final resultado = await widget.icaService.registrarContribuyenteCenso(
        entidadId: widget.entidadId,
        usuarioId: widget.usuarioId,
        nit: _nitController.text,
        razonSocial: _razonSocialController.text,
        direccion: _direccionController.text,
        telefono: '', // FIXME: teléfono hardcodeado, campo pendiente de agregar en UI/backend
        tipoActividad: _tipoActividad!,
        actividadEconomica: _actividadController.text,
        ingresosAnualesEstimados: _ingresosAnuales,
      );
      if (mounted) {
        _contribuyenteId = resultado['contribuyente_id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Censo registrado exitosamente')),
        );
        _limpiarFormularioCenso();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingCenso = false;
      });
    }
  }

  Future<void> _generarDeclaracion() async {
    if (!_declaracionFormKey.currentState!.validate()) return;

    setState(() {
      _isLoadingDeclaracion = true;
    });

    try {
      if (_contribuyenteId == null) {
        throw Exception('Debe registrar el censo antes de generar declaración');
      }

      await widget.icaService.generarDeclaracionICA(
        entidadId: widget.entidadId,
        usuarioId: widget.usuarioId,
        contribuyenteId: _contribuyenteId!,
        periodo: _periodoController.text,
        periodoDeclaracion: PeriodoDeclaracionICA.bimestral, // FIXME: periodo hardcodeado, no confiable para producción
        ingresosGravables: _baseGravable,
        ingresosNoGravables: _ingresosNoGravables,
        ingresosExentos: _ingresosExentos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Declaración generada exitosamente')),
        );
        _limpiarFormularioDeclaracion();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingDeclaracion = false;
      });
    }
  }

  void _limpiarFormularioCenso() {
    _nitController.clear();
    _razonSocialController.clear();
    _direccionController.clear();
    _actividadController.clear();
    _tipoActividad = null;
    _ingresosAnuales = 0;
    _censoFormKey.currentState?.reset();
  }

  void _limpiarFormularioDeclaracion() {
    _periodoController.clear();
    _baseGravable = 0;
    _ingresosNoGravables = 0;
    _ingresosExentos = 0;
    _declaracionFormKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impuesto de Industria y Comercio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Censo'),
            Tab(text: 'Declaración'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCensoTab(),
          _buildDeclaracionTab(),
        ],
      ),
    );
  }

  Widget _buildCensoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _censoFormKey,
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
                      'Información del Contribuyente',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nitController,
                      decoration: const InputDecoration(
                        labelText: 'NIT',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese el NIT';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _razonSocialController,
                      decoration: const InputDecoration(
                        labelText: 'Razón Social',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese la razón social';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese la dirección';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TipoActividadICA>(
                      initialValue: _tipoActividad,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Actividad',
                        border: OutlineInputBorder(),
                      ),
                      items: TipoActividadICA.values.map((tipo) {
                        return DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _tipoActividad = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Seleccione el tipo de actividad';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _actividadController,
                      decoration: const InputDecoration(
                        labelText: 'Actividad Económica',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Ingresos Anuales: \$${_ingresosAnuales.toStringAsFixed(2)}'),
                    Slider(
                      value: _ingresosAnuales,
                      min: 0,
                      max: 1000000000,
                      divisions: 100,
                      label: '\$${_ingresosAnuales.toStringAsFixed(0)}',
                      onChanged: (value) {
                        setState(() {
                          _ingresosAnuales = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoadingCenso ? null : _registrarCenso,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoadingCenso
                  ? const CircularProgressIndicator()
                  : const Text('Registrar Censo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclaracionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _declaracionFormKey,
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
                      'Generar Declaración',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nitController,
                      decoration: const InputDecoration(
                        labelText: 'NIT del Contribuyente',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese el NIT';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _periodoController,
                      decoration: const InputDecoration(
                        labelText: 'Periodo (YYYY-MM)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese el periodo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Base Gravable: \$${_baseGravable.toStringAsFixed(2)}'),
                    Slider(
                      value: _baseGravable,
                      min: 0,
                      max: 100000000,
                      divisions: 100,
                      label: '\$${_baseGravable.toStringAsFixed(0)}',
                      onChanged: (value) {
                        setState(() {
                          _baseGravable = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Ingresos No Gravables: \$${_ingresosNoGravables.toStringAsFixed(2)}'),
                    Slider(
                      value: _ingresosNoGravables,
                      min: 0,
                      max: 10000000,
                      divisions: 100,
                      label: '\$${_ingresosNoGravables.toStringAsFixed(0)}',
                      onChanged: (value) {
                        setState(() {
                          _ingresosNoGravables = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Ingresos Exentos: \$${_ingresosExentos.toStringAsFixed(2)}'),
                    Slider(
                      value: _ingresosExentos,
                      min: 0,
                      max: 10000000,
                      divisions: 100,
                      label: '\$${_ingresosExentos.toStringAsFixed(0)}',
                      onChanged: (value) {
                        setState(() {
                          _ingresosExentos = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoadingDeclaracion ? null : _generarDeclaracion,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoadingDeclaracion
                  ? const CircularProgressIndicator()
                  : const Text('Generar Declaración'),
            ),
          ],
        ),
      ),
    );
  }
}
