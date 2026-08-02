# Matriz de trazabilidad comercial

**Corte de auditoría:** 2026-08-01  
**Alcance:** código comercial de MerkaERP (`lib/` y pruebas comerciales en `test/`). Se excluye la implementación del sector público.  
**Propósito:** relacionar requisito normativo/funcional, código, prueba ejecutada, evidencia y estado real. Este documento no certifica cumplimiento legal; identifica qué está respaldado por código y pruebas y qué requiere corrección o validación especializada.

## Criterio de estados

- **Completo:** implementación y prueba ejecutada cubren específicamente el requisito.
- **Parcial:** existe implementación, pero falta cobertura, integración o exactitud normativa.
- **Pendiente:** no existe una implementación utilizable o la existente no cumple el requisito esencial.
- **No verificable sin más contexto:** faltan datos de configuración, clasificación del contribuyente o una decisión contable/tributaria para evaluar el requisito.

## Resumen ejecutivo

1. No existe una política monetaria central: dinero, cantidades, impuestos y saldos usan `double` en Dart y `REAL` en SQLite. Un probe reprodujo `10000 x 99.99 = 999899.99999992212` y una diferencia de COP 0,01 entre redondeo de IVA por línea y por documento.
2. El flujo POS tiene una regresión tributaria reproducible: una venta de COP 5.000 devuelve COP 4.979,30 por una ReteICA automática de 0,414 %, pese a que la regla empresarial configurada no participa en ese cálculo.
3. Los borradores F300/F350 no son confiables: F300 supone que toda venta incluye IVA 19 % y F350 distribuye retenciones con porcentajes arbitrarios 40/30/20. Además, el reporte fiscal consulta `nomina_liquidaciones.neto`, pero el esquema real crea `neto_pagar`.
4. La facturación electrónica es local/simulada. El cliente activo es `NoOp`; el supuesto CUFE es Base64 más un sufijo, no SHA-384 conforme al anexo técnico DIAN vigente; no hay CUDE.
5. La partida doble se valida en servicios, pero no en SQLite. Un probe insertó por SQL directo un asiento con débito 100 y crédito 0.
6. Inventarios mezclan promedio ponderado, FEFO y un stock ledger separado que incluso expone LIFO. El flujo POS no consume ese ledger y `kardex_inventario` no tiene escritores activos.
7. Nómina privada contiene tarifas base razonables, pero calcula IBC sobre salario básico, ignora exoneraciones, provisiona mal intereses de cesantías, no tiene configuración operativa visible ni pruebas comerciales.

## Evidencia ejecutada de esta auditoría

| ID | Comando / prueba | Resultado |
|---|---|---|
| EV-01 | Probe Dart temporal de precisión IEEE-754 | `0.1 + 0.2 = 0.30000000000000004`; `10000 x 99.99 = 999899.99999992212`; IVA de tres líneas de 100,01: 57,00 redondeando por línea frente a 57,01 redondeando al final. El probe fue eliminado después de ejecutarse. |
| EV-02 | `flutter test test/accounting_rules_test.dart test/accounting_report_test.dart test/architectural_consolidation_test.dart test/core/invoicing/cufe_test.dart test/core/invoicing/crear_factura_integration_test.dart test/core/invoicing/dian_transmission_client_noop_test.dart test/enterprise_services_test.dart test/purchase_repository_test.dart test/sales_repository_test.dart` | **27 pruebas pasaron** (`All tests passed!`). |
| EV-03 | `flutter test test/sales_flow_test.dart` | **Falló**: esperaba `5000`, obtuvo `4979.3` en `test/sales_flow_test.dart:68`. |
| EV-04 | `flutter test test/commercial_security_test.dart` | **5 pasaron, 1 falló**. La sexta reutiliza la misma base `:memory:` y falla al crear de nuevo `app_config`; no certifica el escenario fail-closed que declara. |
| EV-05 | Probe Flutter/SQLite temporal sobre esquema de instalación nueva | **2 pruebas pasaron**. Confirmó que `nomina_liquidaciones` contiene `neto_pagar` y no `neto`, que `obtenerReporteFiscal()` lanza `DatabaseException`, y que SQL directo persiste un asiento con `debito=100.0, credito=0.0`. El probe fue eliminado. |

## 1. Matemática financiera y precisión numérica

