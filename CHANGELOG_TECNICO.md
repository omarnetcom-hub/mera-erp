# CHANGELOG TÉCNICO - MÓDULOS DE SECTOR PÚBLICO (COLOMBIA)

---

## [Fase 6 - Verificación Auditoría Forense y Reportes de Ley] Conexión RBAC en Servicios de Reportes
**Fecha:** 2026-07-22

### Auditoría Métodos de Escritura / Persistencia en Servicios de Reportes
Se revisaron los 4 servicios de rendición de cuentas y auditoría forense para verificar la presencia de operaciones de escritura (`db.insert`):

1. **`CHIPReporterService` (`generarCGN2015_001` a `005`, `generarCGN2016C01`):**
   - **Acción:** Persiste registros en la tabla `reportes_chip`.
   - **RBAC Aplicado:** Conectado `_validarPermiso` con `Permiso.consultarAuditoria`.
2. **`SIAObservaService` (`generarReportePlanMejoramiento`):**
   - **Acción:** Persiste registros en la tabla `reportes_sia_observa`.
   - **RBAC Aplicado:** Conectado `_validarPermiso` con `Permiso.consultarAuditoria`.
3. **`FUTTerritorialService` (`generarFUTIngresos`, `generarFUTGastos`, `generarFUTDeudaPublica`, `generarFUTRegalias`):**
   - **Acción:** Persiste registros en la tabla `reportes_fut_territorial`.
   - **RBAC Aplicado:** Conectado `_validarPermiso` con `Permiso.consultarAuditoria`.
4. **`SIIFService` (`generarReportePresupuestoMensual`):**
   - **Acción:** Persiste registros en la tabla `reportes_siif_nacion`.
   - **RBAC Aplicado:** Conectado `_validarPermiso` con `Permiso.consultarAuditoria`.

### Garantía de Perfil de Auditor (`jefeControlInterno`)
- **Acceso Autorizado:** El rol `jefeControlInterno` posee el permiso `Permiso.consultarAuditoria`, por lo que **PUEDE** generar y guardar estos reportes analíticos oficiales de control.
- **Acceso Denegado (Solo Lectura Operativa):** Ninguno de estos 4 servicios modifica tablas de negocio operativo (`cdps`, `rps`, `pagos`, `asientos_contables_sp`, `contratos`). Al intentar invocar acciones operativas desde servicios de Presupuesto, Tesorería o Contabilidad, la capa de servicio le niega el acceso inmediatamente de forma **Fail-Closed**.

---

## [Fase 6 - Cobertura Transversal RBAC] Segregación de Funciones en Tesorería, Contabilidad, Rentas y Auditoría
**Fecha:** 2026-07-22
...
