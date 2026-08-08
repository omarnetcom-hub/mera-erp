# Sesion migracion de dinero - 2026-08-02

## Fase 1 - Diseno aprobado

- Documento: `docs/MIGRACION_DINERO_CENTAVOS_DISENO.md`.
- Commit publicado: `6d5bf14`.
- Decision: preservar multimoneda y almacenar unidades menores por moneda.

## Fase 2 - MoneyValue y esquema v75

### Respaldo y copias

```text
Origen activo: C:\Users\PC\Documents\merka_erp_test_fresco.db
Respaldo inmutable: C:\Users\PC\Documents\merka_erp_test_fresco_pre_centavos_2026-08-02.db
Copia validada: C:\Users\PC\Documents\merka_erp_test_fresco_validacion_v75_2026-08-02.db
SHA-256 respaldo antes y despues: 12F7F5BB08CD827A4A325FA1B2EF2D08B0E603099B745F1B06477799242879F7
```

### Implementacion

- `MoneyValue` usa `int`/`BigInt`, moneda y escala explicitas; no ofrece constructor desde `double`.
- La base sube de v74 a v75.
- El manifiesto congelado contiene 125 tablas y 355 columnas monetarias.
- v75 reconstruye cada tabla, conserva DDL/indices/triggers/vistas, migra fila por fila y ejecuta `foreign_key_check` e `integrity_check`.
- Moneda no resoluble con valor distinto de cero aborta; sector publico resuelve COP/2.
- Se corrigio v66 para omitir onboarding sin entidad territorial real, sin fabricar el destino de la FK.

### Inventario exacto migrado

- `abonos_cxc`: `monto`
- `abonos_cxp`: `monto`
- `accounting_journal_lines`: `credit`, `debit`, `local_credit`, `local_debit`
- `activos_estado`: `depreciacion_acumulada`, `valor_adquisicion`, `valor_libros`, `valor_neto`, `valor_residual`
- `activos_fijos`: `costo`, `depreciacion_acumulada`, `valor_libros`, `valor_residual`
- `acuerdos_pago`: `saldo_pendiente`, `valor_cuota`, `valor_original`, `valor_pagado`
- `ap_payment_schedules`: `amount`
- `ap_supplier_ledger`: `amount`, `open_amount`
- `apropiaciones`: `saldo_disponible`, `valor_apropiado`, `valor_cdp`, `valor_inicial`, `valor_obligado`, `valor_pagado`, `valor_rp`
- `ar_ledger_entries`: `amount`, `open_amount`
- `ar_payment_promises`: `amount`
- `asiento_lineas`: `credito`, `debito`
- `asientos_contables_sp`: `total_credito`, `total_debito`
- `autorizaciones_vigencias_futuras`: `apropiacion_vigencia_actual`, `monto_total`
- `avisos_tablero`: `impuesto_aviso`, `tarifa`, `valor_aviso`
- `bancos`: `saldo_inicial`
- `bank_statement_lines`: `amount`
- `bienios_sgr`: `monto_ejecutado_bienio`, `monto_presupuestado_bienio`
- `caja_sesiones`: `diferencia`, `monto_contado`, `monto_inicial`, `total_egresos`, `total_ingresos`, `total_ventas`
- `cdps`: `saldo_disponible`, `valor_cdp`, `valor_comprometido_rp`
- `censo_ica`: `ingresos_anuales_estimados`
- `cierres_caja`: `diferencia`, `efectivo_contado`, `saldo_sistema`
- `comisiones_liquidadas`: `base`, `comision`
- `commission_rules`: `max_amount`, `min_amount`
- `commissions`: `commission_amount`, `sale_amount`
- `compras`: `credito`, `efectivo`, `impuesto_total`, `retefuente`, `reteica`, `reteiva`, `subtotal`, `total`, `transferencia`
- `compras_detalle`: `costo_unitario`, `subtotal`
- `comprobantes_contables`: `total`
- `compromisos_vigencias_futuras`: `monto_comprometido`, `monto_obligado`, `monto_pagado`
- `conciliaciones_bancarias`: `diferencia`, `saldo_extracto`, `saldo_libros`
- `conciliaciones_reciprocas`: `diferencia_monto_validada`, `monto_conciliado`, `tolerancia_monto`
- `conciliaciones_reciprocas_partidas`: `monto_eliminar`
- `configuracion_depreciacion_unidades`: `costo_depreciable`, `costo_por_unidad`, `depreciacion_acumulada`, `valor_adquisicion`, `valor_residual`
- `consolidaciones_nicsp40`: `valor_ejecutado`, `valor_no_ejecutado`, `valor_transferido`
- `contratos`: `valor_contrato`
- `contratos_eps_adres`: `monto_contrato`, `monto_facturado`
- `cotizacion_detalle`: `precio_unitario`, `subtotal`
- `cotizaciones`: `impuesto`, `subtotal`, `total`
- `crm_opportunities`: `value`
- `cuentas_por_cobrar`: `saldo`, `total`
- `cuentas_por_pagar`: `saldo`, `total`
- `customer_credit_profiles`: `balance`, `credit_limit`
- `declaraciones_ica`: `base_gravable`, `impuesto_ica`, `ingresos_exentos`, `ingresos_gravables`, `ingresos_no_gravables`, `intereses_mora`, `total_pagar`
- `detalles_asientos`: `credito`, `debito`
- `devoluciones_compras`: `total`
- `devoluciones_compras_detalle`: `costo_unitario`, `subtotal`
- `devoluciones_ventas`: `total`
- `devoluciones_ventas_detalle`: `precio_unitario`, `subtotal`
- `documentos_compra_flujo`: `total`
- `documentos_compra_flujo_lineas`: `costo_unitario`, `total`
- `documentos_venta_flujo`: `total`
- `documentos_venta_flujo_lineas`: `precio_unitario`, `total`
- `embargos_judiciales`: `valor_embargo`
- `empleados`: `salario_base`
- `empleados_sp`: `salario_basico`
- `enterprise_fixed_assets`: `accumulated_depreciation`, `book_value`, `cost`, `fiscal_depreciation`, `monthly_depreciation`
- `enterprise_tax_calculations`: `retention`, `tax`, `taxable_base`, `total`
- `extractos_bancarios`: `valor`
- `facturas_salud`: `monto_glosado`, `monto_pagado`, `monto_total`
- `fixed_asset_events`: `amount`
- `fondo_unidad_tesoreria`: `saldo_disponible`, `valor_ejecutado`, `valor_inicial`
- `glosas`: `valor_aceptado`, `valor_glosado`, `valor_rechazado`
- `historial_precios`: `precio_anterior`, `precio_nuevo`
- `horas_extra`: `salario_hora`, `valor_recargo`, `valor_total`
- `inventory_lots`: `unit_cost`
- `kardex_inventario`: `costo_total`, `costo_unitario`
- `liquidaciones_nomina`: `auxilio_alimentacion`, `auxilio_transporte`, `caja_compensacion`, `fondo_solidaridad`, `horas_extra`, `icbf`, `neto_pagar`, `pension`, `recargo_nocturno`, `riesgos_laborales`, `salario_basico`, `salario_devengado`, `salud`, `sena`, `total_aportes`, `total_devengado`
- `liquidaciones_prediales`: `avaluo_catastral`, `descuento_pronto_pago`, `impuesto_base`, `intereses_mora`, `total_pagar`
- `lotes`: `costo`
- `movimientos_caja`: `monto`
- `movimientos_inventario`: `costo_anterior`, `costo_nuevo`
- `nomina_liquidaciones`: `aportes_empleador`, `arl`, `cesantias`, `fsp`, `intereses_cesantias`, `neto_pagar`, `parafiscal_caja`, `parafiscal_icbf`, `parafiscal_sena`, `pension_empleado`, `pension_empleador`, `prima_servicios`, `retefuente`, `salario_base`, `salud_empleado`, `salud_empleador`, `total_deducciones`, `total_devengado`, `vacaciones`
- `obligaciones`: `saldo_pendiente`, `valor_obligacion`, `valor_pagado`
- `obligaciones_vigencias_futuras`: `monto_obligado`, `monto_pagado`
- `order_lines`: `discount_amount`, `subtotal`, `tax_amount`, `total`, `unit_cost`, `unit_price`
- `pac`: `saldo_disponible`, `valor_ejecutado`, `valor_programado`
- `pagos`: `valor_pago`
- `pagos_ica`: `valor_pagado`
- `payment_transactions`: `amount`
- `payroll_novelties`: `tarifa`, `valor`
- `payroll_parameters`: `smmlv`, `transportation_allowance`, `uvt`
- `pedido_detalle`: `precio_unitario`, `subtotal`
- `pedidos`: `impuesto`, `subtotal`, `total`
- `polizas`: `valor_asegurado`
- `predios`: `avaluo_anterior`, `avaluo_catastral`
- `presupuesto_lineas`: `monto_presupuestado`
- `presupuestos`: `diferencia`, `valor_presupuestado`, `valor_real`
- `price_history`: `new_price`, `old_price`
- `procesos_cobro_coactivo`: `saldo_pendiente`, `valor_deuda`, `valor_recuperado`
- `procesos_contratacion`: `valor_estimado`
- `procesos_disciplinarios`: `monto_sancion`
- `productos`: `costo`, `precio`
- `provisiones`: `saldo_disponible`, `valor_provision`, `valor_utilizado`
- `proyectos_mga`: `saldo_por_ejecutar`, `valor_ejecutado`, `valor_total`
- `proyectos_ocad`: `monto_aprobado`, `monto_giro_spgr`
- `purchase_analytics_read_model`: `retention`, `spend`, `tax`
- `purchase_document_lines`: `retention_total`, `subtotal`, `tax_total`, `total`, `unit_cost`
- `purchase_documents`: `budget_available`, `retention_total`, `subtotal`, `tax_total`, `total`
- `quote_lines`: `discount_amount`, `subtotal`, `tax_amount`, `total`, `unit_cost`, `unit_price`
- `recargos`: `salario_hora`, `valor_recargo`
- `recepciones_satisfaccion`: `valor_recibido`, `valor_reconocido`
- `regalias`: `valor_asignado`, `valor_distribuido`, `valor_ejecutado`, `valor_estimado`, `valor_recibido`
- `registros_produccion`: `costo_por_unidad`, `depreciacion_periodo`
- `reglas_retenciones_empresa`: `base_minima`
- `reteica`: `valor_retenido`
- `retroactivos`: `diferencia_mensual`, `salario_anterior`, `salario_nuevo`, `saldo_pendiente`, `valor_pagado`, `valor_total`
- `revalorizaciones`: `incremento`, `valor_anterior`, `valor_nuevo`
- `rips`: `valor_copago`, `valor_modera`, `valor_neto`, `valor_servicio`
- `rps`: `saldo_disponible`, `valor_obligado`, `valor_rp`
- `saldos_cuentas`: `saldo_acreedor`, `saldo_deudor`, `saldo_neto`
- `sales_analytics_read_model`: `revenue`, `tax`
- `sales_document_lines`: `discount`, `subtotal`, `tax_total`, `total`, `unit_price`
- `sales_documents`: `discount_total`, `subtotal`, `tax_total`, `total`
- `sales_orders`: `discount_amount`, `subtotal`, `tax_amount`, `total`
- `sales_quotes`: `discount_amount`, `subtotal`, `tax_amount`, `total`
- `sgp`: `saldo_disponible`, `valor_asignado`, `valor_ejecutado`, `valor_recibido`, `valor_transferido`
- `stock_bodega`: `costo`
- `supplier_balances`: `balance`
- `traslados_bodega`: `costo_at_movement`
- `treasury_bank_accounts`: `balance`
- `treasury_bank_movements`: `amount`
- `treasury_transfers`: `amount`
- `ventas`: `costo_unitario`, `credito`, `efectivo`, `impuesto_total`, `precio_unitario`, `retefuente`, `reteica`, `reteiva`, `subtotal`, `total`, `transferencia`
- `ventas_detalle`: `precio_unitario`, `subtotal`
- `vigencias_futuras_distribucion`: `monto_autorizado`, `monto_comprometido`, `monto_obligado`, `monto_pagado`, `saldo_disponible`