| Requisito / criterio | Norma o referencia | Archivo(s) que lo implementan | Test que lo cubre | Evidencia | Estado |
|---|---|---|---|---|---|
| Representar dinero sin error binario acumulativo y con una escala explícita. | Criterio de integridad financiera; el anexo técnico de facturación exige reglas explícitas de precisión y redondeo [N6]. | `sales/domain/sales_document.dart`; `purchases/domain/purchase_document.dart`; `accounting/domain/journal_entry.dart`; `inventory/domain/stock_ledger.dart`; `db_helper.dart` (`REAL` en importes). | Ninguna prueba fija una política monetaria global. | Inspección: uso transversal de `double`/`REAL`, sin `Decimal`, fixed-point ni enteros en centavos. EV-01 cuantifica el error. | **Parcial:** los cálculos funcionan para casos simples, pero no existe representación exacta ni normalización al persistir. |
| Aplicar una única política de redondeo a subtotal, IVA, retenciones, costos y total del documento. | Anexo técnico DIAN: reglas de redondeo y campos de ajuste [N6]. | `create_sale_use_case.dart`; `create_purchase_use_case.dart`; `sales_document.dart`; `purchase_document.dart`; `cufe.dart`. | `cufe_test.dart` solo verifica `toStringAsFixed(2)` dentro del identificador local. | EV-01 muestra diferencia de COP 0,01 según el punto de redondeo. No se encontraron `round`, `floor` o normalización monetaria en los cálculos transaccionales. | **Pendiente:** no hay regla común por línea/documento ni persistencia normalizada. |
| Evitar tolerancias que acepten asientos materialmente distintos por acumulación. | Partida doble e integridad contable; la materialidad no sustituye igualdad aritmética en el registro. | `JournalEntry.balanced`, `TrialBalance.balanced`, `DatabaseHelper.registrarAsientoContable()` usan tolerancia de COP 0,01. | `architectural_consolidation_test.dart`; `accounting_report_test.dart`. | EV-02 pasa casos exactos; no prueba acumulaciones masivas ni límites de la tolerancia. | **Parcial:** hay control de tolerancia en servicios, pero depende de `double` y no existe control SQL. |

**Resumen D1:** 0 Completos / 2 Parciales / 1 Pendiente.

## 2. Impuestos y normativa DIAN

