// ============================================================
// db_helper.dart
// Capa de acceso a datos (SQLite).
// Maneja todas las operaciones de la base de datos local.
// ============================================================

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'accounting/application/accounting_engine.dart';
import 'catalog/domain/master_catalog.dart';
import 'core/branch/branch_context.dart';
import 'core/currency/currency_service.dart';
import 'core/payments/payment_service.dart';
import 'core/webhooks/webhook_service.dart';
import 'features/feature_registry.dart';
import 'features/feature_key.dart';
import 'inventory/application/advanced_inventory_service.dart';
import 'inventory/application/price_history_service.dart';
import 'models/company.dart';
import 'models/company_profile.dart';
import 'sales/application/commission_service.dart';
import 'sales/application/order_service.dart';
import 'sales/application/quote_service.dart';
import 'sales/application/warranty_service.dart';
import 'core/templates/template_service.dart';
import 'core/privacy/gdpr_service.dart';

part 'core/database/database_initializer.dart';

class ActiveCompanyConfiguration {
  const ActiveCompanyConfiguration({
    required this.companyId,
    required this.companyName,
    required this.features,
    required this.settings,
    required this.onboardingCompleted,
  });

  final int companyId;
  final String companyName;
  final Map<String, bool> features;
  final Map<String, String> settings;
  final bool onboardingCompleted;
}

