import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../db_helper.dart';
import '../../sector_publico/security/roles_permisos_service.dart';

enum ModoOperacion { privada, publica }

class SelectorModoService {
  /// Obtiene el modo de operación guardado para la empresa activa.
  /// Si no existe, retorna null para indicar que no se ha configurado de forma explícita.
  static Future<ModoOperacion?> obtenerModoActual() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final companyRows = await db.query(
        'app_config',
        where: 'clave = ?',
        whereArgs: ['company_active_id'],
        limit: 1,
      );
      final companyIdStr = companyRows.isNotEmpty
          ? companyRows.first['valor']?.toString()
          : '1';
      final companyId = int.tryParse(companyIdStr ?? '1') ?? 1;

      final rows = await db.query(
        'company_settings',
        where: 'company_id = ? AND setting_key = ?',
        whereArgs: [companyId, 'tipo_entidad'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final val = rows.first['setting_value']?.toString();
        if (val == 'publica') return ModoOperacion.publica;
        if (val == 'privada') return ModoOperacion.privada;
      }
    } catch (e) {
      debugPrint('Error al obtener modo de operación: $e');
    }
    return null;
  }

  /// Verifica si un usuario tiene autoridad para reconfigurar el marco normativo del ERP
  /// REGLA FAIL-CLOSED:
  /// - En Sector Público: Solo Alcalde / Representante Legal o Secretario de Hacienda.
  /// - En Sector Comercial: Solo Administrador ('administrador').
  /// - Sin rol vinculado o sin match: Retorna FALSE.
  static Future<bool> tieneAutoridadReconfiguracion({
    required Database db,
    required String entidadId,
    required dynamic usuarioId,
  }) async {
    if (usuarioId == null) return false;
    final usuarioIdStr = usuarioId.toString().trim();
    if (usuarioIdStr.isEmpty ||
        usuarioIdStr == 'null' ||
        usuarioIdStr == 'sin_sesion') {
      return false;
    }

    // 1. Verificar si es funcionario del Sector Público
    final rolPublico = await RolesPermisosService.obtenerRolUsuarioEnEntidad(
      db: db,
      entidadId: entidadId,
      usuarioId: usuarioIdStr,
    );

    if (rolPublico != null) {
      return rolPublico == RolSectorPublico.alcaldeRepresentanteLegal ||
          rolPublico == RolSectorPublico.secretarioHacienda;
    }

    // 2. Verificar rol en el sistema comercial (tabla usuarios)
    try {
      final res = await db.query(
        'usuarios',
        where: 'id = ? OR usuario = ?',
        whereArgs: [usuarioIdStr, usuarioIdStr],
      );

      if (res.isNotEmpty) {
        final rolComercial = res.first['rol']?.toString()?.toLowerCase();
        return rolComercial == 'administrador';
      }
    } catch (_) {
      // Ignorar si la tabla no existe en la prueba actual
    }

    // Fail-Closed: Sin rol verificado, denegar autoridad
    return false;
  }

  /// Guarda el modo de operación con validación de seguridad Fail-Closed
  static Future<void> guardarModo({
    Database? database,
    required String entidadId,
    required dynamic usuarioId,
    required ModoOperacion modo,
  }) async {
    final db = database ?? await DatabaseHelper.instance.database;

    final autorizado = await tieneAutoridadReconfiguracion(
      db: db,
      entidadId: entidadId,
      usuarioId: usuarioId,
    );

    if (!autorizado) {
      throw Exception(
        'Acceso denegado: El usuario $usuarioId no tiene autoridad (Alcalde/Representante Legal o Administrador) '
        'para reconfigurar el marco normativo del ERP en la entidad $entidadId.',
      );
    }

    final companyRows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['company_active_id'],
      limit: 1,
    );
    final companyIdStr = companyRows.isNotEmpty
        ? companyRows.first['valor']?.toString()
        : '1';
    final companyId = int.tryParse(companyIdStr ?? '1') ?? 1;

    final val = modo == ModoOperacion.publica ? 'publica' : 'privada';

    await db.insert('company_settings', {
      'company_id': companyId,
      'setting_key': 'tipo_entidad',
      'setting_value': val,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// Pantalla dedicada para la selección manual del modo de operación del ERP
class SelectorModoScreen extends StatefulWidget {
  final String entidadId;
  final String usuarioId;
  final ModoOperacion? modoInicial;
  final ValueChanged<ModoOperacion>? onModoSeleccionado;

  const SelectorModoScreen({
    super.key,
    required this.entidadId,
    required this.usuarioId,
    this.modoInicial,
    this.onModoSeleccionado,
  });

  @override
  State<SelectorModoScreen> createState() => _SelectorModoScreenState();
}

class _SelectorModoScreenState extends State<SelectorModoScreen> {
  ModoOperacion? _modoSeleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _modoSeleccionado = widget.modoInicial;
  }

  Future<void> _seleccionarModo(ModoOperacion modo) async {
    setState(() {
      _modoSeleccionado = modo;
      _guardando = true;
    });

    try {
      await SelectorModoService.guardarModo(
        entidadId: widget.entidadId,
        usuarioId: widget.usuarioId,
        modo: modo,
      );

      if (!mounted) return;
      setState(() => _guardando = false);

      if (widget.onModoSeleccionado != null) {
        widget.onModoSeleccionado!(modo);
      } else {
        Navigator.of(context).pop(modo);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo de Operación del ERP'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.business_center,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Selecciona el perfil de tu entidad',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'El ERP adaptará la interfaz, menús y normas según la arquitectura seleccionada.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_guardando)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Opción 1: Empresa Privada / Comercial
                  _buildCardOpcion(
                    context: context,
                    modo: ModoOperacion.privada,
                    titulo: 'Sector Comercial / Empresa Privada',
                    subtitulo:
                        'Facturación electrónica DIAN, Punto de Venta (POS), Inventario Avanzado, Ventas, Compras, Clientes y NIIF.',
                    icono: Icons.storefront,
                    colorIcono: Colors.blue.shade700,
                    seleccionado: _modoSeleccionado == ModoOperacion.privada,
                    onTap: () => _seleccionarModo(ModoOperacion.privada),
                  ),
                  const SizedBox(height: 20),
                  // Opción 2: Sector Público / Entidad Territorial
                  _buildCardOpcion(
                    context: context,
                    modo: ModoOperacion.publica,
                    titulo: 'Sector Público / Entidad Territorial',
                    subtitulo:
                        'Presupuesto EOP (CDP/RP/Obligación/Pago), PAC, Contabilidad NICSP, Contratación Ley 80, Nómina, Rentas, Regalías SGR y SIIF/CHIP.',
                    icono: Icons.account_balance,
                    colorIcono: Colors.amber.shade800,
                    seleccionado: _modoSeleccionado == ModoOperacion.publica,
                    onTap: () => _seleccionarModo(ModoOperacion.publica),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardOpcion({
    required BuildContext context,
    required ModoOperacion modo,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: seleccionado ? 2.5 : 1.0,
          ),
          color: seleccionado
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.2)
              : Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colorIcono.withValues(alpha: 0.15),
              child: Icon(icono, size: 32, color: colorIcono),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (seleccionado)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