| Requisito / criterio | Norma o referencia | Archivo(s) que lo implementan | Test que lo cubre | Evidencia | Estado |
|---|---|---|---|---|---|
| Manejar IVA 0 %, 5 % y 19 % según clasificación real del bien/servicio. | ET arts. 468 y 468-1; reglas de bienes excluidos/exentos y descontables [N1][N2]. | `catalog/domain/master_catalog.dart:57-62`; `db_helper.dart:3908-3943`; campos `productos.impuesto_pct` y líneas de venta/compra. | No hay prueba de clasificación tributaria por producto. | Inspección: existen 0/5/19, pero `EXEMPT` mezcla exento, excluido y no gravado; también aparece `IVA_8` sin semántica separada de INC. La tarifa es selección/manual, no deriva de clasificación fiscal. | **Parcial:** catálogo básico presente, clasificación normativa ausente. |
| Separar IVA generado en ventas e IVA descontable procedente en compras y producir F300 por tarifa/periodicidad. | ET arts. 485 y 488; formulario y periodicidad dependen de la responsabilidad tributaria [N1][N2]. | `AccountingEngine.sale/purchase`; `DatabaseHelper.obtenerReporteFiscal()`; `obtenerBorradorFormulario300()`. | `commercial_security_test.dart` solo prueba aislamiento con un esquema artificial; no prueba F300 ni procedencia del descuento. | `obtenerReporteFiscal()` suma todo IVA de compras como descontable. F300 calcula `baseGravada = ventas / 1.19`, por lo que falla con tarifas mixtas, ventas excluidas o valores sin IVA incluido. EV-05 confirma que el reporte falla en una instalación nueva por `neto` vs. `neto_pagar`. | **Parcial:** separación contable nominal, borrador fiscal no confiable. |
| Aplicar ReteFuente por concepto, calidad del beneficiario, base mínima y UVT vigentes. | DUR 1625/2016 arts. 1.2.4.9.1, 1.2.4.4.14 y reglas de honorarios/servicios; UVT 2026 COP 52.374 [N3][N4][N5]. | `db_helper.dart:2078-2098`, `2330-2343`, `3946-3974`; `create_sale_use_case.dart:120-165`; `compras_page.dart`; `ventas_page.dart`. | Ninguna prueba normativa por concepto/base. | Código usa `1090 * 47062` como umbral y comenta “UVT 2024”; la UVT vigente es 52.374. Las reglas semilla tienen `base_minima=0`; compras reciben retenciones manuales. F350 reparte el total 40 % servicios, 30 % honorarios y 20 % arrendamientos sin datos fuente. | **Parcial:** tarifas nominales 2,5/3,5/4/6/10/11 existen, pero bases, vigencia, concepto y reporte están desalineados. |
| Calcular ReteICA desde reglas por empresa/municipio, no desde una tarifa global. | Ley 14/1983: tarifa determinada territorialmente por concejos dentro del marco legal [N7]. | `reglas_retenciones_empresa`; `create_sale_use_case.dart:129,164-165`; `obtenerBorradorICA()`. | `sales_flow_test.dart`; primera prueba de `commercial_security_test.dart`. | EV-03 falla: venta de 5.000 resulta 4.979,30 por 0,414 % automático. `CreateSaleUseCase` lee `tax_parameters.reteica_base_rate`, no `reglas_retenciones_empresa`; el catálogo semilla empresarial usa 0,966 %. | **Parcial:** **regresión confirmada**; la regla empresarial no gobierna el flujo POS. |
| Transmitir factura UBL 2.1 a DIAN/PTA con autenticación, validación previa y respuesta persistida. | Resolución DIAN 000165/2023, anexo 1.9, modificada por resoluciones posteriores listadas por DIAN [N6]. | `dian_transmission_client.dart`; `dian_transmission_client_noop.dart`; `dian_transmission_client_registry.dart`; `facturacion_electronica_page.dart`. | `dian_transmission_client_noop_test.dart`. | EV-02 confirma únicamente estados de configuración del NoOp. El registro global instancia `NoOpDianTransmissionClient`; `transmitInvoice()` devuelve `simulated` y no hace red. | **Pendiente:** no existe cliente DIAN/PTA real. |
| Generar CUFE/CUDE conforme al algoritmo y campos del anexo técnico vigente. | Resolución 000165/2023 v1.9 y procedimiento CUFE; DIAN confirma SHA-384 [N6][N8]. | `core/invoicing/cufe.dart`; `core/invoicing/xml/generator.dart`. | `cufe_test.dart`; `crear_factura_integration_test.dart`. | EV-02 pasa consistencia interna, no conformidad DIAN. `computeCufe()` aplica Base64 a `Venta|Total|Fecha|PIN` y añade `fe2026dian`; no usa SHA-384 ni la cadena normativa. No se encontró generador CUDE. XML es “UBL-like” mínimo y omite bloques fiscales obligatorios. | **Pendiente:** identificador y documento no son certificables ante DIAN. |
| Manejar Impuesto Nacional al Consumo sin confundirlo con IVA. | ET arts. 512-1, 512-2 y 512-9: restaurantes 8 %, telefonía/datos 4 %, con reglas de base y responsables [N9][N10]. | `tax_parameters.inc_restaurant_rate/inc_telecom_rate`; `MasterCatalog.IVA_8`. | Sin pruebas. | Las tasas existen solo como parámetros; no se consumen en ventas, contabilidad, XML ni formulario 310. `IVA_8` se trata como impuesto genérico, no como INC. | **Parcial:** metadatos presentes, flujo tributario ausente. |

**Resumen D2:** 0 Completos / 5 Parciales / 2 Pendientes.

## 3. Lógica contable comercial