### Comparacion de la copia del respaldo

- Version: v63 -> v75.
- Tablas verificadas: 125/125.
- Columnas verificadas como INTEGER: 355/355.
- Filas antes/despues: identicas en cada tabla; 7 filas totales dentro del manifiesto tras agregar muestras controladas.
- Celdas monetarias comparadas: 10/10.
- Muestras: `99.99 -> 9999`, `10000.0 -> 1000000`, `9900.01 -> 990001`.

### Estado de compilacion

- Errores de compilacion/analyze introducidos: **ninguno**.
- `flutter analyze`: 189 issues, 0 errores (linea base conservada).
- `flutter build windows`: genera `build/windows/x64/runner/Release/MerkaERP.exe`.
- Riesgo abierto: SQLite entrega valores dinamicos; el build compila, pero los consumidores anteriores siguen interpretando unidades menores como unidades mayores. La incompatibilidad es funcional y queda pendiente de Fases 3/4.

Lista completa de errores de compilacion generados por esta fase:

```text
(vacia: 0 errores)
```

### Evidencia cruda - Tests MoneyValue y migracion v75 en memoria

Comando:

```powershell
flutter test test/core/currency/money_value_test.dart test/core/currency/money_schema_migration_test.dart
```

Salida estandar:

```text
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart
00:00 +0: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart: MoneyValue suma cien valores decimales sin deriva binaria
00:00 +1: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart: MoneyValue compara importes solo dentro de la misma moneda y escala
00:00 +2: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart: MoneyValue convierte texto a unidades menores y vuelve sin perdida
00:00 +3: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart: MoneyValue multiplica y divide con redondeo racional exacto
00:00 +4: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart: MoneyValue falla cerrado sin moneda resuelta
00:00 +5: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_value_test.dart: MoneyValue rechaza precision mayor a la escala de la moneda
00:00 +6: loading C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_schema_migration_test.dart
00:01 +6: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_schema_migration_test.dart: migra las 355 columnas y conserva filas y valores COP
Inicializando tablas del Sector Público para nueva instalación...
00:04 +7: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_schema_migration_test.dart: respeta la escala configurada de una moneda comercial
Inicializando tablas del Sector Público para nueva instalación...
00:06 +8: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_schema_migration_test.dart: es idempotente y no vuelve a escalar una base v75
Inicializando tablas del Sector Público para nueva instalación...
00:09 +9: C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_schema_migration_test.dart: una instalacion nueva v75 termina con esquema INTEGER
Inicializando tablas del Sector Público para nueva instalación...
Inicializando tablas del Sector Público para nueva instalación...
00:12 +10: All tests passed!
```

Error estandar:

```text
```

### Evidencia cruda - Test de migracion v66 relacionado

Comando:

```powershell
flutter test test/sector_publico/configuracion/selector_entidad_migracion_test.dart
```

Salida estandar:

```text
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/sector_publico/configuracion/selector_entidad_migracion_test.dart
00:00 +0: selector guarda historial vigente y convierte tipos del onboarding legado
00:00 +1: migracion conserva y Nomina usa la configuracion_legal vigente
00:00 +2: matriz se siembra y se consulta desde modulos_por_tipo_entidad
00:00 +3: All tests passed!
```

Error estandar:

```text
```

### Evidencia cruda - Test sobre copia real del respaldo

Comando:

```powershell
$env:MERKA_MONEY_VALIDATION_DB="C:\Users\PC\Documents\merka_erp_test_fresco_validacion_v75_2026-08-02.db"; flutter test test/core/currency/money_backup_v75_integration_test.dart
```

Salida estandar:

```text
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/core/currency/money_backup_v75_integration_test.dart
00:00 +0: migra copia del respaldo v63 a v75 y compara cada fila
Shell: TABLE abonos_cxc rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE abonos_cxp rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE accounting_journal_lines rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE activos_estado rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE activos_fijos rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE acuerdos_pago rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE ap_payment_schedules rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE ap_supplier_ledger rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE apropiaciones rows_before=0 rows_after=0 money_columns=7 OK
Shell: TABLE ar_ledger_entries rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE ar_payment_promises rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE asiento_lineas rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE asientos_contables_sp rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE autorizaciones_vigencias_futuras rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE avisos_tablero rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE bancos rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE bank_statement_lines rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE bienios_sgr rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE caja_sesiones rows_before=0 rows_after=0 money_columns=6 OK
Shell: TABLE cdps rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE censo_ica rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE cierres_caja rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE comisiones_liquidadas rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE commission_rules rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE commissions rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE compras rows_before=0 rows_after=0 money_columns=9 OK
Shell: TABLE compras_detalle rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE comprobantes_contables rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE compromisos_vigencias_futuras rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE conciliaciones_bancarias rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE conciliaciones_reciprocas rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE conciliaciones_reciprocas_partidas rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE configuracion_depreciacion_unidades rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE consolidaciones_nicsp40 rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE contratos rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE contratos_eps_adres rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE cotizacion_detalle rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE cotizaciones rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE crm_opportunities rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE cuentas_por_cobrar rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE cuentas_por_pagar rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE customer_credit_profiles rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE declaraciones_ica rows_before=0 rows_after=0 money_columns=7 OK
Shell: TABLE detalles_asientos rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE devoluciones_compras rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE devoluciones_compras_detalle rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE devoluciones_ventas rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE devoluciones_ventas_detalle rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE documentos_compra_flujo rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE documentos_compra_flujo_lineas rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE documentos_venta_flujo rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE documentos_venta_flujo_lineas rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE embargos_judiciales rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE empleados rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE empleados_sp rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE enterprise_fixed_assets rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE enterprise_tax_calculations rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE extractos_bancarios rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE facturas_salud rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE fixed_asset_events rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE fondo_unidad_tesoreria rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE glosas rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE historial_precios rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE horas_extra rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE inventory_lots rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE kardex_inventario rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE liquidaciones_nomina rows_before=0 rows_after=0 money_columns=16 OK
Shell: TABLE liquidaciones_prediales rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE lotes rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE movimientos_caja rows_before=1 rows_after=1 money_columns=1 OK
Shell: TABLE movimientos_inventario rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE nomina_liquidaciones rows_before=0 rows_after=0 money_columns=19 OK
Shell: TABLE obligaciones rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE obligaciones_vigencias_futuras rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE order_lines rows_before=0 rows_after=0 money_columns=6 OK
Shell: TABLE pac rows_before=1 rows_after=1 money_columns=3 OK
Shell: TABLE pagos rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE pagos_ica rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE payment_transactions rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE payroll_novelties rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE payroll_parameters rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE pedido_detalle rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE pedidos rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE polizas rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE predios rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE presupuesto_lineas rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE presupuestos rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE price_history rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE procesos_cobro_coactivo rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE procesos_contratacion rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE procesos_disciplinarios rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE productos rows_before=1 rows_after=1 money_columns=2 OK
Shell: TABLE provisiones rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE proyectos_mga rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE proyectos_ocad rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE purchase_analytics_read_model rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE purchase_document_lines rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE purchase_documents rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE quote_lines rows_before=0 rows_after=0 money_columns=6 OK
Shell: TABLE recargos rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE recepciones_satisfaccion rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE regalias rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE registros_produccion rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE reglas_retenciones_empresa rows_before=4 rows_after=4 money_columns=1 OK
Shell: TABLE reteica rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE retroactivos rows_before=0 rows_after=0 money_columns=6 OK
Shell: TABLE revalorizaciones rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE rips rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE rps rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE saldos_cuentas rows_before=0 rows_after=0 money_columns=3 OK
Shell: TABLE sales_analytics_read_model rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE sales_document_lines rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE sales_documents rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE sales_orders rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE sales_quotes rows_before=0 rows_after=0 money_columns=4 OK
Shell: TABLE sgp rows_before=0 rows_after=0 money_columns=5 OK
Shell: TABLE stock_bodega rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE supplier_balances rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE traslados_bodega rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE treasury_bank_accounts rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE treasury_bank_movements rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE treasury_transfers rows_before=0 rows_after=0 money_columns=1 OK
Shell: TABLE ventas rows_before=0 rows_after=0 money_columns=11 OK
Shell: TABLE ventas_detalle rows_before=0 rows_after=0 money_columns=2 OK
Shell: TABLE vigencias_futuras_distribucion rows_before=0 rows_after=0 money_columns=5 OK
Shell: SAMPLE movimientos_caja.monto original=99.99 migrated=9999 expected=9999
Shell: SAMPLE pac.valor_programado original=10000.0 migrated=1000000 expected=1000000
Shell: SAMPLE pac.valor_ejecutado original=99.99 migrated=9999 expected=9999
Shell: SUMMARY version_before=63 version_after=75 tables=125 columns=355 rows=7 checked_money_cells=10 OK
00:02 +1: All tests passed!
```

Error estandar:

```text
```

### Evidencia cruda - Flutter analyze completo

Comando:

```powershell
flutter analyze --no-pub
```

Salida estandar:

