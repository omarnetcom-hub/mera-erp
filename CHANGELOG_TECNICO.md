# CHANGELOG TÉCNICO - MÓDULOS DE SECTOR PÚBLICO (COLOMBIA)

---

## [Fase 7 - Auditoría de Persistencia en Base de Datos] Inventario de Registros 'default'
**Fecha:** 2026-07-22

### Inventario de Base de Datos de Desarrollo
Se ejecutó un script de inspección sobre las 17 bases de datos SQLite encontradas en el entorno local (incluyendo bases de datos de pruebas e integraciones temporales):

- **Columnas auditadas:** `entidad_id` en todas las tablas del esquema (apropiaciones, cuentas_contables, predios, cdps, rps, pagos, asientos_contables_sp, proyectos_ocad, bienios_sgr, contratos_eps_adres, facturas_salud, actas_responsabilidad, funcionarios_entidad, etc.).
- **Registros hallados con `entidad_id = 'default'`:** **0 registros** across todas las tablas.

### Conclusión Técnica
Dado que las pruebas automatizadas (Fases 3 a 6) inyectan explícitamente identificadores territoriales reales (como `'ENT-001'` o `'ENT-999'`) directamente en la capa de servicios, el valor estático `'default'` de `public_sector_config.dart` solo existía a nivel de interfaz de usuario durante la navegación de desarrollo y **nunca llegó a contaminar datos persistidos en base de datos**. No se requiere migración ni depuración de datos previa a la Fase 8.

---

## [Fase 7 - Auditoría Multi-Entidad & Corrección de Sesión Estricta] AppSession.usuarioId (String?) & Fail-Closed Null Handling
**Fecha:** 2026-07-22
...