| Requisito / criterio | Norma o referencia | Archivo(s) que lo implementan | Test que lo cubre | Evidencia | Estado |
|---|---|---|---|---|---|
| Seleccionar y aplicar coherentemente Grupo 1 (NIIF plenas), Grupo 2 (NIIF para PYMES) o Grupo 3. | Decreto 2420/2015 y anexos 1, 2 y 3 [N11][N12][N13]. | Catálogo genérico `MasterCatalog.niifAccounts`; PUC semilla en `db_helper.dart`. | Sin prueba de clasificación o política NIIF. | No se encontró campo de grupo NIIF, política por empresa, revelaciones ni reglas diferenciadas. El texto UI “NIIF” no determina marco técnico. | **Pendiente:** no puede afirmarse Grupo 2 ni NIIF plena. |
| Garantizar partida doble en todos los caminos de escritura. | Principio de doble partida e integridad del libro. | `JournalEntry.post()`; `DatabaseHelper.registrarAsientoContable()`; `_registrarAsientoConCodigos()`. | `architectural_consolidation_test.dart`; `accounting_report_test.dart`. | EV-02 pasa controles de servicio. EV-05 demuestra que SQL directo persiste débito 100/crédito 0; no hay trigger/constraint SQL que valide el conjunto del asiento. | **Parcial:** control de aplicación, sin garantía de base de datos. |
| Cerrar periodos por empresa e impedir contabilización posterior. | Control contable de corte y trazabilidad; marco NIIF aplicable [N11][N12]. | `_crearTablasPeriodos()`; `cerrarPeriodoContable()`; `_validarPeriodoAbierto()`; `periodos_contables_page.dart`. | Sin prueba comercial de cierre. | Existe bloqueo mensual por fecha, pero la tabla conserva `UNIQUE(anio, mes)` global y no declara `company_id`; métodos posteriores intentan consultar `company_id`. No hay cierre anual de resultados. | **Parcial:** cierre mensual básico con defecto multiempresa y sin evidencia ejecutada. |
| Cerrar el ejercicio y trasladar ingresos/gastos a resultado y ganancias acumuladas. | Presentación de resultados y patrimonio bajo el marco seleccionado [N11][N12]. | Cuenta semilla `36 Resultados del Ejercicio`; `obtenerEstadosFinancieros()` solo calcula utilidad en lectura. | Sin prueba. | No se encontró asiento de cierre comercial ni traslado a utilidades/pérdidas acumuladas. | **Pendiente.** |
| Presentar saldos de naturaleza acreedora con signo correcto y cuadrar Activo = Pasivo + Patrimonio + resultado. | Decreto 2420, estado de situación financiera y estado de resultados [N11][N12]. | `accounting_report_repository.dart`; `db_helper.dart:8071-8097`; `obtenerEstadosFinancieros():7198-7244`; `estados_financieros_page.dart`. | `accounting_report_test.dart` prueba saldo por naturaleza y balance simple; no prueba estados completos. | La consulta invierte correctamente crédito-débito para naturaleza acreedora y `cuadre` incorpora utilidad. No se reprodujo el bug de signo de NICSP 1, pero falta prueba integrada con clases 1-6 y cierre. | **Parcial:** lógica inspeccionada coherente, cobertura insuficiente. |

**Resumen D3:** 0 Completos / 3 Parciales / 2 Pendientes.

## 4. Inventario y costeo

| Requisito / criterio | Norma o referencia | Archivo(s) que lo implementan | Test que lo cubre | Evidencia | Estado |
|---|---|---|---|---|---|
| Usar una fórmula permitida y consistente: FIFO/PEPS o promedio ponderado; no LIFO/UEPS. | NIIF para PYMES 13.18 y NIC 2.25; LIFO no permitido [N12][N14]. | `create_purchase_use_case.dart:172-205` usa promedio ponderado; `create_sale_use_case.dart:300-367` usa costo recibido y FEFO físico; `stock_ledger.dart` expone `fifo`, `lifo`, `average`. | `enterprise_services_test.dart` prueba promedio; `architectural_consolidation_test.dart` prueba FIFO aislado. | EV-02 pasa ambos cálculos aislados. El ledger avanzado no tiene consumidor productivo; LIFO existe como opción de dominio aunque hoy solo FIFO aparece en test. No hay política única por empresa/producto. | **Parcial:** caminos válidos existen, pero están duplicados/desconectados y LIFO debe eliminarse o bloquearse. |
| Mantener Kardex completo para compra, venta, anulación, ajuste y traslado. | Sistema permanente y trazabilidad de inventarios [N12][N13]. | `movimientos_inventario` en venta, compra, anulaciones y traslado; tabla `kardex_inventario`; `StockLedgerService`. | `sales_flow_test.dart` pretende cubrir venta; pruebas puras de ledger/promedio. | EV-03 falla antes de completar sus aserciones por la ReteICA. `kardex_inventario` solo aparece en esquema/backup, sin escritor activo. Los lotes `inventory_lots`, `lotes` y el stock de `productos` forman tres representaciones no reconciliadas. | **Parcial:** hay movimientos operativos, no un Kardex único certificado. |
| Valorar inventario del balance con la misma fórmula de costo y reconocer deterioro/valor neto realizable. | NIIF PYMES 13.18-13.19; NIC 2 [N12][N14]. | `InventoryControlService.analyze()` y `FinancialConsolidationService` calculan `stock * costo`; compra actualiza `productos.costo` por promedio. | `enterprise_services_test.dart` solo prueba un promedio exacto. | Coherente únicamente para el camino principal de promedio ponderado. No concilia lotes FIFO/FEFO, no hay prueba balance-vs-Kardex y no se encontró deterioro a valor neto realizable. | **Parcial.** |

