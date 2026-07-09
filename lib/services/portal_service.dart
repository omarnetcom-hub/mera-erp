import 'dart:math';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import '../db_helper.dart';

enum TipoUsuarioPortal { cliente, vendedor, administrador }

class UsuarioPortal {
  const UsuarioPortal({
    required this.id,
    required this.clientId,
    required this.nombre,
    required this.email,
    required this.tipo,
    required this.activo,
    required this.creadoEn,
    this.ultimoAcceso,
  });

  final int id;
  final int clientId;
  final String nombre;
  final String email;
  final TipoUsuarioPortal tipo;
  final bool activo;
  final DateTime creadoEn;
  final DateTime? ultimoAcceso;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clientId,
      'nombre': nombre,
      'email': email,
      'tipo': tipo.name,
      'activo': activo ? 1 : 0,
      'creado_en': creadoEn.toIso8601String(),
      'ultimo_acceso': ultimoAcceso?.toIso8601String(),
    };
  }

  static UsuarioPortal fromMap(Map<String, dynamic> map) {
    return UsuarioPortal(
      id: map['id'] as int,
      clientId: map['cliente_id'] as int,
      nombre: map['nombre'] as String,
      email: map['email'] as String,
      tipo: TipoUsuarioPortal.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoUsuarioPortal.cliente,
      ),
      activo: (map['activo'] as int) == 1,
      creadoEn: DateTime.parse(map['creado_en'] as String),
      ultimoAcceso: map['ultimo_acceso'] != null
          ? DateTime.parse(map['ultimo_acceso'] as String)
          : null,
    );
  }
}

class TokenAcceso {
  const TokenAcceso({
    required this.token,
    required this.usuarioId,
    required this.expiraEn,
    this.creadoEn,
  });

  final String token;
  final int usuarioId;
  final DateTime expiraEn;
  final DateTime? creadoEn;

  bool get estaExpirado => DateTime.now().isAfter(expiraEn);

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'usuario_id': usuarioId,
      'expira_en': expiraEn.toIso8601String(),
      'creado_en': creadoEn?.toIso8601String(),
    };
  }

  static TokenAcceso fromMap(Map<String, dynamic> map) {
    return TokenAcceso(
      token: map['token'] as String,
      usuarioId: map['usuario_id'] as int,
      expiraEn: DateTime.parse(map['expira_en'] as String),
      creadoEn: map['creado_en'] != null
          ? DateTime.parse(map['creado_en'] as String)
          : null,
    );
  }
}

class PortalService {
  PortalService._();

  static final PortalService instance = PortalService._();
  static const int _tokenExpiraHoras = 24;

