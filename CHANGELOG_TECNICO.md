# CHANGELOG TÉCNICO - MÓDULOS DE SECTOR PÚBLICO Y COMERCIAL (COLOMBIA)

---

## [Fase 8.2b - Unificación de Tenencia Multi-Entidad en el Motor de Sincronización]
**Fecha:** 2026-07-22

### 1. Extensión Polimórfica de Envolventes de Sincronización (`SyncEnvelope`)
- **Falla Corregida:** El motor de sincronización por eventos (`SqliteSyncRepository`) e HTTP por lotes (`SyncService`) utilizaba únicamente identificadores de tenencia comerciales (`company_id` y `branch_id` enteros), estando desconectado del identificador de Sector Público (`entidad_id` texto) y del usuario emisor (`usuario_id`).
- **Solución Aplicada:**
  - Se extendieron `SyncEnvelope` (`lib/sync/domain/sync_models.dart`) y las tablas SQLite `sync_outbox`, `sync_inbox` y `sync_conflicts` agregando los campos:
    - `tenant_type`: `'commercial'` | `'public_sector'` (por defecto `'commercial'`).
    - `entidad_id`: `String?` (para Sector Público, ej. `'ENT-001'`).
    - `user_id`: `String?` (identificador del usuario emisor en `AppSession.usuarioId`).
  - Se mantuvo `company_id` y `branch_id` con lectura segura para **100% de compatibilidad retroactiva** con eventos y tablas existentes sin migraciones destructivas.

### 2. Resolvedor Centralizado de Tenencia (`SyncTenantScope`) - Remediación Fail-Closed
- **Nuevo Componente (`lib/sync/domain/sync_tenant_scope.dart`)**:
  - `SyncTenantScope.commercial(required companyId, required branchId, usuarioId)`: Elimina valores mágicos por defecto (`1`). Requiere que los identificadores comerciales provengan explícitamente del contexto transaccional.
  - `SyncTenantScope.publicSector(entidadId, usuarioId)`: Puebla `tenantType = 'public_sector'`, `entidadId = AppSession.entidadId` y `usuarioId = AppSession.usuarioId`.
  - `SyncTenantScope.current(...)`: Resuelve dinámicamente el scope. Si opera en modo comercial sin `companyId`/`branchId`, lanza un `StateError` de forma **Fail-Closed**.

### 3. Conexión de `SyncTenantScope` en `SalesCommandHandlers` (End-to-End Comercial)
- Se actualizó `SalesCommandHandlers._enqueueSync` (`lib/sales/application/sales_command_handlers.dart`) para utilizar `SyncTenantScope.commercial`. Cada documento de venta encolado en `sync_outbox` ahora incluye explícitamente `tenantType = 'commercial'` y el `usuarioId` activo de la sesión.

### 4. Transporte de Tenencia en Payload HTTP (`SyncService._pushChanges`)
- Se extendió el mapeo de eventos en `SyncService._pushChanges` (`lib/services/sync_service.dart`) para incluir `tenantType`, `companyId`, `branchId`, `entidadId` y `userId` en el payload JSON enviado al endpoint `installations/sync/push` de Render.

### 5. Pieza de Infraestructura Preparada para Sector Público (`PublicSectorSyncHelper`)
- **Estado de Conexión**: Se creó `PublicSectorSyncHelper` (`lib/sector_publico/services/public_sector_sync_helper.dart`) para registrar e ingresar eventos de `cdps`, `rps`, `pagos`, `asientos_contables_sp` y `proyectos_ocad`. **Actualmente se entrega como infraestructura probada y lista, sin estar enganchada aún a los flujos activos de escritura** (los cuales se conectarán en la fase de sincronización presupuestal).
- **Verificación de Esquema SQL**: Se confirmó mediante inspección del código fuente que las 5 tablas (`cdps`, `rps`, `pagos`, `asientos_contables_sp`, `proyectos_ocad`) **ya poseen la columna `entidad_id TEXT NOT NULL`** en sus declaraciones `CREATE TABLE`.
- **Justificación de Arquitectura**: El sector público utilizará **Event-Sourcing (`SyncService` / `SqliteSyncRepository`)** en lugar de replicación CRUD directa (`HybridSyncService`) para preservar la cadena de custodia, inmutabilidad y firmas de relojes vectoriales requeridas por el Estatuto Anticorrupción (Ley 1474) y Ley 80.
- **Diagnóstico del Servidor (Render)**: Para completar la sincronización end-to-end del sector público hacia la nube, se requiere desplegar en el servidor de Render las tablas espejo en PostgreSQL y habilitar las rutas de recepción de eventos polimórficos en `/installations/sync/push`.

---

## [Fase 8.2a - Reestablecimiento de Autenticación Real en SyncService]
**Fecha:** 2026-07-22
...
