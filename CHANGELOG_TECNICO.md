# CHANGELOG TÉCNICO - MÓDULOS DE SECTOR PÚBLICO Y COMERCIAL (COLOMBIA)

---

## [Fase 8 - Remediación de Seguridad Comercial & Aislamiento Multi-Empresa]
**Fecha:** 2026-07-22

### 1. Corrección de Aislamiento Multi-Empresa en Consultas Tributarias (`db_helper.dart`)
- **Falla Corregida:** Las funciones de reportes fiscales y borradores de impuestos (`obtenerReporteFiscal`, `obtenerBorradorICA`, `_calcularValorRealPresupuesto`) consultaban agregados de ventas, compras, ReteFuente, ReteIVA, ReteICA y nómina mediante `WHERE fecha >= ? AND fecha < ?` **sin filtrar por `company_id`**, mezclando las cifras de todas las empresas registradas en SQLite.
- **Solución:** Se incluyó `company_id = ?` con el identificador dinámico de `obtenerEmpresaActivaId()` en las 7 consultas afectadas, garantizando que el Formulario 300 IVA, Formulario 350 Retefuente y Formulario ICA reporten exclusivamente las cifras de la empresa activa.

### 2. Autenticación y Autorización Fail-Closed Comercial (`app_session.dart` & `action_permission.dart`)
- **Falla Corregida:** Cuando `AppSession.usuarioActual` era nulo (sin sesión activa), `AppSession.rol` retornaba por defecto `'consulta'`. Dado que la regla del rol `'consulta'` otorga permisos `view` y `export` para todos los módulos (`moduleId: '*'`), usuarios sin autenticar podían consultar e importar datos de cualquier módulo comercial.
- **Solución:**
  - `AppSession.rol` retorna **`String?` (null)** cuando no existe sesión activa o cuando el rol del registro de usuario es `'sistema'`.
  - `AppSession.puedeAbrir` y `AppSession.puedeEjecutarAccion` deniegan explícitamente (`false`) si el rol es nulo o vacío (**Fail-Closed**).
  - `PermissionService.can` en `lib/core/security/action_permission.dart` valida `role == null || role.isEmpty || role == 'sin_sesion'`, retornando `false` antes de evaluar cualquier regla comodín.

### 3. Protección de 3 Capas para el Rol Reservado `'sistema'` (Cero Puertas Traseras)
- **Aislamiento por Código**: El rol `'sistema'` se mantiene como constante reservada por código en `PermissionService` para ser invocada exclusivamente por componentes internos/batch (ej. `SalesCommandHandlers`, `PurchaseCommandHandlers` que pasen explícitamente `role: 'sistema'`).
- **Defensa en `DatabaseHelper`**: `guardarUsuario` y `actualizarUsuario` lanzan un `ArgumentError` si se intenta guardar un usuario con `rol == 'sistema'`, impidiendo que se cree un usuario súper-administrador invisible por formulario o API.
- **Defensa en `AppSession.rol`**: Si por inyección directa en BD un registro tuviera `rol = 'sistema'`, `AppSession.rol` lo ignora y retorna `null`, bloqueando el acceso Fail-Closed a la sesión humana.

### 4. Pruebas Unitarias Automatizadas (`test/commercial_security_test.dart`)
- `1. Consultas tributarias aisladas por company_id no mezclan cifras entre empresas`: Confirma con 2 empresas que la Empresa A ve únicamente sus \$100,000 de venta y la Empresa B sus \$500,000.
- `2. Sesión nula/sin autenticar responde FAIL-CLOSED`: Confirma que con sesión cerrada no se puede abrir ningún módulo ni ejecutar acciones `view` o `export`.
- `3. Usuario autenticado con rol consulta`: Confirma que un usuario legítimo con rol `'consulta'` puede ver/exportar reportes pero no crear ni anular ventas.
- `4. Rol explícito "sistema"`: Confirma que procesos batch/sistema pueden ejecutar acciones pasando `role: 'sistema'`.
- `5. Protección del rol "sistema"`: Confirma que `guardarUsuario` rechaza el rol `'sistema'` con `ArgumentError` y que una sesión humana inyectada con rol `'sistema'` es bloqueada (Fail-Closed).

---

## [Fase 7 - Auditoría de Persistencia en Base de Datos] Inventario de Registros 'default'
**Fecha:** 2026-07-22
...