```text
Analyzing Caja_simple...                                        

   info - Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check - lib\activos_fijos_page.dart:171:36 - use_build_context_synchronously
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\commissions_page.dart:367:22 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\commissions_page.dart:369:41 - deprecated_member_use
   info - Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check - lib\comprobantes_page.dart:111:25 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\conciliacion_bancaria_page.dart:98:7 - use_build_context_synchronously
warning - The value of the local variable 'data' isn't used - lib\core\api\endpoints\sales_api.dart:98:13 - unused_local_variable
warning - The value of the local variable 'data' isn't used - lib\core\api\endpoints\sales_api.dart:124:13 - unused_local_variable
   info - Don't invoke 'print' in production code - lib\core\database\database_initializer.dart:207:5 - avoid_print
warning - The declaration '_migrarDB' isn't referenced - lib\core\database\database_initializer.dart:237:10 - unused_element
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:154:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:157:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:160:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:163:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:166:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:171:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\core\logging\logging_service.dart:216:5 - avoid_print
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\theme\app_theme.dart:122:37 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\theme\app_theme.dart:315:36 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\theme\app_theme.dart:431:19 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\theme\app_theme.dart:437:19 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\theme\app_theme.dart:443:16 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\theme\app_theme.dart:449:18 - deprecated_member_use
warning - This default clause is covered by the previous cases - lib\core\theme\theme_service.dart:65:7 - unreachable_switch_default
warning - This default clause is covered by the previous cases - lib\core\theme\theme_service.dart:94:7 - unreachable_switch_default
warning - The receiver can't be 'null' because of short-circuiting, so the null-aware operator '?.' can't be used - lib\core\workspace\selector_modo_screen.dart:80:58 - invalid_null_aware_operator
   info - Don't invoke 'print' in production code - lib\db_helper.dart:800:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\db_helper.dart:816:7 - avoid_print
   info - 'Table.fromTextArray' is deprecated and shouldn't be used. Use TableHelper.fromTextArray() instead - lib\declaraciones_tributarias_page.dart:97:15 - deprecated_member_use
   info - The constant name 'presupuesto_publico' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:22:16 - constant_identifier_names
   info - The constant name 'contabilidad_nicsp' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:23:16 - constant_identifier_names
   info - The constant name 'contratacion_publica' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:24:16 - constant_identifier_names
   info - The constant name 'nomina_publica' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:25:16 - constant_identifier_names
   info - The constant name 'auditoria_forense' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:26:16 - constant_identifier_names
   info - The constant name 'rentas_departamentales' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:28:16 - constant_identifier_names
   info - The constant name 'activos_estado' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:30:16 - constant_identifier_names
   info - The constant name 'salud_publica' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:31:16 - constant_identifier_names
   info - The constant name 'consolidacion_nicsp_40' isn't a lowerCamelCase identifier - lib\features\feature_key.dart:34:16 - constant_identifier_names
warning - The value of the local variable 'tipoDocCtrl' isn't used - lib\nomina_page.dart:50:11 - unused_local_variable
   info - Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check - lib\nomina_page.dart:419:36 - use_build_context_synchronously
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\nomina_page.dart:586:72 - deprecated_member_use
   info - 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:307:15 - deprecated_member_use
   info - 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:308:15 - deprecated_member_use
   info - 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:320:15 - deprecated_member_use
   info - 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:321:15 - deprecated_member_use
   info - 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:340:17 - deprecated_member_use
   info - 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:341:17 - deprecated_member_use
   info - 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:350:17 - deprecated_member_use
   info - 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:351:17 - deprecated_member_use
   info - 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:360:17 - deprecated_member_use
   info - 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:361:17 - deprecated_member_use
   info - 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:370:17 - deprecated_member_use
   info - 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre - lib\onboarding\onboarding_page.dart:371:17 - deprecated_member_use
warning - The value of the local variable 'ivaGeneralRate' isn't used - lib\sales\application\create_sale_use_case.dart:120:11 - unused_local_variable
warning - The value of the local variable 'ivaReducedRate' isn't used - lib\sales\application\create_sale_use_case.dart:121:11 - unused_local_variable
warning - The value of the local variable 'retefuenteServices1' isn't used - lib\sales\application\create_sale_use_case.dart:125:11 - unused_local_variable
warning - The value of the local variable 'retefuenteServices2' isn't used - lib\sales\application\create_sale_use_case.dart:126:11 - unused_local_variable
warning - The value of the local variable 'retefuenteHonoraries1' isn't used - lib\sales\application\create_sale_use_case.dart:127:11 - unused_local_variable
warning - The value of the local variable 'retefuenteHonoraries2' isn't used - lib\sales\application\create_sale_use_case.dart:128:11 - unused_local_variable
warning - Unused import: '../models/acta_responsabilidad.dart' - lib\sector_publico\activos\pages\activos_estado_page.dart:15:8 - unused_import
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\activos\pages\activos_estado_page.dart:324:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\activos\pages\activos_estado_page.dart:467:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\activos\pages\activos_estado_page.dart:541:19 - deprecated_member_use
warning - The value of the local variable 'idCtrl' isn't used - lib\sector_publico\activos\pages\activos_estado_page.dart:608:11 - unused_local_variable
warning - The value of the local variable 'dep' isn't used - lib\sector_publico\activos\pages\activos_estado_page.dart:631:29 - unused_local_variable
warning - The value of the local variable 'depreciacionAnual' isn't used - lib\sector_publico\activos\services\activos_service.dart:40:11 - unused_local_variable
   info - The type name 'DatosCGN2015_001' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:93:7 - camel_case_types
   info - The type name 'DatosCGN2015_002' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:150:7 - camel_case_types
   info - The type name 'DatosCGN2015_003' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:201:7 - camel_case_types
   info - The type name 'DatosCGN2015_004' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:237:7 - camel_case_types
   info - The type name 'DatosCGN2015_005' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:279:7 - camel_case_types
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\auditoria\pages\auditoria_forense_page.dart:512:17 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\sector_publico\auditoria\pages\auditoria_forense_page.dart:676:52 - deprecated_member_use
warning - Unused import: 'dart:convert' - lib\sector_publico\auditoria\services\fut_territorial_service.dart:5:8 - unused_import
warning - Unused import: 'dart:convert' - lib\sector_publico\auditoria\services\sia_observa_service.dart:5:8 - unused_import
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:226:19 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:252:50 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:260:51 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:312:15 - unnecessary_string_interpolations
warning - The value of the local variable 'fechaUltimoDia' isn't used - lib\sector_publico\contabilidad\services\depreciacion_job_service.dart:29:11 - unused_local_variable
   info - Unnecessary use of string interpolation - lib\sector_publico\contratacion\pages\contratacion_publica_page.dart:429:19 - unnecessary_string_interpolations
warning - The value of the field '_uuid' isn't used - lib\sector_publico\contratacion\services\secop_service.dart:20:14 - unused_field
   info - Use the null-aware marker '?' rather than a null check via an 'if' - lib\sector_publico\contratacion\services\secop_service.dart:43:7 - use_null_aware_elements
   info - Unnecessary use of string interpolation - lib\sector_publico\nomina\pages\nomina_publica_page.dart:318:15 - unnecessary_string_interpolations
warning - Unused import: '../models/liquidacion_nomina.dart' - lib\sector_publico\nomina\services\pila_service.dart:8:8 - unused_import
   info - The constant name 'en_revision' isn't a lowerCamelCase identifier - lib\sector_publico\planeacion\services\formulacion_mga_service.dart:13:3 - constant_identifier_names
   info - The constant name 'revision_tecnica' isn't a lowerCamelCase identifier - lib\sector_publico\planeacion\services\viabilizacion_service.dart:13:3 - constant_identifier_names
   info - The constant name 'revision_financiera' isn't a lowerCamelCase identifier - lib\sector_publico\planeacion\services\viabilizacion_service.dart:14:3 - constant_identifier_names
   info - Unnecessary use of string interpolation - lib\sector_publico\presupuesto\pages\pac_tesoreria_page.dart:329:71 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\presupuesto\pages\pac_tesoreria_page.dart:330:71 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\presupuesto\pages\pac_tesoreria_page.dart:331:71 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\presupuesto\pages\pac_tesoreria_page.dart:423:15 - unnecessary_string_interpolations
warning - The value of the field '_titulos' isn't used - lib\sector_publico\presupuesto\pages\presupuesto_publico_page.dart:34:22 - unused_field
   info - Don't use 'BuildContext's across async gaps - lib\sector_publico\presupuesto\pages\presupuesto_publico_page.dart:695:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\sector_publico\presupuesto\pages\presupuesto_publico_page.dart:875:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\sector_publico\presupuesto\pages\presupuesto_publico_page.dart:1031:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\sector_publico\presupuesto\pages\presupuesto_publico_page.dart:1207:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\sector_publico\presupuesto\pages\presupuesto_publico_page.dart:1416:28 - use_build_context_synchronously
warning - The value of the local variable 'fechaModificacion' isn't used - lib\sector_publico\presupuesto\services\pac_service.dart:274:11 - unused_local_variable
warning - Unused import: '../models/reporte_spgr.dart' - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:16:8 - unused_import
warning - Unused import: '../models/reporte_sicodis.dart' - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:17:8 - unused_import
warning - The value of the field '_bienios' isn't used - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:46:19 - unused_field
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:454:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:581:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:803:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:1053:17 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\rentas\pages\predial_ica_page.dart:793:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\rentas\pages\predial_ica_page.dart:864:19 - deprecated_member_use
warning - The value of the field '_dio' isn't used - lib\sector_publico\rentas\services\intereses_moratorios_service.dart:14:13 - unused_field
warning - The declaration '_validarPermiso' isn't referenced - lib\sector_publico\rentas\services\predial_service.dart:27:28 - unused_element
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:84:7 - curly_braces_in_flow_control_structures
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:540:19 - deprecated_member_use
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:552:23 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:577:19 - curly_braces_in_flow_control_structures
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:649:19 - deprecated_member_use
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:661:23 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:699:19 - curly_braces_in_flow_control_structures
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:791:19 - deprecated_member_use
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:803:23 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:897:19 - curly_braces_in_flow_control_structures
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:1042:19 - deprecated_member_use
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:1051:23 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib\sector_publico\salud\pages\salud_publica_page.dart:1082:19 - curly_braces_in_flow_control_structures
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\siif\pages\siif_page.dart:199:17 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\siif\pages\siif_page.dart:268:17 - deprecated_member_use
warning - Unused import: 'dart:convert' - lib\sector_publico\siif\services\siif_service.dart:5:8 - unused_import
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\sector_publico\transparencia\pages\transparencia_page.dart:404:56 - deprecated_member_use
   info - Unnecessary use of string interpolation - lib\sector_publico\transparencia\pages\transparencia_page.dart:489:23 - unnecessary_string_interpolations
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:16:5 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:17:5 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:18:5 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:22:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:30:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:40:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:42:9 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:54:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:110:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:124:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:143:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:164:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:188:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:354:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:357:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:489:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:492:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:506:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:509:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:510:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:513:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\seed_operations.dart:516:3 - avoid_print
warning - The value of the local variable 'body' isn't used - lib\services\api_router.dart:539:13 - unused_local_variable
   info - 'RawKeyboard' is deprecated and shouldn't be used. Use HardwareKeyboard instead. This feature was deprecated after v3.18.0-2.0.pre - lib\services\barcode_scanner_service.dart:26:5 - deprecated_member_use
   info - 'instance' is deprecated and shouldn't be used. Use HardwareKeyboard.instance instead. This feature was deprecated after v3.18.0-2.0.pre - lib\services\barcode_scanner_service.dart:26:17 - deprecated_member_use
   info - 'RawKeyboard' is deprecated and shouldn't be used. Use HardwareKeyboard instead. This feature was deprecated after v3.18.0-2.0.pre - lib\services\barcode_scanner_service.dart:31:5 - deprecated_member_use
   info - 'instance' is deprecated and shouldn't be used. Use HardwareKeyboard.instance instead. This feature was deprecated after v3.18.0-2.0.pre - lib\services\barcode_scanner_service.dart:31:17 - deprecated_member_use
   info - 'RawKeyEvent' is deprecated and shouldn't be used. Use KeyEvent instead. This feature was deprecated after v3.18.0-2.0.pre - lib\services\barcode_scanner_service.dart:36:24 - deprecated_member_use
   info - 'RawKeyDownEvent' is deprecated and shouldn't be used. Use KeyDownEvent instead. This feature was deprecated after v3.18.0-2.0.pre - lib\services\barcode_scanner_service.dart:38:19 - deprecated_member_use
   info - Don't invoke 'print' in production code - lib\services\barcode_scanner_service.dart:117:7 - avoid_print
   info - The constant name 'forzar_respaldo' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:10:3 - constant_identifier_names
   info - The constant name 'reiniciar_sesiones' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:11:3 - constant_identifier_names
   info - The constant name 'actualizar_modulos' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:12:3 - constant_identifier_names
   info - The constant name 'enviar_log' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:13:3 - constant_identifier_names
   info - The constant name 'mensaje_admin' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:14:3 - constant_identifier_names
   info - The constant name 'bloquear_instalacion' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:15:3 - constant_identifier_names
   info - The constant name 'activar_instalacion' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:16:3 - constant_identifier_names
   info - The constant name 'forzar_actualizacion' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:17:3 - constant_identifier_names
   info - The constant name 'rollback_actualizacion' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:18:3 - constant_identifier_names
   info - The constant name 'forzar_sincronizacion' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:20:3 - constant_identifier_names
   info - The constant name 'actualizar_licencia' isn't a lowerCamelCase identifier - lib\services\cc_commands_processor.dart:21:3 - constant_identifier_names
warning - The value of the field '_claveComandosPendientes' isn't used - lib\services\cc_commands_processor.dart:128:23 - unused_field
warning - The value of the field '_versionActual' isn't used - lib\services\health_reporter.dart:81:23 - unused_field
warning - The value of the local variable 'memoriaTotal' isn't used - lib\services\health_reporter.dart:217:13 - unused_local_variable
warning - The value of the local variable 'metricas' isn't used - lib\services\health_reporter.dart:287:11 - unused_local_variable
warning - The value of the local variable 'recordId' isn't used - lib\services\hybrid_sync_service.dart:182:13 - unused_local_variable
warning - The value of the local variable 'lastSyncRecordId' isn't used - lib\services\hybrid_sync_service.dart:239:14 - unused_local_variable
   info - The constant name 'en_proceso' isn't a lowerCamelCase identifier - lib\services\produccion_service.dart:6:3 - constant_identifier_names
   info - The constant name 'metro_cuadrado' isn't a lowerCamelCase identifier - lib\services\recetas_service.dart:4:54 - constant_identifier_names
   info - The constant name 'metro_cubico' isn't a lowerCamelCase identifier - lib\services\recetas_service.dart:4:70 - constant_identifier_names
   info - The constant name 'en_curso' isn't a lowerCamelCase identifier - lib\services\rutas_service.dart:4:30 - constant_identifier_names
warning - The value of the local variable 'db' isn't used - lib\services\sync_aware_db_helper.dart:180:11 - unused_local_variable
warning - The value of the field '_currentVersion' isn't used - lib\services\update_service.dart:120:23 - unused_field
warning - Dead code - lib\services\update_service.dart:198:7 - dead_code
   info - Don't use 'BuildContext's across async gaps - lib\transferencias_page.dart:93:21 - use_build_context_synchronously
warning - The declaration '_marcarPasoCompletado' isn't referenced - lib\ui\onboarding_widget.dart:64:8 - unused_element
   info - Don't use 'BuildContext's across async gaps - lib\ui\onboarding_widget.dart:70:28 - use_build_context_synchronously
warning - The member 'setState' can only be used within instance members of subclasses of 'State' - lib\ui\widgets\workspace_widgets.dart:255:39 - invalid_use_of_protected_member
warning - The declaration '_DesktopModuleDirectory' isn't referenced - lib\ui\widgets\workspace_widgets.dart:1125:7 - unused_element
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\warranties_page.dart:442:22 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\warranties_page.dart:444:41 - deprecated_member_use
warning - The value of the local variable 'contabilidadService' isn't used - test\sector_publico\security\rbac_segregacion_test.dart:18:33 - unused_local_variable

```

