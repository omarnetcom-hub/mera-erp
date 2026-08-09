# Cierre de auditoría comercial - sesión 2026-08-09

Este log registra los seis bloques solicitados en orden. Cada bloque debe
tener su propio commit, evidencia cruda y sección literal de cierre antes de
iniciar el siguiente.

## Bloque 1 - UVT y ReteFuente

### Hallazgo y decisión

- El umbral de POS usaba `47062`, presentado como UVT 2024. Se sustituyó por
  una política central con UVT 2026 de COP 52.374, soportada por la Resolución
  DIAN 000238 de 2025.
- La política usa 2 UVT para servicios, 10 UVT para otros ingresos y ninguna
  base mínima para honorarios, conforme al cambio normativo de 2025 consultado
  en los conceptos DIAN 8536/2025 y 5224/2026. La semilla de
  `RTFTE_COMPRAS_25` quedó en 10 UVT expresadas en centavos; una base no nula
  configurada por una empresa no se sobrescribe durante la migración.
- POS selecciona tarifa por concepto y calidad del beneficiario. Compras
  conserva la captura manual existente, pero cada fila nueva registra
  concepto, base y tarifa aplicada cuando se conocen.
- F350 ya no reparte el total 40/30/20: lee las transacciones y acumula por
  `compras`, `servicios`, `honorarios`, `arrendamientos` u
  `otros_ingresos`. Las filas antiguas sin metadatos usan su subtotal como
  base de compatibilidad y no reciben una clasificación inventada.
- El requisito normativo completo permanece Parcial porque la captura manual
  de compras y la responsabilidad tributaria concreta de cada contribuyente
  todavía requieren configuración/validación especializada.

### Archivos

- `lib/taxes/retention_policy.dart`
- `lib/taxes/retention_schema_migration.dart`
- `lib/db_helper.dart` y `lib/core/database/database_initializer.dart`
- `lib/sales/application/create_sale_use_case.dart`
- `lib/purchases/application/create_purchase_use_case.dart`
- `lib/declaraciones_tributarias_page.dart`
- `test/commercial_tax_block1_test.dart`
- `docs/MATRIZ_TRAZABILIDAD_COMERCIAL.md`

### Evidencia cruda

Los archivos siguientes contienen la salida completa, sin resumir, de la
verificación final del bloque:

- `docs/evidencias/auditoria_comercial_bloque_1/block1_tests.txt`
- `docs/evidencias/auditoria_comercial_bloque_1/block1_analyze_final.txt`
- `docs/evidencias/auditoria_comercial_bloque_1/block1_build_final.txt`

El test dirigido terminó así:

```text
00:00 +0: loading C:/Users/PC/Desktop/Caja_simple/test/commercial_tax_block1_test.dart
00:00 +0: ... (setUpAll)
00:02 +0: ... usa UVT 2026 y bases legales por concepto sin pasar por double
00:02 +1: ... la semilla de compras usa 10 UVT sin pisar una base configurada
00:02 +2: ... F350 conserva concepto, base y tarifa de cada transacción
00:02 +3: ... POS aplica base de servicios de 2 UVT y tarifa configurable
00:02 +4: ... (tearDownAll)
00:02 +4: loading C:/Users/PC/Desktop/Caja_simple/test/sales_flow_test.dart
00:03 +4: ... (setUpAll)
00:06 +4: ... venta POS descuenta inventario, registra caja y asiento contable
00:06 +5: ... venta POS aplica ReteICA solo desde regla activa de ventas
00:06 +6: ... (tearDownAll)
00:06 +6: All tests passed!
```

Resultado crudo del comando de análisis: `241 issues found. (ran in 8.0s)`;
salida completa en `block1_analyze_final.txt`. No se introdujeron errores de
compilación en los archivos de este bloque.

Resultado crudo del build:

```text
Building Windows application...
flutter : Nuget.exe not found, trying to download or use cached version.
Building Windows application...                                    78.2s
√ Built build\windows\x64\runner\Release\MerkaERP.exe
```

### Cierre de la subtarea 1

Bloque 1 implementado y verificado. Tests dirigidos: 6 pasaron. Analyze:
241 issues, 0 errores de análisis. Build Windows: exitoso. La matriz fue
actualizada manteniendo ReteFuente en Parcial por la brecha explícita indicada.

Commit: `48e7554`.

## Bloque 2 - Inventario y costeo

### Hallazgo y decisión

- El enum `InventoryCostMethod` exponía `fifo`, `lifo` y `average`; LIFO fue
  retirado por no ser una política seleccionable del sistema. El ledger
  avanzado conserva FIFO para su superficie técnica, y el dominio operativo
  usa promedio ponderado.
- `productos.costo` es la fuente de verdad del costo promedio operativo.
  `lotes` se conserva para FEFO físico y vencimientos. `inventory_lots` queda
  como almacenamiento del ledger avanzado por bodega/branch, sin consumidor
  POS; no se usa para duplicar el saldo operativo.
- `kardex_inventario` se convirtió en el histórico canónico y se alimenta con
  `InventoryMovementService` junto con `movimientos_inventario`, dentro de la
  misma transacción. Se cubrieron compra, venta, anulaciones, ajustes,
  traslados y movimientos de bodega.
- El test de compra mediante `CreatePurchaseUseCase` no pudo usar el camino
  de crédito en una base fresca por una incompatibilidad anterior: la tabla
  `cuentas_por_pagar` no tiene `proveedor_id`/`compra_id`, aunque el caso de
  uso los inserta. El test del bloque siembra la compra con el esquema real y
  valida los escritores de Kardex; esta brecha queda anotada para un frente
  posterior, no se oculta como éxito de compra.

### Evidencia cruda

- `docs/evidencias/auditoria_comercial_bloque_2/block2_tests.txt`
- `docs/evidencias/auditoria_comercial_bloque_2/block2_analyze.txt`
- `docs/evidencias/auditoria_comercial_bloque_2/block2_build.txt`

Resumen crudo de la prueba: `16` pasaron, `All tests passed!`.
Analyze: `240 issues found`, sin errores; build Windows exitoso.

### Cierre de la subtarea 2

Bloque 2 implementado y verificado con 16 pruebas dirigidas y regresiones de
ventas/ledger. La lista de archivos temporales permanentes está en la carpeta
de evidencia indicada. Commit: `451156b`.

## Bloque 3 - F300 confiable

### Hallazgo y decisión

El detalle comercial no guardaba tarifa ni IVA por línea y el borrador
calculaba `baseGravada = ventas / 1.19`. Se agregó la migración v88 con
`impuesto_pct` e `impuesto_total` en `ventas_detalle` y `compras_detalle`.
F300 ahora agrupa bases e IVA generado por 0/5/19 y separa el IVA descontable
por origen de compra. Los encabezados sin detalle se usan solo como fallback
histórico, sin inferir una tarifa distinta.

### Evidencia cruda

- `docs/evidencias/auditoria_comercial_bloque_3/block3_tests_final.txt`
- `docs/evidencias/auditoria_comercial_bloque_3/block3_analyze_final.txt`
- `docs/evidencias/auditoria_comercial_bloque_3/block3_build_final.txt`

La salida de tests terminó en `00:21 +14: All tests passed!`. Analyze terminó
en `240 issues found` y build en `Built build\\windows\\x64\\runner\\Release\\MerkaERP.exe`.

### Cierre de la subtarea 3

Bloque 3 implementado y verificado con 14 pruebas. La regresión de la corrida
conjunta por teardown de fixtures fue corregida antes de esta evidencia final.
Commit: pendiente de crear en esta entrega.
