import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'control_center_agent.dart';
import 'db_helper.dart';
import 'licensing/domain/license_models.dart';
import 'services/hardware_fingerprint_service.dart';
import 'services/licencia_service.dart';
import 'services/control_center_endpoint.dart';

class LicensingPage extends StatefulWidget {
  const LicensingPage({super.key});

  @override
  State<LicensingPage> createState() => _LicensingPageState();
}

class _LicensingPageState extends State<LicensingPage> with SingleTickerProviderStateMixin {
  final _keyController = TextEditingController();
  final _offlineTokenController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _licenseType = 'SUSCRIPCION';
  
  bool _loading = true;
  String _hardwareId = '';
  String _hardwareFingerprint = '';
  String _currentKey = '';
  String _planName = 'Enterprise Local';
  LicenseStatus _status = LicenseStatus.trial;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 30));
  static const int _maxCompanies = 5;
  static const int _maxBranches = 20;
  static const int _maxDevices = 50;
  
  late TabController _tabController;
  final HardwareFingerprintService _fingerprintService = HardwareFingerprintService();
  final LicenciaService _licenciaService = LicenciaService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLicenseData();
    _loadHardwareFingerprint();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _offlineTokenController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHardwareFingerprint() async {
    try {
      final fingerprint = await _fingerprintService.generateFingerprint();
      if (mounted) {
        setState(() {
          _hardwareFingerprint = fingerprint;
        });
      }
    } catch (e) {
      debugPrint('Error loading hardware fingerprint: $e');
    }
  }

  Future<void> _loadLicenseData() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Hardware ID
      _hardwareId = 'MERKA-${Platform.localHostname.toUpperCase()}-${Platform.operatingSystem.toUpperCase()}';
      
      // Fetch stored config
      final keyRows = await db.query('app_config', where: 'clave = ?', whereArgs: ['license_key'], limit: 1);
      if (keyRows.isNotEmpty) {
        _currentKey = keyRows.first['valor']?.toString() ?? '';
      }

      final planRows = await db.query('app_config', where: 'clave = ?', whereArgs: ['license_plan'], limit: 1);
      if (planRows.isNotEmpty) {
        _planName = planRows.first['valor']?.toString() ?? 'Enterprise Local';
      }

      final statusRows = await db.query('app_config', where: 'clave = ?', whereArgs: ['license_status'], limit: 1);
      if (statusRows.isNotEmpty) {
        final st = statusRows.first['valor']?.toString();
        if (st == 'active') _status = LicenseStatus.active;
        if (st == 'expired') _status = LicenseStatus.expired;
        if (st == 'suspended') _status = LicenseStatus.suspended;
      }

      final expireRows = await db.query('app_config', where: 'clave = ?', whereArgs: ['license_expires_at'], limit: 1);
      if (expireRows.isNotEmpty) {
        final dt = DateTime.tryParse(expireRows.first['valor']?.toString() ?? '');
        if (dt != null) _expiresAt = dt;
      }
    } catch (e) {
      debugPrint('Error loading license data: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _activateOnline() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final licenseType = _licenseType ?? 'SUSCRIPCION';
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese correo y contraseña válidos.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Obtener hardware fingerprint
      final fingerprint = await _fingerprintService.generateFingerprint();
      
      // Obtener endpoint del Control Center
      final endpointConfig = await db.query(
        'app_config',
        where: 'clave = ?',
        whereArgs: ['control_center_endpoint'],
        limit: 1,
      );
      final configuredEndpoint = endpointConfig.isNotEmpty 
          ? endpointConfig.first['valor']?.toString().trim()
          : null;
      final endpoint = ControlCenterEndpoint.normalize(configuredEndpoint);
      
      // Hacer petición HTTP al servidor online para activación
      final response = await http.post(
        Uri.parse(ControlCenterEndpoint.activationUrl(endpoint)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'hardware_fingerprint': fingerprint,
          'license_type': licenseType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final licenseData = data['license'];
          final token = data['token'];
          final userData = data['user'];
          final postgresCredentials = data['postgres_credentials'];
          
          // Guardar datos de licencia en base de datos
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_email', '$email')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_status', '${licenseData['status']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_type', '${licenseData['license_type']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_expires_at', '${licenseData['expires_at']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_token', '$token')");
          
          // Guardar límites de licencia
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_max_users', '${licenseData['max_users']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_max_devices', '${licenseData['max_devices']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_max_branches', '${licenseData['max_branches']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('license_modules', '${licenseData['modules']}')");

          // Guardar hardware fingerprint
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('hardware_fingerprint', '$fingerprint')");

          // Guardar credenciales PostgreSQL si están disponibles
          if (postgresCredentials != null) {
            await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_host', '${postgresCredentials['host']}')");
            await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_port', '${postgresCredentials['port']}')");
            await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_database', '${postgresCredentials['database']}')");
            await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_schema', '${postgresCredentials['schema']}')");
            await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_username', '${postgresCredentials['username']}')");
            await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_password', '${postgresCredentials['password']}')");
            
            if (postgresCredentials['connection_string'] != null) {
              await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('postgres_connection_string', '${postgresCredentials['connection_string']}')");
            }
          }

          // Guardar datos del usuario
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('client_id', '${userData['client_id']}')");
          await db.execute("INSERT OR REPLACE INTO app_config (clave, valor) VALUES ('client_name', '${userData['client_name']}')");

          await ControlCenterAgent.reportEvent(
            event: 'license.activated',
            module: 'licensing',
          );

          SystemSound.play(SystemSoundType.click);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('¡Licencia activada con éxito! Tipo: ${licenseData['type']}'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }

          _emailController.clear();
          _passwordController.clear();
          await _loadLicenseData();
        } else {
          throw Exception(data['error'] ?? 'Error desconocido');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al activar licencia: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _activateOffline() async {
    final token = _offlineTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese el token de activación.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final success = await _licenciaService.activarDesdeTokenOffline(token);
      
      if (success) {
        SystemSound.play(SystemSoundType.click);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Licencia activada con éxito!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }

        _offlineTokenController.clear();
        await _loadLicenseData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token inválido o expirado.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al activar licencia: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int get _daysRemaining {
    final diff = _expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final isExpired = _daysRemaining == 0 || _status == LicenseStatus.expired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Licencias Empresariales'),
        actions: [
          IconButton(
            tooltip: 'Actualizar estado',
            icon: const Icon(Icons.refresh),
            onPressed: _loadLicenseData,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExpired
                          ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                          : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpired ? PhosphorIcons.warningCircle() : PhosphorIcons.shieldCheck(),
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan Actual: $_planName',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isExpired
                                  ? 'Su licencia ha expirado. Por favor active una nueva clave para continuar operando sin restricciones.'
                                  : 'Licencia activa y sincronizada localmente con Merka Control Center.',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$_daysRemaining',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                            ),
                            const Text('Días Restantes', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Details Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: compact ? constraints.maxWidth : (constraints.maxWidth - 16) / 2,
                          child: _InfoCard(
                            title: 'Identificador de Dispositivo (HWID)',
                            value: _hardwareId,
                            icon: PhosphorIcons.desktop(),
                            copyable: true,
                            detail: 'Único para esta computadora local. Requerido para licencias offline.',
                          ),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth : (constraints.maxWidth - 16) / 2,
                          child: _InfoCard(
                            title: 'Hardware Fingerprint',
                            value: _hardwareFingerprint.isEmpty ? 'Cargando...' : _hardwareFingerprint,
                            icon: PhosphorIcons.fingerprint(),
                            copyable: true,
                            detail: 'Fingerprint para activación offline. Copie y envíe a soporte.',
                          ),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth : (constraints.maxWidth - 16) / 2,
                          child: _InfoCard(
                            title: 'Clave Registrada',
                            value: _currentKey.isEmpty ? 'MKERP-TRIAL-LOCAL-30D' : _currentKey,
                            icon: PhosphorIcons.key(),
                            copyable: true,
                            detail: 'Estado: ${_status.name.toUpperCase()}',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Activation Section with Tabs
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.lockKey(), color: const Color(0xFF2563EB), size: 24),
                          const SizedBox(width: 12),
                          const Text('Activar o Renovar Licencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Activación Online'),
                          Tab(text: 'Activación Offline'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 350,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOnlineActivationTab(),
                            _buildOfflineActivationTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Limits & Features
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Capacidades e Inclusiones del Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(height: 24),
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _FeatureMetric(label: 'Empresas Máximas', value: '$_maxCompanies'),
                          _FeatureMetric(label: 'Sucursales Permitidas', value: '$_maxBranches'),
                          _FeatureMetric(label: 'Dispositivos POS', value: '$_maxDevices'),
                          const _FeatureMetric(label: 'Facturación Electrónica DIAN', value: 'Incluido'),
                          const _FeatureMetric(label: 'Copilot IA Ilimitado', value: 'Incluido'),
                          const _FeatureMetric(label: 'Sincronización Cloud', value: 'Activa'),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineActivationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingrese su correo y contraseña para activar la licencia en línea.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Contraseña',
            prefixIcon: Icon(Icons.lock_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Tipo de licencia: '),
            DropdownButton<String>(
              value: _licenseType,
              items: const [
                DropdownMenuItem(value: 'SUSCRIPCION', child: Text('Suscripción')),
                DropdownMenuItem(value: 'PERPETUA', child: Text('Perpetua')),
              ],
              onChanged: (value) {
                setState(() => _licenseType = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _activateOnline,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('ACTIVAR EN LÍNEA', style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineActivationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingrese el token de activación offline proporcionado por el equipo de soporte.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _offlineTokenController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Pegue el token aquí...',
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _activateOffline,
                icon: const Icon(Icons.offline_pin),
                label: const Text('ACTIVAR OFFLINE', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.copyable = false,
    required this.detail,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool copyable;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4B5563)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF1F2937)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (copyable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Color(0xFF2563EB)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copiado al portapapeles'), duration: Duration(seconds: 1)),
                    );
                  },
                )
            ],
          ),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }
}

class _FeatureMetric extends StatelessWidget {
  const _FeatureMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
            ],
          )
        ],
      ),
    );
  }
}
