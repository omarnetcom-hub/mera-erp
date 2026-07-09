import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';

class BlindCloseScreen extends StatefulWidget {
  const BlindCloseScreen({super.key});

  @override
  State<BlindCloseScreen> createState() => _BlindCloseScreenState();
}

class _BlindCloseScreenState extends State<BlindCloseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _efectivoContadoController = TextEditingController();
  final _baseAperturaController = TextEditingController(text: '0');
  final _observacionController = TextEditingController();
  
  bool _isLoading = false;
  bool _showSummary = false;
  double? _saldoSistema;
  double? _diferencia;
  String? _errorMessage;

  @override
  void dispose() {
    _efectivoContadoController.dispose();
    _baseAperturaController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _confirmarCierre() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final efectivoContado = double.tryParse(_efectivoContadoController.text) ?? 0;
      final baseApertura = double.tryParse(_baseAperturaController.text) ?? 0;
      final observacion = _observacionController.text;

      // Obtener saldo del sistema (solo para mostrar en resumen después)
      final db = DatabaseHelper.instance;
      _saldoSistema = await db.obtenerSaldoPorCuenta('caja');

      // Llamar al método de backend con arqueo ciego
      await db.registrarCierreCaja(
        efectivoContado: efectivoContado,
        observacion: observacion,
        baseAperturaSiguiente: baseApertura,
        arqueoCiego: true,
      );

      // Calcular diferencia para mostrar en resumen
      _diferencia = efectivoContado - _saldoSistema!;

      setState(() {
        _showSummary = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _efectivoContadoController.clear();
    _baseAperturaController.text = '0';
    _observacionController.clear();
    setState(() {
      _showSummary = false;
      _saldoSistema = null;
      _diferencia = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Caja - Arqueo Ciego'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _showSummary ? _buildSummary() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
                      'Arqueo Ciego',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuenta el efectivo físico sin que el sistema te muestre cuánto debería haber.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _efectivoContadoController,
              decoration: const InputDecoration(
                labelText: 'Efectivo Contado',
                hintText: 'Ingrese el monto que cuenta físicamente',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese el efectivo contado';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Ingrese un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _baseAperturaController,
              decoration: const InputDecoration(
                labelText: 'Base para Apertura Siguiente (Opcional)',
                hintText: 'Monto a dejar en caja para el siguiente turno',
                prefixIcon: Icon(Icons.lock_open),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observacionController,
              decoration: const InputDecoration(
                labelText: 'Observación (Opcional)',
                hintText: 'Notas adicionales sobre el cierre',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
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
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmarCierre,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Confirmar Cierre'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final efectivoContado = double.tryParse(_efectivoContadoController.text) ?? 0;
    final diferenciaColor = (_diferencia ?? 0) >= 0 ? Colors.green : Colors.red;
    final diferenciaText = (_diferencia ?? 0) >= 0 ? 'Sobrante' : 'Faltante';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'Cierre Completado',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryRow(
                    'Efectivo Esperado (Sistema)',
                    '\$${_saldoSistema?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.computer,
                  ),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    'Efectivo Contado (Físico)',
                    '\$${efectivoContado.toStringAsFixed(2)}',
                    Icons.money,
                  ),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    'Diferencia ($diferenciaText)',
                    '\$${(_diferencia?.abs() ?? 0).toStringAsFixed(2)}',
                    Icons.compare_arrows,
                    color: diferenciaColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh),
            label: const Text('Realizar Otro Cierre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al Menú'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey.shade900,
          ),
        ),
      ],
    );
  }
}