  String _generarToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final digest = sha256.convert(bytes);
    return 'portal_${digest.toString().substring(0, 40)}';
  }

  Future<int> crearUsuarioPortal({
    required int clientId,
    required String nombre,
    required String email,
    required String password,
    TipoUsuarioPortal tipo = TipoUsuarioPortal.cliente,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    final id = await db.insert('portal_usuarios', {
      'company_id': companyId,
      'cliente_id': clientId,
      'nombre': nombre,
      'email': email,
      'password_hash': passwordHash,
      'tipo': tipo.name,
      'activo': 1,
      'creado_en': DateTime.now().toIso8601String(),
    });

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'PORTAL_USUARIO_CREADO',
      entidad: 'portal',
      detalle: 'ID: $id, Email: $email, Tipo: ${tipo.name}',
    );

    return id;
  }

  Future<TokenAcceso?> autenticar(String email, String password) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final rows = await db.query(
      'portal_usuarios',
      where: 'company_id = ? AND email = ? AND activo = ?',
      whereArgs: [companyId, email, 1],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final dbHash = rows.first['password_hash'] as String;
    if (!BCrypt.checkpw(password, dbHash)) {
      return null;
    }

    final usuario = UsuarioPortal.fromMap(rows.first);
    final token = _generarToken();
    final expiraEn = DateTime.now().add(Duration(hours: _tokenExpiraHoras));

    // Guardar token
    await db.insert('portal_tokens', {
      'token': token,
      'usuario_id': usuario.id,
      'expira_en': expiraEn.toIso8601String(),
      'creado_en': DateTime.now().toIso8601String(),
    });

    // Actualizar último acceso
    await db.update(
      'portal_usuarios',
      {'ultimo_acceso': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [usuario.id],
    );

    return TokenAcceso(
      token: token,
      usuarioId: usuario.id,
      expiraEn: expiraEn,
      creadoEn: DateTime.now(),
    );
  }

  Future<UsuarioPortal?> validarToken(String token) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'portal_tokens',
      where: 'token = ?',
      whereArgs: [token],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final tokenData = TokenAcceso.fromMap(rows.first);
    if (tokenData.estaExpirado) {
      await db.delete(
        'portal_tokens',
        where: 'token = ?',
        whereArgs: [token],
      );
      return null;
    }

    final usuarioRows = await db.query(
      'portal_usuarios',
      where: 'id = ? AND activo = ?',
      whereArgs: [tokenData.usuarioId, 1],
      limit: 1,
    );

    if (usuarioRows.isEmpty) return null;
    return UsuarioPortal.fromMap(usuarioRows.first);
  }

  Future<void> cerrarSesion(String token) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'portal_tokens',
      where: 'token = ?',
      whereArgs: [token],
    );
  }

  Future<Map<String, dynamic>> obtenerDatosCliente(int clientId) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    // Información del cliente
    final cliente = await db.query(
      'clientes',
      where: 'id = ? AND company_id = ?',
      whereArgs: [clientId, companyId],
      limit: 1,
    );

    if (cliente.isEmpty) throw Exception('Cliente no encontrado');

    // Cuentas por cobrar
    final cuentas = await db.query(
      'cuentas_por_cobrar',
      where: 'cliente_id = ? AND company_id = ?',
      whereArgs: [clientId, companyId],
    );

    // Órdenes recientes
    final ordenes = await db.query(
      'ventas',
      where: 'cliente_id = ? AND company_id = ?',
      whereArgs: [clientId, companyId],
      orderBy: 'fecha DESC',
      limit: 10,
    );

    return {
      'cliente': cliente.first,
      'cuentas_por_cobrar': cuentas,
      'ordenes_recientes': ordenes,
    };
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialCompras(int clientId) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final rows = await db.rawQuery('''
      SELECT v.id, v.fecha, v.total, v.estado,
             COUNT(vd.id) as items
      FROM ventas v
      LEFT JOIN ventas_detalle vd ON v.id = vd.venta_id
      WHERE v.cliente_id = ? AND v.company_id = ?
      GROUP BY v.id
      ORDER BY v.fecha DESC
      LIMIT 50
    ''', [clientId, companyId]);

    return rows.map((row) => row as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> obtenerSaldo(int clientId) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final rows = await db.query(
      'cuentas_por_cobrar',
      where: 'cliente_id = ? AND company_id = ? AND estado = ?',
      whereArgs: [clientId, companyId, 'pendiente'],
    );

    double saldoTotal = rows.fold(0, (sum, row) => sum + (row['saldo'] as num).toDouble());
    double vencido = 0;
    final ahora = DateTime.now();

    for (final row in rows) {
      final fechaVencimiento = DateTime.parse(row['fecha_vencimiento'] as String);
      if (ahora.isAfter(fechaVencimiento)) {
        vencido += (row['saldo'] as num).toDouble();
      }
    }

    return {
      'saldo_total': saldoTotal,
      'saldo_vencido': vencido,
      'saldo_por_vencer': saldoTotal - vencido,
      'numero_facturas': rows.length,
    };
  }

  Future<void> actualizarPassword(int usuarioId, String nuevoPassword) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    final passwordHash = BCrypt.hashpw(nuevoPassword, BCrypt.gensalt());

    await db.update(
      'portal_usuarios',
      {'password_hash': passwordHash},
      where: 'id = ? AND company_id = ?',
      whereArgs: [usuarioId, companyId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'PORTAL_PASSWORD_ACTUALIZADO',
      entidad: 'portal',
      detalle: 'Usuario ID: $usuarioId',
    );
  }

  Future<void> desactivarUsuario(int usuarioId) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    await db.update(
      'portal_usuarios',
      {'activo': 0},
      where: 'id = ? AND company_id = ?',
      whereArgs: [usuarioId, companyId],
    );

    // Revocar todos los tokens del usuario
    await db.delete(
      'portal_tokens',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
    );

    await DatabaseHelper.instance.registrarEventoAuditoria(
      accion: 'PORTAL_USUARIO_DESACTIVADO',
      entidad: 'portal',
      detalle: 'Usuario ID: $usuarioId',
    );
  }

  Future<void> limpiarTokensExpirados() async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'portal_tokens',
      where: 'expira_en < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  Future<List<UsuarioPortal>> listarUsuarios({bool soloActivos = true}) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();

    String where = 'company_id = ?';
    List<dynamic> whereArgs = [companyId];

    if (soloActivos) {
      where += ' AND activo = ?';
      whereArgs.add(1);
    }

    final rows = await db.query(
      'portal_usuarios',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'creado_en DESC',
    );

    return rows.map((row) => UsuarioPortal.fromMap(row)).toList();
  }
}
