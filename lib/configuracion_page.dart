import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'db_helper.dart';
import 'features/company_configuration_service.dart';
import 'features/feature_registry.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final nombreCtrl = TextEditingController();
  final nitCtrl = TextEditingController();
  final regimenCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final ciudadCtrl = TextEditingController();
  final monedaCtrl = TextEditingController(text: 'COP');
  final defaultTaxCtrl = TextEditingController(text: '19');
  final logoPathCtrl = TextEditingController();
  bool cargando = true;
  bool vatEnabled = true;
  bool withholdingEnabled = false;
  Map<String, bool> features = FeatureRegistry.defaultFeatures();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DatabaseHelper.disableAutoLoadsForTests) {
        Future.microtask(_cargar);
      }
    });
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    nitCtrl.dispose();
    regimenCtrl.dispose();
    direccionCtrl.dispose();
    telefonoCtrl.dispose();
    emailCtrl.dispose();
    ciudadCtrl.dispose();
    monedaCtrl.dispose();
    defaultTaxCtrl.dispose();
    logoPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final data = await DatabaseHelper.instance.obtenerEmpresaConfig();
    final companyConfig = await CompanyConfigurationService.instance.loadActive(
      force: true,
    );
    if (!mounted) return;
    nombreCtrl.text = data['nombre']?.toString() ?? 'MerkaERP';
    nitCtrl.text = data['nit']?.toString() ?? '';
    regimenCtrl.text = data['regimen']?.toString() ?? '';
    direccionCtrl.text = data['direccion']?.toString() ?? '';
    telefonoCtrl.text = data['telefono']?.toString() ?? '';
    emailCtrl.text = data['email']?.toString() ?? '';
    ciudadCtrl.text = data['ciudad']?.toString() ?? '';
    monedaCtrl.text = data['moneda']?.toString() ?? 'COP';
    logoPathCtrl.text = data['logo_path']?.toString() ?? '';
    features = companyConfig.features;
    vatEnabled = companyConfig.settings['vat_enabled'] != '0';
    withholdingEnabled = companyConfig.settings['withholding_enabled'] == '1';
    defaultTaxCtrl.text = companyConfig.settings['default_tax'] ?? '19';
    setState(() => cargando = false);
  }

  Future<void> _guardar() async {
    await DatabaseHelper.instance.guardarEmpresaConfig({
      'nombre': nombreCtrl.text.trim(),
      'nit': nitCtrl.text.trim(),
      'regimen': regimenCtrl.text.trim(),
      'direccion': direccionCtrl.text.trim(),
      'telefono': telefonoCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'ciudad': ciudadCtrl.text.trim(),
      'moneda': monedaCtrl.text.trim().isEmpty ? 'COP' : monedaCtrl.text.trim(),
      'logo_path': logoPathCtrl.text.trim(),
    });

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'ACTUALIZAR_EMPRESA',
      entidad: 'empresa_config',
      entidadId: 1,
      detalle: 'Configuración de empresa actualizada',
    );
    await CompanyConfigurationService.instance.updateFeatures(features);
    await CompanyConfigurationService.instance.updateSettings({
      'currency': monedaCtrl.text.trim().isEmpty
          ? 'COP'
          : monedaCtrl.text.trim(),
      'vat_enabled': vatEnabled ? '1' : '0',
      'withholding_enabled': withholdingEnabled ? '1' : '0',
      'default_tax': vatEnabled ? defaultTaxCtrl.text.trim() : '0',
      'tax_regime': regimenCtrl.text.trim(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración guardada'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _featuresCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capacidades empresariales',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Activa solo los modulos que la empresa realmente usa.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...FeatureRegistry.definitions.map(
              (feature) => SwitchListTile(
                dense: true,
                value: features[feature.key] ?? false,
                title: Text(feature.name),
                subtitle: Text(feature.description),
                onChanged: (value) {
                  setState(() {
                    features[feature.key] = value;
                    if (value) {
                      for (final dependency in feature.dependencies) {
                        features[dependency] = true;
                      }
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fiscalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reglas fiscales',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Estas reglas alimentan impuestos sugeridos en inventario, compras y ventas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: vatEnabled,
              title: const Text('IVA habilitado'),
              subtitle: const Text(
                'Si se desactiva, solo se usara impuesto 0%.',
              ),
              onChanged: (value) => setState(() => vatEnabled = value),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: withholdingEnabled,
              title: const Text('Retenciones'),
              subtitle: const Text(
                'Prepara reportes y parametros tributarios.',
              ),
              onChanged: (value) => setState(() => withholdingEnabled = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: defaultTaxCtrl,
              enabled: vatEnabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Impuesto predeterminado (%)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _seleccionarLogo() async {
    final result = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    final path = result?.path;
    if (path == null) return;
    setState(() => logoPathCtrl.text = path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _campo(nombreCtrl, 'Nombre de la empresa'),
                _campo(nitCtrl, 'NIT / documento'),
                _campo(regimenCtrl, 'Régimen tributario'),
                _campo(direccionCtrl, 'Dirección'),
                _campo(telefonoCtrl, 'Teléfono'),
                _campo(emailCtrl, 'Email'),
                _campo(ciudadCtrl, 'Ciudad'),
                _campo(monedaCtrl, 'Moneda'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Imagen institucional',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (logoPathCtrl.text.isNotEmpty &&
                            File(logoPathCtrl.text).existsSync())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Image.file(
                              File(logoPathCtrl.text),
                              height: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                        TextField(
                          controller: logoPathCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ruta del logo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _seleccionarLogo,
                          icon: const Icon(Icons.image),
                          label: const Text('Cargar logo'),
                        ),
                      ],
                    ),
                  ),
                ),
                _fiscalCard(),
                _featuresCard(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ],
            ),
    );
  }
}