**Resumen D4:** 0 Completos / 3 Parciales / 0 Pendientes.

## 5. Multiempresa y multisucursal

| Requisito / criterio | Norma o referencia | Archivo(s) que lo implementan | Test que lo cubre | Evidencia | Estado |
|---|---|---|---|---|---|
| Aislar operaciones y reportes por empresa/sucursal. | Integridad de tenant y estados separados; Decreto 2420 según marco de cada entidad [N11]. | `CompanyContextService`; repositorios de venta/compra; `BranchContextService`; múltiples filtros `company_id`. | `sales_repository_test.dart`, `purchase_repository_test.dart`, `accounting_report_test.dart`; partes 1-5 de `commercial_security_test.dart`. | EV-02 pasa repositorios por empresa. EV-04 deja un escenario fail-closed sin certificar. Hay brechas: `periodos_contables` global y métodos legacy sin filtro consistente. | **Parcial.** |
| Consolidar empresas con alcance contable, eliminaciones y periodo coherente. | Estados consolidados bajo el marco NIIF aplicable [N11][N12]. | `core/multi_company/financial_consolidation.dart`. | Sin pruebas ni consumidor UI. | Suma ventas, gastos, inventario, CxC y CxP por IDs; no consolida asientos, no elimina operaciones intercompañía, no aplica moneda ni políticas homogéneas. `rg` no encontró consumidores fuera del propio archivo. | **Parcial:** servicio huérfano y agregación gerencial, no consolidación NIIF. Conectarlo bien es esfuerzo **grande**: modelo de grupo/participación, eliminaciones, periodos, moneda, pruebas y UI. |
| Ejecutar transferencias interempresa de forma autorizada, atómica y contablemente simétrica. | Segregación, integridad de inventario/caja y trazabilidad. | `core/multi_company/transfer_service.dart`. | Sin pruebas ni consumidor UI. | No exige estado aprobado antes de completar, no usa transacción, puede dejar stock negativo y `products` llama la transferencia completa dentro de cada iteración. No genera asientos contables. | **Pendiente para uso real:** código huérfano con riesgos. Cablear solo UI sería pequeño, pero hacerlo operable es esfuerzo **medio/grande** por transacción, RBAC, mapeo de productos y contabilidad bilateral. |

**Resumen D5:** 0 Completos / 2 Parciales / 1 Pendiente.

## 6. Nómina comercial privada