Error estandar:

```text
dart.exe : 189 issues found. (ran in 7.0s)
En línea: 2 Carácter: 1
+ & 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe' '--packages=C:\src ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (189 issues found. (ran in 7.0s):String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
```

### Evidencia cruda - Flutter build windows

Comando:

```powershell
flutter build windows --no-pub
```

Salida estandar:

```text
Building Windows application...                                 
Building Windows application...                                    89.8s
√ Built build\windows\x64\runner\Release\MerkaERP.exe
```

Error estandar:

```text
dart.exe : Nuget.exe not found, trying to download or use cached version.
En línea: 2 Carácter: 1
+ & 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe' '--packages=C:\src ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (Nuget.exe not f...cached version.:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
```

## Cierre de la Fase 2

Estado: **Completa en nucleo y esquema; consumidores pendientes por diseno de fases**.

La migracion v75 es atomica e idempotente y fue validada contra una copia del respaldo. No se modifico la base activa ni el respaldo inmutable. El build no falla por el tipado dinamico de SQLite, pero no debe considerarse funcionalmente compatible hasta convertir lectores/escritores comerciales y publicos.

Commit: este commit de Fase 2 (ver `git log`).

## Fase 3A - consumidores comerciales, primera entrega

Fecha de cierre: 2026-08-08.

### Inventario y decision de alcance

El manifiesto v75 contiene 197 columnas monetarias comerciales en 74 tablas.
La depuracion identifico 79 consumidores Dart directos y seis bordes de soporte
adicionales encontrados al compilar. Se priorizo una entrega funcional de los
flujos de mayor riesgo: ventas/POS, compras, caja, cartera, bancos, nomina y
reportes fiscales. Esta entrega es parcial: convierte semanticamente 27 de los
79 consumidores inventariados y los seis bordes de soporte; quedan 52
consumidores inventariados en `MIGRACION_DINERO_CENTAVOS_FASE_3A_INVENTARIO.md`.

### Archivos convertidos semanticamente

- `lib/accounting/application/accounting_engine.dart`
- `lib/bancos_page.dart`
- `lib/caja_page.dart`
- `lib/cierres_caja_page.dart`
- `lib/commerce/application/payment_policy.dart`
- `lib/compras_page.dart`
- `lib/conciliacion_bancaria_page.dart`
- `lib/core/api/api_dispatcher.dart`
- `lib/core/currency/money_value.dart`
- `lib/core/currency/money_currency_resolver.dart`
- `lib/core/invoicing/cufe.dart`
- `lib/cuentas_por_cobrar_page.dart`
- `lib/cuentas_por_pagar_page.dart`
- `lib/db_helper.dart`
- `lib/declaraciones_tributarias_page.dart`
- `lib/estados_financieros_page.dart`
- `lib/exportar_excel.dart`
- `lib/extracto_caja_page.dart`
- `lib/extractos_bancarios_page.dart`
- `lib/facturacion_electronica_page.dart`
- `lib/financial_dashboard.dart`
- `lib/nomina_page.dart`
- `lib/presupuestos_page.dart`
- `lib/purchases/application/create_purchase_use_case.dart`
- `lib/purchases/data/purchase_repository.dart`
- `lib/purchases/domain/purchase.dart`
- `lib/reportes_fiscales_page.dart`
- `lib/reportes_page.dart`
- `lib/sales/application/create_sale_use_case.dart`
- `lib/sales/data/sale_repository.dart`
- `lib/sales/domain/sale.dart`
- `lib/transferencias_page.dart`
- `lib/ui/sales_mode_panel.dart`
- `lib/ventas_page.dart`

`order_service.dart`, `quote_service.dart`, `commission_service.dart`,
`warranty_service.dart` y `order.dart` tuvieron formateo mecanico durante la
compilacion incremental. Esos diffs se revirtieron antes del commit; no se
cuentan como convertidos y sus importes siguen en el backlog de esta fase.

### Bugs encontrados y corregidos

1. Cesantias: `intereses_cesantias` aplicaba una sola tasa de 1 %. Ahora usa
   `cesantias.percent('12')`, equivalente al 12 % anual exacto sobre el saldo.
2. ReteICA: se verifico que sigue leyendo `reglas_retenciones_empresa` por
   empresa, con `activo=1` y `aplica_ventas=1`; sin regla activa produce cero.
3. Contabilizacion de venta: se elimino una doble resta de retenciones al
   construir el ingreso y se validan medios de pago con `MoneyValue`.
4. Extractos bancarios: se corrigio el consumidor que usaba nombres inexistentes
   (`banco_id`/`monto`) frente al esquema real (`cuenta`/`valor`).
5. Repositorios de venta/compra: el resolvedor de moneda ahora es inyectable;
   una prueba con gateway aislado ya no abre el `DatabaseHelper` global.

### Evidencia cruda

Analisis:

```text
Comando: dart analyze lib test
Linea base Fase 2: 189 issues, 0 errores
Resultado intermedio: 188 issues, 3 errores (financial_dashboard.dart)
Resultado final: 185 issues found, 0 errores
```

