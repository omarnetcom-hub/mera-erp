# Matriz de Trazabilidad - Sector Publico

## Control del documento

- Fuente normativa: `MerkaERP_SectorPublico_Plan_v1.1.md`.
- Alcance: los 11 macro-sistemas del plan v1.1.
- Criterio de evidencia: **ejecutado** significa que el comando se corrio y termino bien en esta sesion; **inspeccion** significa que se verifico la existencia del codigo o del test, sin volver a ejecutarlo para este documento.
- Actualizacion: al cerrar una funcionalidad, actualizar la fila afectada, el conteo del macro-sistema y la tabla resumen. No promover a **Completo** sin enlazar una prueba ejecutada.

Estados permitidos: **Completo**, **Parcial**, **Pendiente**, **No verificable sin mas contexto**.

## 1. Planeacion y Proyectos

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| PDT cuatrienal con ejes, programas, metas e indicadores | `lib/sector_publico/planeacion/database/schema_planeacion.dart`; `models/pdt.dart`; `services/pdt_service.dart` | `test/sector_publico/planeacion/planeacion_page_test.dart` (inspeccion) | Inspeccion: existen esquema, servicio y pagina. | Parcial - no se certifico importacion Excel/XML ni ejecucion de la prueba. |
| Seguimiento fisico con alertas de cumplimiento | `services/pdt_service.dart`; `pages/planeacion_page.dart` | `planeacion_page_test.dart` (inspeccion) | Inspeccion de codigo. | Parcial - no hay evidencia ejecutada de semaforo por periodo. |
| Seguimiento financiero vinculado a apropiaciones | `services/pdt_service.dart`; `services/presupuesto_service.dart` | No se identifico test de integracion PDT-presupuesto | Inspeccion: ambos servicios existen. | Parcial - falta el cruce automatico y prueba de integracion. |
| Reporte SISMEG | No se identifico implementacion dedicada | Ninguno identificado | Inspeccion de archivos de planeacion. | Pendiente - el plan exige formato SISMEG y no hay generador identificado. |
| Banco de proyectos MGA: BPIN, problema, objetivos, cadena de valor y presupuesto | `models/proyecto_mga.dart`; `services/banco_proyectos_service.dart`; `services/formulacion_mga_service.dart`; `pages/formulacion_mga_form_page.dart` | `planeacion_page_test.dart` (inspeccion) | Inspeccion de codigo. | Parcial - no se certificaron todos los campos MGA obligatorios. |
| Trazabilidad plan-presupuesto-resultado y alerta >20% | `planeacion/database/schema_planeacion.dart`; `services/banco_proyectos_service.dart`; `presupuesto/database/schema_presupuesto.dart` | `test/sector_publico/planeacion/planeacion_page_test.dart` | Ejecutado: `flutter test test\\sector_publico\\planeacion\\planeacion_page_test.dart` - 1 prueba pasa y confirma el banner pendiente. Inspeccion: `proyectos_mga` solo conserva `codigo_cdp`/`codigo_rp` libres y valores financieros; `apropiaciones` no tiene `proyecto_id`, y no existe una meta/avance fisico persistido. | Pendiente - no es posible calcular una desviacion financiera/fisica ni vincular cada rubro a una meta PDT sin un diseno de datos nuevo. |

Resumen M1: 0 Completos / 4 Parciales / 2 Pendientes.

