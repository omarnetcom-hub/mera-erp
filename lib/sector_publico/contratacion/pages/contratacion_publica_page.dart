import 'package:flutter/material.dart';
import '../../../../db_helper.dart';
import '../../security/auditoria_service.dart';
import '../../presupuesto/services/presupuesto_service.dart';
import '../services/contratacion_service.dart';
import '../services/secop_service.dart';
import '../models/proceso_contratacion.dart';
import '../models/contrato.dart';
import '../models/poliza.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class ContratacionPublicaPage extends StatefulWidget {
  final String entidadId;
  final String usuarioId;
  final int tabInicial;

  const ContratacionPublicaPage({
    super.key,
    required this.entidadId,
    required this.usuarioId,
    this.tabInicial = 0,
  });

  @override
  State<ContratacionPublicaPage> createState() => _ContratacionPublicaPageState();
}

class _ContratacionPublicaPageState extends State<ContratacionPublicaPage> {
  int _selectedIndex = 0;
  bool _loading = true;
  late ContratacionService _contratacionService;
  late SECOPService _secopService;

  List<ProcesoContratacion> _procesos = [];
  List<Contrato> _contratos = [];
  List<Poliza> _polizas = [];
  List<Map<String, dynamic>> _cdpsDisponibles = [];
  List<Map<String, dynamic>> _rpsDisponibles = [];