La salida cruda completa esta en
`docs/evidencias/migracion_dinero_fase_3a/dart_analyze_lib_test.txt`.

Regresion comercial focalizada:

```text
00:23 +47: All tests passed!
```

La salida cruda completa de las 47 pruebas esta en
`docs/evidencias/migracion_dinero_fase_3a/flutter_test_comercial.txt`.
Incluye MoneyValue, POS, ReteICA, cesantias al 12 %, F300/F350, CUFE, API,
seguridad, repositorios y factura electronica.

Suite completa:

```text
Suites     : 78
Tests      : 213
Passed     : 185
Error      : 25
Skipped    : 3
RunnerDone : 1
```

Los 25 fallos restantes pertenecen a widgets generales o a fixtures/esquemas
de sector publico pendientes de Fase 3B; no quedo ningun fallo en el lote
comercial convertido. El listado crudo esta en
`docs/evidencias/migracion_dinero_fase_3a/suite_completa_resumen.txt`.

Build Windows:

```text
Building Windows application...                                    88.1s
√ Built build\windows\x64\runner\Release\MerkaERP.exe
```

Salida completa en
`docs/evidencias/migracion_dinero_fase_3a/flutter_build_windows.txt`.

## Cierre de la Fase 3A

Estado: **Parcial, compilable y respaldado por regresion comercial**.

Los flujos comerciales de mayor riesgo operan sobre enteros de unidad menor y
`MoneyValue`, el analizador queda en cero errores y el build Windows termina.
No se declara completa la migracion comercial: quedan 52 consumidores directos,
principalmente documentos enterprise de ventas/compras, inventario, libro
contable, analitica, multiempresa e integraciones. Esos archivos no deben
recibir adaptadores `double` temporales; continuan con la misma regla de borde.

Commit: este commit de Fase 3A (ver `git log`).

## Correccion de regresion de carga de moneda - 2026-08-08

### Diagnostico y decision

La regresion no estaba en `MoneyValue`: `VentasPage.build()` intentaba crear
el acumulador `MoneyValue(minorUnits: 0, currency: _currency)` en la linea
1070 mientras `_currency` todavia era nulo. La moneda se resuelve en
`_cargarDatosInterna()` despues de `await MoneyCurrencyResolver.resolve()` y
se asigna en el `setState` final. `ComprasPage.build()` tenia el mismo defecto
en la linea 770, aunque su cuerpo visual ya tenia un flag `_cargando`.

La correccion conservadora fue retornar un `CircularProgressIndicator` antes
de cualquier acumulacion monetaria cuando la carga no termino o la moneda no
esta resuelta. No se modifico `MoneyValue` ni se agrego una moneda por defecto.
`caja_page.dart`, `cuentas_por_cobrar_page.dart`,
`cuentas_por_pagar_page.dart` y `nomina_page.dart` fueron inspeccionadas: sus
constructores estan protegidos por guardas null o por el estado de carga. En
`ui/sales_mode_panel.dart`, el `build()` ya retorna loading antes de acceder a
`_zero`. No se detecto otro punto equivalente en esas paginas.

### Evidencia cruda de regresion

Comando:

```text
flutter test test/commercial_currency_loading_regression_test.dart test/module_smoke_test.dart --reporter expanded
```

Salida completa:

```text
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/commercial_currency_loading_regression_test.dart
00:00 +0: C:/Users/PC/Desktop/Caja_simple/test/commercial_currency_loading_regression_test.dart: Ventas muestra carga mientras la moneda aún no está resuelta
00:00 +1: C:/Users/PC/Desktop/Caja_simple/test/commercial_currency_loading_regression_test.dart: Compras muestra carga mientras la moneda aún no está resuelta
00:00 +2: C:/Users/PC/Desktop/Caja_simple/test/commercial_currency_loading_regression_test.dart: MoneyValue conserva el fail-closed sin moneda resuelta
00:00 +3: loading C:/Users/PC/Desktop/Caja_simple/test/module_smoke_test.dart
00:02 +3: C:/Users/PC/Desktop/Caja_simple/test/module_smoke_test.dart: (setUpAll)
Inicializando tablas del Sector Público para nueva instalación...
00:06 +3: C:/Users/PC/Desktop/Caja_simple/test/module_smoke_test.dart: todos los modulos principales abren sin excepciones
00:08 +4: C:/Users/PC/Desktop/Caja_simple/test/module_smoke_test.dart: (tearDownAll)
00:08 +4: All tests passed!
```

### Suite completa v2

Comando exacto:

```text
flutter test --reporter silent --file-reporter json:phase3a_audit_suite_v2.json --concurrency=4
```

El archivo JSON registro todos los eventos, aunque el runner no cerro y la
ejecucion fue terminada despues de que dejaron de avanzar los procesos
huérfanos. Conteo extraido del archivo, no del eco del terminal:

```text
Tests procesados: 351 eventos testDone
Passed: 334
Errors: 17
Skipped: 3
module_smoke_test.dart: ya no aparece entre los errores
```

Las 17 fallas restantes pertenecen a login/widget y fixtures o esquemas del
sector publico: `login_widget_test.dart`, `acta_responsabilidad_service_test.dart`,
`fut_territorial_service_test.dart`, `sia_observa_service_test.dart`,
`configuracion_general_service_test.dart`, `onboarding_legado_migracion_test.dart`,
los dos tests de `presupuesto_pago_integracion_test.dart`,
`sicodis_service_test.dart`, `exportacion_declaraciones_test.dart`,
`predial_ica_page_test.dart`, `facturacion_salud_service_test.dart`,
el test de apropiacion de `presupuesto_publico_page_test.dart`,
`salud_publica_page_test.dart`, `siif_service_test.dart` y los dos tests de
`widget_test.dart`.

El conteo sigue siendo 17, pero la lista no fue textualmente identica a la
auditoria previa: antes `presupuesto_publico_page_test.dart` fallaba en
`pumpAndSettle timed out`; ahora fallo `Crear apropiación y verificar en base
de datos`. Por la regla de la sesion, esta variacion se reporta y bloquea el
avance a los 52 consumidores hasta una confirmacion/auditoria posterior.

### Verificacion adicional

```text
flutter analyze 1> phase3a_regression_analyze.txt 2> phase3a_regression_analyze_error.txt
Resultado: timeout del entorno tras 300 segundos; ambos archivos quedaron vacios.
No se declara un analyze global limpio.
```

### Cierre de la correccion de regresion

Estado: **correccion implementada y pruebas dirigidas limpias; avance a los 52
consumidores detenido** por la variacion en la lista de fallas ajenas y por el
timeout del analyze global.

Archivos corregidos: `lib/ventas_page.dart`, `lib/compras_page.dart`.
Test agregado: `test/commercial_currency_loading_regression_test.dart`.
El fail-closed de `MoneyValue` conserva exactamente el mensaje
`A resolved currency is required for MoneyValue`.

Commit de la correccion: `031a080`.

## Auditoria posterior del cambio de sintoma en presupuesto publico - 2026-08-08

### Resultado del aislamiento

Se ejecuto el archivo en aislamiento:

```text
flutter test test/sector_publico/presupuesto/presupuesto_publico_page_test.dart --reporter expanded
```

El proceso no emitio salida en los archivos de texto y agoto 180 segundos.
Se repitio con reporter JSON para recuperar los eventos:

```text
flutter test --reporter silent --file-reporter json:presupuesto_publico_aislado.json test/sector_publico/presupuesto/presupuesto_publico_page_test.dart
```

El test pedido fallo exactamente asi:

```text
Test: Presupuesto Público Page Tests Crear apropiación y verificar en base de datos
Resultado: error
Mensaje: pumpAndSettle timed out
Stack:
#0      WidgetTester.pumpAndSettle.<anonymous closure> (package:flutter_test/src/widget_tester.dart:717:11)
#1      TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
#2      main.<anonymous closure>.<anonymous closure> (file:///C:/Users/PC/Desktop/Caja_simple/test/sector_publico/presupuesto/presupuesto_publico_page_test.dart:196:7)
#3      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
#4      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
```

La falla ocurre en la espera de carga, antes de `tap('Crear Apropiación')`,
antes de llenar el formulario y antes de la consulta/assert de la fila en
`apropiaciones`. No es un mensaje de columna inexistente ni de dato inválido
de apropiación.

### Determinacion de alcance

`git hash-object test/sector_publico/presupuesto/presupuesto_publico_page_test.dart`
coincide con `git rev-parse 765404c:test/sector_publico/presupuesto/presupuesto_publico_page_test.dart`.
El diff `765404c..031a080` solo contiene Ventas, Compras, la prueba de carga
comercial y documentación; no contiene ningún archivo de presupuesto público,
modelo público ni esquema público.

La página pública inicia una carga asíncrona en `initState()` y mantiene
`_loading = true` hasta el final de `_cargarDatos()`. El test usa
`pumpAndSettle()` sin límite en la línea 196, por lo que un futuro/consulta
que no complete deja el `CircularProgressIndicator` animando indefinidamente.
La causa inmediata confirmada es ese desacople del arnés de widget con la
carga pública; el test nunca alcanza la aserción de apropiación. El cambio
comercial no puede explicar esta falla por alcance de archivos y el test es
idéntico al de `765404c`.

Estado: **pendiente conocido de Fase 3B**. No se corrige aquí ni se atribuye
al fix `MoneyValue`.

### Verificacion de analyze y build

`flutter analyze` completo, con salida redirigida y sondeo, no produjo bytes y
agotó 300 segundos. El subconjunto también se probó sin resultado:

```text
dart analyze lib/ventas_page.dart lib/compras_page.dart lib/caja_page.dart lib/cuentas_por_cobrar_page.dart lib/cuentas_por_pagar_page.dart lib/nomina_page.dart lib/db_helper.dart
Resultado: timeout a los 180 segundos, sin diagnosticos.
```

`flutter build windows`, con stdout/stderr redirigidos, tampoco produjo bytes y
agotó 300 segundos. No se declara build exitoso.

## Estrategia alternativa para consumidores restantes 3A - 2026-08-08

La prueba unica de binario `dart analyze lib/core/currency/money_value.dart`
no respondio en 15 segundos. No se insistira con ese binario durante esta
ronda.

Verificacion alternativa por bloque:

1. Tests Flutter dirigidos que importen y ejecuten el consumidor real del
   bloque, incluyendo pruebas de persistencia INTEGER y calculo exacto.
2. `dart format --output=none --set-exit-if-changed` sobre los archivos del
   bloque, solo como chequeo rapido de formato/sintaxis si el binario responde.