## 2. Sistema Financiero Integrado

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Flujo apropiacion -> CDP -> RP -> obligacion -> pago | `presupuesto/database/schema_presupuesto.dart`; `services/presupuesto_service.dart`; `services/pac_service.dart`; `contabilidad/services/contabilidad_nicsp_service.dart` | `test/sector_publico/presupuesto/presupuesto_pago_integracion_test.dart` | Ejecutado: `flutter test test\\sector_publico\\presupuesto\\presupuesto_pago_integracion_test.dart` - 2 pruebas pasaron; cubre cadena completa, aprobacion, ejecucion, cascada, PAC y asiento NICSP de pago. | Completo - evidencia de integracion ejecutada para el flujo presupuestal y de pago. |
| CDP bloqueado sin disponibilidad | `services/presupuesto_service.dart` | `presupuesto_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - no se ejecuto en esta auditoria. |
| RP exige contrato y afecta CDP | `services/presupuesto_service.dart`; `models/rp.dart` | `presupuesto_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta prueba ejecutada de contrato y saldo CDP. |
| Obligacion exige soporte valido y pago exige cupo PAC | `services/presupuesto_service.dart`; `services/pac_service.dart`; `pages/pac_tesoreria_page.dart` | `test/sector_publico/presupuesto/presupuesto_pago_integracion_test.dart` | Ejecutado: el test bloquea un pago que excede el PAC y valida el descuento tras el pago; la obligacion del flujo usa factura valida. | Parcial - falta prueba negativa ejecutada para obligacion sin acta ni factura. |
| PAC mensual, control en tiempo real y modificaciones | `models/pac.dart`; `services/pac_service.dart`; `pages/pac_tesoreria_page.dart` | `test/sector_publico/presupuesto/presupuesto_pago_integracion_test.dart` | Ejecutado: el test verifica cupo aprobado mensual, bloqueo por exceso y descuento del cupo al ejecutar el pago. | Parcial - faltan pruebas de modificacion con acto administrativo, embargos y estampillas. |
| Cierre de vigencia y vigencias futuras | `contabilidad/services/cierre_vigencia_service.dart`; `presupuesto_service.dart` | Ninguno identificado | Inspeccion ejecutada y diseno normativo en `VIGENCIAS_FUTURAS_HALLAZGOS_Y_DISENO.md`: `_calcularReservas` no consulta `obligaciones`; no existe implementacion de vigencias futuras, CONFIS o MFMP. | Parcial - diseno normativo documentado; falta validar estatuto territorial/autoridad de cada entidad y construir el dominio de autorizaciones, distribucion y recibidos excepcionales. |
| NICSP 1: estados financieros | `contabilidad/services/cierre_vigencia_service.dart`; `contabilidad/services/contabilidad_nicsp_service.dart`; `models/estado_financiero.dart`; `pages/contabilidad_nicsp_page.dart` | `test/sector_publico/contabilidad/estado_financiero_nicsp1_integracion_test.dart` | Ejecutado: caso con activo 1.000, pasivo 400, patrimonio 300, ingreso 500 y gasto 200. Presenta pasivo 400, patrimonio 600 (incluye resultado 300) y verifica `1.000 = 400 + 600`. | Parcial - Estado de Situacion Financiera y resultado quedan certificados; faltan pruebas de los demas estados basicos NICSP 1. |
| NICSP 2: flujo de efectivo | `contabilidad/services/flujo_efectivo_service.dart`; `contabilidad/pages/contabilidad_nicsp_page.dart`; `core/workspace/public_sector_config.dart` | `test/sector_publico/contabilidad/flujo_efectivo_service_test.dart` | Ejecutado: `flutter test test\\sector_publico\\contabilidad\\flujo_efectivo_service_test.dart` - 1 prueba paso; verifica efectivo inicial, operacion, inversion, financiacion, variacion neta, efectivo final y auditoria. La ruta RBAC `estado_flujos_efectivo` abre la pestana dedicada. | Parcial - el calculo directo esta certificado con movimientos conocidos, pero la clasificacion CGC y el metodo indirecto requieren validacion normativa adicional. |
| NICSP 12, 17, 19 y 40 | `activos/services/activos_service.dart`; `contabilidad/services/depreciacion_job_service.dart`; `contabilidad/services/provisiones_service.dart`; `transparencia/services/nicsp40_service.dart` | `activos_estado_page_test.dart` (inspeccion); no se identifico prueba especifica de NICSP 40 | Inspeccion de codigo; `consolidation_migration_test.dart` solo cubre migracion de esquema. | Parcial - falta validacion normativa y ejecucion programada de depreciacion/provisiones. |
| CGC publico con clases 1,2,3,4,5,6,8,9 | `database/schema_multi_tenant.dart`; `contabilidad/services/contabilidad_nicsp_service.dart` | `test/sector_publico/contabilidad/catalogo_cgc_test.dart` | Ejecutado: `flutter test test\\sector_publico\\contabilidad\\catalogo_cgc_test.dart` - 2 pruebas pasaron; valida las cuentas clave de las ocho clases y que los asientos NICSP de obligacion/pago usan cuentas del catalogo. | Completo - para las cuentas clave especificadas por el plan y los asientos certificados. |

Resumen M2: 2 Completos / 8 Parciales / 0 Pendientes.