/// Singleton que gestiona la base de datos SQLite de la aplicación.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;
  static bool disableAutoLoadsForTests = false;

  DatabaseHelper._init();

  static Future<void> resetForTests() async {
    disableAutoLoadsForTests = false;
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  // ── Inicialización ────────────────────────────────────────

  /// Devuelve la instancia de la base de datos, creándola si no existe.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('caja_simple.db');
    return _database!;
  }

  Future<String> _getAppDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    } catch (_) {
      return '.';
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await _getAppDir();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 48,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _crearDB,
      onUpgrade: _migrarDB,
    );
  }

  Future<String> obtenerRutaBaseDatos() async {
    final dbPath = await _getAppDir();
    return p.join(dbPath, 'caja_simple.db');
  }

  Future<Directory> _directorioRespaldos() async {
    final dbPath = await _getAppDir();
    final dir = Directory(p.join(dbPath, 'respaldos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> crearRespaldo() async {
    final db = await database;
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');

    final origen = File(await obtenerRutaBaseDatos());
    final dir = await _directorioRespaldos();
    final ahora = DateTime.now();
    final nombre =
        'merkaerp_backup_${ahora.year}${ahora.month.toString().padLeft(2, '0')}${ahora.day.toString().padLeft(2, '0')}_${ahora.hour.toString().padLeft(2, '0')}${ahora.minute.toString().padLeft(2, '0')}${ahora.second.toString().padLeft(2, '0')}.db';
    final destino = File(p.join(dir.path, nombre));

    await origen.copy(destino.path);
    await registrarEventoAuditoria(
      accion: 'CREAR_RESPALDO',
      entidad: 'base_datos',
      detalle: destino.path,
    );

    return destino;
  }

  Future<List<File>> obtenerRespaldos() async {
    final dir = await _directorioRespaldos();
    final archivos = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.db'))
        .cast<File>()
        .toList();
    archivos.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return archivos;
  }

  Future<void> restaurarRespaldo(String rutaRespaldo) async {
    final respaldo = File(rutaRespaldo);
    if (!await respaldo.exists()) {
      throw Exception('El respaldo no existe.');
    }

    final actual = File(await obtenerRutaBaseDatos());
    final dbActual = _database;
    if (dbActual != null) {
      await dbActual.close();
      _database = null;
    }

    await respaldo.copy(actual.path);
    _database = await _initDB('caja_simple.db');
    await registrarEventoAuditoria(
      accion: 'RESTAURAR_RESPALDO',
      entidad: 'base_datos',
      detalle: rutaRespaldo,
    );
  }

  /// Crea todas las tablas en una instalación nueva.
  Future<void> _crearTablasInteligenciaOperativa(Database db) async {
    await _agregarColumnaSiNoExiste(
      db,
      'productos',
      'ubicacion_pasillo',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'productos',
      'ubicacion_estante',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'productos',
      'ubicacion_nivel',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'productos',
      'ubicacion_codigo',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'productos',
      'referencia',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'productos',
      'descripcion',
      "TEXT DEFAULT ''",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lotes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        producto_id INTEGER NOT NULL,
        codigo_lote TEXT NOT NULL,
        fecha_vencimiento TEXT,
        cantidad REAL NOT NULL DEFAULT 0,
        costo REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS series(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        producto_id INTEGER NOT NULL,
        numero_serie TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'disponible',
        created_at TEXT NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notificaciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        tipo TEXT NOT NULL,
        prioridad TEXT NOT NULL,
        titulo TEXT NOT NULL,
        detalle TEXT,
        entidad TEXT,
        entidad_id INTEGER,
        leida INTEGER NOT NULL DEFAULT 0,
        creada_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferencias_usuario(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT NOT NULL,
        clave TEXT NOT NULL,
        valor TEXT,
        actualizado_en TEXT NOT NULL,
        UNIQUE(usuario, clave)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conversaciones_copilot(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        usuario TEXT NOT NULL,
        modulo TEXT,
        rol TEXT,
        mensaje_usuario TEXT NOT NULL,
        respuesta TEXT NOT NULL,
        intent TEXT NOT NULL,
        creada_en TEXT NOT NULL
      )
    ''');
  }

  Future<void> _crearTablasExtensionesEmpresariales(Database db) async {
    await _agregarColumnaSiNoExiste(
      db,
      'bodegas',
      'direccion',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'bodegas',
      'telefono',
      "TEXT DEFAULT ''",
    );
    await _agregarColumnaSiNoExiste(
      db,
      'bodegas',
      'estado',
      "TEXT DEFAULT 'activa'",
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_bodega(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        producto_id INTEGER NOT NULL,
        bodega_id INTEGER NOT NULL,
        cantidad REAL NOT NULL DEFAULT 0,
        costo REAL NOT NULL DEFAULT 0,
        actualizado_en TEXT NOT NULL,
        UNIQUE(producto_id, bodega_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS traslados_bodega(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        producto_id INTEGER NOT NULL,
        bodega_origen_id INTEGER NOT NULL,
        bodega_destino_id INTEGER NOT NULL,
        cantidad REAL NOT NULL,
        estado TEXT NOT NULL DEFAULT 'registrado',
        observacion TEXT,
        usuario TEXT,
        fecha TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS caja_sesiones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        usuario TEXT NOT NULL,
        sucursal_id INTEGER,
        monto_inicial REAL NOT NULL DEFAULT 0,
        total_ventas REAL NOT NULL DEFAULT 0,
        total_ingresos REAL NOT NULL DEFAULT 0,
        total_egresos REAL NOT NULL DEFAULT 0,
        monto_contado REAL,
        diferencia REAL,
        justificacion TEXT,
        estado TEXT NOT NULL DEFAULT 'abierta',
        abierta_en TEXT NOT NULL,
        cerrada_en TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cotizaciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        cliente_id INTEGER,
        cliente TEXT,
        estado TEXT NOT NULL DEFAULT 'borrador',
        subtotal REAL NOT NULL DEFAULT 0,
        impuesto REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        fecha TEXT NOT NULL,
        vence_en TEXT,
        observacion TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cotizacion_detalle(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        cotizacion_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pedidos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        cotizacion_id INTEGER,
        cliente_id INTEGER,
        cliente TEXT,
        estado TEXT NOT NULL DEFAULT 'borrador',
        subtotal REAL NOT NULL DEFAULT 0,
        impuesto REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        fecha TEXT NOT NULL,
        entrega_en TEXT,
        observacion TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pedido_detalle(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        pedido_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS devoluciones_ventas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        venta_id INTEGER NOT NULL,
        nota_credito TEXT,
        total REAL NOT NULL DEFAULT 0,
        motivo TEXT,
        estado TEXT NOT NULL DEFAULT 'emitida',
        fecha TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS devoluciones_ventas_detalle(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        devolucion_id INTEGER NOT NULL,
        venta_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS devoluciones_compras(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        compra_id INTEGER NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        motivo TEXT,
        estado TEXT NOT NULL DEFAULT 'emitida',
        fecha TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS devoluciones_compras_detalle(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        devolucion_id INTEGER NOT NULL,
        compra_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        costo_unitario REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comisiones_vendedor(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        usuario_id INTEGER,
        producto_id INTEGER,
        porcentaje REAL NOT NULL DEFAULT 0,
        activa INTEGER NOT NULL DEFAULT 1,
        actualizado_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comisiones_liquidadas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        venta_id INTEGER NOT NULL,
        usuario_id INTEGER,
        base REAL NOT NULL,
        porcentaje REAL NOT NULL,
        comision REAL NOT NULL,
        periodo TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS presupuesto_lineas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        periodo TEXT NOT NULL,
        cuenta_id INTEGER,
        categoria TEXT,
        monto_presupuestado REAL NOT NULL DEFAULT 0,
        alerta_pct REAL NOT NULL DEFAULT 90,
        creado_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historial_precios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        producto_id INTEGER NOT NULL,
        precio_anterior REAL NOT NULL,
        precio_nuevo REAL NOT NULL,
        usuario TEXT,
        fecha TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recordatorios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        titulo TEXT NOT NULL,
        detalle TEXT,
        tipo TEXT NOT NULL,
        prioridad TEXT NOT NULL DEFAULT 'info',
        entidad TEXT,
        entidad_id INTEGER,
        fecha_evento TEXT NOT NULL,
        notificar_48h INTEGER NOT NULL DEFAULT 1,
        notificar_24h INTEGER NOT NULL DEFAULT 1,
        completado INTEGER NOT NULL DEFAULT 0,
        creado_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plantillas_factura(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        color_primario TEXT NOT NULL DEFAULT '#2563EB',
        mostrar_logo INTEGER NOT NULL DEFAULT 1,
        mostrar_impuestos INTEGER NOT NULL DEFAULT 1,
        campos_json TEXT NOT NULL DEFAULT '{}',
        activa INTEGER NOT NULL DEFAULT 0,
        actualizado_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_tokens(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        token TEXT NOT NULL UNIQUE,
        activo INTEGER NOT NULL DEFAULT 1,
        creado_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_webhooks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        evento TEXT NOT NULL,
        url TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        creado_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_eventos_pendientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        evento TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        intentos INTEGER NOT NULL DEFAULT 0,
        creado_en TEXT NOT NULL,
        enviado_en TEXT
      )
    ''');
  }

  Future<void> _agregarColumnasImpuestos(Database db) async {
    await _agregarColumnaSiNoExiste(db, 'ventas', 'subtotal', 'REAL DEFAULT 0');
    await _agregarColumnaSiNoExiste(
      db,
      'ventas',
      'impuesto_pct',
      'REAL DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'ventas',
      'impuesto_total',
      'REAL DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'compras',
      'subtotal',
      'REAL DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'compras',
      'impuesto_pct',
      'REAL DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'compras',
      'impuesto_total',
      'REAL DEFAULT 0',
    );
  }

  Future<void> _agregarColumnaSiNoExiste(
    Database db,
    String tabla,
    String columna,
    String definicion,
  ) async {
    final columnas = await db.rawQuery('PRAGMA table_info($tabla)');
    final existe = columnas.any((c) => c['name'] == columna);
    if (!existe) {
      await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $definicion');
    }
  }

  Future<void> _agregarCompanyIdATablasOperativas(Database db) async {
    final companyId = await _sincronizarEmpresaLegacy(db);
    const tablas = [
      'productos',
      'ventas',
      'ventas_detalle',
      'compras',
      'compras_detalle',
      'movimientos_caja',
      'movimientos_inventario',
      'proveedores',
      'clientes',
      'cuentas_por_cobrar',
      'cuentas_por_pagar',
      'abonos_cxc',
      'abonos_cxp',
      'cierres_caja',
      'auditoria_eventos',
      'conciliaciones_bancarias',
      'presupuestos',
      'usuarios',
      'facturas_electronicas',
      'empleados',
      'nomina_liquidaciones',
      'activos_fijos',
      'extractos_bancarios',
      'adjuntos_documentos',
      'asientos_contables',
      'asiento_lineas',
      'comprobantes_contables',
    ];

    for (final tabla in tablas) {
      await _agregarColumnaSiNoExiste(db, tabla, 'company_id', 'INTEGER');
      await db.update(tabla, {
        'company_id': companyId,
      }, where: 'company_id IS NULL');
    }
  }

  Future<int> obtenerEmpresaActivaId([DatabaseExecutor? txn]) async {
    final executor = txn ?? await instance.database;
    final activeId = await executor.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['company_active_id'],
      limit: 1,
    );
    if (activeId.isNotEmpty) {
      final id = int.tryParse(activeId.first['valor']?.toString() ?? '');
      if (id != null) {
        return id;
      }
    }
    if (txn != null) {
      try {
        final companies = await txn.query('companies', limit: 1);
        if (companies.isNotEmpty) {
          return companies.first['id'] as int;
        }
      } catch (_) {}
      return 1;
    }
    final db = await instance.database;
    return await _sincronizarEmpresaLegacy(db);
  }

  Future<Map<String, dynamic>> _conEmpresa(Map<String, dynamic> row) async {
    return {...row, 'company_id': await obtenerEmpresaActivaId()};
  }

  Future<void> _crearTablasCartera(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        documento TEXT,
        telefono TEXT,
        direccion TEXT,
        email TEXT,
        estado TEXT DEFAULT 'activo',
        fecha TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cuentas_por_cobrar(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        cliente_id INTEGER,
        cliente TEXT,
        venta_id INTEGER,
        total REAL NOT NULL,
        saldo REAL NOT NULL,
        estado TEXT NOT NULL,
        fecha TEXT NOT NULL,
        vencimiento TEXT,
        descripcion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS abonos_cxc(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        cuenta_id INTEGER NOT NULL,
        monto REAL NOT NULL,
        metodo_pago TEXT,
        observacion TEXT,
        fecha TEXT NOT NULL
      )
    ''');
  }

  Future<void> _crearTablasControl(Database db) async {
    await _agregarColumnaSiNoExiste(db, 'ventas', 'cliente_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'ventas', 'cliente', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cierres_caja(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        fecha TEXT NOT NULL,
        saldo_sistema REAL NOT NULL,
        efectivo_contado REAL NOT NULL,
        diferencia REAL NOT NULL,
        observacion TEXT,
        estado TEXT NOT NULL DEFAULT 'cerrado'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS auditoria_eventos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        fecha TEXT NOT NULL,
        accion TEXT NOT NULL,
        entidad TEXT NOT NULL,
        entidad_id INTEGER,
        detalle TEXT,
        usuario TEXT DEFAULT 'local'
      )
    ''');
  }

  Future<void> _crearTablasEmpresaYComprobantes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresa_config(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        nombre TEXT,
        nit TEXT,
        regimen TEXT,
        direccion TEXT,
        telefono TEXT,
        email TEXT,
        ciudad TEXT,
        logo_path TEXT,
        moneda TEXT DEFAULT 'COP',
        actualizado TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS secuencias_documentos(
        tipo TEXT PRIMARY KEY,
        prefijo TEXT NOT NULL,
        siguiente INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS comprobantes_contables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        tipo TEXT NOT NULL,
        prefijo TEXT NOT NULL,
        numero INTEGER NOT NULL,
        consecutivo TEXT NOT NULL UNIQUE,
        asiento_id INTEGER,
        fecha TEXT NOT NULL,
        concepto TEXT NOT NULL,
        tercero TEXT,
        total REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'emitido',
        FOREIGN KEY (asiento_id) REFERENCES asientos_contables(id)
      )
    ''');

    await db.insert('empresa_config', {
      'id': 1,
      'nombre': 'MerkaERP',
      'moneda': 'COP',
      'actualizado': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _crearTablasPeriodos(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS periodos_contables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        anio INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        estado TEXT NOT NULL DEFAULT 'abierto',
        fecha_apertura TEXT NOT NULL,
        fecha_cierre TEXT,
        observacion TEXT,
        UNIQUE(anio, mes)
      )
    ''');
  }

  Future<void> _crearTablasConciliacion(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conciliaciones_bancarias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        fecha TEXT NOT NULL,
        cuenta TEXT NOT NULL,
        saldo_libros REAL NOT NULL,
        saldo_extracto REAL NOT NULL,
        diferencia REAL NOT NULL,
        observacion TEXT,
        estado TEXT NOT NULL DEFAULT 'registrada'
      )
    ''');
  }

  Future<void> _crearTablasPresupuestos(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS presupuestos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        anio INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        categoria TEXT NOT NULL,
        tipo TEXT NOT NULL,
        valor_presupuestado REAL NOT NULL,
        valor_real REAL NOT NULL DEFAULT 0,
        diferencia REAL NOT NULL DEFAULT 0,
        observacion TEXT,
        fecha TEXT NOT NULL,
        UNIQUE(anio, mes, categoria, tipo)
      )
    ''');
  }

  Future<void> _crearTablasGestionAvanzada(Database db) async {
    await _crearTablasMultiempresaYConfig(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        usuario TEXT NOT NULL UNIQUE,
        rol TEXT NOT NULL,
        pin TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS facturas_electronicas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        venta_id INTEGER,
        prefijo TEXT NOT NULL DEFAULT 'FE',
        numero INTEGER NOT NULL,
        consecutivo TEXT NOT NULL UNIQUE,
        estado TEXT NOT NULL DEFAULT 'borrador',
        cufe TEXT,
        xml TEXT,
        respuesta_dian TEXT,
        fecha TEXT NOT NULL,
        validada TEXT,
        observacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleados(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        documento TEXT,
        cargo TEXT,
        salario_base REAL NOT NULL DEFAULT 0,
        auxilio_transporte REAL NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS nomina_liquidaciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        empleado_id INTEGER NOT NULL,
        empleado TEXT NOT NULL,
        anio INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        devengado REAL NOT NULL,
        deducciones REAL NOT NULL,
        neto REAL NOT NULL,
        estado TEXT NOT NULL DEFAULT 'liquidada',
        fecha TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS activos_fijos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        nombre TEXT NOT NULL,
        categoria TEXT,
        costo REAL NOT NULL,
        fecha_compra TEXT NOT NULL,
        vida_util_meses INTEGER NOT NULL,
        depreciacion_acumulada REAL NOT NULL DEFAULT 0,
        valor_libros REAL NOT NULL,
        estado TEXT NOT NULL DEFAULT 'activo',
        observacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS extractos_bancarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        cuenta TEXT NOT NULL,
        fecha TEXT NOT NULL,
        descripcion TEXT,
        valor REAL NOT NULL,
        tipo TEXT NOT NULL,
        conciliado INTEGER NOT NULL DEFAULT 0,
        referencia TEXT,
        creado TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS adjuntos_documentos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        entidad TEXT NOT NULL,
        entidad_id INTEGER,
        nombre TEXT NOT NULL,
        ruta TEXT NOT NULL,
        notas TEXT,
        fecha TEXT NOT NULL
      )
    ''');

    await db.insert('usuarios', {
      'nombre': 'Administrador',
      'usuario': 'admin',
      'rol': 'administrador',
      'pin': '',
      'activo': 1,
      'fecha': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _crearTablasMultiempresaYConfig(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_config(
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        nit TEXT,
        regimen TEXT,
        direccion TEXT,
        telefono TEXT,
        email TEXT,
        ciudad TEXT,
        moneda TEXT DEFAULT 'COP',
        logo_path TEXT,
        activa INTEGER NOT NULL DEFAULT 1,
        fecha TEXT NOT NULL
      )
    ''');
  }

  Future<void> _crearTablasConfiguracionEmpresarial(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS companies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        tax_id TEXT,
        country TEXT DEFAULT 'Colombia',
        currency TEXT DEFAULT 'COP',
        timezone TEXT DEFAULT 'America/Bogota',
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_profiles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL UNIQUE,
        employee_count TEXT,
        branch_count TEXT,
        operation_volume TEXT,
        tax_regime TEXT,
        vat_enabled INTEGER NOT NULL DEFAULT 0,
        withholding_enabled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (company_id) REFERENCES companies(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_features(
        company_id INTEGER NOT NULL,
        feature_key TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (company_id, feature_key),
        FOREIGN KEY (company_id) REFERENCES companies(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_settings(
        company_id INTEGER NOT NULL,
        setting_key TEXT NOT NULL,
        setting_value TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (company_id, setting_key),
        FOREIGN KEY (company_id) REFERENCES companies(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_templates(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        features_json TEXT NOT NULL,
        settings_json TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _crearTablasCatalogosMaestros(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tax_catalog(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL DEFAULT 0,
        code TEXT NOT NULL,
        label TEXT NOT NULL,
        rate REAL NOT NULL DEFAULT 0,
        sales_enabled INTEGER NOT NULL DEFAULT 1,
        purchases_enabled INTEGER NOT NULL DEFAULT 1,
        active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, code)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS unit_catalog(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL DEFAULT 0,
        code TEXT NOT NULL,
        label TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, code)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounting_rule_settings(
        company_id INTEGER NOT NULL,
        rule_key TEXT NOT NULL,
        account_code TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(company_id, rule_key)
      )
    ''');
  }

  Future<void> _crearTablasComplementosERP(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bodegas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, codigo)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS centros_costo(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'operativo',
        activo INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, codigo)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reglas_impuestos_empresa(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        tasa REAL NOT NULL DEFAULT 0,
        cuenta_venta TEXT,
        cuenta_compra TEXT,
        aplica_ventas INTEGER NOT NULL DEFAULT 1,
        aplica_compras INTEGER NOT NULL DEFAULT 1,
        activo INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, codigo)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reglas_retenciones_empresa(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        tasa REAL NOT NULL DEFAULT 0,
        base_minima REAL NOT NULL DEFAULT 0,
        cuenta_contable TEXT,
        aplica_ventas INTEGER NOT NULL DEFAULT 0,
        aplica_compras INTEGER NOT NULL DEFAULT 1,
        activo INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, codigo)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documentos_compra_flujo(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        etapa TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'borrador',
        proveedor_id INTEGER,
        proveedor TEXT,
        documento_origen_id INTEGER,
        fecha TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        centro_costo_id INTEGER,
        bodega_id INTEGER,
        observacion TEXT,
        created_by TEXT DEFAULT 'local',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documentos_compra_flujo_lineas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        documento_id INTEGER NOT NULL,
        producto_id INTEGER,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL DEFAULT 0,
        costo_unitario REAL NOT NULL DEFAULT 0,
        impuesto_pct REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(documento_id) REFERENCES documentos_compra_flujo(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documentos_venta_flujo(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        etapa TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'borrador',
        cliente_id INTEGER,
        cliente TEXT,
        documento_origen_id INTEGER,
        fecha TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        centro_costo_id INTEGER,
        bodega_id INTEGER,
        observacion TEXT,
        created_by TEXT DEFAULT 'local',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documentos_venta_flujo_lineas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        documento_id INTEGER NOT NULL,
        producto_id INTEGER,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL DEFAULT 0,
        precio_unitario REAL NOT NULL DEFAULT 0,
        impuesto_pct REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(documento_id) REFERENCES documentos_venta_flujo(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kardex_inventario(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        bodega_id INTEGER,
        tipo TEXT NOT NULL,
        cantidad REAL NOT NULL,
        costo_unitario REAL NOT NULL DEFAULT 0,
        costo_total REAL NOT NULL DEFAULT 0,
        stock_anterior REAL NOT NULL DEFAULT 0,
        stock_nuevo REAL NOT NULL DEFAULT 0,
        referencia TEXT,
        documento_tipo TEXT,
        documento_id INTEGER,
        fecha TEXT NOT NULL,
        created_by TEXT DEFAULT 'local'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        aggregate_type TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        idempotency_key TEXT,
        vector_clock_json TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        processed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_clients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        token_hint TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        scopes TEXT,
        created_at TEXT NOT NULL,
        last_used_at TEXT
      )
    ''');
  }

  Future<void> _crearTablasPlataformaDistribuida(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        city TEXT,
        address TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        UNIQUE(company_id, code)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_inbox(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        aggregate_type TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        vector_clock_json TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        received_at TEXT NOT NULL,
        applied_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        direction TEXT NOT NULL,
        event_id TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 100,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        created_at TEXT NOT NULL,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        aggregate_type TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        vector_clock_json TEXT,
        source_node TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        aggregate_type TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        local_payload_json TEXT NOT NULL,
        remote_payload_json TEXT NOT NULL,
        resolution TEXT NOT NULL DEFAULT 'manual',
        status TEXT NOT NULL DEFAULT 'open',
        detected_at TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata(
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        key TEXT NOT NULL,
        value TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(company_id, branch_id, key)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tenant_licenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        plan_id TEXT NOT NULL,
        status TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        max_branches INTEGER NOT NULL DEFAULT 1,
        max_devices INTEGER NOT NULL DEFAULT 1,
        modules_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, plan_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS remote_support_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        session_code TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        requested_by TEXT,
        created_at TEXT NOT NULL,
        expires_at TEXT,
        closed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS telemetry_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        branch_id INTEGER,
        trace_id TEXT,
        span_id TEXT,
        severity TEXT NOT NULL,
        name TEXT NOT NULL,
        payload_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workflow_definitions(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        module TEXT NOT NULL,
        name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        version INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workflow_steps(
        id TEXT PRIMARY KEY,
        workflow_id TEXT NOT NULL,
        step_order INTEGER NOT NULL,
        name TEXT NOT NULL,
        required_role TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workflow_conditions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workflow_id TEXT NOT NULL,
        step_id TEXT NOT NULL,
        field TEXT NOT NULL,
        operator TEXT NOT NULL,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workflow_actions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workflow_id TEXT NOT NULL,
        step_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        parameters_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS rule_definitions(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        module TEXT NOT NULL,
        name TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 100,
        enabled INTEGER NOT NULL DEFAULT 1,
        definition_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scheduler_jobs(
        id TEXT PRIMARY KEY,
        company_id INTEGER,
        branch_id INTEGER,
        name TEXT NOT NULL,
        job_type TEXT NOT NULL,
        schedule TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        last_run_at TEXT,
        next_run_at TEXT,
        payload_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        branch_id INTEGER,
        channel TEXT NOT NULL,
        recipient TEXT,
        subject TEXT,
        body TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        sent_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS plugin_registry(
        id TEXT PRIMARY KEY,
        company_id INTEGER,
        name TEXT NOT NULL,
        version TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 0,
        manifest_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _crearTablasConsolidacionArquitectonica(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_store(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        aggregate_type TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        payload_json TEXT NOT NULL,
        metadata_json TEXT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        idempotency_key TEXT NOT NULL UNIQUE,
        correlation_id TEXT,
        causation_id TEXT,
        trace_id TEXT,
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_dispatch_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_sequence INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        available_at TEXT NOT NULL,
        dispatched_at TEXT,
        created_at TEXT NOT NULL,
        last_error TEXT,
        FOREIGN KEY(event_sequence) REFERENCES event_store(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_dead_letters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_sequence INTEGER,
        error TEXT NOT NULL,
        payload_json TEXT,
        failed_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cqrs_projection_offsets(
        projection_name TEXT NOT NULL,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        last_sequence INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(projection_name, company_id, branch_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS executive_kpi_read_model(
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        metric_key TEXT NOT NULL,
        metric_value REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(company_id, branch_id, metric_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounting_journal_entries(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        consecutive TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        concept TEXT NOT NULL,
        reference TEXT,
        origin TEXT NOT NULL,
        status TEXT NOT NULL,
        reversed_entry_id TEXT,
        correlation_id TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(company_id, consecutive)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounting_journal_lines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER,
        cost_center_id INTEGER,
        account_code TEXT NOT NULL,
        description TEXT,
        debit REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        local_debit REAL NOT NULL DEFAULT 0,
        local_credit REAL NOT NULL DEFAULT 0,
        third_party TEXT,
        currency TEXT NOT NULL DEFAULT 'COP',
        exchange_rate REAL NOT NULL DEFAULT 1,
        FOREIGN KEY(entry_id) REFERENCES accounting_journal_entries(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_lots(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0,
        batch_number TEXT,
        serial_number TEXT,
        received_at TEXT NOT NULL,
        expires_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_reservations(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        document_type TEXT NOT NULL,
        document_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        released_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_event_store_scope_sequence '
      'ON event_store(company_id, branch_id, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_event_store_aggregate '
      'ON event_store(aggregate_type, aggregate_id, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_event_dispatch_queue_status '
      'ON event_dispatch_queue(status, available_at, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_accounting_journal_scope '
      'ON accounting_journal_entries(company_id, branch_id, entry_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_accounting_journal_lines_account '
      'ON accounting_journal_lines(company_id, branch_id, account_code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_lots_product '
      'ON inventory_lots(company_id, branch_id, warehouse_id, product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_reservations_product '
      'ON inventory_reservations(company_id, branch_id, warehouse_id, product_id, status)',
    );
  }

  Future<void> _crearTablasSalesEnterprise(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        type TEXT NOT NULL,
        state TEXT NOT NULL,
        customer_id INTEGER,
        customer TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        credit_days INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        discount_total REAL NOT NULL DEFAULT 0,
        tax_total REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        approved_by TEXT,
        posted_at TEXT,
        reversed_document_id INTEGER,
        correlation_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_document_lines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        product TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax_rate REAL NOT NULL DEFAULT 0,
        tax_total REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(document_id) REFERENCES sales_documents(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_document_audit(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        document_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        user_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_analytics_read_model(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        document_id TEXT NOT NULL,
        event_name TEXT NOT NULL,
        revenue REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        occurred_at TEXT NOT NULL,
        correlation_id TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_documents_scope '
      'ON sales_documents(company_id, branch_id, warehouse_id, state, issue_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_documents_customer '
      'ON sales_documents(company_id, customer_id, state)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_document_lines_document '
      'ON sales_document_lines(company_id, document_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_audit_document '
      'ON sales_document_audit(company_id, document_id, created_at)',
    );
  }

  Future<void> _crearTablasPurchasesEnterprise(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        type TEXT NOT NULL,
        state TEXT NOT NULL,
        supplier_id INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        country TEXT NOT NULL DEFAULT 'Colombia',
        budget_code TEXT,
        budget_available REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_total REAL NOT NULL DEFAULT 0,
        retention_total REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        approved_by TEXT,
        posted_at TEXT,
        reversed_document_id INTEGER,
        correlation_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_document_lines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        product TEXT NOT NULL,
        quantity REAL NOT NULL,
        received_quantity REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL,
        tax_code TEXT NOT NULL DEFAULT 'EXEMPT',
        tax_rate REAL NOT NULL DEFAULT 0,
        retention_rate REAL NOT NULL DEFAULT 0,
        tax_total REAL NOT NULL DEFAULT 0,
        retention_total REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(document_id) REFERENCES purchase_documents(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_approval_steps(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        level INTEGER NOT NULL,
        approver_role TEXT NOT NULL,
        sla_hours INTEGER NOT NULL DEFAULT 24,
        approved_by TEXT,
        approved_at TEXT,
        escalated_to TEXT,
        FOREIGN KEY(document_id) REFERENCES purchase_documents(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_document_audit(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        document_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        user_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_balances(
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        supplier_id INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(company_id, branch_id, supplier_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_analytics_read_model(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        document_id TEXT NOT NULL,
        event_name TEXT NOT NULL,
        spend REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        retention REAL NOT NULL DEFAULT 0,
        occurred_at TEXT NOT NULL,
        correlation_id TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_documents_scope '
      'ON purchase_documents(company_id, branch_id, warehouse_id, state, issue_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_documents_supplier '
      'ON purchase_documents(company_id, supplier_id, state)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_lines_document '
      'ON purchase_document_lines(company_id, document_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_approval_document '
      'ON purchase_approval_steps(company_id, document_id, level)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_audit_document '
      'ON purchase_document_audit(company_id, document_id, created_at)',
    );
  }

  Future<void> _crearTablasFinalEnterprise(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS enterprise_audit_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id INTEGER,
        user_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_credit_profiles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER NOT NULL,
        credit_limit REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,
        risk_score REAL NOT NULL DEFAULT 0,
        blocked INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ar_ledger_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER NOT NULL,
        customer TEXT NOT NULL,
        document_id TEXT NOT NULL,
        document_type TEXT NOT NULL,
        side TEXT NOT NULL,
        amount REAL NOT NULL,
        open_amount REAL NOT NULL DEFAULT 0,
        due_date TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ar_payment_promises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER NOT NULL,
        customer TEXT NOT NULL,
        amount REAL NOT NULL,
        promise_date TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ap_supplier_ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        supplier_id INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        document_id TEXT NOT NULL,
        document_type TEXT NOT NULL,
        side TEXT NOT NULL,
        amount REAL NOT NULL,
        open_amount REAL NOT NULL DEFAULT 0,
        due_date TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ap_payment_schedules(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        party_id INTEGER NOT NULL,
        party TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL,
        source_document_id TEXT,
        payload_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS treasury_bank_accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        account_number TEXT,
        currency TEXT NOT NULL DEFAULT 'COP',
        balance REAL NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS treasury_transfers(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        from_account_id INTEGER NOT NULL,
        to_account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        requested_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        approved INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS treasury_bank_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        bank_account_id INTEGER NOT NULL,
        direction TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT NOT NULL,
        movement_date TEXT NOT NULL,
        reconciled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_statements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        statement_id TEXT NOT NULL,
        bank_account_id INTEGER NOT NULL,
        statement_date TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_statement_lines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        statement_id TEXT NOT NULL,
        bank_account_id INTEGER NOT NULL,
        reference TEXT,
        description TEXT,
        amount REAL NOT NULL,
        movement_date TEXT NOT NULL,
        matched_movement_id INTEGER,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_reconciliations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        reconciliation_id TEXT NOT NULL,
        statement_id TEXT NOT NULL,
        matched_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enterprise_tax_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        code TEXT NOT NULL,
        country TEXT NOT NULL,
        document_type TEXT NOT NULL,
        rate REAL NOT NULL DEFAULT 0,
        retention_rate REAL NOT NULL DEFAULT 0,
        exempt INTEGER NOT NULL DEFAULT 0,
        group_name TEXT NOT NULL DEFAULT 'default',
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enterprise_tax_calculations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        document_type TEXT NOT NULL,
        document_id TEXT NOT NULL,
        taxable_base REAL NOT NULL,
        tax REAL NOT NULL,
        retention REAL NOT NULL,
        total REAL NOT NULL,
        rule_code TEXT NOT NULL,
        correlation_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enterprise_fixed_assets(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        cost REAL NOT NULL,
        useful_life_months INTEGER NOT NULL,
        acquired_at TEXT NOT NULL,
        monthly_depreciation REAL NOT NULL DEFAULT 0,
        accumulated_depreciation REAL NOT NULL DEFAULT 0,
        fiscal_depreciation REAL NOT NULL DEFAULT 0,
        book_value REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_asset_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        asset_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS crm_opportunities(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER NOT NULL,
        customer TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 0,
        stage TEXT NOT NULL,
        next_follow_up_at TEXT NOT NULL,
        owner TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS crm_timeline(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS crm_notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        recipient TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_definitions(
        id TEXT PRIMARY KEY,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        dataset TEXT NOT NULL,
        filters_json TEXT NOT NULL,
        formats_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_runs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        run_id TEXT NOT NULL,
        definition_id TEXT NOT NULL,
        dataset TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        exports_json TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS materialized_reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        warehouse_id INTEGER NOT NULL DEFAULT 1,
        cost_center_id INTEGER NOT NULL DEFAULT 1,
        report_key TEXT NOT NULL,
        dataset TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enterprise_event_metrics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        metric_key TEXT NOT NULL,
        metric_value REAL NOT NULL DEFAULT 0,
        event_name TEXT NOT NULL,
        correlation_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_ar_ledger_scope ON ar_ledger_entries(company_id, branch_id, customer_id, due_date)',
      'CREATE INDEX IF NOT EXISTS idx_ap_ledger_scope ON ap_supplier_ledger(company_id, branch_id, supplier_id, due_date)',
      'CREATE INDEX IF NOT EXISTS idx_treasury_movements ON treasury_bank_movements(company_id, branch_id, bank_account_id, reconciled)',
      'CREATE INDEX IF NOT EXISTS idx_bank_lines_match ON bank_statement_lines(company_id, branch_id, bank_account_id, reference, amount, status)',
      'CREATE INDEX IF NOT EXISTS idx_tax_rules_scope ON enterprise_tax_rules(company_id, branch_id, country, document_type, active)',
      'CREATE INDEX IF NOT EXISTS idx_assets_scope ON enterprise_fixed_assets(company_id, branch_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_crm_pipeline ON crm_opportunities(company_id, branch_id, stage, next_follow_up_at)',
      'CREATE INDEX IF NOT EXISTS idx_reports_scope ON materialized_reports(company_id, branch_id, dataset, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_enterprise_metrics ON enterprise_event_metrics(company_id, branch_id, metric_key, created_at)',
    ];
    for (final index in indexes) {
      await db.execute(index);
    }
  }

  Future<void> _agregarScopeDistribuidoATablas(Database db) async {
    const tablas = [
      'productos',
      'ventas',
      'ventas_detalle',
      'compras',
      'compras_detalle',
      'movimientos_caja',
      'movimientos_inventario',
      'proveedores',
      'clientes',
      'cuentas_por_cobrar',
      'cuentas_por_pagar',
      'abonos_cxc',
      'abonos_cxp',
      'cierres_caja',
      'auditoria_eventos',
      'conciliaciones_bancarias',
      'presupuestos',
      'facturas_electronicas',
      'nomina_liquidaciones',
      'activos_fijos',
      'extractos_bancarios',
      'adjuntos_documentos',
      'asientos_contables',
      'asiento_lineas',
      'comprobantes_contables',
      'documentos_compra_flujo',
      'documentos_compra_flujo_lineas',
      'documentos_venta_flujo',
      'documentos_venta_flujo_lineas',
      'kardex_inventario',
      'sync_outbox',
    ];

    for (final tabla in tablas) {
      await _agregarColumnaSiNoExiste(
        db,
        tabla,
        'branch_id',
        'INTEGER DEFAULT 1',
      );
      await _agregarColumnaSiNoExiste(
        db,
        tabla,
        'warehouse_id',
        'INTEGER DEFAULT 1',
      );
      await _agregarColumnaSiNoExiste(
        db,
        tabla,
        'cost_center_id',
        'INTEGER DEFAULT 1',
      );
      await db.update(tabla, {'branch_id': 1}, where: 'branch_id IS NULL');
      await db.update(tabla, {
        'warehouse_id': 1,
      }, where: 'warehouse_id IS NULL');
      await db.update(tabla, {
        'cost_center_id': 1,
      }, where: 'cost_center_id IS NULL');
    }
    await _agregarColumnaSiNoExiste(
      db,
      'sync_outbox',
      'idempotency_key',
      'TEXT',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'sync_outbox',
      'vector_clock_json',
      'TEXT',
    );
  }

  Future<void> _sembrarCatalogosMaestros(
    DatabaseExecutor db,
    int companyId,
  ) async {
    final now = DateTime.now().toIso8601String();

    for (final tax in MasterCatalog.taxes) {
      await db.insert('tax_catalog', {
        'company_id': companyId,
        'code': tax.code,
        'label': tax.label,
        'rate': tax.rate,
        'sales_enabled': tax.sales ? 1 : 0,
        'purchases_enabled': tax.purchases ? 1 : 0,
        'active': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final unit in MasterCatalog.units) {
      await db.insert('unit_catalog', {
        'company_id': companyId,
        'code': unit.code,
        'label': unit.label,
        'active': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    const accountingRules = {
      'cash': '1105',
      'bank': '1110',
      'accounts_receivable': '1305',
      'inventory': '1435',
      'tax_deductible': '1355',
      'accounts_payable': '2205',
      'tax_payable': '2408',
      'sales_revenue': '4135',
      'cost_of_sales': '6135',
    };

    for (final entry in accountingRules.entries) {
      await db.insert('accounting_rule_settings', {
        'company_id': companyId,
        'rule_key': entry.key,
        'account_code': entry.value,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<int> _sincronizarEmpresaLegacy(Database db) async {
    await _crearTablasEmpresaYComprobantes(db);
    await _crearTablasMultiempresaYConfig(db);
    await _crearTablasConfiguracionEmpresarial(db);
    await _crearTablasCatalogosMaestros(db);
    await _crearTablasComplementosERP(db);
    await _crearTablasPlataformaDistribuida(db);

    final activeId = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['company_active_id'],
      limit: 1,
    );
    if (activeId.isNotEmpty) {
      final id = int.tryParse(activeId.first['valor']?.toString() ?? '');
      if (id != null) {
        await _sembrarCatalogosMaestrosSiNecesario(db, id);
        await _sembrarComplementosERPSiNecesario(db, id);
        await _sembrarPlataformaDistribuidaSiNecesario(db, id);
        return id;
      }
    }

    final legacy = await db.query('empresa_config', where: 'id = 1', limit: 1);
    final data = legacy.isEmpty ? <String, dynamic>{} : legacy.first;
    final now = DateTime.now().toIso8601String();
    final companyId = await db.insert('companies', {
      'name': data['nombre']?.toString().isNotEmpty == true
          ? data['nombre']
          : 'MerkaERP',
      'tax_id': data['nit'] ?? '',
      'country': data['pais'] ?? 'Colombia',
      'currency': data['moneda'] ?? 'COP',
      'timezone': data['zona_horaria'] ?? 'America/Bogota',
      'active': 1,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('company_profiles', {
      'company_id': companyId,
      'tax_regime': data['regimen'] ?? '',
      'vat_enabled': 0,
      'withholding_enabled': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _guardarCompanyFeaturesEnDB(
      db,
      companyId,
      FeatureRegistry.defaultFeatures(),
    );
    await _guardarCompanySettingsEnDB(db, companyId, {
      'onboarding_completed': '0',
      'country': 'Colombia',
      'currency': data['moneda']?.toString() ?? 'COP',
      'timezone': 'America/Bogota',
    });

    await db.insert('app_config', {
      'clave': 'company_active_id',
      'valor': companyId.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _sembrarCatalogosMaestros(db, companyId);
    await _sembrarComplementosERP(db, companyId);
    await _sembrarPlataformaDistribuida(db, companyId);
    await _marcarSiembraLista(db, companyId, 'catalogos_maestros');
    await _marcarSiembraLista(db, companyId, 'complementos_erp');
    await _marcarSiembraLista(db, companyId, 'plataforma_distribuida');

    return companyId;
  }

  Future<bool> _siembraLista(
    DatabaseExecutor db,
    int companyId,
    String seedKey,
  ) async {
    final rows = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['seed_${companyId}_$seedKey'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _marcarSiembraLista(
    DatabaseExecutor db,
    int companyId,
    String seedKey,
  ) async {
    await db.insert('app_config', {
      'clave': 'seed_${companyId}_$seedKey',
      'valor': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _sembrarCatalogosMaestrosSiNecesario(
    DatabaseExecutor db,
    int companyId,
  ) async {
    const seedKey = 'catalogos_maestros';
    if (await _siembraLista(db, companyId, seedKey)) return;
    await _sembrarCatalogosMaestros(db, companyId);
    await _marcarSiembraLista(db, companyId, seedKey);
  }

  Future<void> _sembrarComplementosERPSiNecesario(
    DatabaseExecutor db,
    int companyId,
  ) async {
    const seedKey = 'complementos_erp';
    if (await _siembraLista(db, companyId, seedKey)) return;
    await _sembrarComplementosERP(db, companyId);
    await _marcarSiembraLista(db, companyId, seedKey);
  }

  Future<void> _sembrarPlataformaDistribuidaSiNecesario(
    DatabaseExecutor db,
    int companyId,
  ) async {
    const seedKey = 'plataforma_distribuida';
    if (await _siembraLista(db, companyId, seedKey)) return;
    await _sembrarPlataformaDistribuida(db, companyId);
    await _marcarSiembraLista(db, companyId, seedKey);
  }

  Future<BranchScope> obtenerScopeOperativoActivo() async {
    final db = await database;
    final companyId = await obtenerEmpresaActivaId();
    final config = await obtenerConfiguracionActiva();
    await _sembrarPlataformaDistribuidaSiNecesario(db, companyId);

    Future<int> appInt(String key, int fallback) async {
      final rows = await db.query(
        'app_config',
        where: 'clave = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return fallback;
      return int.tryParse(rows.first['valor']?.toString() ?? '') ?? fallback;
    }

    final branchId = await appInt('branch_active_id', 1);
    final warehouseId = await appInt('warehouse_active_id', 1);
    final costCenterId = await appInt('cost_center_active_id', 1);
    final branchRows = await db.query(
      'branches',
      where: 'company_id = ? AND id = ?',
      whereArgs: [companyId, branchId],
      limit: 1,
    );

    return BranchScope(
      companyId: companyId,
      companyName: config.companyName,
      branchId: branchId,
      branchName: branchRows.isEmpty
          ? 'Sucursal principal'
          : branchRows.first['name']?.toString() ?? 'Sucursal principal',
      warehouseId: warehouseId,
      costCenterId: costCenterId,
    );
  }

  Future<void> _sembrarPlataformaDistribuida(
    DatabaseExecutor db,
    int companyId,
  ) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('branches', {
      'company_id': companyId,
      'code': 'PRINCIPAL',
      'name': 'Sucursal principal',
      'city': '',
      'address': '',
      'active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final branchRows = await db.query(
      'branches',
      where: 'company_id = ? AND code = ?',
      whereArgs: [companyId, 'PRINCIPAL'],
      limit: 1,
    );
    final branchId = branchRows.isEmpty
        ? 1
        : (branchRows.first['id'] as num?)?.toInt() ?? 1;

    await db.insert('app_config', {
      'clave': 'branch_active_id',
      'valor': branchId.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('app_config', {
      'clave': 'warehouse_active_id',
      'valor': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('app_config', {
      'clave': 'cost_center_active_id',
      'valor': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('tenant_licenses', {
      'company_id': companyId,
      'plan_id': 'enterprise-local',
      'status': 'trial',
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'max_branches': 20,
      'max_devices': 50,
      'modules_json':
          '["sales","purchases","inventory","accounting","reports","sync","workflows"]',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'company_id': companyId,
      'branch_id': 1,
      'key': 'node_id',
      'value': 'local-${companyId}_1',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _sembrarComplementosERP(
    DatabaseExecutor db,
    int companyId,
  ) async {
    final now = DateTime.now().toIso8601String();
    final warehouses = [
      {'codigo': 'PRINCIPAL', 'nombre': 'Bodega principal'},
      {'codigo': 'TRANSITO', 'nombre': 'Inventario en transito'},
    ];
    for (final warehouse in warehouses) {
      await db.insert('bodegas', {
        'company_id': companyId,
        'codigo': warehouse['codigo'],
        'nombre': warehouse['nombre'],
        'activa': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final costCenters = [
      {'codigo': 'ADM', 'nombre': 'Administracion', 'tipo': 'soporte'},
      {'codigo': 'COM', 'nombre': 'Comercial', 'tipo': 'operativo'},
      {'codigo': 'OPS', 'nombre': 'Operaciones', 'tipo': 'operativo'},
    ];
    for (final center in costCenters) {
      await db.insert('centros_costo', {
        'company_id': companyId,
        'codigo': center['codigo'],
        'nombre': center['nombre'],
        'tipo': center['tipo'],
        'activo': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final taxes = [
      {
        'codigo': 'IVA_19',
        'nombre': 'IVA general 19%',
        'tasa': 19.0,
        'cuenta_venta': '2408',
        'cuenta_compra': '1355',
      },
      {
        'codigo': 'IVA_5',
        'nombre': 'IVA reducido 5%',
        'tasa': 5.0,
        'cuenta_venta': '2408',
        'cuenta_compra': '1355',
      },
      {
        'codigo': 'EXENTO',
        'nombre': 'Exento / excluido',
        'tasa': 0.0,
        'cuenta_venta': '2408',
        'cuenta_compra': '1355',
      },
    ];
    for (final tax in taxes) {
      await db.insert('reglas_impuestos_empresa', {
        'company_id': companyId,
        'codigo': tax['codigo'],
        'nombre': tax['nombre'],
        'tasa': tax['tasa'],
        'cuenta_venta': tax['cuenta_venta'],
        'cuenta_compra': tax['cuenta_compra'],
        'aplica_ventas': 1,
        'aplica_compras': 1,
        'activo': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final retentions = [
      {
        'codigo': 'RTFTE_COMPRAS_25',
        'nombre': 'Retencion en compras 2.5%',
        'tasa': 2.5,
        'base_minima': 0.0,
        'cuenta_contable': '2365',
      },
      {
        'codigo': 'RTEICA_COMPRAS',
        'nombre': 'Retencion ICA compras',
        'tasa': 0.966,
        'base_minima': 0.0,
        'cuenta_contable': '2367',
      },
    ];
    for (final retention in retentions) {
      await db.insert('reglas_retenciones_empresa', {
        'company_id': companyId,
        'codigo': retention['codigo'],
        'nombre': retention['nombre'],
        'tasa': retention['tasa'],
        'base_minima': retention['base_minima'],
        'cuenta_contable': retention['cuenta_contable'],
        'aplica_ventas': 0,
        'aplica_compras': 1,
        'activo': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _sembrarSecuencias(Database db) async {
    final secuencias = [
      {'tipo': 'asiento', 'prefijo': 'AC', 'siguiente': 1},
      {'tipo': 'venta', 'prefijo': 'VT', 'siguiente': 1},
      {'tipo': 'ventas', 'prefijo': 'VT', 'siguiente': 1},
      {'tipo': 'compra', 'prefijo': 'CP', 'siguiente': 1},
      {'tipo': 'compras', 'prefijo': 'CP', 'siguiente': 1},
      {'tipo': 'egreso', 'prefijo': 'EG', 'siguiente': 1},
      {'tipo': 'ingreso', 'prefijo': 'IN', 'siguiente': 1},
      {'tipo': 'caja', 'prefijo': 'CJ', 'siguiente': 1},
      {'tipo': 'transferencias', 'prefijo': 'TR', 'siguiente': 1},
      {'tipo': 'cuentas_por_pagar', 'prefijo': 'CXP', 'siguiente': 1},
      {'tipo': 'cuentas_por_cobrar', 'prefijo': 'CXC', 'siguiente': 1},
    ];

    for (final secuencia in secuencias) {
      await db.insert(
        'secuencias_documentos',
        secuencia,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _crearTablasContables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cuentas_contables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        codigo TEXT NOT NULL UNIQUE,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        naturaleza TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS asientos_contables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        fecha TEXT NOT NULL,
        concepto TEXT NOT NULL,
        referencia TEXT,
        origen TEXT NOT NULL DEFAULT 'manual',
        estado TEXT NOT NULL DEFAULT 'registrado'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS asiento_lineas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER,
        asiento_id INTEGER NOT NULL,
        cuenta_id INTEGER NOT NULL,
        descripcion TEXT,
        debito REAL NOT NULL DEFAULT 0,
        credito REAL NOT NULL DEFAULT 0,
        tercero TEXT,
        FOREIGN KEY (asiento_id) REFERENCES asientos_contables(id),
        FOREIGN KEY (cuenta_id) REFERENCES cuentas_contables(id)
      )
    ''');
  }

  Future<void> _sembrarPlanCuentas(Database db) async {
    final cuentas = [
      // Clase 1: Activos
      {'codigo': '1', 'nombre': 'Activo', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '11', 'nombre': 'Disponible', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1105', 'nombre': 'Caja', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '110505', 'nombre': 'Caja General', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '110510', 'nombre': 'Cajas Menores', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1110', 'nombre': 'Bancos', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '111005', 'nombre': 'Bancos Nacionales', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1120', 'nombre': 'Cuentas de Ahorro', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '12', 'nombre': 'Inversiones', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1205', 'nombre': 'Inversiones corrientes', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '13', 'nombre': 'Deudores / Cartera', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1305', 'nombre': 'Cuentas por cobrar (Clientes)', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '130505', 'nombre': 'Clientes Nacionales', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1325', 'nombre': 'Anticipos y avances', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1355', 'nombre': 'Impuestos descontables (Anticipos)', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1365', 'nombre': 'Cuentas por cobrar a trabajadores', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '14', 'nombre': 'Inventarios', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1435', 'nombre': 'Inventario (Mercancias no fab. por la empresa)', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '15', 'nombre': 'Propiedades, Planta y Equipo', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1504', 'nombre': 'Terrenos', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1516', 'nombre': 'Construcciones y Edificaciones', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1520', 'nombre': 'Maquinaria y Equipo', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1524', 'nombre': 'Equipo de Oficina', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1528', 'nombre': 'Equipo de Computacion y Comunicacion', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1592', 'nombre': 'Depreciacion Acumulada', 'tipo': 'activo', 'naturaleza': 'credito'},
      {'codigo': '17', 'nombre': 'Diferidos', 'tipo': 'activo', 'naturaleza': 'debito'},
      {'codigo': '1705', 'nombre': 'Gastos Pagados por Anticipado', 'tipo': 'activo', 'naturaleza': 'debito'},

      // Clase 2: Pasivos
      {'codigo': '2', 'nombre': 'Pasivo', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '21', 'nombre': 'Obligaciones Financieras', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2105', 'nombre': 'Obligaciones financieras (Bancos)', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '22', 'nombre': 'Proveedores', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2205', 'nombre': 'Proveedores Nacionales', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '23', 'nombre': 'Cuentas por Pagar', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2335', 'nombre': 'Costos y gastos por pagar', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2365', 'nombre': 'Retencion en la fuente por pagar', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2367', 'nombre': 'Impuesto de industria y comercial retenido (ReteICA)', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2368', 'nombre': 'Retencion de IVA (ReteIVA) por pagar', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2370', 'nombre': 'Retenciones y aportes de nomina', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2380', 'nombre': 'Acreedores varios', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '24', 'nombre': 'Impuestos, Gravamenes y Tasas', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2408', 'nombre': 'Impuestos por pagar (IVA)', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '25', 'nombre': 'Obligaciones Laborales', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2505', 'nombre': 'Salarios por pagar', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2510', 'nombre': 'Cesantias consolidadas', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2515', 'nombre': 'Intereses sobre cesantias', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2520', 'nombre': 'Prima de servicios por pagar', 'tipo': 'pasivo', 'naturaleza': 'credito'},
      {'codigo': '2525', 'nombre': 'Vacaciones consolidadas', 'tipo': 'pasivo', 'naturaleza': 'credito'},

      // Clase 3: Patrimonio
      {'codigo': '3', 'nombre': 'Patrimonio', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '31', 'nombre': 'Capital Social', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '3105', 'nombre': 'Capital suscrito y pagado', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '3115', 'nombre': 'Capital Social (Aportes)', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '33', 'nombre': 'Reservas', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '3305', 'nombre': 'Reservas obligatorias', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '36', 'nombre': 'Resultados del Ejercicio', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '3605', 'nombre': 'Utilidad del ejercicio', 'tipo': 'patrimonio', 'naturaleza': 'credito'},
      {'codigo': '3610', 'nombre': 'Perdida del ejercicio', 'tipo': 'patrimonio', 'naturaleza': 'debito'},

      // Clase 4: Ingresos
      {'codigo': '4', 'nombre': 'Ingresos', 'tipo': 'ingreso', 'naturaleza': 'credito'},
      {'codigo': '41', 'nombre': 'Ingresos Operacionales', 'tipo': 'ingreso', 'naturaleza': 'credito'},
      {'codigo': '4135', 'nombre': 'Ingresos por ventas (Comercio al por mayor/menor)', 'tipo': 'ingreso', 'naturaleza': 'credito'},
      {'codigo': '4175', 'nombre': 'Devoluciones en ventas', 'tipo': 'ingreso', 'naturaleza': 'debito'},
      {'codigo': '42', 'nombre': 'Ingresos No Operacionales', 'tipo': 'ingreso', 'naturaleza': 'credito'},
      {'codigo': '4210', 'nombre': 'Ingresos financieros', 'tipo': 'ingreso', 'naturaleza': 'credito'},
      {'codigo': '4295', 'nombre': 'Ingresos diversos', 'tipo': 'ingreso', 'naturaleza': 'credito'},

      // Clase 5: Gastos
      {'codigo': '5', 'nombre': 'Gastos', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '51', 'nombre': 'Gastos Operacionales de Administracion', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5105', 'nombre': 'Gastos de personal (Nomina)', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5110', 'nombre': 'Honorarios', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5115', 'nombre': 'Impuestos operacionales', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5120', 'nombre': 'Arrendamientos', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5125', 'nombre': 'Seguros', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5130', 'nombre': 'Servicios publicos/comerciales', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5135', 'nombre': 'Gastos operacionales / Diversos', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5140', 'nombre': 'Servicios directos', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5160', 'nombre': 'Depreciaciones', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '52', 'nombre': 'Gastos Operacionales de Ventas', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5205', 'nombre': 'Gastos de personal (Ventas)', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5220', 'nombre': 'Arrendamientos (Ventas)', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5235', 'nombre': 'Servicios (Ventas)', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '53', 'nombre': 'Gastos No Operacionales', 'tipo': 'gasto', 'naturaleza': 'debito'},
      {'codigo': '5305', 'nombre': 'Gastos financieros (Comisiones/Intereses)', 'tipo': 'gasto', 'naturaleza': 'debito'},

      // Clase 6: Costo de Ventas
      {'codigo': '6', 'nombre': 'Costos', 'tipo': 'costo', 'naturaleza': 'debito'},
      {'codigo': '61', 'nombre': 'Costo de Ventas', 'tipo': 'costo', 'naturaleza': 'debito'},
      {'codigo': '6135', 'nombre': 'Costo de ventas (Comercio)', 'tipo': 'costo', 'naturaleza': 'debito'},
      {'codigo': '62', 'nombre': 'Compras', 'tipo': 'costo', 'naturaleza': 'debito'},
      {'codigo': '6205', 'nombre': 'Compras de mercancias', 'tipo': 'costo', 'naturaleza': 'debito'},
    ];

    for (final cuenta in cuentas) {
      await db.insert(
        'cuentas_contables',
        cuenta,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ── Productos ────────────────────────────────────────────

  /// Inserta un nuevo producto y devuelve su id generado.
  Future<int> insertarProducto(Map<String, dynamic> row) async {
    await validarFeatureHabilitada(FeatureKey.inventory);
    final db = await instance.database;
    return await db.insert('productos', await _conEmpresa(row));
  }

  /// Devuelve todos los productos ordenados alfabéticamente.
  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'productos',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'nombre ASC',
    );
  }

  /// Actualiza los datos de un producto existente.
  Future<int> actualizarProducto(int id, Map<String, dynamic> datos) async {
    await validarFeatureHabilitada(FeatureKey.inventory);
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.update(
      'productos',
      datos,
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  /// Elimina un producto por su id.
  Future<int> eliminarProducto(int id) async {
    await validarFeatureHabilitada(FeatureKey.inventory);
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.delete(
      'productos',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  /// Actualiza únicamente el stock de un producto.
  /// Registra un nuevo lote de producto.
  Future<int> registrarLote({
    required int productoId,
    required String codigoLote,
    required String fechaVencimiento,
    required double cantidad,
    required double costo,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.insert('lotes', {
      'company_id': companyId,
      'producto_id': productoId,
      'codigo_lote': codigoLote,
      'fecha_vencimiento': fechaVencimiento,
      'cantidad': cantidad,
      'costo': costo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene todos los lotes de un producto.
  Future<List<Map<String, dynamic>>> obtenerLotesPorProducto(int productoId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'lotes',
      where: 'company_id = ? AND producto_id = ?',
      whereArgs: [companyId, productoId],
      orderBy: 'fecha_vencimiento ASC',
    );
  }

  /// Actualiza la cantidad de un lote específico.
  Future<int> actualizarCantidadLote(int loteId, double nuevaCantidad) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.update(
      'lotes',
      {'cantidad': nuevaCantidad},
      where: 'id = ? AND company_id = ?',
      whereArgs: [loteId, companyId],
    );
  }

  Future actualizarStock(int id, double nuevoStock) async {
    if (nuevoStock < 0) {
      throw Exception('El stock no puede quedar negativo.');
    }
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    await db.update(
      'productos',
      {'stock': nuevoStock},
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  // ── Ventas ───────────────────────────────────────────────

  /// Registra una nueva venta.
  Future<int> insertarVenta(Map<String, dynamic> row) async {
    await validarFeatureHabilitada(FeatureKey.pos);
    final db = await instance.database;

    // Inserta SOLO la cabecera de la venta
    final id = await db.insert('ventas', await _conEmpresa(row));

    return id;
  }

  /// Devuelve todas las ventas, más recientes primero.
  Future<List<Map<String, dynamic>>> obtenerVentas() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'ventas',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerDetalleVenta(int ventaId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.rawQuery(
      '''
      SELECT
        vd.*,
        p.unidad_base,
        p.codigo_barras
      FROM ventas_detalle vd
      INNER JOIN ventas v ON v.id = vd.venta_id
      LEFT JOIN productos p ON p.id = vd.producto_id
      WHERE vd.venta_id = ? AND v.company_id = ?
      ORDER BY vd.id ASC
      ''',
      [ventaId, companyId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerDetalleCompra(int compraId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.rawQuery(
      '''
      SELECT
        cd.*,
        p.unidad_base,
        p.codigo_barras
      FROM compras_detalle cd
      INNER JOIN compras c ON c.id = cd.compra_id
      LEFT JOIN productos p ON p.id = cd.producto_id
      WHERE cd.compra_id = ? AND c.company_id = ?
      ORDER BY cd.id ASC
      ''',
      [compraId, companyId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerVentasActivas() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'ventas',
      where: "company_id = ? AND COALESCE(estado, 'emitida') != 'anulada'",
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  /// Devuelve todas las compras registradas.
  Future<List<Map<String, dynamic>>> obtenerCompras() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    return await db.query(
      'compras',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  /// Elimina una venta por su id.
  Future<int> eliminarVenta(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final filas = await db.delete(
      'ventas',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    await registrarEventoAuditoria(
      accion: 'ANULAR_VENTA',
      entidad: 'ventas',
      entidadId: id,
      detalle: 'Venta eliminada desde módulo de ventas',
    );
    return filas;
  }

  Future<void> anularVenta(int ventaId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    await db.transaction((txn) async {
      final ventas = await txn.query(
        'ventas',
        where: 'id = ? AND company_id = ?',
        whereArgs: [ventaId, companyId],
      );
      if (ventas.isEmpty) {
        throw Exception('La venta no existe.');
      }

      final venta = ventas.first;
      if ((venta['estado']?.toString() ?? 'emitida') == 'anulada') {
        throw Exception('La venta ya fue anulada.');
      }

      final detalles = await txn.query(
        'ventas_detalle',
        where: 'venta_id = ? AND company_id = ?',
        whereArgs: [ventaId, companyId],
      );

      for (final item in detalles) {
        final productoId = (item['producto_id'] as num?)?.toInt() ?? 0;
        final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
        if (productoId <= 0 || cantidad <= 0) continue;

        final productos = await txn.query(
          'productos',
          where: 'id = ? AND company_id = ?',
          whereArgs: [productoId, companyId],
        );
        if (productos.isEmpty) continue;

        final stockActual = (productos.first['stock'] as num).toDouble();
        final stockNuevo = stockActual + cantidad;
        await txn.update(
          'productos',
          {'stock': stockNuevo},
          where: 'id = ? AND company_id = ?',
          whereArgs: [productoId, companyId],
        );
        await txn.insert('movimientos_inventario', {
          'company_id': companyId,
          'producto_id': productoId,
          'tipo': 'entrada',
          'cantidad': cantidad,
          'stock_anterior': stockActual,
          'stock_nuevo': stockNuevo,
          'motivo': 'ANULACION VENTA #$ventaId',
          'fecha': DateTime.now().toIso8601String(),
        });
      }

      final metodo = await txn.query(
        'metodos_pago',
        where: 'id = ?',
        whereArgs: [venta['metodo_pago_id']],
      );
      final nombreMetodo = metodo.isEmpty
          ? ''
          : metodo.first['nombre'].toString().toUpperCase().trim();
      final total = (venta['total'] as num?)?.toDouble() ?? 0;

      if (nombreMetodo == 'CREDITO') {
        await txn.update(
          'cuentas_por_cobrar',
          {'estado': 'anulada', 'saldo': 0},
          where: 'venta_id = ? AND company_id = ?',
          whereArgs: [ventaId, companyId],
        );
        await txn.insert('movimientos_caja', {
          'company_id': companyId,
          'tipo': 'egreso',
          'concepto': 'Anulacion cuenta por cobrar venta #$ventaId',
          'monto': total,
          'fecha': DateTime.now().toIso8601String(),
          'origen': 'cartera',
        });
      } else {
        final origen =
            nombreMetodo == 'TRANSFERENCIA' ||
                nombreMetodo == 'TARJETA' ||
                nombreMetodo == 'NEQUI' ||
                nombreMetodo == 'DAVIPLATA'
            ? 'banco'
            : 'caja';
        await txn.insert('movimientos_caja', {
          'company_id': companyId,
          'tipo': 'egreso',
          'concepto': 'Anulacion venta #$ventaId',
          'monto': total,
          'fecha': DateTime.now().toIso8601String(),
          'origen': origen,
        });
      }

      await txn.update(
        'ventas',
        {'estado': 'anulada'},
        where: 'id = ? AND company_id = ?',
        whereArgs: [ventaId, companyId],
      );
      await txn.insert('auditoria_eventos', {
        'company_id': companyId,
        'fecha': DateTime.now().toIso8601String(),
        'accion': 'ANULAR_VENTA',
        'entidad': 'ventas',
        'entidad_id': ventaId,
        'detalle': 'Venta anulada, stock restaurado y saldos revertidos',
        'usuario': 'local',
      });
    });
  }

  Future<void> eliminarCompra(int compraId) async {
    try {
      final db = await instance.database;
      final companyId = await obtenerEmpresaActivaId();

      await db.transaction((txn) async {
        // 🔥 OBTENER COMPRA
        final compras = await txn.query(
          'compras',
          where: 'id = ? AND company_id = ?',
          whereArgs: [compraId, companyId],
        );

        if (compras.isEmpty) return;

        final compra = compras.first;

        // 🚫 si ya estaba anulada
        if (compra['estado'] == 'anulada') {
          throw Exception('La compra ya fue anulada.');
        }

        final total = (compra['total'] as num).toDouble();
        final efectivo = (compra['efectivo'] as num?)?.toDouble() ?? 0;
        final transferencia = (compra['transferencia'] as num?)?.toDouble() ?? 0;
        final credito = (compra['credito'] as num?)?.toDouble() ?? 0;
        final metodoPagoId = compra['metodo_pago_id'];

        // 🔥 OBTENER MÉTODO DE PAGO
        final metodo = await txn.query(
          'metodos_pago',
          where: 'id = ?',
          whereArgs: [metodoPagoId],
        );

        String nombreMetodo = 'EFECTIVO';

        if (metodo.isNotEmpty && metodo.first['nombre'] != null) {
          nombreMetodo = metodo.first['nombre'].toString();
        }

        // 🔥 OBTENER DETALLE
        final detalles = await txn.query(
          'compras_detalle',
          where: 'compra_id = ? AND company_id = ?',
          whereArgs: [compraId, companyId],
        );

        for (final item in detalles) {
          final productoId = (item['producto_id'] as num?)?.toInt() ?? 0;
          final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
          if (productoId == 0 || cantidad <= 0) continue;

          final productos = await txn.query(
            'productos',
            where: 'id = ? AND company_id = ?',
            whereArgs: [productoId, companyId],
          );
          if (productos.isEmpty) continue;

          final stockActual = (productos.first['stock'] as num?)?.toDouble() ?? 0;
          if (stockActual < cantidad) {
            throw Exception(
              'No se puede anular la compra #$compraId porque ${item['producto']} ya fue vendido o consumido. Stock actual: $stockActual, requerido: $cantidad.',
            );
          }
        }

        // 🔥 DEVOLVER STOCK
        for (final item in detalles) {
          final productoId = (item['producto_id'] as num?)?.toInt() ?? 0;
          final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;

          if (productoId == 0) continue;

          final productos = await txn.query(
            'productos',
            where: 'id = ? AND company_id = ?',
            whereArgs: [productoId, companyId],
          );

          if (productos.isEmpty) continue;

          final producto = productos.first;
          final stockActual = (producto['stock'] as num?)?.toDouble() ?? 0;
          final nuevoStock = stockActual - cantidad;

          await txn.update(
            'productos',
            {'stock': nuevoStock},
            where: 'id = ? AND company_id = ?',
            whereArgs: [productoId, companyId],
          );

          await txn.insert('movimientos_inventario', {
            'company_id': companyId,
            'producto_id': productoId,
            'tipo': 'salida',
            'cantidad': cantidad,
            'stock_anterior': stockActual,
            'stock_nuevo': nuevoStock,
            'motivo': 'ANULACION COMPRA #$compraId',
            'fecha': DateTime.now().toIso8601String(),
          });
        }

        final metodoUpper = nombreMetodo.toString().trim().toUpperCase();

        if (efectivo > 0) {
          await txn.insert('movimientos_caja', {
            'company_id': companyId,
            'tipo': 'ingreso',
            'concepto': 'Anulacion compra #$compraId (Caja)',
            'monto': efectivo,
            'fecha': DateTime.now().toIso8601String(),
            'origen': 'caja',
          });
        }
        if (transferencia > 0) {
          await txn.insert('movimientos_caja', {
            'company_id': companyId,
            'tipo': 'ingreso',
            'concepto': 'Anulacion compra #$compraId (Banco)',
            'monto': transferencia,
            'fecha': DateTime.now().toIso8601String(),
            'origen': 'banco',
          });
        }

        if (efectivo == 0 &&
            transferencia == 0 &&
            credito == 0 &&
            (metodoUpper == 'EFECTIVO' ||
                metodoUpper == 'TRANSFERENCIA' ||
                metodoUpper == 'TARJETA' ||
                metodoUpper == 'NEQUI' ||
                metodoUpper == 'DAVIPLATA')) {
          final cuenta =
              (metodoUpper == 'TRANSFERENCIA' ||
                  metodoUpper == 'TARJETA' ||
                  metodoUpper == 'NEQUI' ||
                  metodoUpper == 'DAVIPLATA')
              ? 'banco'
              : 'caja';

          await txn.insert('movimientos_caja', {
            'company_id': companyId,
            'tipo': 'ingreso',
            'concepto': 'Anulación compra #$compraId',
            'monto': total,
            'fecha': DateTime.now().toIso8601String(),
            'origen': cuenta,
          });
        }

        // 🔥 SI ERA CRÉDITO → CANCELAR DEUDA
        if (metodoUpper == 'CREDITO' || credito > 0) {
          await txn.update(
            'cuentas_por_pagar',
            {'estado': 'anulada', 'saldo': 0},
            where: 'compra_id = ? AND company_id = ?',
            whereArgs: [compraId, companyId],
          );
        }

        await txn.update(
          'compras',
          {'estado': 'anulada'},
          where: 'id = ? AND company_id = ?',
          whereArgs: [compraId, companyId],
        );

        await txn.insert('auditoria_eventos', {
          'company_id': companyId,
          'fecha': DateTime.now().toIso8601String(),
          'accion': 'ANULAR_COMPRA',
          'entidad': 'compras',
          'entidad_id': compraId,
          'detalle': 'Compra anulada y stock revertido',
          'usuario': 'local',
        });
      });
    } catch (e) {
      throw Exception('Error anulando compra: $e');
    }
  }

  // ── Métodos de Pago ───────────────────────────────────

  /// Devuelve todos los métodos de pago registrados.
  Future<List<Map<String, dynamic>>> obtenerMetodosPago() async {
    final db = await instance.database;
    return await db.query('metodos_pago', orderBy: 'nombre ASC');
  }

  // ── Movimientos de Caja ──────────────────────────────────

  /// Registra un movimiento de caja (ingreso o egreso).
  Future<int> insertarMovimiento(Map<String, dynamic> row) async {
    await validarFeatureHabilitada(FeatureKey.cash);
    final tipo = row['tipo']?.toString() ?? '';
    final monto = (row['monto'] as num?)?.toDouble() ?? 0;
    final origen = row['origen']?.toString() ?? 'caja';
    if ((tipo == 'egreso' || tipo == 'transferencia') && monto > 0) {
      await validarSaldoSuficiente(
        origen: origen,
        monto: monto,
        bancoId: row['banco_id'] as int?,
      );
    }
    final db = await instance.database;
    return await db.insert('movimientos_caja', await _conEmpresa(row));
  }

  /// Devuelve todos los movimientos activos, más recientes primero.
  Future<List<Map<String, dynamic>>> obtenerMovimientos() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'movimientos_caja',
      where: 'company_id = ? AND COALESCE(activo, 1) = 1',
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  /// Movimientos de caja en un rango de fechas (solo activos).
  Future<List<Map<String, dynamic>>> obtenerMovimientosPorPeriodo({
    required DateTime desde,
    required DateTime hasta,
    String? origen,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final inicio = desde.toIso8601String();
    final fin = hasta.add(const Duration(days: 1)).toIso8601String();
    var where = 'company_id = ? AND COALESCE(activo, 1) = 1 AND fecha >= ? AND fecha < ?';
    final args = <Object>[companyId, inicio, fin];
    if (origen != null && origen.isNotEmpty && origen != 'todas') {
      where += ' AND origen = ?';
      args.add(origen);
    }
    return await db.query(
      'movimientos_caja',
      where: where,
      whereArgs: args,
      orderBy: 'fecha ASC',
    );
  }

  /// Valida que haya fondos suficientes antes de un egreso.
  Future<void> validarSaldoSuficiente({
    required String origen,
    required double monto,
    int? bancoId,
  }) async {
    if (origen == 'cartera') return;
    double saldo;
    if (bancoId != null) {
      saldo = await obtenerSaldoBanco(bancoId);
    } else {
      saldo = await obtenerSaldoPorCuenta(origen);
    }
    if (saldo < monto) {
      throw Exception(
        'Fondos insuficientes. Saldo disponible: \$${saldo.toStringAsFixed(2)}',
      );
    }
  }

  /// Elimina un movimiento por su id.
  Future<int> eliminarMovimiento(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.delete(
      'movimientos_caja',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  Future<void> transferirEntreCuentas({
    required String origen,
    required String destino,
    required double monto,
    required String concepto,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    // 🔴 validar saldo
    final saldoOrigen = await obtenerSaldoPorCuenta(origen);

    if (saldoOrigen < monto) {
      throw Exception('Saldo insuficiente en $origen');
    }

    final now = DateTime.now().toIso8601String();

    // 🔴 salida (egreso del origen)
    await db.insert('movimientos_caja', {
      'company_id': companyId,
      'tipo': 'transferencia',
      'concepto': 'Transferencia: $origen → $destino',
      'monto': monto,
      'fecha': now,
      'origen': origen,
    });

    // 🔵 entrada (ingreso al destino)
    await db.insert('movimientos_caja', {
      'company_id': companyId,
      'tipo': 'ingreso',
      'concepto': concepto,
      'monto': monto,
      'fecha': now,
      'origen': destino,
    });

    await registrarAsientoTransferencia(
      origen: origen,
      destino: destino,
      monto: monto,
      concepto: concepto,
    );
  }

  Future<double> obtenerSaldoPorCuenta(String cuenta) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    // 🟢 Caja y Banco funcionan normal
    if (cuenta == 'caja' || cuenta == 'banco') {
      final resIngresos = await db.rawQuery(
        "SELECT COALESCE(SUM(monto), 0) AS total "
        "FROM movimientos_caja "
        "WHERE company_id = ? AND COALESCE(activo, 1) = 1 "
        "AND tipo = 'ingreso' AND origen = ?",
        [companyId, cuenta],
      );

      final resEgresos = await db.rawQuery(
        "SELECT COALESCE(SUM(monto), 0) AS total "
        "FROM movimientos_caja "
        "WHERE company_id = ? AND COALESCE(activo, 1) = 1 "
        "AND tipo IN ('egreso', 'transferencia') AND origen = ?",
        [companyId, cuenta],
      );

      final ingresos = (resIngresos.first['total'] as num).toDouble();
      final egresos = (resEgresos.first['total'] as num).toDouble();

      return ingresos - egresos;
    }

    // 🔴 CARTERA = SOLO DEUDA (NO DINERO REAL)
    if (cuenta == 'cartera') {
      final res = await db.rawQuery(
        '''
      SELECT COALESCE(SUM(monto), 0) AS total
      FROM movimientos_caja
      WHERE company_id = ? AND origen = 'cartera' AND tipo = 'ingreso'
    ''',
        [companyId],
      );

      return (res.first['total'] as num).toDouble();
    }

    return 0;
  }

  /// Suma el total de todas las ventas registradas.
  Future<double> obtenerTotalVentas() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final res = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM ventas WHERE company_id = ? AND COALESCE(estado, 'emitida') != 'anulada'",
      [companyId],
    );
    return (res.first['total'] as num).toDouble();
  }

  Future<double> obtenerSaldoPorOrigen(String origen) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    final res = await db.rawQuery(
      '''
    SELECT COALESCE(SUM(monto), 0) AS total
    FROM movimientos_caja
    WHERE company_id = ? AND origen = ?
  ''',
      [companyId, origen],
    );

    return (res.first['total'] as num).toDouble();
  }
  // ── Proveedores ───────────────────────────────────────────

  Future<int> insertarProveedor(Map<String, dynamic> row) async {
    await validarFeatureHabilitada(FeatureKey.purchases);
    final db = await instance.database;

    return await db.insert('proveedores', await _conEmpresa(row));
  }

  Future<List<Map<String, dynamic>>> obtenerProveedores() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    return await db.query(
      'proveedores',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'nombre ASC',
    );
  }

  Future<int> actualizarProveedor(int id, Map<String, dynamic> datos) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    return await db.update(
      'proveedores',
      datos,
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  Future<int> eliminarProveedor(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    return await db.delete(
      'proveedores',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  Future<bool> proveedorTieneCompras(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM compras WHERE proveedor_id = ? AND company_id = ?',
      [id, companyId],
    );
    return ((res.first['total'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<int> insertarCliente(Map<String, dynamic> row) async {
    await validarFeatureHabilitada(FeatureKey.crm);
    final db = await instance.database;
    return await db.insert('clientes', await _conEmpresa(row));
  }

  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'clientes',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'nombre ASC',
    );
  }

  Future<int> actualizarCliente(int id, Map<String, dynamic> datos) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.update(
      'clientes',
      datos,
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  Future<int> eliminarCliente(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.delete(
      'clientes',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerCuentasPorCobrar() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'cuentas_por_cobrar',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  Future<int> registrarCuentaPorCobrar({
    required int ventaId,
    required double total,
    int? clienteId,
    String cliente = 'Cliente general',
    String descripcion = '',
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.insert('cuentas_por_cobrar', {
      'company_id': companyId,
      'cliente_id': clienteId,
      'cliente': cliente,
      'venta_id': ventaId,
      'total': total,
      'saldo': total,
      'estado': 'pendiente',
      'fecha': DateTime.now().toIso8601String(),
      'descripcion': descripcion.isEmpty
          ? 'Venta a crédito #$ventaId'
          : descripcion,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerAbonosCXC(int cuentaId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'abonos_cxc',
      where: 'cuenta_id = ? AND company_id = ?',
      whereArgs: [cuentaId, companyId],
      orderBy: 'fecha DESC',
    );
  }

  Future<void> registrarAbonoCXC({
    required int cuentaId,
    required double monto,
    required String metodoPago,
    String observacion = '',
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    final cuentas = await db.query(
      'cuentas_por_cobrar',
      where: 'id = ? AND company_id = ?',
      whereArgs: [cuentaId, companyId],
    );

    if (cuentas.isEmpty) return;

    final cuenta = cuentas.first;
    final saldoActual = (cuenta['saldo'] as num).toDouble();
    if (monto <= 0) {
      throw Exception('El abono debe ser mayor que cero.');
    }
    if (monto > saldoActual) {
      throw Exception('El abono no puede superar el saldo pendiente.');
    }
    final nuevoSaldo = saldoActual - monto;
    final nuevoEstado = nuevoSaldo <= 0 ? 'pagada' : 'parcial';

    await db.insert('abonos_cxc', {
      'company_id': companyId,
      'cuenta_id': cuentaId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'observacion': observacion,
      'fecha': DateTime.now().toIso8601String(),
    });

    await db.update(
      'cuentas_por_cobrar',
      {'saldo': nuevoSaldo <= 0 ? 0 : nuevoSaldo, 'estado': nuevoEstado},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cuentaId, companyId],
    );

    final origen = metodoPago.toUpperCase() == 'EFECTIVO' ? 'caja' : 'banco';

    await db.insert('movimientos_caja', {
      'company_id': companyId,
      'tipo': 'ingreso',
      'concepto': 'Abono cuenta por cobrar #$cuentaId',
      'monto': monto,
      'fecha': DateTime.now().toIso8601String(),
      'origen': origen,
    });

    await registrarAsientoAbonoCXC(
      cuentaId: cuentaId,
      monto: monto,
      metodoPago: metodoPago,
    );
  }

  Future<int> registrarCierreCaja({
    required double efectivoContado,
    String observacion = '',
    double baseAperturaSiguiente = 0,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final saldoSistema = await obtenerSaldoPorCuenta('caja');
    final diferencia = efectivoContado - saldoSistema;
    final excedente = efectivoContado - baseAperturaSiguiente;
    var retiroBanco = 0.0;

    if (baseAperturaSiguiente > 0 && excedente > 0) {
      retiroBanco = excedente;
      await insertarMovimiento({
        'tipo': 'transferencia',
        'concepto': 'Retiro cierre caja → Bancos (base \$${baseAperturaSiguiente.toStringAsFixed(0)})',
        'monto': retiroBanco,
        'fecha': DateTime.now().toIso8601String(),
        'origen': 'caja',
      });
      await insertarMovimiento({
        'tipo': 'ingreso',
        'concepto': 'Depósito desde cierre de caja',
        'monto': retiroBanco,
        'fecha': DateTime.now().toIso8601String(),
        'origen': 'banco',
      });
      await registrarAsientoTransferencia(
        origen: 'caja',
        destino: 'banco',
        monto: retiroBanco,
        concepto: 'Cierre caja: traslado excedente a bancos',
      );
    }

    final id = await db.insert('cierres_caja', {
      'company_id': companyId,
      'fecha': DateTime.now().toIso8601String(),
      'saldo_sistema': saldoSistema,
      'efectivo_contado': efectivoContado,
      'diferencia': diferencia,
      'observacion': observacion,
      'estado': 'cerrado',
      'base_apertura_siguiente': baseAperturaSiguiente,
      'retiro_banco': retiroBanco,
    });

    await registrarEventoAuditoria(
      accion: 'CIERRE_CAJA',
      entidad: 'cierres_caja',
      entidadId: id,
      detalle:
          'Sistema: $saldoSistema, contado: $efectivoContado, diferencia: $diferencia, base: $baseAperturaSiguiente, retiro banco: $retiroBanco',
    );
    await cambiarBloqueoOperativo(true);

    return id;
  }

  Future<List<Map<String, dynamic>>> obtenerCierresCaja() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'cierres_caja',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  Future<int> registrarConciliacionBancaria({
    required String cuenta,
    required double saldoExtracto,
    String observacion = '',
  }) async {
    final db = await instance.database;
    final cuentaNormalizada = cuenta.trim().toLowerCase();
    final saldoLibros = await obtenerSaldoPorCuenta(cuentaNormalizada);
    final diferencia = saldoExtracto - saldoLibros;

    final id = await db.insert('conciliaciones_bancarias', {
      'fecha': DateTime.now().toIso8601String(),
      'cuenta': cuentaNormalizada,
      'saldo_libros': saldoLibros,
      'saldo_extracto': saldoExtracto,
      'diferencia': diferencia,
      'observacion': observacion,
      'estado': 'registrada',
    });

    await registrarEventoAuditoria(
      accion: 'CONCILIACION_BANCARIA',
      entidad: 'conciliaciones_bancarias',
      entidadId: id,
      detalle:
          'Cuenta: $cuentaNormalizada, libros: $saldoLibros, extracto: $saldoExtracto, diferencia: $diferencia',
    );

    return id;
  }

  Future<List<Map<String, dynamic>>> obtenerConciliacionesBancarias() async {
    final db = await instance.database;
    return await db.query('conciliaciones_bancarias', orderBy: 'fecha DESC');
  }

  Future<int> guardarPresupuesto({
    required int anio,
    required int mes,
    required String categoria,
    required String tipo,
    required double valorPresupuestado,
    String observacion = '',
  }) async {
    final db = await instance.database;
    final valorReal = await _calcularValorRealPresupuesto(
      anio: anio,
      mes: mes,
      categoria: categoria,
      tipo: tipo,
    );
    final diferencia = tipo == 'ingreso'
        ? valorReal - valorPresupuestado
        : valorPresupuestado - valorReal;

    final datos = {
      'anio': anio,
      'mes': mes,
      'categoria': categoria.trim(),
      'tipo': tipo.trim().toLowerCase(),
      'valor_presupuestado': valorPresupuestado,
      'valor_real': valorReal,
      'diferencia': diferencia,
      'observacion': observacion,
      'fecha': DateTime.now().toIso8601String(),
    };

    final id = await db.insert(
      'presupuestos',
      datos,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await registrarEventoAuditoria(
      accion: 'GUARDAR_PRESUPUESTO',
      entidad: 'presupuestos',
      entidadId: id,
      detalle:
          '$anio-$mes $tipo $categoria presupuesto: $valorPresupuestado real: $valorReal',
    );

    return id;
  }

  Future<List<Map<String, dynamic>>> obtenerPresupuestos() async {
    final db = await instance.database;
    return await db.query(
      'presupuestos',
      orderBy: 'anio DESC, mes DESC, tipo ASC, categoria ASC',
    );
  }

  Future<void> recalcularPresupuestos() async {
    final db = await instance.database;
    final presupuestos = await obtenerPresupuestos();
    for (final p in presupuestos) {
      final valorReal = await _calcularValorRealPresupuesto(
        anio: (p['anio'] as num).toInt(),
        mes: (p['mes'] as num).toInt(),
        categoria: p['categoria'].toString(),
        tipo: p['tipo'].toString(),
      );
      final valorPresupuestado = (p['valor_presupuestado'] as num).toDouble();
      final tipo = p['tipo'].toString();
      final diferencia = tipo == 'ingreso'
          ? valorReal - valorPresupuestado
          : valorPresupuestado - valorReal;

      await db.update(
        'presupuestos',
        {'valor_real': valorReal, 'diferencia': diferencia},
        where: 'id = ?',
        whereArgs: [p['id']],
      );
    }
  }

  Future<double> _calcularValorRealPresupuesto({
    required int anio,
    required int mes,
    required String categoria,
    required String tipo,
  }) async {
    final db = await instance.database;
    final inicio = DateTime(anio, mes, 1).toIso8601String();
    final fin = DateTime(anio, mes + 1, 1).toIso8601String();
    final categoriaNormalizada = categoria.trim().toLowerCase();

    if (tipo.toLowerCase() == 'ingreso') {
      if (categoriaNormalizada.contains('venta')) {
        final res = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(total), 0) AS total
          FROM ventas
          WHERE fecha >= ? AND fecha < ?
          ''',
          [inicio, fin],
        );
        return (res.first['total'] as num).toDouble();
      }

      final res = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(monto), 0) AS total
        FROM movimientos_caja
        WHERE fecha >= ? AND fecha < ? AND tipo = 'ingreso'
        ''',
        [inicio, fin],
      );
      return (res.first['total'] as num).toDouble();
    }

    if (categoriaNormalizada.contains('compra') ||
        categoriaNormalizada.contains('inventario')) {
      final res = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(total), 0) AS total
        FROM compras
        WHERE fecha >= ? AND fecha < ? AND estado != 'anulada'
        ''',
        [inicio, fin],
      );
      return (res.first['total'] as num).toDouble();
    }

    final res = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(monto), 0) AS total
      FROM movimientos_caja
      WHERE fecha >= ? AND fecha < ? AND tipo = 'egreso'
      ''',
      [inicio, fin],
    );
    return (res.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> obtenerUsuarios() async {
    final db = await instance.database;
    return await db.query('usuarios', orderBy: 'activo DESC, nombre ASC');
  }

  Future<int> guardarUsuario({
    required String nombre,
    required String usuario,
    required String rol,
    String pin = '',
    bool activo = true,
  }) async {
    final db = await instance.database;
    final id = await db.insert('usuarios', {
      'nombre': nombre,
      'usuario': usuario,
      'rol': rol,
      'pin': pin,
      'activo': activo ? 1 : 0,
      'fecha': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await registrarEventoAuditoria(
      accion: 'GUARDAR_USUARIO',
      entidad: 'usuarios',
      entidadId: id,
      detalle: '$usuario - $rol',
    );
    return id;
  }

  Future<void> actualizarUsuario({
    required int id,
    required String nombre,
    required String usuario,
    required String rol,
    String pin = '',
    bool activo = true,
  }) async {
    final db = await instance.database;
    await db.update(
      'usuarios',
      {
        'nombre': nombre,
        'usuario': usuario,
        'rol': rol,
        'pin': pin,
        'activo': activo ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await registrarEventoAuditoria(
      accion: 'ACTUALIZAR_USUARIO',
      entidad: 'usuarios',
      entidadId: id,
      detalle: '$usuario - $rol',
    );
  }

  Future<void> eliminarUsuario(int id) async {
    final db = await instance.database;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);

    await registrarEventoAuditoria(
      accion: 'ELIMINAR_USUARIO',
      entidad: 'usuarios',
      entidadId: id,
      detalle: 'Usuario eliminado',
    );
  }

  Future<Map<String, dynamic>?> validarUsuarioLocal({
    required String usuario,
    required String pin,
  }) async {
    final db = await instance.database;
    final res = await db.query(
      'usuarios',
      where: 'LOWER(usuario) = ? AND activo = 1',
      whereArgs: [usuario.trim().toLowerCase()],
      limit: 1,
    );
    if (res.isEmpty) return null;

    final user = res.first;
    final pinGuardado = user['pin']?.toString() ?? '';
    if (pinGuardado.isNotEmpty && pinGuardado != pin) return null;
    return user;
  }

  Future<List<Map<String, dynamic>>> obtenerFacturasElectronicas() async {
    final db = await instance.database;
    return await db.query('facturas_electronicas', orderBy: 'fecha DESC');
  }

  Future<int> crearFacturaElectronicaBorrador({
    required int ventaId,
    String observacion = '',
  }) async {
    final db = await instance.database;
    final secuencia = await db.query(
      'secuencias_documentos',
      where: 'tipo = ?',
      whereArgs: ['venta'],
    );
    final prefijo = secuencia.isEmpty
        ? 'FE'
        : secuencia.first['prefijo'].toString();
    final siguiente = secuencia.isEmpty
        ? 1
        : (secuencia.first['siguiente'] as num).toInt();
    final consecutivo = '$prefijo-${siguiente.toString().padLeft(6, '0')}';
    final numero = siguiente;
    await db.update(
      'secuencias_documentos',
      {'siguiente': siguiente + 1},
      where: 'tipo = ?',
      whereArgs: ['venta'],
    );
    final ventas = await db.query(
      'ventas',
      where: 'id = ?',
      whereArgs: [ventaId],
    );
    final venta = ventas.isEmpty ? <String, dynamic>{} : ventas.first;
    final xml = _generarXmlFacturaElectronica(consecutivo, venta);

    final id = await db.insert('facturas_electronicas', {
      'venta_id': ventaId,
      'prefijo': 'FE',
      'numero': numero,
      'consecutivo': consecutivo,
      'estado': 'borrador',
      'xml': xml,
      'fecha': DateTime.now().toIso8601String(),
      'observacion': observacion,
    });

    await registrarEventoAuditoria(
      accion: 'CREAR_FACTURA_ELECTRONICA',
      entidad: 'facturas_electronicas',
      entidadId: id,
      detalle: 'Borrador $consecutivo para venta #$ventaId',
    );
    return id;
  }

  String _generarXmlFacturaElectronica(
    String consecutivo,
    Map<String, dynamic> venta,
  ) {
    final total = (venta['total'] as num?)?.toDouble() ?? 0;
    final impuesto = (venta['impuesto_total'] as num?)?.toDouble() ?? 0;
    final cliente = venta['cliente']?.toString() ?? 'Cliente general';
    return '''
<Invoice>
  <ID>$consecutivo</ID>
  <IssueDate>${DateTime.now().toIso8601String()}</IssueDate>
  <AccountingCustomerParty>$cliente</AccountingCustomerParty>
  <TaxTotal>$impuesto</TaxTotal>
  <PayableAmount>$total</PayableAmount>
  <Note>Borrador interno. Requiere validacion previa DIAN/proveedor tecnologico.</Note>
</Invoice>
''';
  }

  Future<int> actualizarEstadoFacturaElectronica({
    required int id,
    required String estado,
    String cufe = '',
    String respuestaDian = '',
  }) async {
    final db = await instance.database;
    return await db.update(
      'facturas_electronicas',
      {
        'estado': estado,
        'cufe': cufe,
        'respuesta_dian': respuestaDian,
        'validada': estado == 'validada'
            ? DateTime.now().toIso8601String()
            : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerEmpleados() async {
    final db = await instance.database;
    return await db.query('empleados', orderBy: 'activo DESC, nombre ASC');
  }

  Future<int> guardarEmpleado({
    required String nombre,
    required double salarioBase,
    String documento = '',
    String cargo = '',
    double auxilioTransporte = 0,
    String metodoPago = 'Efectivo',
    String banco = '',
    String numeroCuenta = '',
  }) async {
    final db = await instance.database;
    return await db.insert('empleados', {
      'nombre': nombre,
      'documento': documento,
      'cargo': cargo,
      'salario_base': salarioBase,
      'auxilio_transporte': auxilioTransporte,
      'metodo_pago': metodoPago,
      'banco': banco,
      'numero_cuenta': numeroCuenta,
      'activo': 1,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Future<int> actualizarEmpleado({
    required int id,
    required String nombre,
    required double salarioBase,
    required String documento,
    required String cargo,
    required double auxilioTransporte,
    required String metodoPago,
    required String banco,
    required String numeroCuenta,
  }) async {
    final db = await instance.database;
    return await db.update('empleados', {
      'nombre': nombre,
      'documento': documento,
      'cargo': cargo,
      'salario_base': salarioBase,
      'auxilio_transporte': auxilioTransporte,
      'metodo_pago': metodoPago,
      'banco': banco,
      'numero_cuenta': numeroCuenta,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> liquidarNomina({
    required int empleadoId,
    required int anio,
    required int mes,
    double horasExtra = 0,
    double bonificaciones = 0,
    double otrasDeducciones = 0,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final empleados = await db.query(
      'empleados',
      where: 'id = ?',
      whereArgs: [empleadoId],
    );
    if (empleados.isEmpty) throw Exception('Empleado no encontrado');

    final empleado = empleados.first;
    final salario = (empleado['salario_base'] as num).toDouble();
    final auxilio = (empleado['auxilio_transporte'] as num).toDouble();
    final salud = salario * 0.04;
    final pension = salario * 0.04;
    final devengado = salario + auxilio + horasExtra + bonificaciones;
    final deducciones = salud + pension + otrasDeducciones;
    final neto = devengado - deducciones;

    final metodoPago = empleado['metodo_pago']?.toString() ?? 'Efectivo';
    final banco = empleado['banco']?.toString() ?? '';
    final numeroCuenta = empleado['numero_cuenta']?.toString() ?? '';

    final esBanco = metodoPago.toUpperCase() != 'EFECTIVO';
    final origenCaja = esBanco ? 'banco' : 'caja';
    final cuentaDinero = esBanco ? '111005' : '110505';

    final movCajaId = await db.insert('movimientos_caja', {
      'company_id': companyId,
      'tipo': 'egreso',
      'concepto': 'Nómina $mes/$anio - ${empleado['nombre']}',
      'monto': neto,
      'fecha': DateTime.now().toIso8601String(),
      'origen': origenCaja,
    });

    final asientoId = await _registrarAsientoConCodigos(
      concepto: 'Liquidación Nómina $mes/$anio - ${empleado['nombre']}',
      referencia: 'NOM-$empleadoId',
      origen: 'nomina',
      lineas: [
        {
          'codigo': '510506',
          'debito': salario,
          'credito': 0,
          'descripcion': 'Gasto Sueldo: ${empleado['nombre']}',
        },
        if (auxilio > 0)
          {
            'codigo': '510527',
            'debito': auxilio,
            'credito': 0,
            'descripcion': 'Auxilio transporte: ${empleado['nombre']}',
          },
        if (horasExtra > 0)
          {
            'codigo': '510515',
            'debito': horasExtra,
            'credito': 0,
            'descripcion': 'Horas extras: ${empleado['nombre']}',
          },
        if (bonificaciones > 0)
          {
            'codigo': '510548',
            'debito': bonificaciones,
            'credito': 0,
            'descripcion': 'Bonificaciones: ${empleado['nombre']}',
          },
        {
          'codigo': '237005',
          'debito': 0,
          'credito': salud,
          'descripcion': 'Retención Salud 4%: ${empleado['nombre']}',
        },
        {
          'codigo': '238030',
          'debito': 0,
          'credito': pension,
          'descripcion': 'Retención Pensión 4%: ${empleado['nombre']}',
        },
        if (otrasDeducciones > 0)
          {
            'codigo': '237095',
            'debito': 0,
            'credito': otrasDeducciones,
            'descripcion': 'Otras deducciones: ${empleado['nombre']}',
          },
        {
          'codigo': cuentaDinero,
          'debito': 0,
          'credito': neto,
          'descripcion': 'Pago neto nómina: ${empleado['nombre']}',
        },
      ],
    );

    final id = await db.insert('nomina_liquidaciones', {
      'empleado_id': empleadoId,
      'empleado': empleado['nombre'],
      'anio': anio,
      'mes': mes,
      'devengado': devengado,
      'deducciones': deducciones,
      'neto': neto,
      'estado': 'liquidada',
      'fecha': DateTime.now().toIso8601String(),
      'metodo_pago': metodoPago,
      'banco': banco,
      'numero_cuenta': numeroCuenta,
      'asiento_id': asientoId,
      'movimiento_caja_id': movCajaId,
    });

    await registrarEventoAuditoria(
      accion: 'LIQUIDAR_NOMINA',
      entidad: 'nomina_liquidaciones',
      entidadId: id,
      detalle: '${empleado['nombre']} $anio-$mes neto $neto',
    );
    return id;
  }

  Future<void> anularLiquidacionNomina(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final liquidaciones = await db.query(
      'nomina_liquidaciones',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (liquidaciones.isEmpty) return;
    final liq = liquidaciones.first;

    await db.update(
      'nomina_liquidaciones',
      {'estado': 'anulada'},
      where: 'id = ?',
      whereArgs: [id],
    );

    final movId = liq['movimiento_caja_id'] as int?;
    if (movId != null) {
      await db.update(
        'movimientos_caja',
        {'activo': 0},
        where: 'id = ? AND company_id = ?',
        whereArgs: [movId, companyId],
      );
    }

    final asientoId = liq['asiento_id'] as int?;
    if (asientoId != null) {
      final lineas = await db.query(
        'asiento_lineas',
        where: 'asiento_id = ?',
        whereArgs: [asientoId],
      );
      final lineasReversion = lineas.map((l) => {
        'codigo': l['codigo'].toString(),
        'debito': (l['credito'] as num).toDouble(),
        'credito': (l['debito'] as num).toDouble(),
        'descripcion': 'Reversión: ${l['descripcion']}',
      }).toList();

      await _registrarAsientoConCodigos(
        concepto: 'Reversión liquidación nómina #${liq['id']}',
        referencia: 'REV-NOM-${liq['id']}',
        origen: 'nomina_reversion',
        lineas: lineasReversion,
      );
    }

    await registrarEventoAuditoria(
      accion: 'ANULAR_NOMINA',
      entidad: 'nomina_liquidaciones',
      entidadId: id,
      detalle: 'Anulación liquidación nómina #$id',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerNomina() async {
    final db = await instance.database;
    return await db.query(
      'nomina_liquidaciones',
      orderBy: 'anio DESC, mes DESC',
    );
  }

  Future<int> guardarActivoFijo({
    required String nombre,
    required double costo,
    required int vidaUtilMeses,
    String categoria = '',
    String observacion = '',
    String tipoDepreciacion = 'maquinaria',
    String codigoPuc = '1524',
    String codigoPucDepreciacion = '5160',
  }) async {
    final db = await instance.database;
    return await db.insert('activos_fijos', {
      'nombre': nombre,
      'categoria': categoria,
      'costo': costo,
      'fecha_compra': DateTime.now().toIso8601String(),
      'vida_util_meses': vidaUtilMeses,
      'depreciacion_acumulada': 0,
      'valor_libros': costo,
      'estado': 'activo',
      'observacion': observacion,
      'tipo_depreciacion': tipoDepreciacion,
      'codigo_puc': codigoPuc,
      'codigo_puc_depreciacion': codigoPucDepreciacion,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerActivosFijos() async {
    final db = await instance.database;
    final activos = await db.query(
      'activos_fijos',
      orderBy: 'fecha_compra DESC',
    );
    return activos.map((a) {
      final costo = (a['costo'] as num).toDouble();
      final vida = (a['vida_util_meses'] as num).toInt();
      final fecha =
          DateTime.tryParse(a['fecha_compra'].toString()) ?? DateTime.now();
      final meses =
          (DateTime.now().year - fecha.year) * 12 +
          DateTime.now().month -
          fecha.month;
      final depMensual = vida <= 0 ? 0 : costo / vida;
      final depAcumulada = (depMensual * meses).clamp(0, costo).toDouble();
      return {
        ...a,
        'depreciacion_acumulada_calc': depAcumulada,
        'valor_libros_calc': costo - depAcumulada,
        'depreciacion_mensual': depMensual,
      };
    }).toList();
  }

  Future<int> importarMovimientoExtracto({
    required String cuenta,
    required String fecha,
    required String descripcion,
    required double valor,
    String referencia = '',
  }) async {
    final db = await instance.database;
    return await db.insert('extractos_bancarios', {
      'cuenta': cuenta,
      'fecha': fecha,
      'descripcion': descripcion,
      'valor': valor.abs(),
      'tipo': valor >= 0 ? 'ingreso' : 'egreso',
      'conciliado': 0,
      'referencia': referencia,
      'creado': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> obtenerExtractosBancarios() async {
    final db = await instance.database;
    return await db.query('extractos_bancarios', orderBy: 'fecha DESC');
  }

  Future<int> guardarAdjunto({
    required String entidad,
    required String nombre,
    required String ruta,
    int? entidadId,
    String notas = '',
  }) async {
    final db = await instance.database;
    return await db.insert('adjuntos_documentos', {
      'entidad': entidad,
      'entidad_id': entidadId,
      'nombre': nombre,
      'ruta': ruta,
      'notas': notas,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> obtenerAdjuntos() async {
    final db = await instance.database;
    return await db.query('adjuntos_documentos', orderBy: 'fecha DESC');
  }

  Future<Map<String, double>> obtenerReporteFiscal({
    required int anio,
    required int mes,
  }) async {
    final db = await instance.database;
    final inicio = DateTime(anio, mes, 1).toIso8601String();
    final fin = DateTime(anio, mes + 1, 1).toIso8601String();

    Future<double> total(String sql) async {
      final res = await db.rawQuery(sql, [inicio, fin]);
      return (res.first['total'] as num).toDouble();
    }

    final ventas = await total(
      "SELECT COALESCE(SUM(total), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, 'emitida') != 'anulada'",
    );
    final compras = await total(
      "SELECT COALESCE(SUM(total), 0) AS total FROM compras WHERE fecha >= ? AND fecha < ? AND estado != 'anulada'",
    );
    final ivaGenerado = await total(
      "SELECT COALESCE(SUM(impuesto_total), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, 'emitida') != 'anulada'",
    );
    final ivaDescontable = await total(
      "SELECT COALESCE(SUM(impuesto_total), 0) AS total FROM compras WHERE fecha >= ? AND fecha < ? AND estado != 'anulada'",
    );
    final nomina = await total(
      "SELECT COALESCE(SUM(neto), 0) AS total FROM nomina_liquidaciones WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, 'activo') != 'anulado'",
    );
    final retefuenteVentas = await total(
      'SELECT COALESCE(SUM(retefuente), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, \'emitida\') != \'anulada\'',
    );
    final reteivaVentas = await total(
      'SELECT COALESCE(SUM(reteiva), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, \'emitida\') != \'anulada\'',
    );
    final reteicaVentas = await total(
      'SELECT COALESCE(SUM(reteica), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, \'emitida\') != \'anulada\'',
    );
    final retefuenteCompras = await total(
      'SELECT COALESCE(SUM(retefuente), 0) AS total FROM compras WHERE fecha >= ? AND fecha < ? AND estado != \'anulada\'',
    );

    return {
      'ventas': ventas,
      'compras': compras,
      'iva_generado': ivaGenerado,
      'iva_descontable': ivaDescontable,
      'iva_por_pagar': ivaGenerado - ivaDescontable,
      'nomina': nomina,
      'retefuente_practicada': retefuenteVentas,
      'reteiva_practicada': reteivaVentas,
      'reteica_practicada': reteicaVentas,
      'retefuente_recibida': retefuenteCompras,
    };
  }

  Future<int> registrarEventoAuditoria({
    required String accion,
    required String entidad,
    int? entidadId,
    String detalle = '',
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.insert('auditoria_eventos', {
      'company_id': companyId,
      'fecha': DateTime.now().toIso8601String(),
      'accion': accion,
      'entidad': entidad,
      'entidad_id': entidadId,
      'detalle': detalle,
      'usuario': 'local',
    });
  }

  Future<List<Map<String, dynamic>>> obtenerAuditoria() async {
    final db = await instance.database;
    return await db.query('auditoria_eventos', orderBy: 'fecha DESC');
  }

  Future<Map<String, double>> obtenerEstadosFinancieros() async {
    final balance = await obtenerBalanceComprobacion();
    double activos = 0;
    double pasivos = 0;
    double patrimonio = 0;
    double ingresos = 0;
    double gastos = 0;
    double costos = 0;

    for (final cuenta in balance) {
      final tipo = cuenta['tipo'].toString();
      final saldo = (cuenta['saldo'] as num?)?.toDouble() ?? 0;

      switch (tipo) {
        case 'activo':
          activos += saldo;
          break;
        case 'pasivo':
          pasivos += saldo;
          break;
        case 'patrimonio':
          patrimonio += saldo;
          break;
        case 'ingreso':
          ingresos += saldo;
          break;
        case 'gasto':
          gastos += saldo;
          break;
        case 'costo':
          costos += saldo;
          break;
      }
    }

    final utilidad = ingresos - costos - gastos;

    return {
      'activos': activos,
      'pasivos': pasivos,
      'patrimonio': patrimonio,
      'ingresos': ingresos,
      'costos': costos,
      'gastos': gastos,
      'utilidad': utilidad,
      'cuadre': activos - (pasivos + patrimonio + utilidad),
    };
  }

  Future<Map<String, dynamic>> obtenerEmpresaConfig() async {
    final db = await instance.database;
    final res = await db.query('empresa_config', where: 'id = 1', limit: 1);
    if (res.isEmpty) {
      return {'id': 1, 'nombre': 'MerkaERP', 'moneda': 'COP'};
    }
    return res.first;
  }

  Future<void> guardarEmpresaConfig(Map<String, dynamic> datos) async {
    final db = await instance.database;
    await db.insert('empresa_config', {
      'id': 1,
      ...datos,
      'actualizado': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> obtenerEmpresas() async {
    final db = await instance.database;
    await _crearTablasMultiempresaYConfig(db);
    return await db.query('empresas', orderBy: 'activa DESC, nombre ASC');
  }

  Future<int> guardarEmpresa(Map<String, dynamic> datos) async {
    final db = await instance.database;
    await _crearTablasMultiempresaYConfig(db);
    return await db.insert('empresas', {
      ...datos,
      'fecha': DateTime.now().toIso8601String(),
      'activa': datos['activa'] ?? 1,
    });
  }

  Future<void> actualizarEmpresa(int id, Map<String, dynamic> datos) async {
    final db = await instance.database;
    await db.update(
      'empresas',
      {
        ...datos,
        'fecha': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> eliminarEmpresa(int id) async {
    final db = await instance.database;
    await db.delete('empresas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> seleccionarEmpresa(Map<String, dynamic> empresa) async {
    await guardarEmpresaConfig({
      'nombre': empresa['nombre'] ?? 'MerkaERP',
      'nit': empresa['nit'] ?? '',
      'regimen': empresa['regimen'] ?? '',
      'direccion': empresa['direccion'] ?? '',
      'telefono': empresa['telefono'] ?? '',
      'email': empresa['email'] ?? '',
      'ciudad': empresa['ciudad'] ?? '',
      'moneda': empresa['moneda'] ?? 'COP',
      'logo_path': empresa['logo_path'] ?? '',
    });
    await _guardarAppConfig('empresa_actual_id', empresa['id'].toString());
  }

  Future<void> _guardarAppConfig(String clave, String valor) async {
    final db = await instance.database;
    await _crearTablasMultiempresaYConfig(db);
    await db.insert('app_config', {
      'clave': clave,
      'valor': valor,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> obtenerAppConfig(String clave) async {
    final db = await instance.database;
    await _crearTablasMultiempresaYConfig(db);
    final res = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: [clave],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['valor']?.toString();
  }

  Future<ActiveCompanyConfiguration> obtenerConfiguracionActiva() async {
    final db = await instance.database;
    final companyId = await _sincronizarEmpresaLegacy(db);

    final companyRows = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [companyId],
      limit: 1,
    );
    final company = companyRows.isEmpty
        ? {'id': companyId, 'name': 'MerkaERP'}
        : companyRows.first;

    final featureRows = await db.query(
      'company_features',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
    final features = FeatureRegistry.defaultFeatures();
    for (final row in featureRows) {
      features[row['feature_key'].toString()] =
          (row['enabled'] as num? ?? 0) == 1;
    }

    final settingRows = await db.query(
      'company_settings',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
    final settings = <String, String>{};
    for (final row in settingRows) {
      settings[row['setting_key'].toString()] =
          row['setting_value']?.toString() ?? '';
    }

    return ActiveCompanyConfiguration(
      companyId: companyId,
      companyName: company['name']?.toString() ?? 'MerkaERP',
      features: features,
      settings: settings,
      onboardingCompleted: settings['onboarding_completed'] == '1',
    );
  }

  Future<void> guardarConfiguracionInicial({
    required Company company,
    required CompanyProfile profile,
    required Map<String, bool> features,
    required Map<String, String> settings,
  }) async {
    final db = await instance.database;
    await _crearTablasConfiguracionEmpresarial(db);
    await _crearTablasEmpresaYComprobantes(db);
    await _crearTablasMultiempresaYConfig(db);

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final companyId = await txn.insert('companies', {
        ...company.toMap(),
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('company_profiles', {
        ...profile.toMap(),
        'company_id': companyId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await _guardarCompanyFeaturesEnDB(txn, companyId, features);
      await _guardarCompanySettingsEnDB(txn, companyId, {
        ...settings,
        'onboarding_completed': '1',
      });

      await txn.insert('app_config', {
        'clave': 'company_active_id',
        'valor': companyId.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('empresa_config', {
        'id': 1,
        'nombre': company.name,
        'nit': company.taxId,
        'regimen': profile.taxRegime,
        'moneda': company.currency,
        'actualizado': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    await registrarEventoAuditoria(
      accion: 'CONFIGURACION_INICIAL',
      entidad: 'companies',
      detalle: '${company.name} configurada por onboarding',
    );
  }

  Future<void> aplicarCatalogoInicial({
    required List<Map<String, dynamic>> baseCatalog,
    required Map<String, bool> features,
    required Map<String, String> settings,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final vatEnabled = settings['vat_enabled'] != '0';
    final defaultTax = vatEnabled
        ? (double.tryParse(settings['default_tax'] ?? '') ?? 0)
        : 0.0;
    final invoicePrefix = settings['invoice_prefix']?.trim();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await _sembrarCatalogosMaestrosSiNecesario(txn, companyId);

      if (invoicePrefix != null && invoicePrefix.isNotEmpty) {
        for (final tipo in const ['venta', 'ventas']) {
          await txn.insert('secuencias_documentos', {
            'tipo': tipo,
            'prefijo': invoicePrefix,
            'siguiente': 1,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          await txn.update(
            'secuencias_documentos',
            {'prefijo': invoicePrefix},
            where: 'tipo = ?',
            whereArgs: [tipo],
          );
        }
      }

      for (final method in const [
        'EFECTIVO',
        'TRANSFERENCIA',
        'TARJETA',
        'NEQUI',
        'DAVIPLATA',
        'CREDITO',
        'PAGO MIXTO',
      ]) {
        await txn.insert('metodos_pago', {
          'nombre': method,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final inventoryEnabled = features[FeatureKey.inventory] == true;
      if (inventoryEnabled) {
        for (final item in baseCatalog) {
          final name = item['nombre']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final exists = await txn.query(
            'productos',
            where: 'company_id = ? AND lower(nombre) = lower(?)',
            whereArgs: [companyId, name],
            limit: 1,
          );
          if (exists.isNotEmpty) continue;
          await txn.insert('productos', {
            'company_id': companyId,
            'nombre': name,
            'unidad_base': item['unidad']?.toString() ?? 'UND',
            'stock': 0,
            'costo': 0,
            'precio': 0,
            'impuesto_pct': defaultTax,
            'codigo_barras': '',
            'conversion_nombre': '',
            'conversion_cantidad': 0,
          });
        }
      }

      await txn.insert('company_settings', {
        'company_id': companyId,
        'setting_key': 'catalog_seeded_at',
        'setting_value': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> obtenerCatalogoImpuestos() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    await _sembrarCatalogosMaestrosSiNecesario(db, companyId);
    return await db.query(
      'tax_catalog',
      where: 'company_id = ? AND active = 1',
      whereArgs: [companyId],
      orderBy: 'rate ASC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerCatalogoUnidades() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    await _sembrarCatalogosMaestrosSiNecesario(db, companyId);
    return await db.query(
      'unit_catalog',
      where: 'company_id = ? AND active = 1',
      whereArgs: [companyId],
      orderBy: 'label ASC',
    );
  }

  Future<Map<String, String>> obtenerReglasContablesEmpresa([DatabaseExecutor? txn]) async {
    final executor = txn ?? await instance.database;
    final companyId = await obtenerEmpresaActivaId(executor);
    if (txn == null) {
      final db = await instance.database;
      await _sembrarCatalogosMaestrosSiNecesario(db, companyId);
    }
    final rows = await executor.query(
      'accounting_rule_settings',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
    return {
      for (final row in rows)
        row['rule_key'].toString(): row['account_code'].toString(),
    };
  }

  Future<void> guardarCompanyFeatures(
    int companyId,
    Map<String, bool> features,
  ) async {
    final db = await instance.database;
    await _crearTablasConfiguracionEmpresarial(db);
    await _guardarCompanyFeaturesEnDB(db, companyId, features);
    await registrarEventoAuditoria(
      accion: 'ACTUALIZAR_FEATURES',
      entidad: 'company_features',
      entidadId: companyId,
      detalle: features.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .join(', '),
    );
  }

  Future<void> guardarCompanySettings(
    int companyId,
    Map<String, String> settings,
  ) async {
    final db = await instance.database;
    await _crearTablasConfiguracionEmpresarial(db);
    await _guardarCompanySettingsEnDB(db, companyId, settings);
    await registrarEventoAuditoria(
      accion: 'ACTUALIZAR_SETTINGS',
      entidad: 'company_settings',
      entidadId: companyId,
      detalle: settings.keys.join(', '),
    );
  }

  Future<void> _guardarCompanyFeaturesEnDB(
    DatabaseExecutor db,
    int companyId,
    Map<String, bool> features,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (final entry in features.entries) {
      if (!FeatureRegistry.isKnown(entry.key)) continue;
      await db.insert('company_features', {
        'company_id': companyId,
        'feature_key': entry.key,
        'enabled': entry.value ? 1 : 0,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _guardarCompanySettingsEnDB(
    DatabaseExecutor db,
    int companyId,
    Map<String, String> settings,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (final entry in settings.entries) {
      await db.insert('company_settings', {
        'company_id': companyId,
        'setting_key': entry.key,
        'setting_value': entry.value,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<bool> operacionBloqueadaPorCierre() async {
    return (await obtenerAppConfig('operacion_bloqueada')) == '1';
  }

  Future<bool> featureEstaHabilitada(String featureKey) async {
    final config = await obtenerConfiguracionActiva();
    return config.features[featureKey] ?? false;
  }

  Future<void> validarFeatureHabilitada(String featureKey) async {
    if (!await featureEstaHabilitada(featureKey)) {
      throw Exception('Modulo deshabilitado para la empresa activa.');
    }
  }

  Future<void> cambiarBloqueoOperativo(bool bloqueado) async {
    await _guardarAppConfig('operacion_bloqueada', bloqueado ? '1' : '0');
    await registrarEventoAuditoria(
      accion: bloqueado ? 'BLOQUEAR_OPERACION' : 'ABRIR_OPERACION',
      entidad: 'app_config',
      detalle: bloqueado
          ? 'Operacion bloqueada por cierre de caja'
          : 'Operacion reabierta manualmente',
    );
  }

  Future<String> _tomarConsecutivo(Transaction txn, String tipo) async {
    final secuencia = await txn.query(
      'secuencias_documentos',
      where: 'tipo = ?',
      whereArgs: [tipo],
      limit: 1,
    );

    if (secuencia.isEmpty) {
      await txn.insert('secuencias_documentos', {
        'tipo': tipo,
        'prefijo': 'DOC',
        'siguiente': 1,
      });
      return 'DOC-000001';
    }

    final prefijo = secuencia.first['prefijo'].toString();
    final siguiente = (secuencia.first['siguiente'] as num).toInt();
    final consecutivo = '$prefijo-${siguiente.toString().padLeft(6, '0')}';

    await txn.update(
      'secuencias_documentos',
      {'siguiente': siguiente + 1},
      where: 'tipo = ?',
      whereArgs: [tipo],
    );

    return consecutivo;
  }

  Future<int> _registrarComprobanteEnTransaccion(
    Transaction txn, {
    required int companyId,
    required int asientoId,
    required String tipo,
    required String concepto,
    required double total,
    String? tercero,
    DateTime? fecha,
  }) async {
    final secuencia = await txn.query(
      'secuencias_documentos',
      where: 'tipo = ?',
      whereArgs: [tipo],
      limit: 1,
    );
    final prefijo = secuencia.isEmpty
        ? 'DOC'
        : secuencia.first['prefijo'].toString();
    final consecutivo = await _tomarConsecutivo(txn, tipo);
    final numero = int.tryParse(consecutivo.split('-').last) ?? 0;

    return await txn.insert('comprobantes_contables', {
      'company_id': companyId,
      'tipo': tipo,
      'prefijo': prefijo,
      'numero': numero,
      'consecutivo': consecutivo,
      'asiento_id': asientoId,
      'fecha': (fecha ?? DateTime.now()).toIso8601String(),
      'concepto': concepto,
      'tercero': tercero,
      'total': total,
      'estado': 'emitido',
    });
  }

  Future<List<Map<String, dynamic>>> obtenerComprobantes() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query(
      'comprobantes_contables',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'fecha DESC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerDetalleComprobante(
    int comprobanteId,
  ) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.rawQuery(
      '''
      SELECT
        l.*,
        c.codigo,
        c.nombre AS cuenta,
        c.tipo,
        c.naturaleza
      FROM comprobantes_contables cc
      INNER JOIN asiento_lineas l ON l.asiento_id = cc.asiento_id
      INNER JOIN cuentas_contables c ON c.id = l.cuenta_id
      WHERE cc.id = ? AND cc.company_id = ?
      ORDER BY l.id ASC
      ''',
      [comprobanteId, companyId],
    );
  }

  // ── ABONOS CUENTAS POR PAGAR ─────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerPeriodosContables() async {
    final db = await instance.database;
    return await db.query('periodos_contables', orderBy: 'anio DESC, mes DESC');
  }

  Future<void> abrirPeriodoContable({
    required int anio,
    required int mes,
    String observacion = '',
  }) async {
    final db = await instance.database;
    await db.insert('periodos_contables', {
      'anio': anio,
      'mes': mes,
      'estado': 'abierto',
      'fecha_apertura': DateTime.now().toIso8601String(),
      'observacion': observacion,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await registrarEventoAuditoria(
      accion: 'ABRIR_PERIODO',
      entidad: 'periodos_contables',
      detalle: '$anio-${mes.toString().padLeft(2, '0')}',
    );
  }

  Future<void> cerrarPeriodoContable({
    required int anio,
    required int mes,
    String observacion = '',
  }) async {
    final db = await instance.database;
    await db.insert('periodos_contables', {
      'anio': anio,
      'mes': mes,
      'estado': 'cerrado',
      'fecha_apertura': DateTime.now().toIso8601String(),
      'fecha_cierre': DateTime.now().toIso8601String(),
      'observacion': observacion,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.update(
      'periodos_contables',
      {
        'estado': 'cerrado',
        'fecha_cierre': DateTime.now().toIso8601String(),
        'observacion': observacion,
      },
      where: 'anio = ? AND mes = ?',
      whereArgs: [anio, mes],
    );

    await registrarEventoAuditoria(
      accion: 'CERRAR_PERIODO',
      entidad: 'periodos_contables',
      detalle: '$anio-${mes.toString().padLeft(2, '0')}',
    );
  }

  Future<bool> periodoEstaCerrado(DateTime fecha, [DatabaseExecutor? txn]) async {
    final executor = txn ?? await instance.database;
    final res = await executor.query(
      'periodos_contables',
      where: 'anio = ? AND mes = ? AND estado = ?',
      whereArgs: [fecha.year, fecha.month, 'cerrado'],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> _validarPeriodoAbierto(DateTime fecha, [DatabaseExecutor? txn]) async {
    if (await periodoEstaCerrado(fecha, txn)) {
      throw Exception(
        'El periodo ${fecha.year}-${fecha.month.toString().padLeft(2, '0')} está cerrado.',
      );
    }
  }

  Future<void> registrarAbonoCXP({
    required int cuentaId,
    required double monto,
    required String metodoPago,
    String observacion = '',
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();

    // 🔥 obtener cuenta actual
    final cuentas = await db.query(
      'cuentas_por_pagar',
      where: 'id = ? AND company_id = ?',
      whereArgs: [cuentaId, companyId],
    );

    if (cuentas.isEmpty) return;

    final cuenta = cuentas.first;

    final saldoActual = (cuenta['saldo'] as num).toDouble();
    if (monto <= 0) {
      throw Exception('El abono debe ser mayor que cero.');
    }
    if (monto > saldoActual) {
      throw Exception('El abono no puede superar el saldo pendiente.');
    }

    final nuevoSaldo = saldoActual - monto;

    // 🔥 nuevo estado
    String nuevoEstado = 'parcial';

    if (nuevoSaldo <= 0) {
      nuevoEstado = 'pagada';
    }

    // 🔥 registrar abono
    await db.insert('abonos_cxp', {
      'company_id': companyId,
      'cuenta_id': cuentaId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'observacion': observacion,
      'fecha': DateTime.now().toIso8601String(),
    });

    // 🔥 actualizar saldo
    await db.update(
      'cuentas_por_pagar',
      {'saldo': nuevoSaldo <= 0 ? 0 : nuevoSaldo, 'estado': nuevoEstado},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cuentaId, companyId],
    );

    // 🔥 registrar salida de dinero
    final origen = metodoPago.toUpperCase() == 'EFECTIVO' ? 'caja' : 'banco';

    await db.insert('movimientos_caja', {
      'company_id': companyId,
      'tipo': 'egreso',
      'concepto': 'Abono cuenta por pagar #$cuentaId',
      'monto': monto,
      'fecha': DateTime.now().toIso8601String(),
      'origen': origen,
    });

    await registrarAsientoAbonoCXP(
      cuentaId: cuentaId,
      monto: monto,
      metodoPago: metodoPago,
    );
  }

  Future<List<Map<String, dynamic>>> obtenerCuentasContables() async {
    final db = await instance.database;
    return await db.query(
      'cuentas_contables',
      where: 'activa = 1',
      orderBy: 'codigo ASC',
    );
  }

  Future<int> insertarCuentaContable(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('cuentas_contables', row);
  }

  Future<int> registrarAsientoContable({
    required String concepto,
    required List<Map<String, dynamic>> lineas,
    String? referencia,
    String origen = 'manual',
    DateTime? fecha,
  }) async {
    if (lineas.length < 2) {
      throw Exception('Un asiento necesita al menos dos líneas.');
    }

    final totalDebito = lineas.fold<double>(
      0,
      (sum, linea) => sum + ((linea['debito'] as num?)?.toDouble() ?? 0),
    );
    final totalCredito = lineas.fold<double>(
      0,
      (sum, linea) => sum + ((linea['credito'] as num?)?.toDouble() ?? 0),
    );

    if ((totalDebito - totalCredito).abs() > 0.01) {
      throw Exception('El asiento no está balanceado.');
    }
    if (totalDebito <= 0) {
      throw Exception('El asiento debe tener valor.');
    }

    final fechaAsiento = fecha ?? DateTime.now();
    await _validarPeriodoAbierto(fechaAsiento);

    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.transaction((txn) async {
      final asientoId = await txn.insert('asientos_contables', {
        'company_id': companyId,
        'fecha': fechaAsiento.toIso8601String(),
        'concepto': concepto,
        'referencia': referencia,
        'origen': origen,
        'estado': 'registrado',
      });

      for (final linea in lineas) {
        final debito = ((linea['debito'] as num?)?.toDouble() ?? 0);
        final credito = ((linea['credito'] as num?)?.toDouble() ?? 0);

        if (debito < 0 || credito < 0 || (debito > 0 && credito > 0)) {
          throw Exception('Cada línea debe tener débito o crédito, no ambos.');
        }

        await txn.insert('asiento_lineas', {
          'company_id': companyId,
          'asiento_id': asientoId,
          'cuenta_id': linea['cuenta_id'],
          'descripcion': linea['descripcion'] ?? concepto,
          'debito': debito,
          'credito': credito,
          'tercero': linea['tercero'],
        });
      }

      await _registrarComprobanteEnTransaccion(
        txn,
        companyId: companyId,
        asientoId: asientoId,
        tipo: origen == 'manual' ? 'asiento' : origen,
        concepto: concepto,
        total: totalDebito,
        fecha: fechaAsiento,
      );

      return asientoId;
    });
  }

  Future<List<Map<String, dynamic>>> obtenerAsientosContables() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.rawQuery(
      '''
      SELECT
        a.id,
        a.fecha,
        a.concepto,
        a.referencia,
        a.origen,
        a.estado,
        COALESCE(SUM(l.debito), 0) AS debito,
        COALESCE(SUM(l.credito), 0) AS credito
      FROM asientos_contables a
      LEFT JOIN asiento_lineas l ON l.asiento_id = a.id
      WHERE a.company_id = ?
      GROUP BY a.id
      ORDER BY a.fecha DESC, a.id DESC
    ''',
      [companyId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerDetalleAsiento(
    int asientoId,
  ) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.rawQuery(
      '''
      SELECT
        l.*,
        c.codigo,
        c.nombre AS cuenta,
        c.tipo,
        c.naturaleza
      FROM asiento_lineas l
      INNER JOIN cuentas_contables c ON c.id = l.cuenta_id
      WHERE l.asiento_id = ? AND l.company_id = ?
      ORDER BY l.id ASC
    ''',
      [asientoId, companyId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerBalanceComprobacion() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.rawQuery(
      '''
      SELECT
        c.id,
        c.codigo,
        c.nombre,
        c.tipo,
        c.naturaleza,
        COALESCE(SUM(l.debito), 0) AS debito,
        COALESCE(SUM(l.credito), 0) AS credito,
        CASE
          WHEN c.naturaleza = 'debito'
          THEN COALESCE(SUM(l.debito), 0) - COALESCE(SUM(l.credito), 0)
          ELSE COALESCE(SUM(l.credito), 0) - COALESCE(SUM(l.debito), 0)
        END AS saldo
      FROM cuentas_contables c
      LEFT JOIN asiento_lineas l ON l.cuenta_id = c.id AND l.company_id = ?
      WHERE c.activa = 1
      GROUP BY c.id
      ORDER BY c.codigo ASC
    ''',
      [companyId],
    );
  }

  Future<int> _cuentaIdPorCodigo(Transaction txn, String codigo) async {
    final res = await txn.query(
      'cuentas_contables',
      columns: ['id'],
      where: 'codigo = ?',
      whereArgs: [codigo],
      limit: 1,
    );

    if (res.isEmpty) {
      throw Exception('No existe la cuenta contable $codigo.');
    }

    return res.first['id'] as int;
  }

  Future<int> _registrarAsientoConCodigos({
    required String concepto,
    required List<Map<String, dynamic>> lineas,
    String? referencia,
    String origen = 'automatico',
    DateTime? fecha,
    Transaction? txn,
  }) async {
    final fechaAsiento = fecha ?? DateTime.now();
    await _validarPeriodoAbierto(fechaAsiento, txn);
    final companyId = await obtenerEmpresaActivaId(txn);

    Future<int> performRegistration(Transaction t) async {
      final lineasConCuenta = <Map<String, dynamic>>[];

      for (final linea in lineas) {
        lineasConCuenta.add({
          ...linea,
          'cuenta_id': await _cuentaIdPorCodigo(
            t,
            linea['codigo'].toString(),
          ),
        });
      }

      final totalDebito = lineasConCuenta.fold<double>(
        0,
        (sum, linea) => sum + ((linea['debito'] as num?)?.toDouble() ?? 0),
      );
      final totalCredito = lineasConCuenta.fold<double>(
        0,
        (sum, linea) => sum + ((linea['credito'] as num?)?.toDouble() ?? 0),
      );

      if ((totalDebito - totalCredito).abs() > 0.01) {
        throw Exception('El asiento automático no está balanceado.');
      }

      final asientoId = await t.insert('asientos_contables', {
        'company_id': companyId,
        'fecha': fechaAsiento.toIso8601String(),
        'concepto': concepto,
        'referencia': referencia,
        'origen': origen,
        'estado': 'registrado',
      });

      for (final linea in lineasConCuenta) {
        await t.insert('asiento_lineas', {
          'company_id': companyId,
          'asiento_id': asientoId,
          'cuenta_id': linea['cuenta_id'],
          'descripcion': linea['descripcion'] ?? concepto,
          'debito': ((linea['debito'] as num?)?.toDouble() ?? 0),
          'credito': ((linea['credito'] as num?)?.toDouble() ?? 0),
          'tercero': linea['tercero'],
        });
      }

      final terceros = lineasConCuenta
          .map((linea) => linea['tercero'])
          .where((tercero) => tercero != null && tercero.toString().isNotEmpty)
          .map((tercero) => tercero.toString())
          .toList();

      await _registrarComprobanteEnTransaccion(
        t,
        companyId: companyId,
        asientoId: asientoId,
        tipo: origen,
        concepto: concepto,
        total: totalDebito,
        tercero: terceros.isEmpty ? null : terceros.first,
        fecha: fechaAsiento,
      );

      return asientoId;
    }

    if (txn != null) {
      return await performRegistration(txn);
    } else {
      final db = await instance.database;
      return await db.transaction((t) => performRegistration(t));
    }
  }

  String _codigoCuentaDinero(String origen) {
    final cuenta = origen.toLowerCase().trim();
    if (cuenta == 'banco') return '1110';
    if (cuenta == 'cartera') return '1305';
    return '1105';
  }

  Future<int> registrarAsientoVenta({
    required int ventaId,
    required double total,
    required String metodoPago,
    double costoVenta = 0,
    double impuesto = 0,
    Transaction? txn,
  }) async {
    final companyId = await obtenerEmpresaActivaId(txn);
    List<Map<String, dynamic>> saleRows;
    
    if (txn != null) {
      saleRows = await txn.query(
        'ventas',
        where: 'id = ? AND company_id = ?',
        whereArgs: [ventaId, companyId],
        limit: 1,
      );
    } else {
      final db = await instance.database;
      saleRows = await db.query(
        'ventas',
        where: 'id = ? AND company_id = ?',
        whereArgs: [ventaId, companyId],
        limit: 1,
      );
    }

    double cashPayment = 0;
    double bankPayment = 0;
    double credit = 0;
    double retefuente = 0;
    double reteiva = 0;
    double reteica = 0;
    String clientName = 'Cliente general';

    if (saleRows.isNotEmpty) {
      final sale = saleRows.first;
      cashPayment = (sale['efectivo'] as num?)?.toDouble() ?? 0;
      bankPayment = (sale['transferencia'] as num?)?.toDouble() ?? 0;
      credit = (sale['credito'] as num?)?.toDouble() ?? 0;
      retefuente = (sale['retefuente'] as num?)?.toDouble() ?? 0;
      reteiva = (sale['reteiva'] as num?)?.toDouble() ?? 0;
      reteica = (sale['reteica'] as num?)?.toDouble() ?? 0;
      clientName = sale['cliente']?.toString() ?? 'Cliente general';
    }

    if (cashPayment == 0 && bankPayment == 0 && credit == 0) {
      final normalized = metodoPago.toUpperCase().trim();
      if (normalized == 'CREDITO') {
        credit = total;
      } else if (normalized == 'TRANSFERENCIA' || normalized == 'TARJETA' || normalized == 'NEQUI' || normalized == 'DAVIPLATA') {
        bankPayment = total;
      } else {
        cashPayment = total;
      }
    }

    final rules = await _reglasContablesActivas(txn);
    final draft = AccountingEngine(rules: rules).sale(
      saleId: ventaId,
      total: total,
      cashPayment: cashPayment,
      bankPayment: bankPayment,
      credit: credit,
      costOfSale: costoVenta,
      tax: impuesto,
      retefuente: retefuente,
      reteiva: reteiva,
      reteica: reteica,
      client: clientName,
    );

    return await _registrarAsientoConCodigos(
      concepto: draft.concept,
      referencia: draft.reference,
      origen: draft.origin,
      lineas: draft.toLegacyLines(),
      txn: txn,
    );
  }

  Future<int> registrarAsientoCompra({
    required int compraId,
    required double total,
    required double pagoCaja,
    required double pagoBanco,
    required double credito,
    String? proveedor,
    double impuesto = 0,
    Transaction? txn,
  }) async {
    final rules = await _reglasContablesActivas(txn);
    final draft = AccountingEngine(rules: rules).purchase(
      purchaseId: compraId,
      total: total,
      cashPayment: pagoCaja,
      bankPayment: pagoBanco,
      credit: credito,
      supplier: proveedor,
      tax: impuesto,
    );

    return await _registrarAsientoConCodigos(
      concepto: draft.concept,
      referencia: draft.reference,
      origen: draft.origin,
      lineas: draft.toLegacyLines(),
      txn: txn,
    );
  }

  Future<AccountingRuleSet> _reglasContablesActivas([DatabaseExecutor? txn]) async {
    final rules = await obtenerReglasContablesEmpresa(txn);
    return AccountingRuleSet(
      cashAccount: rules['cash'] ?? '1105',
      bankAccount: rules['bank'] ?? '1110',
      accountsReceivableAccount: rules['accounts_receivable'] ?? '1305',
      inventoryAccount: rules['inventory'] ?? '1435',
      taxDeductibleAccount: rules['tax_deductible'] ?? '1355',
      accountsPayableAccount: rules['accounts_payable'] ?? '2205',
      taxPayableAccount: rules['tax_payable'] ?? '2408',
      salesRevenueAccount: rules['sales_revenue'] ?? '4135',
      costOfSalesAccount: rules['cost_of_sales'] ?? '6135',
    );
  }

  Future<int> registrarAsientoMovimientoCaja({
    required String tipo,
    required String concepto,
    required double monto,
    required String origen,
  }) async {
    final cuentaDinero = _codigoCuentaDinero(origen);
    final esIngreso = tipo.toLowerCase().trim() == 'ingreso';

    return await _registrarAsientoConCodigos(
      concepto: concepto,
      origen: 'caja',
      lineas: [
        {
          'codigo': esIngreso ? cuentaDinero : '5135',
          'debito': monto,
          'credito': 0,
          'descripcion': concepto,
        },
        {
          'codigo': esIngreso ? '4135' : cuentaDinero,
          'debito': 0,
          'credito': monto,
          'descripcion': concepto,
        },
      ],
    );
  }

  Future<int> registrarAsientoTransferencia({
    required String origen,
    required String destino,
    required double monto,
    required String concepto,
  }) async {
    return await _registrarAsientoConCodigos(
      concepto: concepto,
      origen: 'transferencias',
      lineas: [
        {
          'codigo': _codigoCuentaDinero(destino),
          'debito': monto,
          'credito': 0,
          'descripcion': concepto,
        },
        {
          'codigo': _codigoCuentaDinero(origen),
          'debito': 0,
          'credito': monto,
          'descripcion': concepto,
        },
      ],
    );
  }

  Future<int> registrarAsientoAbonoCXP({
    required int cuentaId,
    required double monto,
    required String metodoPago,
  }) async {
    final cuentaDinero = metodoPago.toUpperCase().trim() == 'EFECTIVO'
        ? '1105'
        : '1110';

    return await _registrarAsientoConCodigos(
      concepto: 'Abono cuenta por pagar #$cuentaId',
      referencia: 'CXP-$cuentaId',
      origen: 'cuentas_por_pagar',
      lineas: [
        {
          'codigo': '2205',
          'debito': monto,
          'credito': 0,
          'descripcion': 'Disminución de cuenta por pagar #$cuentaId',
        },
        {
          'codigo': cuentaDinero,
          'debito': 0,
          'credito': monto,
          'descripcion': 'Pago de cuenta por pagar #$cuentaId',
        },
      ],
    );
  }

  Future<int> registrarAsientoAbonoCXC({
    required int cuentaId,
    required double monto,
    required String metodoPago,
  }) async {
    final cuentaDinero = metodoPago.toUpperCase().trim() == 'EFECTIVO'
        ? '1105'
        : '1110';

    return await _registrarAsientoConCodigos(
      concepto: 'Abono cuenta por cobrar #$cuentaId',
      referencia: 'CXC-$cuentaId',
      origen: 'cuentas_por_cobrar',
      lineas: [
        {
          'codigo': cuentaDinero,
          'debito': monto,
          'credito': 0,
          'descripcion': 'Cobro de cartera #$cuentaId',
        },
        {
          'codigo': '1305',
          'debito': 0,
          'credito': monto,
          'descripcion': 'Disminución de cuenta por cobrar #$cuentaId',
        },
      ],
    );
  }

  // ── CATÁLOGO DE BANCOS Y EXTRACTOS ─────────────────────────

  Future<List<Map<String, dynamic>>> obtenerBancos() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query('bancos', where: 'company_id = ?', whereArgs: [companyId], orderBy: 'nombre ASC');
  }

  Future<int> guardarBanco({
    required String nombre,
    required String numeroCuenta,
    required String tipo,
    required double saldoInicial,
    required String cuentaPuc,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.insert('bancos', {
      'company_id': companyId,
      'nombre': nombre,
      'numero_cuenta': numeroCuenta,
      'tipo': tipo,
      'saldo_inicial': saldoInicial,
      'cuenta_puc': cuentaPuc,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Future<void> eliminarBanco(int id) async {
    final db = await instance.database;
    await db.delete('bancos', where: 'id = ?', whereArgs: [id]);
  }

  // ── VALIDACIÓN Y OBTENCIÓN DE SALDO REAL ───────────────────

  Future<double> obtenerSaldoDisponible(String metodo) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final codigoPuc = metodo.toUpperCase().trim() == 'EFECTIVO' ? '1105%' : '1110%';
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT SUM(debito) - SUM(credito) as saldo 
      FROM asiento_lineas 
      WHERE company_id = ? AND codigo LIKE ?
    ''', [companyId, codigoPuc]);
    return (res.first['saldo'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> obtenerSaldoBanco(int bancoId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final bancos = await db.query('bancos', where: 'id = ?', whereArgs: [bancoId]);
    if (bancos.isEmpty) return 0.0;
    final banco = bancos.first;
    final cuentaPuc = banco['cuenta_puc']?.toString() ?? '111005';
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT SUM(debito) - SUM(credito) as saldo 
      FROM asiento_lineas 
      WHERE company_id = ? AND codigo LIKE ?
    ''', [companyId, '$cuentaPuc%']);
    final saldoInicial = (banco['saldo_inicial'] as num?)?.toDouble() ?? 0.0;
    return saldoInicial + ((res.first['saldo'] as num?)?.toDouble() ?? 0.0);
  }

  // ── ANULACIÓN DE MOVIMIENTO DE CAJA/BANCOS ──────────────────

  Future<void> anularMovimientoCaja(int id) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final movs = await db.query('movimientos_caja', where: 'id = ?', whereArgs: [id]);
    if (movs.isEmpty) return;
    final mov = movs.first;

    await db.update('movimientos_caja', {'activo': 0}, where: 'id = ?', whereArgs: [id]);

    final concepto = 'Reversión: ${mov['concepto']}';
    final monto = (mov['monto'] as num).toDouble();
    final esIngreso = mov['tipo'].toString().toLowerCase() == 'ingreso';

    final bancoId = mov['banco_id'] as int?;
    String cuentaDinero = '110505';
    if (bancoId != null) {
      final bancos = await db.query('bancos', where: 'id = ?', whereArgs: [bancoId]);
      if (bancos.isNotEmpty) {
        cuentaDinero = bancos.first['cuenta_puc']?.toString() ?? '111005';
      }
    }

    await _registrarAsientoConCodigos(
      concepto: concepto,
      origen: 'caja_anulacion',
      lineas: [
        {
          'codigo': esIngreso ? '4135' : cuentaDinero,
          'debito': monto,
          'credito': 0,
          'descripcion': concepto,
        },
        {
          'codigo': esIngreso ? cuentaDinero : '5135',
          'debito': 0,
          'credito': monto,
          'descripcion': concepto,
        },
      ],
    );
  }

  // ── EXTRACTOS BANCARIOS Y CONCILIACIÓN ─────────────────────

  Future<int> guardarExtractoBancario({
    required int bancoId,
    required String fecha,
    required String descripcion,
    required double monto,
    required String referencia,
  }) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.insert('extractos_bancarios', {
      'company_id': companyId,
      'banco_id': bancoId,
      'fecha': fecha,
      'descripcion': descripcion,
      'monto': monto,
      'referencia': referencia,
      'conciliado': 0,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerExtractosPorBanco(int bancoId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    return await db.query('extractos_bancarios', where: 'company_id = ? AND banco_id = ?', whereArgs: [companyId, bancoId], orderBy: 'fecha DESC');
  }

  Future<List<Map<String, dynamic>>> obtenerLineasContablesBancariasNoConciliadas(int bancoId) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final bancos = await db.query('bancos', where: 'id = ?', whereArgs: [bancoId]);
    if (bancos.isEmpty) return [];
    final cuentaPuc = bancos.first['cuenta_puc']?.toString() ?? '111005';

    return await db.rawQuery('''
      SELECT al.*, ac.fecha as fecha_asiento, ac.concepto as concepto_asiento
      FROM asiento_lineas al
      JOIN asientos_contables ac ON al.asiento_id = ac.id
      WHERE al.company_id = ? AND al.codigo LIKE ?
      AND al.id NOT IN (
        SELECT IFNULL(asiento_linea_id, 0) FROM extractos_bancarios WHERE conciliado = 1
      )
      ORDER BY ac.fecha DESC
    ''', [companyId, '$cuentaPuc%']);
  }

  Future<void> conciliarTransacciones(int extractoId, int asientoLineaId) async {
    final db = await instance.database;
    await db.update('extractos_bancarios', {
      'conciliado': 1,
      'asiento_linea_id': asientoLineaId,
    }, where: 'id = ?', whereArgs: [extractoId]);
  }

  Future<void> desconciliarTransaccion(int extractoId) async {
    final db = await instance.database;
    await db.update('extractos_bancarios', {
      'conciliado': 0,
      'asiento_linea_id': null,
    }, where: 'id = ?', whereArgs: [extractoId]);
  }

  // ── ACTIVOS FIJOS Y DEPRECIACIÓN AUTOMÁTICA ─────────────────

  Future<void> procesarDepreciacionMensual() async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final activos = await db.query('activos_fijos', where: 'company_id = ?', whereArgs: [companyId]);
    final ahoraStr = DateTime.now().toIso8601String().split('T').first;

    for (final act in activos) {
      final id = act['id'] as int;
      final costo = (act['costo'] as num).toDouble();
      final vidaUtilMeses = (act['vida_util_meses'] as num).toInt();
      if (vidaUtilMeses <= 0) continue;

      final ultDep = act['fecha_depreciacion']?.toString();
      final ahora = DateTime.now();

      if (ultDep != null && ultDep.substring(0, 7) == ahoraStr.substring(0, 7)) {
        continue;
      }

      final depMensual = costo / vidaUtilMeses;
      final codigoPucActivo = act['codigo_puc']?.toString() ?? '1524';
      final codigoPucGasto = act['codigo_puc_depreciacion']?.toString() ?? '5160';

      await _registrarAsientoConCodigos(
        concepto: 'Depreciación Mensual Activo #$id - ${act['nombre']}',
        referencia: 'DEP-$id',
        origen: 'activos_fijos',
        lineas: [
          {
            'codigo': codigoPucGasto,
            'debito': depMensual,
            'credito': 0,
            'descripcion': 'Depreciación gasto mensual: ${act['nombre']}',
          },
          {
            'codigo': codigoPucActivo,
            'debito': 0,
            'credito': depMensual,
            'descripcion': 'Depreciación acumulada mensual: ${act['nombre']}',
          },
        ],
      );

      await db.update('activos_fijos', {
        'fecha_depreciacion': ahoraStr,
      }, where: 'id = ?', whereArgs: [id]);
    }
  }

  // ── PERIODOS CONTABLES: COMPROBACIÓN DE CIERRE Y REVERSIÓN ──

  Future<bool> esPeriodoAbierto(String fecha) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    if (fecha.isEmpty) return true;
    final anioMes = fecha.substring(0, 7);
    final partes = anioMes.split('-');
    final anio = int.tryParse(partes[0]) ?? 0;
    final mes = int.tryParse(partes[1]) ?? 0;

    final periodos = await db.query(
      'periodos_contables',
      where: 'company_id = ? AND anio = ? AND mes = ?',
      whereArgs: [companyId, anio, mes],
      limit: 1,
    );
    if (periodos.isEmpty) return true;
    return periodos.first['estado']?.toString() == 'abierto';
  }

  Future<void> cambiarEstadoPeriodo(int anio, int mes, String estado) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final periodos = await db.query(
      'periodos_contables',
      where: 'company_id = ? AND anio = ? AND mes = ?',
      whereArgs: [companyId, anio, mes],
    );

    if (periodos.isEmpty) {
      await db.insert('periodos_contables', {
        'company_id': companyId,
        'anio': anio,
        'mes': mes,
        'estado': estado,
        'fecha': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'periodos_contables',
        {'estado': estado},
        where: 'company_id = ? AND anio = ? AND mes = ?',
        whereArgs: [companyId, anio, mes],
      );
    }
  }

  Future<int> actualizarBanco({
    required int id,
    required String nombre,
    required String numeroCuenta,
    required String tipo,
    required double saldoInicial,
    required String cuentaPuc,
  }) async {
    final db = await instance.database;
    return await db.update(
      'bancos',
      {
        'nombre': nombre,
        'numero_cuenta': numeroCuenta,
        'tipo': tipo,
        'saldo_inicial': saldoInicial,
        'cuenta_puc': cuentaPuc,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borrador Formulario 300 (IVA) - DIAN Colombia.
  Future<Map<String, double>> obtenerBorradorFormulario300({
    required int anio,
    required int mes,
  }) async {
    final fiscal = await obtenerReporteFiscal(anio: anio, mes: mes);
    final baseGravada = (fiscal['ventas'] ?? 0) / 1.19;
    return {
      'ingresos_gravados': fiscal['ventas'] ?? 0,
      'base_gravada': baseGravada,
      'iva_generado': fiscal['iva_generado'] ?? 0,
      'iva_descontable': fiscal['iva_descontable'] ?? 0,
      'saldo_pagar': fiscal['iva_por_pagar'] ?? 0,
      'reteiva_practicada': fiscal['reteiva_practicada'] ?? 0,
    };
  }

  /// Borrador Formulario 350 (Retención en la Fuente) - DIAN.
  Future<Map<String, double>> obtenerBorradorFormulario350({
    required int anio,
    required int mes,
  }) async {
    final fiscal = await obtenerReporteFiscal(anio: anio, mes: mes);
    return {
      'retefuente_compras': fiscal['retefuente_recibida'] ?? 0,
      'retefuente_servicios': (fiscal['retefuente_practicada'] ?? 0) * 0.4,
      'retefuente_honorarios': (fiscal['retefuente_practicada'] ?? 0) * 0.3,
      'retefuente_arrendamientos': (fiscal['retefuente_practicada'] ?? 0) * 0.2,
      'total_retenciones': fiscal['retefuente_practicada'] ?? 0,
    };
  }

  /// Borrador Formulario 110 (Renta Personas Jurídicas) - resumen anual.
  Future<Map<String, double>> obtenerBorradorFormulario110({required int anio}) async {
    final db = await instance.database;
    final companyId = await obtenerEmpresaActivaId();
    final inicio = DateTime(anio, 1, 1).toIso8601String();
    final fin = DateTime(anio + 1, 1, 1).toIso8601String();

    Future<double> sum(String sql) async {
      final res = await db.rawQuery(sql, [companyId, inicio, fin]);
      return (res.first['total'] as num?)?.toDouble() ?? 0;
    }

    final ventas = await sum(
      "SELECT COALESCE(SUM(total), 0) AS total FROM ventas WHERE company_id = ? AND fecha >= ? AND fecha < ? AND COALESCE(estado, 'emitida') != 'anulada'",
    );
    final compras = await sum(
      "SELECT COALESCE(SUM(total), 0) AS total FROM compras WHERE company_id = ? AND fecha >= ? AND fecha < ? AND estado != 'anulada'",
    );
    final estados = await obtenerEstadosFinancieros();

    return {
      'patrimonio_bruto': estados['activos'] ?? 0,
      'pasivos': estados['pasivos'] ?? 0,
      'patrimonio_liquido': estados['patrimonio'] ?? 0,
      'ingresos_operacionales': ventas,
      'costos_ventas': compras,
      'gastos_operativos': (estados['gastos'] ?? 0),
      'utilidad_gravable': estados['utilidad'] ?? (ventas - compras),
    };
  }

  /// Borrador ICA municipal (bimestral/anual).
  Future<Map<String, double>> obtenerBorradorICA({
    required int anio,
    required int mesInicio,
    required int mesFin,
    double tarifaPorMil = 11.04,
  }) async {
    final db = await instance.database;
    final inicio = DateTime(anio, mesInicio, 1).toIso8601String();
    final fin = DateTime(anio, mesFin + 1, 1).toIso8601String();
    final res = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ? AND COALESCE(estado, 'emitida') != 'anulada'",
      [inicio, fin],
    );
    final ingresosBrutos = (res.first['total'] as num?)?.toDouble() ?? 0;
    final ingresosNetos = ingresosBrutos * 0.95;
    final ica = ingresosNetos * (tarifaPorMil / 1000);
    final avisosTableros = ica * 0.15;

    final reteica = await db.rawQuery(
      'SELECT COALESCE(SUM(reteica), 0) AS total FROM ventas WHERE fecha >= ? AND fecha < ?',
      [inicio, fin],
    );
    final reteicaPracticada = (reteica.first['total'] as num?)?.toDouble() ?? 0;

    return {
      'ingresos_brutos': ingresosBrutos,
      'ingresos_netos_gravables': ingresosNetos,
      'tarifa_por_mil': tarifaPorMil,
      'impuesto_ica': ica,
      'avisos_tableros': avisosTableros,
      'reteica_practicada': reteicaPracticada,
      'saldo_pagar': ica + avisosTableros - reteicaPracticada,
    };
  }
}