3. No se usaran `flutter analyze` ni `flutter build windows` globales en esta
   ronda por el bloqueo estructural ya confirmado.

Al cierre, Omar debe ejecutar manualmente en su entorno:

```text
flutter analyze
flutter build windows
```

Estos dos comandos quedan pendientes de verificacion global por Omar.

## Continuacion Fase 3A - verificacion alternativa y bloques restantes - 2026-08-08

### Paso 0: diagnostico del bloqueo

Se ejecuto una sola vez el analisis acotado solicitado:

\`\`\`text
dart analyze lib/core/currency/money_value.dart
Resultado: no produjo salida y agoto el timeout de 15 segundos.
\`\`\`

Esto confirma que el bloqueo no es exclusivo de \`flutter analyze\`; el binario
\`dart analyze\` tampoco respondio en esta sesion. La verificacion usada para
los bloques fue:

\`\`\`text
flutter test <tests dirigidos del bloque> --reporter expanded
dart format --output=none --set-exit-if-changed <archivos del bloque>
\`\`\`

No se relanzaron \`flutter analyze\` ni \`flutter build windows\` globales.
Quedan pendientes para Omar al cierre:

\`\`\`text
flutter analyze
flutter build windows
\`\`\`

### Bloque de documentos empresariales de ventas

Se convirtieron 5 consumidores de produccion y su borde API compartido:

- \`lib/sales/domain/sales_document.dart\`
- \`lib/sales/data/sales_document_repository.dart\`
- \`lib/sales/application/sales_command_handlers.dart\`
- \`lib/sales/application/sales_query_handlers.dart\`
- \`lib/sales/application/sales_projections.dart\`
- \`lib/core/api/api_dispatcher.dart\` (borde compartido de ventas y Compras)

Los importes del documento, sus lineas, eventos, proyecciones y persistencia
usan \`MoneyValue\`; cantidades y tasas permanecen como \`double\`. El API
resuelve la moneda antes de construir el comando. Se corrigio tambien el
payload de reverso para que las proyecciones no reciban importes sin tipar.

Evidencia cruda:

\`\`\`text
flutter test test/sales_enterprise_test.dart --reporter expanded

00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart
00:00 +0: SalesDocument enforce enterprise state machine and immutability
00:00 +1: SalesCommandHandlers create, post, audit, events and analytics query
00:00 +2: ApiDispatcher exposes enterprise sales document endpoints
00:00 +3: All tests passed!
\`\`\`

\`\`\`text
dart format --output=none --set-exit-if-changed lib/sales/domain/sales_document.dart lib/sales/data/sales_document_repository.dart lib/sales/application/sales_command_handlers.dart lib/sales/application/sales_query_handlers.dart lib/sales/application/sales_projections.dart lib/core/api/api_dispatcher.dart test/sales_enterprise_test.dart
Formatted 7 files (0 changed)
\`\`\`

### Bloque de documentos empresariales de Compras

Se convirtieron estos 5 consumidores de produccion:

- \`lib/purchases/domain/purchase_document.dart\`
- \`lib/purchases/data/purchase_document_repository.dart\`
- \`lib/purchases/application/purchase_command_handlers.dart\`
- \`lib/purchases/application/purchase_query_handlers.dart\`
- \`lib/purchases/application/purchase_projections.dart\`

El contrato de compra, presupuesto, impuestos, retenciones, saldos de
proveedor, eventos y analytics usan \`MoneyValue\`. SQLite recibe unidades
menores y las filas se rehidratan con la moneda resuelta de la empresa. La
frontera heredada de contabilidad sigue expresando el asiento como \`double\`
porque \`JournalEntry/JournalLine\` aún no fue convertido; se documenta como
dependencia pendiente, sin cast dinamico ni division manual.

Evidencia cruda:

\`\`\`text
flutter test test/purchases_enterprise_test.dart --reporter expanded

00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart
00:00 +0: PurchaseDocument enforces approvals, partial receipt, posting and reversal
00:01 +1: PurchaseCommandHandlers integrate events, audit, supplier balance and analytics
00:01 +2: ApiDispatcher exposes enterprise purchase endpoints
00:01 +3: All tests passed!
\`\`\`

\`\`\`text
dart format --output=none --set-exit-if-changed lib/purchases/domain/purchase_document.dart lib/purchases/data/purchase_document_repository.dart lib/purchases/application/purchase_command_handlers.dart lib/purchases/application/purchase_query_handlers.dart lib/purchases/application/purchase_projections.dart lib/core/api/api_dispatcher.dart test/purchases_enterprise_test.dart
Formatted 7 files (0 changed)
\`\`\`

### Bloque de costos de inventario por lote

Se convirtieron estos 3 consumidores:

- \`lib/inventory/domain/stock_ledger.dart\`
- \`lib/inventory/data/stock_ledger_repository.dart\`
- \`lib/inventory/application/stock_ledger_service.dart\`

Los costos por lote y consumos ahora usan \`MoneyValue\`, incluyendo FIFO,
promedio ponderado, persistencia INTEGER y payloads de eventos. Las cantidades
siguen siendo \`double\`. El flujo de Compras deja de convertir el costo de la
linea a \`double\` al recibir inventario.

Evidencia cruda:

\`\`\`text
flutter test test/architectural_consolidation_test.dart test/purchases_enterprise_test.dart --reporter expanded

00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart
00:00 +0: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica event bus persistente aplica scope, idempotencia y correlacion
00:01 +1: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica ledger contabiliza, reversa y conserva partida doble
00:01 +2: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica posting service persiste asientos y publica eventos
00:01 +3: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica stock ledger consume FIFO y emite evento transaccional
00:01 +4: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica api expone event store, replay y read model ejecutivo
00:01 +5: loading C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart
00:01 +5: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: PurchaseDocument enforces approvals, partial receipt, posting and reversal
00:02 +6: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: PurchaseCommandHandlers integrate events, audit, supplier balance and analytics
00:02 +7: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: ApiDispatcher exposes enterprise purchase endpoints
00:02 +8: All tests passed!
\`\`\`

\`\`\`text
dart format --output=none --set-exit-if-changed lib/inventory/domain/stock_ledger.dart lib/inventory/data/stock_ledger_repository.dart lib/inventory/application/stock_ledger_service.dart lib/purchases/application/purchase_command_handlers.dart test/architectural_consolidation_test.dart
Formatted 5 files (0 changed)
\`\`\`

### Estado del turno

Se convirtieron **14 consumidores de produccion de los 52 pendientes**:
5 de Ventas, 5 de Compras, 3 de Inventario y el borde API compartido. Los
tests dirigidos ejecutados en este turno pasaron: 3 de Ventas, 3 de Compras y
5 arquitectónicos, con las pruebas de formato correspondientes.

Quedan pendientes, entre otros, \`JournalEntry/JournalLine\` y sus repositorios,
los modelos heredados \`Product\`/\`InventoryLot\`, \`InventoryControlService\`,
pedidos/cotizaciones y los reportes/integraciones del inventario comercial.
No se encontraron bugs adicionales de doble conteo en los bloques verificados;
sí se detectó y aisló la frontera heredada de contabilidad que todavía usa
\`double\`.

Reejecucion conjunta final de los tres grupos:

\`\`\`text
flutter test test/sales_enterprise_test.dart test/purchases_enterprise_test.dart test/architectural_consolidation_test.dart --reporter expanded
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart
00:00 +0: C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart: SalesDocument enforce enterprise state machine and immutability
00:00 +1: C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart: SalesCommandHandlers create, post, audit, events and analytics query
00:00 +2: C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart: ApiDispatcher exposes enterprise sales document endpoints
00:00 +3: loading C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart
00:00 +3: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: PurchaseDocument enforces approvals, partial receipt, posting and reversal
00:00 +4: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: PurchaseCommandHandlers integrate events, audit, supplier balance and analytics
00:01 +5: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: ApiDispatcher exposes enterprise purchase endpoints
00:01 +6: loading C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart
00:01 +6: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica event bus persistente aplica scope, idempotencia y correlacion
00:01 +7: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica ledger contabiliza, reversa y conserva partida doble
00:01 +8: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica posting service persiste asientos y publica eventos
00:01 +9: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica stock ledger consume FIFO y emite evento transaccional
00:01 +10: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica api expone event store, replay y read model ejecutivo
00:01 +11: All tests passed!
\`\`\`

### Cierre de la conversion parcial 3A del 2026-08-08

Estado: **Parcial**. Los bloques de ventas empresariales, Compras empresariales
y costos por lote de inventario quedan convertidos y cubiertos por tests
dirigidos. La Fase 3A no queda cerrada: faltan 38 consumidores del inventario
de 52 y la verificacion global de analyze/build debe ejecutarla Omar.
No se toca \`backend\`; su estado local preexistente se conserva.

## Limpieza de evidencia temporal - 2026-08-08

- \`phase3a_audit_suite.json\`: borrado; era la salida puntual de la suite,
  ya resumida y respaldada por este log.
- \`presupuesto_publico_aislado.json\`: borrado; era la salida puntual del
  diagnóstico de Fase 3B, ya documentada en este log.
- \`phase3a_analyze_v3.txt\` y \`phase3a_analyze_v3_error.txt\`: ambos estaban
  vacíos y se intentaron borrar, pero Windows los mantiene abiertos por otro
  proceso. Quedaron ignorados mediante \`.gitignore\`; no aparecen como
  untracked. Omar puede eliminarlos cuando cierre el proceso que los retiene.
- \`.gitignore\`: agrega patrones raíz para \`phase3a\`, salidas
  \`*_analyze_*.txt\`, \`*_audit_*.json\` y \`*_aislado.json\`.

### Cierre de la limpieza temporal

Estado: **Completo en Git**. El working tree queda limpio salvo el submodulo
\`backend\` preexistente; los dos archivos vacios bloqueados no forman parte del
indice ni del estado de Git.

## Continuacion Fase 3A - conversion del bloque contable - 2026-08-08

### Alcance y decisiones

Se priorizo el bloque contable de los 38 consumidores comerciales pendientes.
Quedaron convertidos seis archivos de produccion del subdominio contable:

- `lib/accounting/domain/journal_entry.dart`
- `lib/accounting/domain/trial_balance.dart`
- `lib/accounting/application/ledger_engine.dart`
- `lib/accounting/application/accounting_posting_service.dart`
- `lib/accounting/data/journal_entry_repository.dart`
- `lib/accounting/data/accounting_report_repository.dart`

`lib/purchases/application/purchase_command_handlers.dart` tambien se ajusto
como puente del posting de compras hacia `JournalLine`, pero ya pertenecia al
bloque de Compras convertido en el commit `4abbbe7` y no se cuenta de nuevo.
Con este turno quedan **6 de 38** consumidores restantes convertidos y **32 de
38** pendientes.

Los importes de asientos, lineas, saldos y balances ahora usan `MoneyValue` y
se serializan como unidad menor mediante `toSql()`/`toWireMap()`. La igualdad
de partida doble es exacta en unidades menores; se elimino la tolerancia basada
en `double`. El `double` que permanece en este bloque es `exchangeRate`, que es
metadato de conversion monetaria, no un importe contable.

### Validacion SQL de partida doble

No se agrego un trigger SQL en este turno. La regla de agregado requiere validar
el conjunto completo de lineas de un asiento dentro de la misma transaccion;
un trigger por fila no puede garantizarla sin un estado intermedio o un modelo
de insercion diferida. El dominio ya rechaza descuadres exactos antes de
contabilizar, y el test nuevo cubre un descuadre de un centavo. La garantia a
nivel de base de datos queda anotada como trabajo separado de esquema y
transaccion, no como una garantia ya resuelta.

### Evidencia cruda de tests dirigidos

Comando ejecutado:

```text
flutter test test/accounting_rules_test.dart test/accounting_report_test.dart test/architectural_consolidation_test.dart test/api_dispatcher_test.dart test/purchases_enterprise_test.dart test/sales_enterprise_test.dart --reporter expanded
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/accounting_rules_test.dart
00:00 +0: C:/Users/PC/Desktop/Caja_simple/test/accounting_rules_test.dart: AccountingEngine configurable usa cuentas configuradas para venta
00:00 +1: C:/Users/PC/Desktop/Caja_simple/test/accounting_rules_test.dart: AccountingEngine configurable usa cuentas configuradas para compra
00:00 +2: loading C:/Users/PC/Desktop/Caja_simple/test/accounting_report_test.dart
00:01 +2: C:/Users/PC/Desktop/Caja_simple/test/accounting_report_test.dart: JournalEntry con MoneyValue rechaza un descuadre de un centavo sin tolerancia double
00:01 +3: C:/Users/PC/Desktop/Caja_simple/test/accounting_report_test.dart: TrialBalance calcula totales y estado balanceado
00:01 +4: C:/Users/PC/Desktop/Caja_simple/test/accounting_report_test.dart: SqliteAccountingReportRepository consulta balance por empresa activa
00:01 +5: loading C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart
00:02 +5: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica event bus persistente aplica scope, idempotencia y correlacion
00:02 +6: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica ledger contabiliza, reversa y conserva partida doble
00:02 +7: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica posting service persiste asientos y publica eventos
00:02 +8: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica stock ledger consume FIFO y emite evento transaccional
00:02 +9: C:/Users/PC/Desktop/Caja_simple/test/architectural_consolidation_test.dart: Consolidacion arquitectonica api expone event store, replay y read model ejecutivo
00:02 +10: loading C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart
00:03 +10: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher expone resumen operativo con inventario, ventas y compras
00:03 +11: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher pagina listados y expone metadatos de paginacion
00:03 +12: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher bloquea endpoints cuando el rol no tiene permiso
00:03 +13: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher expone balance de comprobacion contable
00:03 +14: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher crea venta desde cuerpo API con nombres externos
00:03 +15: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher crea compra desde cuerpo API y serializa asignacion de pago
00:03 +16: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher expone endpoints empresariales de readiness y seguridad
00:03 +17: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher expone flujos empresariales y reposicion de inventario
00:03 +18: C:/Users/PC/Desktop/Caja_simple/test/api_dispatcher_test.dart: ApiDispatcher expone empresas y reporte fiscal sin endpoints pendientes
00:03 +19: loading C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart
00:04 +19: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: PurchaseDocument enforces approvals, partial receipt, posting and reversal
00:04 +20: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: PurchaseCommandHandlers integrate events, audit, supplier balance and analytics
00:04 +21: C:/Users/PC/Desktop/Caja_simple/test/purchases_enterprise_test.dart: ApiDispatcher exposes enterprise purchase endpoints
00:04 +22: loading C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart
00:05 +22: C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart: SalesDocument enforce enterprise state machine and immutability
00:05 +23: C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart: SalesCommandHandlers create, post, audit, events and analytics query
00:05 +24: C:/Users/PC/Desktop/Caja_simple/test/sales_enterprise_test.dart: ApiDispatcher exposes enterprise sales document endpoints
00:05 +25: All tests passed!
```

### Evidencia cruda de formato

```text
dart format --output=none --set-exit-if-changed lib/accounting/application/accounting_posting_service.dart lib/accounting/application/ledger_engine.dart lib/accounting/data/accounting_report_repository.dart lib/accounting/data/journal_entry_repository.dart lib/accounting/domain/journal_entry.dart lib/accounting/domain/trial_balance.dart lib/purchases/application/purchase_command_handlers.dart test/accounting_report_test.dart test/api_dispatcher_test.dart test/architectural_consolidation_test.dart
Formatted 10 files (0 changed).
```

No se reejecutaron `flutter analyze` ni `flutter build windows` globales:
continuan bloqueados estructuralmente en este entorno, por instruccion de la
fase anterior. Omar debe cerrar esa verificacion manualmente con:

```text
flutter analyze
flutter build windows
```

### Cierre de la subtarea contabilidad

Estado: **Parcial**. Los seis consumidores contables priorizados quedaron
convertidos en el commit `b65b763`.
convertidos y los 25 tests dirigidos pasaron. Quedan 32 consumidores
comerciales del inventario de 38, y la validacion de partida doble a nivel SQL
queda pendiente de una migracion/transaccion especifica. No se toco el
submodulo `backend`.

## Cierre de Fase 3A - tramo final de 35 consumidores - 2026-08-08

### Reconciliacion del universo

El manifiesto directo tenia 79 consumidores comerciales. La contabilidad
priorizada ya habia convertido 6 de los 38 pendientes; el cierre restante se
reconcilio como 35 archivos exactos, agrupados asi:

**Pedidos y cotizaciones (5):**

- `lib/sales/domain/order.dart`
- `lib/sales/domain/order_line.dart`
- `lib/sales/domain/quote.dart`
- `lib/sales/application/order_service.dart`
- `lib/sales/application/quote_service.dart`

**Otros documentos/API/pantallas (6):**

- `lib/services/api_router.dart`
- `lib/public_api_server.dart`
- `lib/documento_pdf_service.dart`
- `lib/detalle_compra_page.dart`
- `lib/comprobantes_page.dart`
- `lib/contabilidad_page.dart`

**Inventario heredado (6):**

- `lib/inventory/application/inventory_control_service.dart`
- `lib/inventory/domain/inventory_lot.dart`
- `lib/inventory/domain/inventory_summary.dart`
- `lib/inventory/domain/price_history.dart`
- `lib/inventory/domain/product.dart`
- `lib/inventario_page.dart`

**Reportes/proyecciones/integraciones (18):**

- `lib/core/analytics/dashboard_analytics.dart`
- `lib/core/multi_company/financial_consolidation.dart`
- `lib/core/payments/payment_service.dart`
- `lib/core/predictive/predictive_analytics.dart`
- `lib/cqrs/application/dashboard_projection.dart`
- `lib/cqrs/domain/read_models.dart`
- `lib/enterprise/application/final_enterprise_command_handlers.dart`
- `lib/enterprise/application/final_enterprise_projections.dart`
- `lib/enterprise/application/final_enterprise_query_handlers.dart`
- `lib/enterprise/domain/final_enterprise_contexts.dart`
- `lib/services/enterprise_feature_service.dart`
- `lib/services/merka_intelligence_service.dart`
- `lib/services/nequi_service.dart`
- `lib/services/pse_service.dart`
- `lib/services/recetas_service.dart`
- `lib/ui/finance_mode_panel.dart`
- `lib/ui/operations_mode_panel.dart`
- `lib/seed_operations.dart`

Total del tramo: `5 + 6 + 6 + 18 = 35`; total de Fase 3A: `44 + 35 = 79`.

### Decisiones y cambios

- Los modelos, servicios y persistencia de estos 35 archivos usan `MoneyValue`
  en calculos monetarios y `toSql()` para SQLite INTEGER.
- Las salidas de API, eventos, auditoria y reportes usan `toWireMap()`; la
  conversion a unidades mayores queda en UI/presentacion.
- El seed comercial tambien fue actualizado: productos, ventas, compras,
  asientos, caja y cierres se siembran en unidad menor sin aritmetica monetaria
  con `double`.
- Se agrego `test/phase3a_remaining_money_test.dart` como smoke de integracion
  para dominio empresarial, depreciacion y esquema de pasarelas.
- No se cambio `backend`; su submodulo permanece con cambios locales
  preexistentes.

### Evidencia cruda dirigida

```text
flutter test test/module_smoke_test.dart test/merka_intelligence_service_test.dart test/final_enterprise_contexts_test.dart test/architectural_consolidation_test.dart test/api_dispatcher_test.dart test/orders_quotes_money_test.dart test/inventory_legacy_money_test.dart --reporter expanded
00:20 +22: All tests passed!