## 3. Rentas y Tributos

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Carga de catastro IGAC | `rentas/services/predial_service.dart`; `models/predio.dart` | `predial_ica_page_test.dart` (inspeccion) | Inspeccion de codigo. | Parcial - no se certifico importacion masiva en formato IGAC. |
| Liquidacion masiva predial, tarifas y topes | `predial_service.dart`; `models/liquidacion_predial.dart` | `predial_ica_page_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta prueba normativa de topes y reglas por estrato/rural. |
| Acuerdos de pago, descuentos y exenciones | `models/acuerdo_pago.dart`; `predial_service.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - no hay evidencia de los escenarios legales completos. |
| Intereses moratorios diarios con tasa actualizable | `services/intereses_moratorios_service.dart` | `test/sector_publico/rentas/intereses_moratorios_service_test.dart` | Ejecutado: `flutter test test\\sector_publico\\rentas\\intereses_moratorios_service_test.dart` - 3 pruebas pasaron; certifica `I = K x T x t`, fechas y conversion diaria equivalente de 26.79% EA: $19.515,55 sobre $1.000.000 durante 30 dias. | Parcial - la formula local ya usa tasa diaria equivalente; falta persistir historial de tasas/fuentes y una actualizacion verificable por vigencia. |
| ICA, avisos y tableros, ReteICA y fiscalizacion | `services/ica_service.dart`; `pages/predial_ica_page.dart` | `predial_ica_page_test.dart` (inspeccion) | Inspeccion de codigo. | Parcial - falta integracion DIAN/exogena y pruebas de reglas locales. |
| Cobro coactivo: mandamiento a extincion | `services/cobro_coactivo_service.dart`; `models/proceso_cobro_coactivo.dart` | Ninguno identificado | Inspeccion: enum de seis etapas y persistencia basica; `avanzarEtapa` acepta cualquier etapa sin validar predecesora ni plazo legal. | Parcial - faltan transiciones legales, vencimientos/notificaciones y pruebas de cautelares, remate y cierre. |

Resumen M3: 0 Completos / 6 Parciales / 0 Pendientes.

## 4. Contratacion Publica

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Seis modalidades de seleccion | `contratacion/models/proceso_contratacion.dart`; `services/contratacion_service.dart` | `test/sector_publico/contratacion/contratacion_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta confirmar cobertura de las seis modalidades contra Ley 80/1150. |
| Fase precontractual: estudios, CDP y proceso | `contratacion_service.dart`; `pages/contratacion_publica_page.dart` | `test/sector_publico/contratacion/contratacion_flujo_rp_integracion_test.dart` | Ejecutado: proceso adjudicado con CDP permite registrar el contrato firmado; no cubre estudios previos ni las seis modalidades. | Parcial - falta prueba de estudios/seleccion y cobertura normativa de modalidades. |
| Fase contractual: contrato, polizas y ejecucion | `models/contrato.dart`; `models/poliza.dart`; `contratacion_service.dart`; `presupuesto_service.dart` | `test/sector_publico/contratacion/contratacion_flujo_rp_integracion_test.dart`; `contratacion_migracion_v68_test.dart` | Ejecutados: camino feliz firmado -> RP atomico -> poliza vigente -> legalizacion; tres tests de bloqueo independientes para RP sin contrato firmado, RP ajeno al proceso y legalizacion sin poliza vigente. | Parcial - falta certificar controles de ejecucion y poscontractuales. |
| Fase postcontractual: interventoria y liquidacion | `services/interventoria_liquidacion_service.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - servicio no conectado ni probado de extremo a extremo. |
| Interoperabilidad SECOP II/X-Road | `services/secop_service.dart` | Ninguno identificado | Inspeccion: el servicio existe; no se hallo evidencia de backend/ruta real. | Pendiente - falta integracion SECOP II real, credenciales, contrato y prueba. |

Resumen M4: 0 Completos / 4 Parciales / 1 Pendiente.

## 5. Nomina y Recursos Humanos Publicos

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Liquidacion de nomina publica | `nomina/services/nomina_service.dart`; `pages/nomina_publica_page.dart` | `test/sector_publico/nomina/nomina_service_test.dart` (inspeccion) | Sin evidencia ejecutada directa — solo inspeccion de `nomina_service.dart`. | Parcial - falta certificacion funcional completa de la liquidacion. |
| Seis regimenes salariales | `services/regimen_docente_service.dart`; modelos de nomina | Ninguno identificado para seis regimenes | Inspeccion de codigo. | Pendiente - solo se identifico servicio docente; faltan los demas regimenes y cobertura. |
| Factores salariales, prestaciones y horas extra | `services/horas_extra_service.dart`; `pages/horas_extra_form_page.dart`; `services/auxilio_alimentacion_service.dart` | `test/sector_publico/nomina/horas_extra_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - horas extra existen; auxilio y factores no estan certificados en flujo completo. |
| Retroactividad salarial | `services/retroactivos_service.dart`; `models/retroactivo.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - falta prueba de recalculo, aportes y trazabilidad. |
| Archivo PILA sector publico | `services/pila_service.dart` | Ninguno identificado | Inspeccion de codigo. | Pendiente - falta prueba y validacion contra estructura PILA. |

