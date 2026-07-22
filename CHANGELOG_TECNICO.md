# CHANGELOG TÉCNICO - MÓDULOS DE SECTOR PÚBLICO Y COMERCIAL (COLOMBIA)

---

## [Fase 8.2a - Reestablecimiento de Autenticación Real en SyncService]
**Fecha:** 2026-07-22

### 1. Remediación del Método `login()` en `SyncService` (`lib/services/sync_service.dart`)
- **Falla Corregida:** El método `login(username, password)` tenía comentadas las cláusulas de retorno de fallo (`return false;`) y retornaba incondicionalmente `true` ante errores 401 Unauthorized y excepciones de red (`catch`), permitiendo que el sistema asumiera erróneamente un inicio de sesión remoto exitoso sin validar credenciales contra el servidor.
- **Solución Aplicada:**
  - Se restauró y reforzó la validación real contra el endpoint del backend (`https://merkaerp-control-center-backend.onrender.com/api/v1/auth/login`).
  - **Manejo Fail-Closed de Respuestas HTTP**: Si el servidor responde con un código distinto de 200/201 (ej. 401 Credenciales Inválidas, 403 Prohibido), el método retorna explícitamente `false` y no inicia el temporizador de sincronización automática.
  - **Manejo Fail-Closed de Excepciones**: En caso de servidor caído, fallo de conexión o timeout (15s), la excepción es capturada en el bloque `catch` y el método retorna `false` de forma segura.
  - **Validación de Payloads**: Valida que la respuesta contenga strings no nulos ni vacíos para `token` y `userId` antes de guardarlos en SQLite (`app_config`) e iniciar `_startAutoSync()`.

---

## [Fase 8 - Hardening Comercial Completo: Aislamiento Tributario y Fail-Closed]
**Fecha:** 2026-07-22

### 1. Aislamiento Multi-Empresa en Consultas Tributarias y Financieras (`db_helper.dart`)
- **Falla Corregida:** Múltiples funciones de reportes tributarios, fiscales y conciliaciones bancarias (`obtenerReporteFiscal`, `obtenerBorradorICA`, `_calcularValorRealPresupuesto`, `obtenerLineasContablesBancariasNoConciliadas`) realizaban agregaciones sobre las tablas `ventas`, `compras`, `nomina_liquidaciones`, `movimientos_caja` y `extractos_bancarios` **sin filtrar por `company_id`**, mezclando cifras entre empresas distintas registradas en SQLite.
- **Solución Aplicada:**
  - Se incluyó `company_id = ?` obtenido dinámicamente mediante `await obtenerEmpresaActivaId()` en un total de 16 consultas SQL financieras y tributarias.
  - La función `obtenerBorradorICA` fue aislada por `company_id` en sus 2 consultas agregadas sobre ingresos e impuesto ICA.
  - La subconsulta de conciliación bancaria `obtenerLineasContablesBancariasNoConciliadas` incorporó `company_id = ?` en la tabla `extractos_bancarios`.
  - Se confirmó mediante auditoría integral por script de inspección que el 100% de las consultas financieras a `ventas`, `compras`, `nomina_liquidaciones`, `cuentas_por_cobrar`, `cuentas_por_pagar`, `movimientos_caja`, `asiento_lineas`, `asientos_contables`, `bancos`, `extractos_bancarios` y `activos_fijos` filtran estrictamente por `company_id = ?`.

### 2. Autenticación y Autorización Fail-Closed Comercial (`app_session.dart` & `action_permission.dart`)
- **Falla Corregida:** Cuando `AppSession.usuarioActual` era nulo (sin sesión activa), `AppSession.rol` retornaba por defecto `'consulta'`. Dado que la regla del rol `'consulta'` otorga permisos `view` y `export` para todos los módulos (`moduleId: '*'`), usuarios sin autenticar podían consultar e importar datos de cualquier módulo comercial.
- **Solución Aplicada:**
  - `AppSession.rol` retorna **`String?` (null)** cuando no existe sesión activa o cuando el rol registrado es `'sistema'`.
  - `AppSession.puedeAbrir` y `AppSession.puedeEjecutarAccion` deniegan explícitamente (`false`) si el rol es nulo o vacío (**Fail-Closed**).
  - `PermissionService.can` en `lib/core/security/action_permission.dart` valida `role == null || role.isEmpty || role == 'sin_sesion'`, retornando `false` antes de evaluar cualquier regla comodín (`moduleId: '*'`).

### 3. Protección de 3 Capas para el Rol Reservado `'sistema'` (Cero Puertas Traseras)
- **Aislamiento por Código**: El rol `'sistema'` se mantiene como constante reservada por código en `PermissionService` para ser invocada exclusivamente por componentes internos/batch (ej. `SalesCommandHandlers`, `PurchaseCommandHandlers` que pasen explícitamente `role: 'sistema'`).
- **Defensa en `DatabaseHelper`**: `guardarUsuario` y `actualizarUsuario` lanzan un `ArgumentError` si se intenta guardar un usuario con `rol == 'sistema'`, impidiendo que se cree un usuario súper-administrador invisible por formulario o API.
- **Defensa en `AppSession.rol`**: Si por inyección directa en BD un registro tuviera `rol = 'sistema'`, `AppSession.rol` lo ignora y retorna `null`, bloqueando el acceso Fail-Closed a la sesión humana.
- **Formulario de Usuarios (`usuarios_page.dart`)**: La interfaz mantiene únicamente los roles funcionales (`administrador`, `contador`, `cajero`, `operador`, `consulta`), omitiendo `'sistema'`.

### 4. Fail-Closed en Contexto de Empresa Transaccional (`obtenerEmpresaActivaId`)
- **Falla Corregida:** Cuando `obtenerEmpresaActivaId(txn)` se invocaba dentro de un contexto transaccional (`txn != null`) y no se encontraba una empresa en la tabla `companies`, la función retornaba de forma silenciosa un entero fijo por defecto `1`.
- **Solución Aplicada:** Se reemplazó el fallback silencioso `return 1;` por la excepción explícita `throw StateError('No se encontró una empresa activa para la transacción contable.')`, garantizando que ninguna transacción contable o fiscal opere a ciegas sobre una empresa por defecto sin configuración previa.

### 5. Suite de Pruebas Unitarias Automatizadas (`test/commercial_security_test.dart`)
- `1. Consultas tributarias aisladas por company_id`: Confirma con 2 empresas que la Empresa A ve únicamente sus \$100,000 de venta y la Empresa B sus \$500,000.
- `2. Sesión nula/sin autenticar responde FAIL-CLOSED`: Confirma que con sesión cerrada no se puede abrir ningún módulo ni ejecutar acciones `view` o `export`.
- `3. Usuario autenticado con rol consulta`: Confirma que un usuario legítimo con rol `'consulta'` puede ver/exportar reportes pero no crear ni anular ventas.
- `4. Rol explícito "sistema"`: Confirma que procesos batch/sistema pueden ejecutar acciones pasando `role: 'sistema'`.
- `5. Protección del rol "sistema"`: Confirma que `guardarUsuario` rechaza el rol `'sistema'` con `ArgumentError` y que una sesión humana inyectada con rol `'sistema'` es bloqueada (`null`).
- `6. Fail-Closed en obtenerEmpresaActivaId`: Confirma que `obtenerEmpresaActivaId(txn)` lanza `StateError` en una base de datos vacía sin empresa configurada.

---

## [Fase 7 - Auditoría de Persistencia en Base de Datos] Inventario de Registros 'default'
**Fecha:** 2026-07-22
...
