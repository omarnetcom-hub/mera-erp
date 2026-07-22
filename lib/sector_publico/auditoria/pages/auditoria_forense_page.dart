import 'package:flutter/material.dart';
import '../../../../db_helper.dart';
import '../../security/auditoria_service.dart';
import '../services/chip_reporter_service.dart';
import '../services/sia_observa_service.dart';
import '../services/fut_territorial_service.dart';
import '../../siif/pages/siif_page.dart';
import '../../models/registro_auditoria.dart';
import '../models/reporte_chip.dart';

class AuditoriaForensePage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;

  const AuditoriaForensePage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
  });

  @override
  State<AuditoriaForensePage> createState() => _AuditoriaForensePageState();
}

class _AuditoriaForensePageState extends State<AuditoriaForensePage> {
  int _selectedIndex = 0;
  bool _loading = true;
  late AuditoriaService _auditoriaService;
  late CHIPReporterService _chipReporterService;

  List<RegistroAuditoria> _registros = [];
  List<ReporteCHIP> _reportesChip = [];
  List<RegistroAuditoria> _anomalias = [];

  // Filtros de búsqueda
  String? _filtroModulo;
  TipoEventoAuditoria? _filtroEvento;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  final List<String> _titulos = [
    'Registros de Auditoría',
    'Reportes CHIP CGN',
    'Verificación de Integridad',
    'Alertas de Anomalías',
  ];