Resumen M5: 0 Completos / 3 Parciales / 2 Pendientes.

## 6. Almacen, Inventarios y Activos del Estado

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Clasificacion de bienes del Estado | `activos/models/activo_estado.dart`; `services/activos_service.dart` | `test/sector_publico/activos/activos_estado_page_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta certificacion de todas las clasificaciones CGC. |
| Depreciacion NICSP 17 por tipo de bien | `services/depreciacion_unidades_service.dart`; `contabilidad/services/depreciacion_job_service.dart` | `test/sector_publico/contabilidad/depreciacion_job_service_test.dart` | Ejecutado: `flutter test test\\sector_publico\\contabilidad\\depreciacion_job_service_test.dart` - 1 prueba paso; valida depreciacion mensual, actualizacion del activo y asiento con debito/credito. | Parcial - el job queda certificado para linea recta; faltan programacion operativa y validacion normativa de tasas/tipos. |
| Actas de responsabilidad y trazabilidad | `models/acta_responsabilidad.dart`; `services/acta_responsabilidad_service.dart` | `test/sector_publico/activos/acta_responsabilidad_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - prueba existente no fue ejecutada en esta auditoria. |
| FUT asociado a activos | `auditoria/services/fut_territorial_service.dart`; `models/reporte_fut_territorial.dart` | Ninguno identificado para datos de activos | Inspeccion de codigo; el test FUT existente cubre ingresos y exportacion, no activos. | Parcial - falta certificacion de formato FUT y datos de activos. |

Resumen M6: 0 Completos / 4 Parciales / 0 Pendientes.

## 7. Trazabilidad, Seguridad y Rendicion de Cuentas

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Auditoria append-only, hash encadenado e irreversibilidad | `security/auditoria_service.dart`; `database/schema_multi_tenant.dart` | `test/sector_publico/security/auditoria_registros_inmutabilidad_test.dart` | Ejecutado: `flutter test ...auditoria_registros_inmutabilidad_test.dart` -> DELETE bloqueado, archivado 0->1 permitido, UPDATE mixto bloqueado, `All tests passed!` | Completo - para la inmutabilidad SQLite y archivado permitido; el hash se inspecciono en codigo. |
| Retencion diferenciada y archivado | `security/auditoria_service.dart` | `auditoria_registros_inmutabilidad_test.dart` | Ejecutado: el test invoca `archivarRegistrosAntiguos` con el trigger activo. | Parcial - se probo archivado, no la politica completa de 5/10/50 anos. |
| Roles, RBAC y segregacion de funciones | `security/roles_permisos_service.dart` | `test/sector_publico/security/roles_permisos_service_test.dart`; `rbac_segregacion_test.dart` (inspeccion) | Ejecutado: `flutter test test\\sector_publico\\security\\roles_permisos_service_test.dart` - 9 pruebas pasaron; Secretario General recibe exclusivamente gestionar usuarios/asignar roles y no puede ejercer facultades fiscales. | Parcial - falta evidencia ejecutada de toda la matriz RBAC y un modulo publico de usuarios aislado por entidad. |
| Generador universal de archivos planos | `auditoria/services/chip_reporter_service.dart`; `fut_territorial_service.dart`; `sia_observa_service.dart` | `fut_territorial_service_test.dart`; `sia_observa_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - no se certificaron formatos contra receptores externos. |
| CHIP: CGN2015_001 a 005 y CGN2016C01 | `auditoria/models/reporte_chip.dart`; `auditoria/services/chip_reporter_service.dart`; `auditoria/pages/auditoria_forense_page.dart` | `test/sector_publico/auditoria/chip_datos_sistema_integracion_test.dart` | Ejecutado: CGN 2015_001 toma entidad y funcionarios; 002 toma saldos contables; 003 toma el Estado de Situacion Financiera. Con datos sembrados verifica 700 ingresos, 300 gastos y 1.100 = 400 + 700, incluso tras recuperar JSON de `reportes_chip`. | Parcial - CGN 2015_004 carece de adiciones/reducciones/creditos/contracreditos persistidos; 005 no tiene deuda publica modelada; 2016C01 no tiene modelo/fuente consolidada. En 002 faltan taxonomias persistidas para regalias y gasto de inversion. |

Resumen M7: 1 Completo / 4 Parciales / 0 Pendientes.

## 8. Facturacion y Gestion en Salud Publica

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| RIPS: seis archivos AF, AC, AP, AT, AU y AM | `salud/models/rips.dart`; `services/rips_service.dart` | Ninguno identificado para los seis archivos | Inspeccion de codigo; `salud_publica_page_test.dart` no valida los archivos RIPS. | Parcial - no se certificaron los seis archivos frente a Resolucion 2275/2023. |
| Validacion CUPS/CUM/CIE-10 y vinculo factura-RIPS | `rips_service.dart`; `facturacion_salud_service.dart` | `test/sector_publico/salud/facturacion_salud_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta evidencia de reglas completas y relacion 1:1. |
| Transmision ADRES/EPS | No se identifico cliente de interoperabilidad | Ninguno identificado | Inspeccion de archivos de salud. | Pendiente - falta integracion externa y trazabilidad de envios. |
| Contratos EPS/ADRES: evento, capitacion y PGP | `models/contrato_eps.dart`; `facturacion_salud_service.dart` | `facturacion_salud_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta certificacion de manuales tarifarios y conciliacion de poblacion. |
| Glosas, plazos y conciliacion | `models/glosa.dart`; `services/glosas_service.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - faltan pruebas de plazos legales y cartera. |