flutter test test/phase3a_remaining_money_test.dart --reporter expanded
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/phase3a_remaining_money_test.dart
00:00 +0: (setUpAll)
00:00 +0: bloque periférico conserva dinero exacto en dominio y API
00:00 +1: pasarela persiste importes como INTEGER
00:00 +2: (tearDownAll)
00:00 +2: All tests passed!
```

### Suite completa y comparacion con la linea base

```text
flutter test --reporter silent --file-reporter json:phase3a_audit_suite_final.json --concurrency=4
testDone=217 success=200 errors=17 skipped=3
```

Las 17 fallas son las mismas 17 ya clasificadas como ajenas a 3A: `login_widget_test.dart`, `acta_responsabilidad_service_test.dart`, `fut_territorial_service_test.dart`, `sia_observa_service_test.dart`, `configuracion_general_service_test.dart`, `onboarding_legado_migracion_test.dart`, dos casos de `presupuesto_pago_integracion_test.dart`, `sicodis_service_test.dart`, `exportacion_declaraciones_test.dart`, `facturacion_salud_service_test.dart`, `predial_ica_page_test.dart`, `presupuesto_publico_page_test.dart`, `salud_publica_page_test.dart`, `siif_service_test.dart` y dos casos de `widget_test.dart`. Los mensajes siguen siendo los fallos de esquema/fixtures/widgets sectoriales conocidos; no hay una falla nueva comercial.

### Verificacion global pendiente

El entorno sigue bloqueando los comandos globales. Omar debe correr al cierre
de la fase, en su maquina:

```text
flutter analyze
flutter build windows
```

La validacion de partida doble a nivel SQL sigue pendiente como trabajo
separado; la capa de dominio ya valida igualdad exacta en unidades menores.

**Fase 3A: 79/79 consumidores comerciales convertidos - COMPLETA.**

### Cierre de la subtarea Fase 3A tramo final

Estado: **Completo en el alcance comercial de la fase**. La suite dirigida
paso y la suite completa mantuvo exactamente las 17 fallas sectoriales/widget
conocidas. Queda pendiente solo la verificacion global manual de analyze/build
y el trabajo separado de garantia SQL de partida doble.

## Fase 3B - cierre del bloque presupuesto y contabilidad

### Alcance trabajado

Se incorporo `public_sector_money.dart` como borde explicito COP con escala
fija 2 para el sector publico. El bloque convertido queda compuesto por:

- Presupuesto: `apropiacion.dart`, `cdp.dart`, `rp.dart`, `obligacion.dart`,
  `pac.dart`, `pago.dart`, `pac_service.dart`, `presupuesto_service.dart`,
  `vigencias_futuras_service.dart`, `presupuesto_publico_page.dart` y
  `pac_tesoreria_page.dart`.
- Contabilidad: `asiento_contable.dart`, `cuenta_contable.dart`,
  `estado_financiero.dart`, `contabilidad_nicsp_service.dart`,
  `cierre_vigencia_service.dart`, `flujo_efectivo_service.dart`,
  `provisiones_service.dart`, `depreciacion_job_service.dart`,
  `consolidacion_jerarquica_service.dart`,
  `conciliacion_reciprocas_service.dart`,
  `contabilidad_nicsp_page.dart` y `conciliacion_reciproca_dialog.dart`.
- Integraciones que dependian de firmas cambiadas: `chip_reporter_service.dart`,
  `contratacion_service.dart` y `contratacion_publica_page.dart`.
- Pruebas ajustadas a INTEGER/MoneyValue: `catalogo_cgc_test.dart`,
  `conciliacion_reciprocas_integracion_test.dart`,
  `estado_financiero_nicsp1_integracion_test.dart`,
  `presupuesto_service_test.dart`, `presupuesto_pago_integracion_test.dart` y
  `vigencias_futuras_integracion_test.dart`.

Los porcentajes de configuracion de depreciacion y provision, y los valores
que salen como texto de UI/exportacion, permanecen en `double` solo en esos
bordes; las columnas monetarias y los calculos del dominio usan `MoneyValue`.

### Evidencia cruda del bloque

```text
dart format --output=none --set-exit-if-changed [archivos del bloque]
Changed ...
Formatted 13 files (12 changed) in 0.16 seconds.
Exit code: 1 (el comando reporta cambios de formato; el parser procesa los archivos)