  @override
  void initState() {
    super.initState();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      _auditoriaService = AuditoriaService(db);
      _chipReporterService = CHIPReporterService(db: db, auditoriaService: _auditoriaService);
      await _cargarDatos();
    } catch (e) {
      _mostrarError('Error al inicializar servicios: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cargarDatos() async {
    try {
      // 1. Consultar registros de auditoría con filtros actuales
      _registros = await _auditoriaService.consultarRegistros(
        entidadId: widget.entidadId,
        modulo: _filtroModulo,
        tipoEvento: _filtroEvento,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        limite: 100,
      );

      // 2. Consultar reportes CHIP
      _reportesChip = await _chipReporterService.consultarReportes(
        entidadId: widget.entidadId,
      );

      // 3. Detectar anomalías forenses automáticamente
      await _detectarAnomalias();
    } catch (e) {
      _mostrarError('Error al cargar datos de auditoría: $e');
    }
  }

  Future<void> _detectarAnomalias() async {
    try {
      // Cargamos los últimos 500 registros para escanear anomalías
      final todos = await _auditoriaService.consultarRegistros(
        entidadId: widget.entidadId,
        limite: 500,
      );

      final tempAnomalias = <RegistroAuditoria>[];
      for (final reg in todos) {
        // Regla 1: Intentos de eliminación son anomalías críticas
        if (reg.tipoEvento == TipoEventoAuditoria.intentoEliminacion) {
          tempAnomalias.add(reg);
          continue;
        }

        // Regla 2: Transacciones hechas en horario no laboral nocturno (10 PM - 5 AM)
        final hora = reg.fechaHora.hour;
        if (hora >= 22 || hora < 5) {
          tempAnomalias.add(reg);
          continue;
        }
      }

      setState(() {
        _anomalias = tempAnomalias;
      });
    } catch (e) {
      debugPrint('Error detectando anomalías: $e');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_selectedIndex]),
        backgroundColor: const Color(0xFF006D77),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildRegistrosTab(),
                _buildReportesCHIPTab(),
                _buildIntegridadTab(),
                _buildAlertasTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF006D77),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Registros',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'CHIP CGN',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Integridad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Alertas',
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrosTab() {
    return Column(
      children: [
        _buildPanelFiltros(),
        Expanded(
          child: _registros.isEmpty
              ? const Center(child: Text('No se encontraron registros de auditoría'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _registros.length,
                  itemBuilder: (context, index) {
                    final reg = _registros[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          _getIconoEvento(reg.tipoEvento),
                          color: _getColorEvento(reg.tipoEvento),
                        ),
                        title: Text(reg.accion),
                        subtitle: Text(
                          'Módulo: ${reg.modulo} | Usuario: ${reg.usuarioNombre ?? reg.usuarioId}\nFecha: ${reg.fechaHora.toLocal()}',
                        ),
                        trailing: Text(
                          '#${reg.hashActual.substring(0, 8)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        isThreeLine: true,
                        onTap: () => _mostrarDetalleRegistro(reg),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPanelFiltros() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filtroModulo,
                  decoration: const InputDecoration(labelText: 'Módulo'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...['contabilidad', 'tesoreria', 'contratacion', 'nomina', 'transparencia', 'seguridad', 'configuracion', 'auditoria']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))),
                  ],
                  onChanged: (val) {
                    setState(() => _filtroModulo = val);
                    _cargarDatos();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<TipoEventoAuditoria>(
                  initialValue: _filtroEvento,
                  decoration: const InputDecoration(labelText: 'Evento'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...TipoEventoAuditoria.values.map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.toString().split('.').last)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _filtroEvento = val);
                    _cargarDatos();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_fechaDesde == null ? 'Desde: Inicial' : 'Desde: ${_fechaDesde!.toString().split(' ')[0]}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaDesde ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _fechaDesde = d);
                    _cargarDatos();
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_fechaHasta == null ? 'Hasta: Actual' : 'Hasta: ${_fechaHasta!.toString().split(' ')[0]}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaHasta ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _fechaHasta = d);
                    _cargarDatos();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Limpiar Filtros',
                onPressed: () {
                  setState(() {
                    _filtroModulo = null;
                    _filtroEvento = null;
                    _fechaDesde = null;
                    _fechaHasta = null;
                  });
                  _cargarDatos();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportesCHIPTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reportes CGN Historial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _dialogoGenerarCHIP,
                icon: const Icon(Icons.add),
                label: const Text('Generar Paquete CHIP'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _reportesChip.isEmpty
              ? const Center(child: Text('No hay reportes CHIP generados'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _reportesChip.length,
                  itemBuilder: (context, index) {
                    final rep = _reportesChip[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(rep.nombreFormulario),
                        subtitle: Text('Vigencia: ${rep.vigencia} | Fecha: ${rep.fechaGeneracion.toLocal().toString().split(' ')[0]}'),
                        trailing: Chip(
                          label: Text(rep.estado.toUpperCase()),
                          backgroundColor: rep.estado == 'enviado' ? Colors.green : Colors.grey,
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID de Reporte: ${rep.id}'),
                                Text('Usuario Generador: ${rep.usuarioGenero}'),
                                const Divider(),
                                const Text('Datos Reportados:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(rep.datos.toString()),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.text_snippet),
                                      label: const Text('Exportar Plano'),
                                      onPressed: () => _exportarPlanoCHIP(rep),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.verified),
                                      label: const Text('Validar Estructura'),
                                      onPressed: () => _validarEstructuraCHIP(rep),
                                    ),
                                    if (rep.estado != 'enviado') ...[
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.send),
                                        label: const Text('Marcar Enviado'),
                                        onPressed: () => _marcarEnviadoCHIP(rep),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildIntegridadTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 96, color: Color(0xFF006D77)),
          const SizedBox(height: 24),
          const Text(
            'Verificación Criptográfica de la Cadena',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'El sistema audita de forma append-only. Cada transacción calcula un hash SHA-256 que encadena criptográficamente el hash del registro anterior. '
            'Si un registro se modifica por fuera del software o se elimina de la base de datos local, la verificación fallará.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _verificarIntegridadChain,
            icon: const Icon(Icons.verified),
            label: const Text('Verificar Cadena Completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Integraciones Regulatorias Activas (Fase 4):',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Color(0xFF006D77)),
            title: const Text('Módulo SIIF Nación II (MinHacienda)'),
            subtitle: const Text('Consolidación y exportación de reportes presupuestales y financieros mensuales.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SIIFPage(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assessment, color: Color(0xFF006D77)),
            title: const Text('Rendición SIA Observa (CGR)'),
            subtitle: const Text('Consolidado anual de Contratación, Presupuesto y Nómina para Plan de Mejoramiento.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _dialogoGenerarSIAObserva,
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in, color: Color(0xFF006D77)),
            title: const Text('Reportes FUT Territorial (DNP)'),
            subtitle: const Text('Estructuración trimestral de Ingresos, Gastos, Deuda Pública y Regalías.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _dialogoGenerarFUTTerritorial,
          ),
        ],
      ),
    );
  }

  void _dialogoGenerarFUTTerritorial() {
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    int trimestreSeleccionado = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Formulario FUT Territorial (DNP)'),
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
                value: trimestreSeleccionado,
                decoration: const InputDecoration(labelText: 'Trimestre a Reportar'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Trimestre 1 (Ene-Mar)')),
                  DropdownMenuItem(value: 2, child: Text('Trimestre 2 (Abr-Jun)')),
                  DropdownMenuItem(value: 3, child: Text('Trimestre 3 (Jul-Sep)')),
                  DropdownMenuItem(value: 4, child: Text('Trimestre 4 (Oct-Dic)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => trimestreSeleccionado = val);
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
                  final db = await DatabaseHelper.instance.database;
                  final auditoria = AuditoriaService(db);
                  final service = FUTTerritorialService(db: db, auditoriaService: auditoria);

                  final rep = await service.generarFUTIngresos(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    vigencia: vigenciaCtrl.text,
                    trimestre: trimestreSeleccionado,
                  );

                  final plano = await service.exportarAPlano(rep.id);

                  if (context.mounted) {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Formulario FUT DNP Generado (.txt / CSV)'),
                        content: SingleChildScrollView(child: SelectableText(plano)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Generar y Exportar'),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogoGenerarSIAObserva() {
    final vigenciaCtrl = TextEditingController(text: DateTime.now().year.toString());
    final hallazgosCtrl = TextEditingController();
    final accionesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rendición SIA Observa (CGR)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vigenciaCtrl,
              decoration: const InputDecoration(labelText: 'Vigencia Fiscal', hintText: 'ej. 2026'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: hallazgosCtrl,
              decoration: const InputDecoration(labelText: 'Total Hallazgos Atendidos', hintText: 'ej. 10'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: accionesCtrl,
              decoration: const InputDecoration(labelText: 'Total Acciones Implementadas', hintText: 'ej. 8'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (vigenciaCtrl.text.isEmpty || hallazgosCtrl.text.isEmpty || accionesCtrl.text.isEmpty) return;
              try {
                final db = await DatabaseHelper.instance.database;
                final auditoria = AuditoriaService(db);
                final service = SIAObservaService(db: db, auditoriaService: auditoria);

                final rep = await service.generarReportePlanMejoramiento(
                  entidadId: widget.entidadId,
                  usuarioId: widget.usuarioId,
                  vigencia: vigenciaCtrl.text,
                  hallazgosAtendidos: int.parse(hallazgosCtrl.text),
                  accionesImplementadas: int.parse(accionesCtrl.text),
                );

                final plano = await service.exportarAPlano(rep.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reporte SIA Observa Generado (.txt)'),
                      content: SingleChildScrollView(child: SelectableText(plano)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Generar y Exportar'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertasTab() {
    if (_anomalias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No se detectaron anomalías en la base de datos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('Cadena de eventos e ingresos limpia.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _anomalias.length,
      itemBuilder: (context, index) {
        final anom = _anomalias[index];
        final esHoraNoLaboral = anom.fechaHora.hour >= 22 || anom.fechaHora.hour < 5;
        return Card(
          color: const Color(0xFFFFF3E0),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange),
            title: Text('Anomalía: ${anom.accion}'),
            subtitle: Text(
              '${esHoraNoLaboral ? "REGISTRO NOCTURNO INUSUAL" : "INTENTO DE ELIMINACIÓN BLOQUEADO"}\n'
              'Módulo: ${anom.modulo} | Usuario: ${anom.usuarioNombre ?? anom.usuarioId}\n'
              'Fecha: ${anom.fechaHora.toLocal()}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            isThreeLine: true,
            onTap: () => _mostrarDetalleRegistro(anom),
          ),
        );
      },
    );
  }

  IconData _getIconoEvento(TipoEventoAuditoria tipo) {
    switch (tipo) {
      case TipoEventoAuditoria.login:
        return Icons.login;
      case TipoEventoAuditoria.logout:
        return Icons.logout;
      case TipoEventoAuditoria.cambioContrasena:
        return Icons.password;
      case TipoEventoAuditoria.cambioPermiso:
        return Icons.security;
      case TipoEventoAuditoria.expedicionCDP:
      case TipoEventoAuditoria.expedicionRP:
        return Icons.assignment_turned_in;
      case TipoEventoAuditoria.modificacionCDP:
      case TipoEventoAuditoria.modificacionRP:
        return Icons.edit_attributes;
      case TipoEventoAuditoria.registroObligacion:
        return Icons.account_balance_wallet;
      case TipoEventoAuditoria.pago:
      case TipoEventoAuditoria.pagoNomina:
        return Icons.payment;
      case TipoEventoAuditoria.asientoContable:
        return Icons.book;
      case TipoEventoAuditoria.reversaAsiento:
        return Icons.settings_backup_restore;
      case TipoEventoAuditoria.cierreVigencia:
        return Icons.lock;
      case TipoEventoAuditoria.liquidacionNomina:
      case TipoEventoAuditoria.reliquidacion:
        return Icons.calculate;
      case TipoEventoAuditoria.liquidacionTributo:
        return Icons.assessment;
      case TipoEventoAuditoria.recaudoTributo:
        return Icons.attach_money;
      case TipoEventoAuditoria.inicioCobroCoactivo:
        return Icons.gavel;
      case TipoEventoAuditoria.inicioProceso:
        return Icons.work_outline;
      case TipoEventoAuditoria.adjudicacion:
        return Icons.assignment;
      case TipoEventoAuditoria.firmaContrato:
        return Icons.border_color;
      case TipoEventoAuditoria.liquidacionContrato:
        return Icons.assignment_return;
      case TipoEventoAuditoria.creacionRegistro:
        return Icons.add_circle_outline;
      case TipoEventoAuditoria.modificacionRegistro:
        return Icons.edit_note;
      case TipoEventoAuditoria.intentoEliminacion:
        return Icons.delete_forever;
    }
  }

  Color _getColorEvento(TipoEventoAuditoria tipo) {
    switch (tipo) {
      case TipoEventoAuditoria.login:
      case TipoEventoAuditoria.logout:
        return Colors.teal;
      case TipoEventoAuditoria.cambioContrasena:
      case TipoEventoAuditoria.cambioPermiso:
        return Colors.amber;
      case TipoEventoAuditoria.expedicionCDP:
      case TipoEventoAuditoria.expedicionRP:
      case TipoEventoAuditoria.creacionRegistro:
        return Colors.green;
      case TipoEventoAuditoria.modificacionCDP:
      case TipoEventoAuditoria.modificacionRP:
      case TipoEventoAuditoria.modificacionRegistro:
        return Colors.blue;
      case TipoEventoAuditoria.registroObligacion:
      case TipoEventoAuditoria.pago:
      case TipoEventoAuditoria.pagoNomina:
        return Colors.indigo;
      case TipoEventoAuditoria.asientoContable:
      case TipoEventoAuditoria.reversaAsiento:
      case TipoEventoAuditoria.cierreVigencia:
        return Colors.deepPurple;
      case TipoEventoAuditoria.liquidacionNomina:
      case TipoEventoAuditoria.reliquidacion:
      case TipoEventoAuditoria.liquidacionTributo:
      case TipoEventoAuditoria.recaudoTributo:
        return Colors.brown;
      case TipoEventoAuditoria.inicioCobroCoactivo:
        return Colors.pink;
      case TipoEventoAuditoria.inicioProceso:
      case TipoEventoAuditoria.adjudicacion:
      case TipoEventoAuditoria.firmaContrato:
      case TipoEventoAuditoria.liquidacionContrato:
        return Colors.cyan;
      case TipoEventoAuditoria.intentoEliminacion:
        return Colors.red;
    }
  }

  void _mostrarDetalleRegistro(RegistroAuditoria reg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reg.accion),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${reg.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(),
              Text('Módulo: ${reg.modulo}'),
              Text('Tipo Evento: ${reg.tipoEvento.toString().split('.').last}'),
              Text('Fecha/Hora: ${reg.fechaHora.toLocal()}'),
              Text('Usuario: ${reg.usuarioNombre ?? reg.usuarioId}'),
              Text('IP: ${reg.ipDireccion ?? "N/A"}'),
              const Divider(),
              const Text('Valor Anterior:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(reg.valorAnterior.toString()),
              const SizedBox(height: 8),
              const Text('Valor Nuevo:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(reg.valorNuevo.toString()),
              const Divider(),
              Text('Hash Anterior: ${reg.hashAnterior ?? "N/A"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              Text('Hash Actual: ${reg.hashActual}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
              if (reg.observaciones != null) ...[
                const Divider(),
                Text('Observaciones: ${reg.observaciones}'),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _dialogoGenerarCHIP() async {
    final formKey = GlobalKey<FormState>();
    final vigenciaController = TextEditingController(text: DateTime.now().year.toString());

    // Controladores institucionales y de oficiales responsables
    final representanteController = TextEditingController();
    final identificacionRepController = TextEditingController();
    final ordenadorController = TextEditingController();
    final identificacionOrdController = TextEditingController();
    final contadorController = TextEditingController();
    final identificacionContController = TextEditingController();
    final tarjetaContController = TextEditingController();
    final direccionController = TextEditingController();
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();

    // Controladores financieros / presupuestales vacíos por defecto
    final tributariosController = TextEditingController();
    final noTributariosController = TextEditingController();
    final sgpController = TextEditingController();
    final regaliasController = TextEditingController();
    final personalController = TextEditingController();
    final inversionController = TextEditingController();

    final activoCorrController = TextEditingController();
    final pasivoCorrController = TextEditingController();

    setState(() => _loading = true);
    Map<String, dynamic>? datosEntidad;
    List<Map<String, dynamic>> funcionariosResult = [];
    try {
      final db = await DatabaseHelper.instance.database;
      final entResult = await db.query(
        'entidades_territoriales',
        where: 'id = ?',
        whereArgs: [widget.entidadId],
      );
      if (entResult.isNotEmpty) {
        datosEntidad = entResult.first;
      }
      funcionariosResult = await db.query(
        'funcionarios_entidad',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
        orderBy: 'cargo_clave ASC',
      );
    } catch (e) {
      debugPrint('Error cargando datos de la entidad: $e');
    } finally {
      setState(() => _loading = false);
    }

    if (datosEntidad == null) {
      _mostrarError('No se encontró la configuración de la entidad territorial para el formulario CGN 2015_001');
      return;
    }

    // Poblar controladores con datos persistidos de funcionarios si existen
    for (final row in funcionariosResult) {
      final cargo = row['cargo_clave'] as String;
      if (cargo == 'representante_legal') {
        representanteController.text = row['nombre_completo'] as String;
        identificacionRepController.text = row['identificacion'] as String;
      } else if (cargo == 'ordenador_gasto') {
        ordenadorController.text = row['nombre_completo'] as String;
        identificacionOrdController.text = row['identificacion'] as String;
      } else if (cargo == 'contador') {
        contadorController.text = row['nombre_completo'] as String;
        identificacionContController.text = row['identificacion'] as String;
        tarjetaContController.text = row['tarjeta_profesional'] as String? ?? '';
      } else if (cargo == 'contacto_entidad') {
        direccionController.text = row['direccion'] as String;
        telefonoController.text = row['telefono'] as String;
        emailController.text = row['email'] as String;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generar Paquete CHIP CGN'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CGN 2015_001 (Datos de la Entidad):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D77))),
                  const SizedBox(height: 6),
                  Text('NIT: ${datosEntidad!['nit']}'),
                  Text('Razón Social: ${datosEntidad['razon_social']}'),
                  Text('Tipo: ${datosEntidad['tipo_entity'] ?? datosEntidad['tipo_entidad']}'),
                  const Divider(),
                  TextFormField(
                    controller: vigenciaController,
                    decoration: const InputDecoration(labelText: 'Vigencia Fiscal (Año)'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: direccionController,
                    decoration: const InputDecoration(labelText: 'Dirección Oficial de la Entidad'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: telefonoController,
                    decoration: const InputDecoration(labelText: 'Teléfono de Contacto'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Institucional'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Funcionarios Responsables (Firmas CHIP):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D77))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: representanteController,
                    decoration: const InputDecoration(labelText: 'Nombre Representante Legal'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: identificacionRepController,
                    decoration: const InputDecoration(labelText: 'Identificación Representante'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: ordenadorController,
                    decoration: const InputDecoration(labelText: 'Nombre Ordenador del Gasto'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: identificacionOrdController,
                    decoration: const InputDecoration(labelText: 'Identificación Ordenador del Gasto'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: contadorController,
                    decoration: const InputDecoration(labelText: 'Nombre Contador General'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: identificacionContController,
                    decoration: const InputDecoration(labelText: 'Identificación Contador'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: tarjetaContController,
                    decoration: const InputDecoration(labelText: 'Tarjeta Profesional Contador'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('CGN 2015_002 (Ingresos y Gastos):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D77))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: tributariosController,
                    decoration: const InputDecoration(labelText: 'Ingresos Tributarios (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: noTributariosController,
                    decoration: const InputDecoration(labelText: 'Ingresos No Tributarios (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: sgpController,
                    decoration: const InputDecoration(labelText: 'Transferencias SGP (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: regaliasController,
                    decoration: const InputDecoration(labelText: 'Regalías (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: personalController,
                    decoration: const InputDecoration(labelText: 'Gastos de Personal (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: inversionController,
                    decoration: const InputDecoration(labelText: 'Gastos de Inversión (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('CGN 2015_003 (Balance / Situación Financiera):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D77))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: activoCorrController,
                    decoration: const InputDecoration(labelText: 'Activo Corriente (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: pasivoCorrController,
                    decoration: const InputDecoration(labelText: 'Pasivo Corriente (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  setState(() => _loading = true);
                  try {
                    // 1. Persistir los funcionarios y datos de contacto oficiales de la entidad
                    await _chipReporterService.guardarFuncionariosResponsables(
                      entidadId: widget.entidadId,
                      representanteNombre: representanteController.text,
                      representanteId: identificacionRepController.text,
                      ordenadorNombre: ordenadorController.text,
                      ordenadorId: identificacionOrdController.text,
                      contadorNombre: contadorController.text,
                      contadorId: identificacionContController.text,
                      contadorTarjeta: tarjetaContController.text,
                      direccion: direccionController.text,
                      telefono: telefonoController.text,
                      email: emailController.text,
                    );

                    // 2. Construir objetos DatosCGN para procesar el reporte oficial
                    final d001 = DatosCGN2015_001(
                      nit: datosEntidad!['nit'] as String,
                      razonSocial: datosEntidad['razon_social'] as String,
                      tipoEntidad: (datosEntidad['tipo_entity'] ?? datosEntidad['tipo_entidad']) as String,
                      departamento: (datosEntidad['departamento'] ?? 'N/A') as String,
                      municipio: (datosEntidad['municipio'] ?? 'N/A') as String,
                      direccion: direccionController.text,
                      telefono: telefonoController.text,
                      email: emailController.text,
                      representanteLegal: representanteController.text,
                      identificacionRepresentante: identificacionRepController.text,
                      ordenadorGasto: ordenadorController.text,
                      identificacionOrdenador: identificacionOrdController.text,
                      contador: contadorController.text,
                      identificacionContador: identificacionContController.text,
                      tarjetaProfesionalContador: tarjetaContController.text,
                    );

                    final ingTrib = double.parse(tributariosController.text);
                    final ingNoTrib = double.parse(noTributariosController.text);
                    final sgp = double.parse(sgpController.text);
                    final reg = double.parse(regaliasController.text);
                    final gPers = double.parse(personalController.text);
                    final gInv = double.parse(inversionController.text);

                    final totalIng = ingTrib + ingNoTrib + sgp + reg;
                    final totalGast = gPers + gInv;

                    final d002 = DatosCGN2015_002(
                      ingresosTributarios: ingTrib,
                      ingresosNoTributarios: ingNoTrib,
                      transferenciasSGP: sgp,
                      regalias: reg,
                      otrosIngresos: 0,
                      totalIngresos: totalIng,
                      gastosPersonal: gPers,
                      gastosGenerales: 0,
                      transferencias: 0,
                      gastosInversion: gInv,
                      otrosGastos: 0,
                      totalGastos: totalGast,
                      resultadoOperacional: totalIng - totalGast,
                    );

                    final actCorr = double.parse(activoCorrController.text);
                    final pasCorr = double.parse(pasivoCorrController.text);
                    final pat = actCorr - pasCorr;

                    final d003 = DatosCGN2015_003(
                      activoCorriente: actCorr,
                      activoNoCorriente: 0,
                      totalActivo: actCorr,
                      pasivoCorriente: pasCorr,
                      pasivoNoCorriente: 0,
                      totalPasivo: pasCorr,
                      patrimonio: pat,
                      totalPasivoPatrimonio: actCorr,
                    );

                    final d004 = DatosCGN2015_004(
                      apropiacionInicial: totalIng,
                      adiciones: 0,
                      reducciones: 0,
                      credito: 0,
                      contraCredito: 0,
                      apropiacionDefinitiva: totalIng,
                      compromisos: totalGast,
                      obligaciones: totalGast,
                      pagos: totalGast,
                      saldoPorComprometer: totalIng - totalGast,
                    );

                    final d005 = DatosCGN2015_005(
                      deudaInterna: 0,
                      deudaExterna: 0,
                      deudaTotal: 0,
                      servicioDeuda: 0,
                      cuotaAmortizacion: 0,
                      intereses: 0,
                      deudaVencida: 0,
                    );

                    await _chipReporterService.generarPaqueteCHIP(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      vigencia: vigenciaController.text,
                      datos001: d001,
                      datos002: d002,
                      datos003: d003,
                      datos004: d004,
                      datos005: d005,
                    );

                    _mostrarExito('Paquete CHIP (CGN 2015_001 a 2015_005) generado con éxito');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al generar CHIP: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D77)),
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPlanoCHIP(ReporteCHIP rep) async {
    setState(() => _loading = true);
    try {
      final plano = await _chipReporterService.exportarAPlano(rep.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Archivo Plano CHIP - ${rep.tipoFormulario.toString().split('.').last.toUpperCase()}'),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black87,
              child: Text(
                plano,
                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarError('Error al exportar a plano: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _validarEstructuraCHIP(ReporteCHIP rep) async {
    setState(() => _loading = true);
    try {
      final plano = await _chipReporterService.exportarAPlano(rep.id);
      final res = await _chipReporterService.validarFormatoCHIP(
        formatoPlano: plano,
        tipoFormulario: rep.tipoFormulario,
      );
      final esValido = res['valido'] as bool;
      final errores = res['errores'] as List<dynamic>;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verificación de Formato CHIP CGN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    esValido ? Icons.check_circle : Icons.error,
                    color: esValido ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    esValido ? 'Estructura Correcta' : 'Estructura con Inconsistencias',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Total Líneas Validadas: ${res['total_lineas']}'),
              if (errores.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Errores de Formato/Cuadraturas:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...errores.map((e) => Text('• $e', style: const TextStyle(color: Colors.red))),
              ] else
                const Text('• Cumple con reglas de balance activo/pasivo+patrimonio.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarError('Error al validar formato CHIP: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _marcarEnviadoCHIP(ReporteCHIP rep) async {
    setState(() => _loading = true);
    try {
      await _chipReporterService.marcarEnviado(
        reporteId: rep.id,
        usuarioId: widget.usuarioId,
      );
      _mostrarExito('Estado del reporte actualizado a enviado en el control de radicación');
      await _cargarDatos();
    } catch (e) {
      _mostrarError('Error al marcar enviado: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _verificarIntegridadChain() async {
    setState(() => _loading = true);
    try {
      final esValida = await _auditoriaService.verificarIntegridadCadena(widget.entidadId);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verificación Criptográfica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                esValida ? Icons.verified_user : Icons.gpp_bad,
                size: 64,
                color: esValida ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                esValida
                    ? 'INTEGRIDAD CONFIRMADA: La secuencia completa de hashes SHA-256 está intacta. No hay registros alterados ni eliminados.'
                    : 'ALERTA DE SEGURIDAD: La secuencia de hashes está rota. Se detectaron modificaciones directas o registros eliminados en la base de datos.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarError('Error verificando integridad: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
}