Resumen M8: 0 Completos / 4 Parciales / 1 Pendiente.

## 9. Sistema General de Regalias

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Proyectos OCAD, actas y ejecutor | `regalias/models/proyecto_ocad.dart`; `services/regalias_service.dart` | Ninguno identificado especifico de OCAD | Inspeccion de codigo. | Parcial - falta prueba de vinculacion MGA/OCAD y trazabilidad de ejecutor. |
| Presupuesto bienal y ejecucion SGR separada | `models/bienio_sgr.dart`; `models/regalia.dart`; `services/regalias_service.dart` | `test/sector_publico/regalias/spgr_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta certificacion del flujo CDP-RP-Obligacion-Pago SGR. |
| Rendimientos financieros reinvertidos | No se identifico validacion especifica | Ninguno identificado | Inspeccion de codigo. | Pendiente - falta control obligatorio de reinversion. |
| Reporte de programacion, ejecucion y giro SPGR/SMSCE | `services/spgr_service.dart`; `models/reporte_spgr.dart` | `spgr_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - no hay evidencia de interoperabilidad DNP real. |

Resumen M9: 0 Completos / 3 Parciales / 1 Pendiente.

## 10. Sistema General de Participaciones

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Componentes SGP: educacion, salud, agua y proposito general | `regalias/models/sgp.dart`; `services/sgp_service.dart` | Ninguno identificado para componentes SGP | Inspeccion de codigo; `sicodis_service_test.dart` cubre certificacion/exportacion, no los cuatro componentes. | Parcial - falta verificar reglas completas por componente. |
| Destinacion especifica: bloquear cruce de recursos | `services/validacion_distribucion_service.dart`; `sgp_service.dart` | Ninguno identificado para la validacion | Inspeccion de codigo. | Parcial - falta prueba de bloqueo presupuestal intersectorial. |
| Nomina docente y escalafon | `nomina/services/regimen_docente_service.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - servicio aislado; falta integracion con SGP y prueba. |
| FUT y reporte SICODIS | `services/sicodis_service.dart`; `models/reporte_sicodis.dart` | `sicodis_service_test.dart` (inspeccion) | Inspeccion de codigo/test. | Parcial - falta evidencia ejecutada y validacion contra SICODIS. |

Resumen M10: 0 Completos / 4 Parciales / 0 Pendientes.

## 11. Transparencia Proactiva y Control Disciplinario

| Requisito (del plan v1.1) | Archivo(s) que lo implementan | Test que lo cubre | Evidencia (comando + resultado, si lo corriste) | Estado |
|---|---|---|---|---|
| Portal Ley 1712: presupuesto, contratos, PDT, planta y EEFF | `transparencia/services/transparencia_service.dart`; `portal_transparencia_service.dart`; `pages/transparencia_page.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - no se certifico publicacion real, periodicidad ni datos abiertos. |
| Consolidacion NICSP 40 | `transparencia/services/nicsp40_service.dart`; `models/consolidacion_nicsp40.dart` | Ninguno identificado para consolidacion NICSP 40 | Inspeccion de codigo; `consolidation_migration_test.dart` cubre migracion de base, no consolidacion contable. | Parcial - falta certificacion contable y de consolidacion operativa. |
| Expediente disciplinario y reserva por rol | `models/proceso_disciplinario.dart`; `services/disciplinario_service.dart` | Ninguno identificado | Inspeccion de codigo. | Parcial - falta prueba de etapas, reserva y controles de acceso. |
| Alerta forense genera queja preliminar | No se identifico enlace automatico auditoria->disciplinario | Ninguno identificado | Inspeccion de servicios de auditoria y disciplinario. | Pendiente - falta integracion automatica exigida por el plan. |
| Exportacion SID Procuraduria | No se identifico exportador SID | Ninguno identificado | Inspeccion de archivos de transparencia. | Pendiente - falta interoperabilidad y formato SID. |

