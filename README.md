# MerkaERP

MerkaERP es una plataforma ERP local para empresas que necesitan operar ventas,
compras, inventario, caja, bancos, cartera, contabilidad, reportes, usuarios,
multiempresa y control documental desde una base SQLite preparada para crecer a
servicios y API.

## Modulos

- Centro de trabajo: navegacion por Operacion, Finanzas, Control y Gestion.
- Caja y bancos: ingresos, egresos, saldos, transferencias y cierres.
- Inventario: productos, unidades, costos, precios, impuestos, stock y codigos.
- Ventas: facturacion POS, descuento de inventario, caja/banco/cartera y asiento.
- Compras: abastecimiento, inventario, caja/banco/CXP y asiento contable.
- Clientes y proveedores: terceros comerciales y trazabilidad documental.
- Cartera: cuentas por cobrar, cuentas por pagar y abonos.
- Contabilidad: plan de cuentas, asientos, comprobantes, periodos y estados.
- Reportes: resumen gerencial, fiscal, conciliacion, extractos y presupuestos.
- Gestion: usuarios, permisos, empresas, adjuntos, respaldos, nomina y activos.
- Centro ERP: workspace ejecutivo con dashboards financieros, tesoreria, CRM,
  activos, reporting, busqueda global, comandos y selector empresa/sucursal.

## Complementos empresariales

- Release: checklist para APK/AAB, firma, versionado, pruebas y respaldo.
- Datos: auditoria de inconsistencias y tablas preparadas para crecimiento.
- NIIF: politica contable con partida doble, terceros y dimensiones.
- Compras: flujo solicitud, aprobacion, orden, recepcion, factura, CXP y pago.
- Inventario: bodegas, kardex extendido, reposicion y costo promedio.
- Ventas: cotizacion, pedido, remision, factura, cartera y recaudo.
- Seguridad: matriz de permisos y acciones sensibles auditables.
- Interfaz: navegacion compacta y componentes con control de overflow.
- Manual: guia operativa por modulo y flujo.
- API: endpoints internos para diagnostico, integracion y multiusuario futuro.
- Plataforma distribuida: sucursales, sync offline-first, licencias, telemetry,
  workflows, reglas, soporte remoto, jobs y plugins.
- Arquitectura event-driven: event store persistente, dispatcher asincrono,
  retry queue, dead letters, correlacion, idempotencia y proyecciones CQRS.
- SALES enterprise: documentos comerciales con estados draft/pending/approved/
  posted/cancelled/reversed, inmutabilidad posted, reversos, auditoria,
  telemetry, sync opcional, endpoints REST internos y proyeccion analitica.
- PURCHASES enterprise: requisiciones, RFQ, ordenes, recepciones parciales,
  facturas proveedor, notas/devoluciones, aprobaciones multinivel con SLA,
  tax integration, saldo proveedor, posting contable, inventario y analytics.
- Final enterprise: AR, AP, Treasury, Bank Reconciliation, Tax Engine,
  Fixed Assets, CRM y Reporting Engine integrados con eventos, auditoria,
  telemetry, sync hooks, permisos, API, SQLite y PostgreSQL.
- UI enterprise: Centro ERP conectado al API dispatcher para leer AR/AP aging,
  ledgers, tesoreria, conciliacion, activos, CRM, reportes materializados,
  sync, telemetry y scope multi-tenant sin endpoints decorativos.
- Contabilidad empresarial: journal entries inmutables, posting service,
  reversos, balance de comprobacion y persistencia por sucursal.
- Inventario avanzado: stock ledger por lotes, reservas, FIFO, LIFO y costo
  promedio con eventos transaccionales.

## Arquitectura

- `lib/core`: API interna, permisos, eventos, company context y gateways de datos.
- `lib/cqrs`: read models y proyecciones materializadas para dashboards.
- `lib/features`: capacidades empresariales y configuracion por empresa.
- `lib/inventory`, `lib/sales`, `lib/purchases`: capas data/domain/application.
- `lib/accounting`: motor contable, reportes y balance de comprobacion.
- `lib/catalog`: impuestos, unidades, metodos de pago y reglas contables.
- `lib/onboarding`: configuracion inicial por plantilla y capacidades.
- `assets/templates`: plantillas para retail, servicios, restaurante y manufactura.
- `docs`: notas tecnicas de arquitectura y expansion.

## Estado tecnico

- Multiempresa por `company_id`.
- Repositorios con gateway de base de datos y alcance por empresa.
- Casos de uso transaccionales para ventas y compras.
- API dispatcher interno preparado para REST o sincronizacion.
- Permisos por rol, modulo y accion.
- Catalogos y reglas contables persistentes por empresa.
- Complementos SQLite v34 para bodegas, centros de costo, impuestos,
  retenciones, documentos de flujo, kardex, outbox y clientes API.
- Plataforma SQLite v35 con `branch_id`, `warehouse_id`, `cost_center_id`,
  `sync_inbox`, `sync_queue`, `sync_events`, `sync_conflicts`,
  `sync_metadata`, licencias, telemetry, workflows, reglas y scheduler.
- Consolidacion SQLite v36 con `event_store`, `event_dispatch_queue`,
  `event_dead_letters`, offsets CQRS, read model ejecutivo,
  `accounting_journal_entries`, `accounting_journal_lines`, `inventory_lots`
  e `inventory_reservations`.
- SALES SQLite v37 con `sales_documents`, `sales_document_lines`,
  `sales_document_audit` y `sales_analytics_read_model`, compatible con
  PostgreSQL en `backend/migrations/001_platform.sql`.
- PURCHASES SQLite v38 con `purchase_documents`, `purchase_document_lines`,
  `purchase_approval_steps`, `purchase_document_audit`, `supplier_balances` y
  `purchase_analytics_read_model`, compatible con PostgreSQL.
- Final enterprise SQLite v39 con ledgers AR/AP, tesoreria, conciliacion,
  tax rules/calculations, activos fijos, CRM, reportes materializados y metricas
  event-driven enterprise.
- Centro ERP operativo sobre endpoints finales con pestañas ejecutivas,
  filtros avanzados, tablas empresariales, paleta de comandos, busqueda global
  y cambio de empresa/sucursal usando `app_config`.
- Endpoints internos para event store, replay de eventos y dashboard ejecutivo.
- Backend SaaS en `backend/` con contrato OpenAPI, migracion PostgreSQL y
  worker de sincronizacion alineados con la topologia distribuida.
- Suite de pruebas para dominio, API, repositorios, permisos y contabilidad.

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Instalación en Windows

1. Instale Inno Setup 6 desde https://jrsoftware.org/isinfo.php.
2. Ejecute el script de PowerShell:
   ```powershell
   PowerShell -ExecutionPolicy Bypass -File .\installer\build_installer.ps1
   ```
3. El instalador quedará en la carpeta build/installer como MerkaERP-Setup.exe.

## Ajustes de estabilidad

- La app ahora inicializa de forma tolerante si alguno de los servicios de arranque falla.
- Si un servicio remoto no responde, el arranque continúa y la app entra normalmente.

La base local conserva el archivo `caja_simple.db` por compatibilidad con datos
existentes de instalaciones anteriores.