| Requisito / criterio | Norma o referencia | Archivo(s) que lo implementan | Test que lo cubre | Evidencia | Estado |
|---|---|---|---|---|---|
| Configurar parámetros anuales y determinar IBC salarial correctamente. | Salud sobre IBC: Ley 1122/2007 art. 10; pensión 16 %; auxilio de transporte no integra IBC [N15][N16][N17]. | `payroll_parameters`; `DatabaseHelper.liquidarNomina()`. | No hay pruebas de nómina comercial; las pruebas bajo `test/sector_publico/nomina/` no aplican. | No se encontró semilla ni UI para crear `payroll_parameters`. Salud/pensión se calculan solo sobre `salario`, mientras horas extra y bonificaciones solo entran en FSP/devengado; no existe clasificación salarial/no salarial de novedades. | **Parcial:** estructura presente, IBC conceptualmente incompleto y configuración no operativa. |
| Calcular salud 4 % trabajador/8,5 % empleador y pensión 4 %/12 %, respetando exoneraciones. | Ley 1122/2007; Ley 100/1993; ET art. 114-1 [N15][N16][N18]. | Defaults de `payroll_parameters`; `liquidarNomina():6224-6250`. | Sin pruebas. | Las tarifas default coinciden con la regla general, pero `health_exonerated` nunca se lee y la base excluye pagos salariales variables. | **Parcial.** |
| Calcular ARL según clase y sobre IBC correcto. | Decreto 1072/2015: tasas iniciales I-V 0,522 %, 1,044 %, 2,436 %, 4,350 %, 6,960 % [N19]. | Defaults `arl_level_1_rate` a `arl_level_5_rate`; switch en `liquidarNomina():6252-6270`. | Sin pruebas comerciales. | Las tasas default coinciden, pero se aplican solo al salario básico, no al IBC completo; no hay validación de actividad económica/clase asignada. | **Parcial.** |
| Calcular cesantías, prima, intereses y vacaciones sobre bases y tiempo causado correctos. | CST arts. 186, 249 y 306; intereses 12 % anual sobre cesantías [N20][N21]. | `liquidarNomina():6277-6281`; parámetros 8,33 %, 8,33 %, 1 % y 4,17 %. | Sin pruebas. | Cesantías y prima usan solo salario y omiten auxilio de transporte/variables cuando corresponda; no consideran días. `interesesCesantias = cesantias * 0.01` aplica 1 % a la provisión de cesantías, no 12 % anual sobre el saldo, quedando aproximadamente 12 veces por debajo de la provisión mensual usual. | **Parcial:** error material identificado. |
| Calcular parafiscales 2 % SENA, 3 % ICBF y 4 % caja con exoneración aplicable. | Reglas 2/3/4 y ET art. 114-1 [N18][N22]. | Defaults y `liquidarNomina():6272-6275`. | Sin pruebas. | Tasas default correctas, pero se aplican siempre. No se usa `health_exonerated`, no hay bandera de contribuyente ni regla de menos de 10 SMMLV; tampoco base salarial configurable. | **Parcial.** |
| Obtener neto correcto, aplicar retención laboral y ejecutar liquidación de forma atómica. | Reglas laborales/tributarias y trazabilidad transaccional. | `liquidarNomina():6290-6441`. | Sin pruebas. | `retefuente=0` está explícitamente pendiente. El movimiento de caja, asiento y liquidación se hacen fuera de una única transacción; un fallo puede dejar operación parcial. El asiento registra devengos/deducciones del trabajador, no todas las cargas/provisiones del empleador. | **Pendiente para certificación.** |
| Integrar nómina con reportes fiscales sin romper el esquema real. | Integridad de declaraciones e información contable. | `obtenerReporteFiscal():6641-6643`; esquema `nomina_liquidaciones`. | `commercial_security_test.dart` usa un esquema de prueba distinto (`neto`). | EV-05 confirma: producción crea `neto_pagar`, la consulta usa `SUM(neto)` y lanza `DatabaseException` en instalación nueva. | **Pendiente:** bug de esquema bloqueante. |

**Resumen D6:** 0 Completos / 5 Parciales / 2 Pendientes.

## Resumen por dominio

| Dominio | Completos | Parciales | Pendientes | Diagnóstico |
|---|---:|---:|---:|---|
| 1. Precisión numérica | 0 | 2 | 1 | Sin tipo monetario ni política de redondeo. |
| 2. Impuestos y DIAN | 0 | 5 | 2 | Catálogos parciales; ReteICA regresionada; F300/F350 y DIAN no certificables. |
| 3. Contabilidad | 0 | 3 | 2 | Servicios validan, pero DB/cierre/marco NIIF incompletos. |
| 4. Inventario | 0 | 3 | 0 | Tres representaciones y métodos desconectados; no hay Kardex único. |
| 5. Multiempresa | 0 | 2 | 1 | Aislamiento parcial; consolidación y transferencias huérfanas. |
| 6. Nómina privada | 0 | 5 | 2 | Tarifas nominales, bases/provisiones/transacción/reportes incorrectos o sin prueba. |
| **Total** | **0** | **20** | **8** | **Ningún dominio comercial queda certificado completo con la evidencia actual.** |

## Brechas críticas priorizadas

