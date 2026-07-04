import 'features/company_configuration_service.dart';
import 'features/module_definition.dart';
import 'core/security/action_permission.dart';

class AppSession {
  static Map<String, dynamic>? usuarioActual;

  static String get rol =>
      usuarioActual?['rol']?.toString().toLowerCase() ?? 'consulta';

  static String get nombre =>
      usuarioActual?['nombre']?.toString() ?? 'Usuario local';

  static void iniciar(Map<String, dynamic> usuario) {
    usuarioActual = usuario;
  }

  static void cerrar() {
    usuarioActual = null;
  }

  static bool puedeAbrir(String modulo) {
    final normalizado = _normalizarModulo(modulo);
    if (rol == 'administrador') return true;

    const permisos = {
      'contador': {
        'caja',
        'compras',
        'ventas',
        'inventario',
        'clientes',
        'proveedores',
        'contabilidad',
        'cuentas x cobrar',
        'cuentas x pagar',
        'comprobantes',
        'periodos',
        'estados fin.',
        'reportes',
        'fiscal',
        'conciliacion',
        'extractos',
        'presupuestos',
        'cierres caja',
        'recibos',
        'auditoria',
        'config.',
        'manual',
        'empresas',
      },
      'cajero': {
        'caja',
        'ventas',
        'inventario',
        'clientes',
        'cierres caja',
        'recibos',
        'reportes',
        'manual',
      },
      'operador': {
        'caja',
        'ventas',
        'compras',
        'inventario',
        'clientes',
        'proveedores',
        'recibos',
        'manual',
      },
      'consulta': {
        'reportes',
        'comprobantes',
        'estados fin.',
        'auditoria',
        'recibos',
        'manual',
      },
    };

    return permisos[rol]?.contains(normalizado) ?? false;
  }

  static bool puedeAbrirModulo(ModuleDefinition modulo) {
    if (modulo.requiresAdmin && !puedeAdministrar()) return false;
    if (!puedeAbrir(modulo.permissionLabel ?? modulo.title)) return false;
    if (!puedeEjecutarAccion(modulo.id, AppAction.view)) return false;
    final featureKey = modulo.featureKey;
    if (featureKey == null) return true;
    return CompanyConfigurationService.instance.featureEnabledSync(featureKey);
  }

  static bool puedeEjecutarAccion(String moduloId, AppAction accion) {
    return PermissionService.instance.can(
      role: rol,
      moduleId: moduloId,
      action: accion,
    );
  }

  static String _normalizarModulo(String modulo) {
    final value = modulo.toLowerCase().trim();
    const aliases = {
      'cierres de caja': 'cierres caja',
      'estados financieros': 'estados fin.',
      'configuracion': 'config.',
      'configuración': 'config.',
      'facturación': 'facturacion',
      'facturacion electronica': 'facturacion',
      'usuarios y permisos': 'usuarios',
      'conciliacion bancaria': 'conciliacion',
      'cuentas por cobrar': 'cuentas x cobrar',
      'cuentas por pagar': 'cuentas x pagar',
      'auditoría': 'auditoria',
      'nómina': 'nomina',
    };
    return aliases[value] ?? value;
  }

  static bool puedeModificarOperacion() {
    return rol == 'administrador' || rol == 'cajero' || rol == 'operador';
  }

  static bool puedeAdministrar() {
    return rol == 'administrador';
  }
}