Resumen M11: 0 Completos / 3 Parciales / 2 Pendientes.

## Resumen por Macro-Sistema

| Macro-sistema | Completos | Parciales | Pendientes | Lectura operativa |
|---|---:|---:|---:|---|
| M1 Planeacion y Proyectos | 0 | 4 | 2 | Base funcional sin trazabilidad presupuesto-resultado certificada. |
| M2 Financiero Integrado | 1 | 9 | 0 | Flujo presupuestal-pago certificado; faltan coberturas normativas complementarias. |
| M3 Rentas y Tributos | 0 | 6 | 0 | Servicios presentes; faltan reglas locales e integraciones externas. |
| M4 Contratacion | 0 | 4 | 1 | SECOP II real es el bloqueo principal. |
| M5 Nomina | 0 | 3 | 2 | Liquidacion base existe; faltan seis regimenes y PILA validada. |
| M6 Activos | 0 | 4 | 0 | Base y pruebas aisladas; falta automatizacion/certificacion. |
| M7 Seguridad y Rendicion | 1 | 4 | 0 | Inmutabilidad SQLite probada; reportes regulatorios aun parciales. |
| M8 Salud | 0 | 4 | 1 | Falta interoperabilidad ADRES/EPS y validacion RIPS completa. |
| M9 SGR | 0 | 3 | 1 | Falta control de reinversion e interoperabilidad DNP real. |
| M10 SGP | 0 | 4 | 0 | Falta bloqueo certificado de destinacion y SICODIS validado. |
| M11 Transparencia | 0 | 3 | 2 | Falta publicacion verificable y enlace disciplinario/SID. |
| **Total** | **1** | **49** | **8** | **No hay macro-sistema completo como unidad operativa.** |

## Brechas criticas priorizadas

1. **Integracion SECOP II/X-Road real (M4).** Sin contrato de interoperabilidad, autenticacion, trazabilidad y pruebas contra SECOP II, el ciclo contractual no es apto para operacion publica.
2. **Controles financieros normativos restantes (M2).** El flujo CDP-RP-obligacion-pago-PAC ya tiene prueba de integracion; faltan pruebas negativas de soportes, cierre de vigencia, vigencias futuras y controles complementarios.
3. **Seis regimenes de nomina y archivo PILA validado (M5).** La liquidacion base no habilita operacion si faltan regimenes, retroactivos completos y el archivo regulatorio.
4. **RIPS validado e interoperabilidad ADRES/EPS (M8).** Es bloqueante para facturacion hospitalaria y cobro de servicios de salud.
5. **Trazabilidad PDT-presupuesto-resultado (M1).** Falta la regla de que no exista gasto sin plan, incluidos avances y alerta de desviacion financiera/fisica.
6. **Rentas territoriales con reglas locales y ciclo coactivo completo (M3).** Sin catastro IGAC validado, tasas actualizadas, topes y plazos legales, no debe operarse recaudo masivo.
7. **Reportes regulatorios externos (CHIP, FUT, SICODIS y SPGR).** Hay modelos/servicios parciales, pero falta validacion de formato y envio contra los receptores oficiales.
8. **Transparencia publica, disciplinario y SID (M11).** Falta convertir hallazgos forenses en expedientes controlados y publicar informacion exigible de forma verificable.

La inmutabilidad de auditoria no figura como brecha: el trigger SQLite y sus tres casos de prueba directa ya fueron ejecutados correctamente en esta sesion.