1. **Detener cálculos tributarios automáticos incorrectos:** ReteICA POS, umbral ReteFuente, F300/F350 y error `neto`/`neto_pagar`. Son cifras fiscales y de caja visibles al cliente.
2. **Definir y migrar una política monetaria exacta:** fixed-point/enteros por unidad mínima o biblioteca decimal, escalas por moneda y redondeo DIAN centralizado.
3. **Reemplazar CUFE/XML local y NoOp por un flujo DIAN/PTA certificable:** anexo técnico 1.9 vigente, SHA-384, UBL completo, firma, CUDE, transmisión y respuestas.
4. **Corregir y probar nómina privada:** IBC de novedades, exoneración, prestaciones, retención laboral, asientos patronales y transacción atómica.
5. **Blindar partida doble en persistencia:** impedir por diseño que SQL directo deje asientos incompletos/desbalanceados; definir estrategia compatible con inserción transaccional por cabecera/líneas.
6. **Unificar inventario/Kardex y costeo:** retirar LIFO, elegir política por naturaleza de inventario, conectar POS al ledger y reconciliar lotes/stock/costo/contabilidad.
7. **Implementar cierre contable por empresa y ejercicio:** esquema tenant-correcto, asiento de cierre, resultado y acumulados con pruebas.
8. **Decidir multiempresa:** mantener consolidación/transferencias como backlog o convertirlas en flujos contables seguros antes de exponer UI.

## Fuentes normativas y técnicas

- **[N1]** [Ley 1819 de 2016, modificación del ET art. 468: IVA general 19 %](https://normograma.dian.gov.co/dian/compilacion/docs/ley_1819_2016.htm).
- **[N2]** [Estatuto Tributario compilado, arts. 485 y 488 sobre impuestos descontables](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=6533).
- **[N3]** [DIAN, Concepto 6251 de 2024: retención por otros ingresos, art. 1.2.4.9.1 DUR 1625](https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_6251_2024.htm).
- **[N4]** [DIAN, Concepto 6491 de 2025: servicios 4 %/6 % y base en UVT](https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_6491_2025.htm).
- **[N5]** [DIAN, Resolución 000238 de 2025: UVT 2026 = COP 52.374](https://normograma.dian.gov.co/dian/compilacion/docs/resolucion_dian_0238_2025.htm).
- **[N6]** [DIAN, Resolución 000165 de 2023 y Anexo Técnico FEV 1.9](https://normograma.dian.gov.co/dian/compilacion/docs/resolucion_dian_0165_2023.htm); [micrositio técnico vigente](https://micrositios.dian.gov.co/sistema-de-facturacion-electronica/documentacion-tecnica/).
- **[N7]** [Ley 14 de 1983, ICA y tarifas territoriales](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=267).
- **[N8]** [DIAN, Oficio 901212 de 2022: CUFE mediante SHA-384](https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_901212_2022.htm).
- **[N9]** [DIAN, ET art. 512-9: INC restaurantes 8 %](https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_902460_2022.htm).
- **[N10]** [DIAN, ET arts. 512-1/512-2: INC telefonía, datos e internet móvil 4 %](https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_8274_2019.htm).
- **[N11]** [Decreto 2420 de 2015, marcos técnicos de los grupos contables](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76745).
- **[N12]** [Decreto 2420 de 2015, Anexo 2: NIIF para PYMES](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=74535).
- **[N13]** [Decreto 2420 de 2015, Anexo 3: marco para microempresas](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76055).
- **[N14]** [Decreto 2420 de 2015, Anexo 1: NIC 2, FIFO/promedio ponderado](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76054).
- **[N15]** [Ley 1122 de 2007 art. 10: salud 12,5 %, distribución 8,5 %/4 %](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=22600).
- **[N16]** [Función Pública, Concepto 164481 de 2024: salud 12,5 % y pensión 16 %](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=259976).
- **[N17]** [Consejo de Estado, Sentencia 90064 de 2016: auxilio de transporte fuera de bases de aportes](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=71191).
- **[N18]** [Estatuto Tributario art. 114-1: exoneración de salud, SENA e ICBF](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=6533).
- **[N19]** [Decreto 1072 de 2015: tasas iniciales ARL por clase](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=72173).
- **[N20]** [Código Sustantivo del Trabajo: vacaciones, cesantías y prima de servicios](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=199983).
- **[N21]** [Decreto 116 de 1976: intereses de cesantías del 12 % anual](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=3285).
- **[N22]** [Ley 1233 de 2008: distribución parafiscal 3 % ICBF, 2 % SENA y 4 % caja](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=31586).

## Regla de mantenimiento

Al corregir una brecha, agregar el test específico y su comando a “Evidencia ejecutada”, actualizar únicamente las filas que ese test cubra y subir a **Completo** solo cuando la prueba reproduzca el requisito normativo/funcional completo. Una prueba de estructura, aislamiento o ausencia de excepción no sustituye una prueba de exactitud de cifras.