dart analyze lib/sector_publico/contabilidad lib/sector_publico/presupuesto lib/core/currency/public_sector_money.dart
command timed out after 120329 milliseconds

dart analyze lib/core/currency/public_sector_money.dart
command timed out after 60337 milliseconds

dart test test/sector_publico/contabilidad/estado_financiero_nicsp1_integracion_test.dart test/sector_publico/contabilidad/conciliacion_reciprocas_integracion_test.dart test/sector_publico/contabilidad/catalogo_cgc_test.dart --reporter expanded
command timed out after 90314 milliseconds; no test output was produced
```

No se afirma que los tests pasaron: el bloqueo ocurre antes de que el runner
publique resultados. `flutter analyze` y `flutter build windows` siguen
pendientes para Omar, con los comandos exactos:

```text
flutter analyze
flutter build windows
```

### Decisiones y pendientes

- Se mantuvo COP fijo a 2 decimales para este dominio; no se usa la moneda de
  empresa del lado comercial.
- La validacion de partida doble SQL sigue fuera del alcance de este bloque;
  la capa NICSP valida igualdad exacta con `MoneyValue`.
- Este commit no cierra Fase 3B: quedan consumidores de activos, contratacion
  completa, nomina, planeacion, regalias, rentas, salud, SIIF/FUT/CHIP y
  transparencia por inventariar/convertir y probar.

### Cierre del bloque presupuesto y contabilidad

Commit publicado: `2531602` (`feat(dinero): convertir presupuesto y contabilidad
publicos a unidad menor`). Fase 3B permanece **en progreso**; no se declara
`X/X COMPLETA` hasta reconciliar y convertir los consumidores restantes del
inventario congelado.

## Fase 3B - cierre del bloque activos y FUT local

### Cambios

Se convirtieron a `MoneyValue` y SQLite INTEGER los modelos y servicios de
`activo_estado.dart`, `fondo_unidad_tesoreria.dart`, `activos_service.dart`,
`depreciacion_unidades_service.dart`, `fondo_unidad_tesoreria_service.dart` y
`revalorizacion_service.dart`, junto con `activos_estado_page.dart`. El job de
depreciacion por unidades y revalorizacion conserva porcentajes/volumenes como
parametros no monetarios, pero todos los valores de activos, fondos, asientos
y acumulados usan unidades menores exactas.

### Evidencia cruda

```text
dart format --output=none --set-exit-if-changed lib/sector_publico/activos test/sector_publico/contabilidad/depreciacion_job_service_test.dart
Formatted 11 files (11 changed) in 0.12 seconds.
Exit code: 1 (cambios de formato reportados; el parser proceso los archivos)

dart test test/sector_publico/contabilidad/depreciacion_job_service_test.dart --reporter expanded
Pendiente de ejecucion util: el runner dart test de esta sesion queda sin salida y vence por timeout antes de iniciar.
```

### Cierre de la subtarea activos y FUT

Commit publicado: `48fd8f7` (`feat(dinero): convertir activos y fondos publicos a
unidad menor`). Fase 3B sigue **en progreso**. Queda pendiente la verificacion
ejecutada del test NICSP 17 y la conversion de rentas, SGR/SGP, nomina,
contratacion completa, salud y reportes/transparencia.

## Fase 3B - cierre del bloque de rentas publicas

### Cambios

Se convirtieron a `MoneyValue` con COP fijo y escala 2 los consumidores de
rentas identificados en este bloque: `predio.dart`, `liquidacion_predial.dart`,
`acuerdo_pago.dart`, `proceso_cobro_coactivo.dart`, `predial_service.dart`,
`cobro_coactivo_service.dart`, `intereses_moratorios_service.dart` e
`ica_service.dart`. Las entradas de UI usan `publicMoneyFromMajor`; las
escrituras SQLite usan `toSql()` y los calculos de predial, mora, cobro,
retenciones, avisos y tableros se ejecutan en unidades menores. Se alineo
`schema_rentas.dart` para que las columnas monetarias nazcan como `INTEGER`;
tarifas, porcentajes, IPC y areas permanecen como magnitudes no monetarias.
Tambien se corrigieron los bordes de declaracion ICA, exportacion plana y
pantalla predial/ICA para no presentar centavos como pesos.

### Evidencia cruda

```text
dart format --output=none --set-exit-if-changed [13 archivos de rentas]
Formatted 13 files (0 changed) in 0.36 seconds.
Exit code: 0

flutter test test/sector_publico/rentas/proceso_cobro_coactivo_transiciones_test.dart --reporter expanded
This crash may already be reported.
PathExistsException: Cannot copy file to 'C:\Users\PC\Desktop\Caja_simple\build\native_assets\windows\sqlite3.dll'
path = 'C:\Users\PC\Desktop\Caja_simple\.dart_tool\hooks_runner\shared\sqlite3\build\download-94e63ca\sqlite3.dll'
OS Error: No se puede crear un archivo que ya existe, errno = 183
Stack relevante: _File.copy -> _copyNativeCodeAssetsToBundleOnWindowsLinux ->
_copyNativeCodeAssetsForOS -> installCodeAssets -> TestCommand.runCommand.
Exit code: 1; no asercion del test llego a ejecutarse.

flutter clean
Deleting build...
Deleting .dart_tool...
Failed to remove build/.dart_tool: un proceso puede estar usando esos artefactos.
Exit code: 0

flutter test test/sector_publico/rentas/proceso_cobro_coactivo_transiciones_test.dart --reporter expanded
Resolving dependencies...
Got dependencies!
This crash may already be reported.
PathExistsException: Cannot copy file to 'C:\Users\PC\Desktop\Caja_simple\build\native_assets\windows\sqlite3.dll'
path = 'C:\Users\PC\Desktop\Caja_simple\.dart_tool\hooks_runner\shared\sqlite3\build\download-7970568\sqlite3.dll'
OS Error: No se puede crear un archivo que ya existe, errno = 183
Stack relevante: _File.copy -> _copyNativeCodeAssetsToBundleOnWindowsLinux ->
_copyNativeCodeAssetsForOS -> installCodeAssets -> TestCommand.runCommand.
Exit code: 1; no asercion del test llego a ejecutarse.
```

No se afirma que los tests de rentas pasaron: Flutter falla durante la
preparacion de assets nativos de SQLite, antes de compilar/ejecutar las
aserciones. `flutter analyze` y `flutter build windows` siguen pendientes de
ejecucion por Omar en un entorno que no reproduzca este bloqueo, usando:

```text
flutter analyze
flutter build windows
flutter test test/sector_publico/rentas/exportacion_declaraciones_test.dart test/sector_publico/rentas/intereses_moratorios_service_test.dart test/sector_publico/rentas/proceso_cobro_coactivo_transiciones_test.dart --reporter expanded
```

### Bugs y decisiones

- Se elimino el calculo monetario con `double` de ICA, incluido el impuesto
  por avisos y los acumulados del tablero, evitando el riesgo de presentar o
  sumar centavos como pesos.
- Se mantuvo el fail-closed de `MoneyValue.fromSql`: solo acepta enteros en
  columnas migradas; no se agrego una conversion silenciosa de `REAL` legado.
- La validacion SQL de partida doble sigue fuera del alcance de este bloque.
- El submodulo `backend` conserva sus cambios locales preexistentes y no fue
  tocado.

### Cierre de la subtarea rentas

Commit publicado: `4264f4f` (`feat(dinero): convertir rentas publicas a unidad menor`).
El bloque de rentas queda convertido a nivel de codigo y esquema del modulo,
pero su evidencia de tests queda **pendiente de ejecucion** por el crash
reproducible de assets nativos. Fase 3B sigue en progreso; no se declara
`X/X COMPLETA` hasta convertir y verificar SGR/SGP, nomina publica,
contratacion, salud, planeacion, transparencia y reportes restantes.