  final List<String> _titulos = [
    'Procesos de Contratación',
    'Contratos',
    'Pólizas de Garantía',
    'SECOP II',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.tabInicial.clamp(0, _titulos.length - 1).toInt();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final auditoriaService = AuditoriaService(db);
      final presupuestoService = PresupuestoService(db: db, auditoriaService: auditoriaService);

      _contratacionService = ContratacionService(
        db: db,
        presupuestoService: presupuestoService,
        auditoriaService: auditoriaService,
      );

      _secopService = SECOPService(
        db: db,
        auditoriaService: auditoriaService,
      );

      await _cargarDatos();
    } catch (e) {
      _mostrarError('No se pudo inicializar el módulo de Contratación. Verifica la conexión e intenta de nuevo.');
      debugPrint('Error al inicializar servicios de Contratación: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Cargar Procesos de Contratación
      final procesosResult = await db.query(
        'procesos_contratacion',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
        orderBy: 'fecha_inicio DESC',
      );
      _procesos = procesosResult.map((r) => ProcesoContratacion.fromJson(r)).toList();

      // 2. Cargar Contratos
      _contratos = await _contratacionService.consultarContratos(
        entidadId: widget.entidadId,
      );

      // 3. Cargar Pólizas (Consulta directa a tabla debido a gap de consulta global en servicio)
      final polizasResult = await db.query(
        'polizas',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
        orderBy: 'fecha_emision DESC',
      );
      _polizas = polizasResult.map((r) => Poliza.fromJson(r)).toList();

      // 4. Cargar CDPs disponibles para asociar
      _cdpsDisponibles = await db.query(
        'cdps',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
      );

      // 5. Cargar RPs disponibles
      _rpsDisponibles = await db.query(
        'rps',
        where: 'entidad_id = ?',
        whereArgs: [widget.entidadId],
      );
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildProcesosTab(),
                _buildContratosTab(),
                _buildPolizasTab(),
                _buildSECOPTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Procesos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Contratos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Pólizas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload),
            label: 'SECOP II',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _crearProceso,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.add),
            )
          : _selectedIndex == 1
              ? FloatingActionButton(
                  onPressed: _crearContrato,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(Icons.add),
                )
              : _selectedIndex == 2
                  ? FloatingActionButton(
                      onPressed: _registrarPoliza,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(Icons.add),
                    )
                  : null,
    );
  }

  Widget _buildProcesosTab() {
    if (_procesos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay procesos de contratación registrados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _crearProceso,
              icon: Icon(Icons.add),
              label: const Text('Crear Proceso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _procesos.length,
      itemBuilder: (context, index) {
        final proceso = _procesos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(proceso.numeroProceso),
            subtitle: Text('${proceso.objetoContrato} | ${CurrencyFormatter.format(proceso.valorEstimado)}'),
            trailing: Chip(
              label: Text(proceso.estado.toString().split('.').last.toUpperCase()),
              backgroundColor: _getEstadoColor(proceso.estado),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modalidad: ${proceso.modalidad.toString().split('.').last}'),
                    Text('Tipo Contrato: ${proceso.tipoContrato}'),
                    Text('Dependencia Solicitante: ${proceso.dependenciaSolicitante}'),
                    Text('Responsable: ${proceso.responsableProceso}'),
                    if (proceso.numeroCDP != null)
                      Text('CDP Asociado: ${proceso.numeroCDP}', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (proceso.secopId != null)
                      Text('ID SECOP II: ${proceso.secopId}', style: TextStyle(color: Colors.blue)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (proceso.cdpId == null)
                          TextButton.icon(
                            icon: Icon(Icons.link),
                            label: const Text('Asociar CDP'),
                            onPressed: () => _asociarCDP(proceso),
                          ),
                        if (proceso.estado == EstadoProceso.estudioPrevio && proceso.cdpId != null)
                          TextButton.icon(
                            icon: Icon(Icons.cloud_upload),
                            label: const Text('Publicar SECOP'),
                            onPressed: () => _publicarSECOP(proceso),
                          ),
                        if (proceso.estado == EstadoProceso.publicado)
                          TextButton.icon(
                            icon: Icon(Icons.gavel),
                            label: const Text('Adjudicar'),
                            onPressed: () => _adjudicarProceso(proceso),
                          ),
                        if (proceso.estado == EstadoProceso.adjudicado)
                          TextButton.icon(
                            icon: Icon(Icons.description),
                            label: const Text('Crear Contrato'),
                            onPressed: () => _crearContratoDesdeProceso(proceso),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildContratosTab() {
    if (_contratos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay contratos registrados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _crearContrato,
              icon: Icon(Icons.add),
              label: const Text('Crear Contrato'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contratos.length,
      itemBuilder: (context, index) {
        final contrato = _contratos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(contrato.numeroContrato),
            subtitle: Text('${contrato.contratistaNombre} | ${CurrencyFormatter.format(contrato.valorContrato)}'),
            trailing: Chip(
              label: Text(contrato.estado.toString().split('.').last.toUpperCase()),
              backgroundColor: _getEstadoContratoColor(contrato.estado),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Objeto: ${contrato.objetoContrato}'),
                    Text('Contratista Identificación: ${contrato.contratistaIdentificacion}'),
                    Text('CDP: ${contrato.numeroCDP} | RP: ${contrato.numeroRP}'),
                    Text('Firma: ${DateFormatter.format(contrato.fechaFirma)}'),
                    Text('Ejecución: ${DateFormatter.format(contrato.fechaInicioEjecucion)} a ${DateFormatter.format(contrato.fechaFinEjecucion)} (${contrato.duracionDias} días)'),
                    if (contrato.fechaLegalizacion != null)
                      Text('Legalizado el: ${DateFormatter.format(contrato.fechaLegalizacion!)}'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (contrato.estado == EstadoContrato.enFirma || contrato.estado == EstadoContrato.firmado)
                          TextButton.icon(
                            icon: Icon(Icons.verified),
                            label: const Text('Legalizar Contrato'),
                            onPressed: () => _legalizarContrato(contrato),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolizasTab() {
    if (_polizas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay pólizas registradas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _registrarPoliza,
              icon: Icon(Icons.add),
              label: const Text('Registrar Póliza'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _polizas.length,
      itemBuilder: (context, index) {
        final poliza = _polizas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(Icons.security, color: Theme.of(context).colorScheme.primary),
            title: Text('Póliza: ${poliza.numeroPoliza} (${poliza.tipoPoliza.toString().split('.').last})'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contrato: ${poliza.numeroContrato}'),
                Text('Aseguradora: ${poliza.aseguradora}'),
                Text('Vigencia: ${DateFormatter.format(poliza.fechaInicioVigencia)} a ${DateFormatter.format(poliza.fechaFinVigencia)}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${CurrencyFormatter.format(poliza.valorAsegurado)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  poliza.estado.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: poliza.estado == EstadoPoliza.vigente ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSECOPTab() {
    final contratosNoSincronizados = _contratos.where((c) => c.estado == EstadoContrato.legalizado).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sincronización con el Sistema Electrónico de Contratación Pública SECOP II a través de la pasarela gubernamental X-Road.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: contratosNoSincronizados.isEmpty
              ? const Center(
                  child: Text('Todos los contratos legalizados están sincronizados con SECOP II'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: contratosNoSincronizados.length,
                  itemBuilder: (context, index) {
                    final contrato = contratosNoSincronizados[index];
                    return Card(
                      child: ListTile(
                        title: Text(contrato.numeroContrato),
                        subtitle: Text('Valor: ${CurrencyFormatter.format(contrato.valorContrato)} | Contratista: ${contrato.contratistaNombre}'),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _sincronizarContrato(contrato),
                          icon: Icon(Icons.sync, size: 16),
                          label: const Text('Sincronizar'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getEstadoColor(EstadoProceso estado) {
    switch (estado) {
      case EstadoProceso.estudioPrevio:
        return Colors.grey;
      case EstadoProceso.publicado:
        return Colors.blue;
      case EstadoProceso.enEvaluacion:
        return Colors.orange;
      case EstadoProceso.adjudicado:
        return Colors.green;
      case EstadoProceso.terminado:
        return Colors.teal;
      default:
        return Colors.red;
    }
  }

  Color _getEstadoContratoColor(EstadoContrato estado) {
    switch (estado) {
      case EstadoContrato.enFirma:
        return Colors.orange;
      case EstadoContrato.firmado:
        return Colors.blue;
      case EstadoContrato.legalizado:
        return Colors.green;
      case EstadoContrato.enEjecucion:
        return Colors.indigo;
      case EstadoContrato.terminado:
        return Colors.teal;
      default:
        return Colors.red;
    }
  }

  void _crearProceso() {
    final formKey = GlobalKey<FormState>();
    final objetoController = TextEditingController();
    final valorEstimadoController = TextEditingController();
    final tipoContratoController = TextEditingController(text: 'prestacion_servicios');
    final dependenciaController = TextEditingController();
    final responsableController = TextEditingController();
    ModalidadSeleccion modalidadSeleccionada = ModalidadSeleccion.minimaCuantia;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Proceso de Contratación'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: objetoController,
                    decoration: const InputDecoration(labelText: 'Objeto del Contrato'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  DropdownButtonFormField<ModalidadSeleccion>(
                    initialValue: modalidadSeleccionada,
                    decoration: const InputDecoration(labelText: 'Modalidad de Selección'),
                    items: ModalidadSeleccion.values.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m.toString().split('.').last));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => modalidadSeleccionada = val);
                      }
                    },
                  ),
                  TextFormField(
                    controller: valorEstimadoController,
                    decoration: const InputDecoration(labelText: 'Valor Estimado'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: tipoContratoController,
                    decoration: const InputDecoration(labelText: 'Tipo de Contrato (ej. obra, suministro, consultoria)'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: dependenciaController,
                    decoration: const InputDecoration(labelText: 'Dependencia Solicitante'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: responsableController,
                    decoration: const InputDecoration(labelText: 'Responsable del Proceso'),
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
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    await _contratacionService.crearProceso(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      objetoContrato: objetoController.text,
                      modalidad: modalidadSeleccionada,
                      valorEstimado: double.parse(valorEstimadoController.text),
                      tipoContrato: tipoContratoController.text,
                      dependenciaSolicitante: dependenciaController.text,
                      responsableProceso: responsableController.text,
                    );
                    _mostrarExito('Proceso de contratación creado');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al crear proceso: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _asociarCDP(ProcesoContratacion proceso) {
    if (_cdpsDisponibles.isEmpty) {
      _mostrarError('No hay CDPs registrados en el presupuesto para asociar.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    String? cdpSeleccionado;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Asociar CDP al Proceso'),
          content: Form(
            key: formKey,
            child: DropdownButtonFormField<String>(
              initialValue: cdpSeleccionado,
              decoration: const InputDecoration(labelText: 'Seleccione CDP'),
              items: _cdpsDisponibles.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text('CDP #${c['numero_cdp']} - Saldo: ${CurrencyFormatter.format((c['saldo_disponible'] as num).toDouble())}'),
                );
              }).toList(),
              onChanged: (val) {
                setDialogState(() => cdpSeleccionado = val);
              },
              validator: (value) => value == null ? 'Requerido' : null,
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
                  final cdp = _cdpsDisponibles.firstWhere((c) => c['id'] == cdpSeleccionado);
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    await _contratacionService.asociarCDP(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      procesoId: proceso.id,
                      cdpId: cdp['id'] as String,
                      numeroCDP: cdp['numero_cdp'].toString(),
                    );
                    _mostrarExito('CDP asociado correctamente');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al asociar CDP: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
              child: const Text('Asociar'),
            ),
          ],
        ),
      ),
    );
  }

  void _publicarSECOP(ProcesoContratacion proceso) {
    final formKey = GlobalKey<FormState>();
    final nitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicar Proceso en SECOP II'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Se publicará el pliego en SECOP II vía pasarela X-Road.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: nitController,
                decoration: const InputDecoration(labelText: 'NIT de la Entidad Pública'),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
            ],
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
                Navigator.pop(context);
                setState(() => _loading = true);
                try {
                  await _secopService.publicarEnSECOP(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    procesoId: proceso.id,
                    nitEntidad: nitController.text,
                  );
                  _mostrarExito('Proceso publicado exitosamente en SECOP II');
                  await _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al publicar en SECOP II: $e');
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  void _adjudicarProceso(ProcesoContratacion proceso) {
    if (proceso.secopId == null || proceso.secopId!.isEmpty) {
      _mostrarError('Este proceso no tiene ID de SECOP II asociado, debe publicarlo primero.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final proveedorController = TextEditingController();
    final valorController = TextEditingController(text: proceso.valorEstimado.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjudicar Proceso'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Número: ${proceso.numeroProceso}'),
              Text('Objeto: ${proceso.objetoContrato}'),
              const Divider(),
              TextFormField(
                controller: proveedorController,
                decoration: const InputDecoration(labelText: 'Proveedor / Contratista Adjudicado (ID)'),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: valorController,
                decoration: const InputDecoration(labelText: 'Valor de Adjudicación'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
            ],
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
                Navigator.pop(context);
                setState(() => _loading = true);
                try {
                  await _secopService.publicarAdjudicacionSECOP(
                    entidadId: widget.entidadId,
                    usuarioId: widget.usuarioId,
                    procesoId: proceso.id,
                    secopId: proceso.secopId!,
                    proveedorId: proveedorController.text,
                    valorAdjudicacion: double.parse(valorController.text),
                  );
                  _mostrarExito('Proceso adjudicado exitosamente');
                  await _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al adjudicar: $e');
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
            child: const Text('Adjudicar'),
          ),
        ],
      ),
    );
  }

  void _crearContratoDesdeProceso(ProcesoContratacion proceso) {
    _mostrarFormularioContrato(proceso: proceso);
  }

  void _crearContrato() {
    final adjudicados = _procesos.where((p) => p.estado == EstadoProceso.adjudicado).toList();
    if (adjudicados.isEmpty) {
      _mostrarError('No hay procesos adjudicados disponibles para crear contratos.');
      return;
    }
    _mostrarFormularioContrato();
  }

  void _mostrarFormularioContrato({ProcesoContratacion? proceso}) {
    final formKey = GlobalKey<FormState>();
    final contratistaNombreController = TextEditingController();
    final contratistaIdentificacionController = TextEditingController();
    final contratistaIdController = TextEditingController();

    ProcesoContratacion? procesoSeleccionado = proceso;
    String? rpSeleccionado;

    DateTime fechaFirma = DateTime.now();
    DateTime fechaInicio = DateTime.now();
    DateTime fechaFin = DateTime.now().add(const Duration(days: 30));

    final adjudicados = _procesos.where((p) => p.estado == EstadoProceso.adjudicado).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Contrato (Ley 80)'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (proceso == null)
                    DropdownButtonFormField<ProcesoContratacion>(
                      initialValue: procesoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Proceso Adjudicado'),
                      items: adjudicados.map((p) {
                        return DropdownMenuItem(value: p, child: Text(p.numeroProceso));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          procesoSeleccionado = val;
                          rpSeleccionado = null;
                        });
                      },
                      validator: (value) => value == null ? 'Requerido' : null,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Proceso: ${proceso.numeroProceso}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: rpSeleccionado,
                    decoration: const InputDecoration(labelText: 'Registro Presupuestal (RP)'),
                    items: _rpsDisponibles.where((r) {
                      if (procesoSeleccionado == null) return false;
                      return r['cdp_id'] == procesoSeleccionado!.cdpId;
                    }).map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id'] as String,
                        child: Text('RP #${r['numero_rp']} - Valor: ${CurrencyFormatter.format((r['valor_compromiso'] as num).toDouble())}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => rpSeleccionado = val);
                    },
                    validator: (value) => value == null ? 'Requerido (Exigencia Ley 80)' : null,
                  ),
                  TextFormField(
                    controller: contratistaIdController,
                    decoration: const InputDecoration(labelText: 'ID de Contratista'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: contratistaNombreController,
                    decoration: const InputDecoration(labelText: 'Nombre / Razón Social Contratista'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: contratistaIdentificacionController,
                    decoration: const InputDecoration(labelText: 'Identificación NIT/CC'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Firma: ${fechaFirma.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaFirma,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaFirma = selected);
                          }
                        },
                        child: const Text('Fecha Firma'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Inicio: ${fechaInicio.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaInicio = selected);
                          }
                        },
                        child: const Text('Fecha Inicio'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fin: ${fechaFin.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaFin,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaFin = selected);
                          }
                        },
                        child: const Text('Fecha Fin'),
                      ),
                    ],
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
                if (formKey.currentState!.validate() && procesoSeleccionado != null) {
                  final rp = _rpsDisponibles.firstWhere((r) => r['id'] == rpSeleccionado);
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    await _contratacionService.crearContrato(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      procesoId: procesoSeleccionado!.id,
                      contratistaId: contratistaIdController.text,
                      contratistaNombre: contratistaNombreController.text,
                      contratistaIdentificacion: contratistaIdentificacionController.text,
                      cdpId: procesoSeleccionado!.cdpId!,
                      numeroCDP: procesoSeleccionado!.numeroCDP!,
                      rpId: rp['id'] as String,
                      numeroRP: rp['numero_rp'].toString(),
                      fechaFirma: fechaFirma,
                      fechaInicioEjecucion: fechaInicio,
                      fechaFinEjecucion: fechaFin,
                    );
                    _mostrarExito('Contrato creado exitosamente');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al crear contrato: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _legalizarContrato(Contrato contrato) async {
    setState(() => _loading = true);
    try {
      await _contratacionService.legalizarContrato(
        entidadId: widget.entidadId,
        usuarioId: widget.usuarioId,
        contratoId: contrato.id,
      );
      _mostrarExito('Contrato legalizado correctamente');
      await _cargarDatos();
    } catch (e) {
      _mostrarError('Error al legalizar contrato: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _registrarPoliza() {
    if (_contratos.isEmpty) {
      _mostrarError('No hay contratos registrados para asociar pólizas.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final aseguradoraController = TextEditingController();
    final valorAseguradoController = TextEditingController();
    Contrato? contratoSeleccionado;
    TipoPoliza tipoPolizaSeleccionada = TipoPoliza.cumplimiento;

    DateTime fechaInicio = DateTime.now();
    DateTime fechaFin = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar Póliza de Garantía'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Contrato>(
                    initialValue: contratoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Contrato Asociado'),
                    items: _contratos.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.numeroContrato));
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => contratoSeleccionado = val);
                    },
                    validator: (value) => value == null ? 'Requerido' : null,
                  ),
                  DropdownButtonFormField<TipoPoliza>(
                    initialValue: tipoPolizaSeleccionada,
                    decoration: const InputDecoration(labelText: 'Tipo de Póliza'),
                    items: TipoPoliza.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.toString().split('.').last));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tipoPolizaSeleccionada = val);
                      }
                    },
                  ),
                  TextFormField(
                    controller: aseguradoraController,
                    decoration: const InputDecoration(labelText: 'Aseguradora'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: valorAseguradoController,
                    decoration: const InputDecoration(labelText: 'Valor Asegurado'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Inicio: ${fechaInicio.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaInicio = selected);
                          }
                        },
                        child: const Text('Fecha Inicio'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fin: ${fechaFin.toString().split(' ')[0]}'),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: fechaFin,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => fechaFin = selected);
                          }
                        },
                        child: const Text('Fecha Fin'),
                      ),
                    ],
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
                if (formKey.currentState!.validate() && contratoSeleccionado != null) {
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  try {
                    await _contratacionService.registrarPoliza(
                      entidadId: widget.entidadId,
                      usuarioId: widget.usuarioId,
                      contratoId: contratoSeleccionado!.id,
                      numeroContrato: contratoSeleccionado!.numeroContrato,
                      tipoPoliza: tipoPolizaSeleccionada,
                      aseguradora: aseguradoraController.text,
                      valorAsegurado: double.parse(valorAseguradoController.text),
                      fechaInicioVigencia: fechaInicio,
                      fechaFinVigencia: fechaFin,
                    );
                    _mostrarExito('Póliza registrada correctamente');
                    await _cargarDatos();
                  } catch (e) {
                    _mostrarError('Error al registrar póliza: $e');
                  } finally {
                    setState(() => _loading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary
foregroundColor: Colors.white,),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _sincronizarContrato(Contrato contrato) async {
    setState(() => _loading = true);
    try {
      await _secopService.sincronizarContratoSECOP(
        entidadId: widget.entidadId,
        usuarioId: widget.usuarioId,
        contratoId: contrato.id,
        secopId: contrato.numeroContrato, // Usar número de contrato como identificador SECOP
      );
      _mostrarExito('Contrato sincronizado exitosamente con SECOP II');
      await _cargarDatos();
    } catch (e) {
      _mostrarError('Error al sincronizar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
}
