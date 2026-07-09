import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../services/hardware_fingerprint_service.dart';
import '../services/license_validation_service.dart';
import '../services/licencia_service.dart';
import '../services/control_center_endpoint.dart';
import '../login_page.dart';

class LicenseActivationPage extends StatefulWidget {
  const LicenseActivationPage({super.key, this.onActivated});

  final VoidCallback? onActivated;

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  final HardwareFingerprintService _fingerprintService = HardwareFingerprintService();
  final LicenseValidationService _validationService = LicenseValidationService();
  final LicenciaService _licenciaService = LicenciaService.instance;
  final Dio _dio = Dio();
  
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _offlineTokenController = TextEditingController();
  
  bool _loading = false;
  bool _hasInternet = true;
  String? _hardwareFingerprint;
  String? _uuid;
  String? _errorMessage;
  bool _activationSuccess = false;
  
  // Control Center endpoint
  static const String _defaultControlCenterEndpoint = 'https://merkaerp-control-center-backend.onrender.com';
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    // Generar hardware fingerprint
    _hardwareFingerprint = await _fingerprintService.generateFingerprint();
    _uuid = await _fingerprintService.generateUUID();
    
    // Verificar conectividad
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = connectivity != ConnectivityResult.none;
    });
    
    // Verificar si ya hay una licencia activa
    final existingLicense = await _licenciaService.obtenerLicencia();
    if (existingLicense != null && existingLicense.estado == EstadoLicencia.activa) {
      setState(() {
        _activationSuccess = true;
      });
    }
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _offlineTokenController.dispose();
    super.dispose();
  }
  
  Future<void> _activateOnline() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    
    try {
      final endpoint = ControlCenterEndpoint.normalize(_defaultControlCenterEndpoint);
      final response = await _dio.post(
        ControlCenterEndpoint.activationUrl(endpoint),
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'hardware_fingerprint': _hardwareFingerprint,
          'license_type': 'SUSCRIPCION',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.data['success'] == true) {
        final token = response.data['token'];
        
        // Guardar licencia en base de datos local
        await _saveLicenseToLocal({
          'uuid': _uuid,
          'license_type': 'SUSCRIPCION',
          'estado': 'ACTIVO',
          'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'plan': 'Profesional',
          'hardware_fingerprint': _hardwareFingerprint,
          'offline_token': token,
          'modules': ['ventas', 'inventario', 'caja', 'bancos', 'cartera', 'contabilidad', 'reportes_basicos', 'reportes_avanzados'],
        });
        
        setState(() {
          _activationSuccess = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Licencia activada exitosamente')),
          );
        }
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? 'Error en activación';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
  
  Future<void> _activateOffline() async {
    if (_offlineTokenController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Ingrese el token de activación';
      });
      return;
    }
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    
    try {
      // Validar token
      final tokenData = _validationService.validateOfflineToken(
        _offlineTokenController.text.trim(),
      );
      
      if (tokenData == null) {
        setState(() {
          _errorMessage = 'Token inválido o corrupto';
        });
        return;
      }
      
      // Verificar hardware fingerprint
      final tokenFingerprint = tokenData['hfp'] as String;
      final fingerprintMatch = await _fingerprintService.validateFingerprint(tokenFingerprint);
      
      if (!fingerprintMatch) {
        setState(() {
          _errorMessage = 'El token no corresponde a este hardware';
        });
        return;
      }
      
      // Verificar expiración
      if (_validationService.isTokenExpired(tokenData)) {
        setState(() {
          _errorMessage = 'El token ha expirado';
        });
        return;
      }
      
      // Verificar estado
      if (!_validationService.isTokenActive(tokenData)) {
        setState(() {
          _errorMessage = 'El token está inactivo: ${tokenData['st']}';
        });
        return;
      }
      
      // Guardar licencia en base de datos local
      await _saveLicenseToLocal({
        'uuid': _uuid,
        'license_type': tokenData['lt'],
        'estado': tokenData['st'],
        'fecha_expiracion': tokenData['ed'],
        'plan': 'Profesional',
        'hardware_fingerprint': _hardwareFingerprint,
        'modules': tokenData['md'],
      });
      
      setState(() {
        _activationSuccess = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Licencia activada exitosamente (Offline)')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validando token: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
  
  Future<void> _saveLicenseToLocal(Map<String, dynamic> licenseData) async {
    // Guardar usando LicenciaService
    final tipoLicencia = licenseData['license_type'] == 'PERPETUA'
        ? TipoLicencia.perpetua
        : TipoLicencia.suscripcion;
    
    final estado = licenseData['estado'] == 'ACTIVO'
        ? EstadoLicencia.activa
        : EstadoLicencia.trial;
    
    final licencia = LicenciaInfo(
      uuid: _uuid ?? 'unknown',
      plan: TipoPlan.profesional,
      estado: estado,
      fechaExpiracion: DateTime.parse(licenseData['fecha_expiracion'] as String),
      modulosHabilitados: (licenseData['modules'] as List).map((e) => e.toString()).toList(),
      tipoLicencia: tipoLicencia,
      hardwareFingerprint: _hardwareFingerprint,
      offlineToken: licenseData['offline_token'] as String?,
    );
    
    await _licenciaService.guardarLicencia(licencia);
  }
  
  void _copyFingerprint() {
    if (_hardwareFingerprint != null) {
      Clipboard.setData(ClipboardData(text: _hardwareFingerprint!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hardware Fingerprint copiado')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_activationSuccess) {
      return _buildSuccessScreen();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activación de Licencia'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildHardwareInfo(),
              const SizedBox(height: 24),
              _buildConnectionStatus(),
              const SizedBox(height: 24),
              if (_hasInternet) _buildOnlineActivation() else _buildOfflineActivation(),
              const SizedBox(height: 24),
              if (_errorMessage != null) _buildErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activar MerkaERP',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _hasInternet
              ? 'Active su licencia conectándose con el Control Center'
              : 'Modo Offline - Active su licencia manualmente',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
    );
  }
  
  Widget _buildHardwareInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.computer, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Información del Hardware',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Hardware Fingerprint', _hardwareFingerprint ?? 'Generando...'),
            const SizedBox(height: 8),
            _buildInfoRow('UUID', _uuid ?? 'Generando...'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _copyFingerprint,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Fingerprint'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildConnectionStatus() {
    return Card(
      color: _hasInternet ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _hasInternet ? Icons.wifi : Icons.wifi_off,
              color: _hasInternet ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text(
              _hasInternet ? 'Conexión a Internet Disponible' : 'Sin Conexión a Internet - Modo Offline',
              style: TextStyle(
                color: _hasInternet ? Colors.green.shade800 : Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOnlineActivation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Activación Online',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'cliente@empresa.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _activateOnline,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Activar Online'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOfflineActivation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.offline_pin, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Activación Offline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ingrese el token de activación proporcionado por el equipo de soporte.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _offlineTokenController,
              decoration: const InputDecoration(
                labelText: 'Token de Activación',
                hintText: 'Pegue el token aquí...',
                prefixIcon: Icon(Icons.key),
              ),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _activateOffline,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Activar Offline'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Para obtener un token, contacte a soporte proporcionando su Hardware Fingerprint.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Licencia Activada',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MerkaERP está listo para usar',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      if (widget.onActivated != null) {
                        widget.onActivated!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(true);
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      }
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
