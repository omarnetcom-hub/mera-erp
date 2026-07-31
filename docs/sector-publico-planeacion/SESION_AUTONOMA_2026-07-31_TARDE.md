# Sesion autonoma - 2026-07-31 tarde

## Alcance y criterio

- Objetivo: cerrar en orden las subtareas A-D del Sistema Financiero Integrado y, solo si hay margen suficiente, evaluar E-F.
- Regla de evidencia: no se eleva una fila de la matriz a `Completo` sin una prueba ejecutada que cubra especificamente el requisito.
- Regla de decisiones: ante ambiguedades, se usa la opcion conservadora y se documenta. Credenciales externas, llamadas reales o cambios irreversibles sobre datos reales se registran como `requiere decision humana` y no se ejecutan.
- Nota de hashes: un commit no puede contener su propio hash sin cambiarlo. El hash de cada subtarea se registrara en la siguiente actualizacion del log; el resumen final consolidara todos los hashes publicados.

## Inicio de sesion

- Estado inicial: `main` sincronizada con `origin/main` tras `db75535`.
- Subtarea en curso: A - cierre de vigencia y vigencias futuras.

## Subtarea A - Cierre de vigencia y vigencias futuras

### Hallazgo y decision

- `CierreVigenciaService._calcularReservas` no consulta `obligaciones`. Solo suma los saldos de cuentas cuyo codigo inicia por `24` y las provisiones activas. Eso no demuestra reservas presupuestales basadas en obligaciones sin pago.
- No existe tabla o flujo sectorial para registrar bienes o servicios recibidos sin obligacion. Los soportes de recibo y factura viven dentro de la propia tabla `obligaciones`, por lo que no hay fuente de datos que permita calcular ese subconjunto de cuentas por pagar sin inventar datos.
- No se encontro implementacion de vigencias futuras, autorizacion Confis, MFMP ni compromiso plurianual en `lib/sector_publico` o `test/sector_publico`.
- Decision autonoma conservadora: no se implemento una formula ni una prueba de integracion que aparentara cubrir el requisito. Se mantuvo M2 como `Parcial` y se documento la brecha especifica en la matriz. Implementar las dos fuentes de datos y las reglas de autorizacion es una decision de diseno y normativa que requiere revision humana.

### Pruebas

- No se ejecuto una prueba de cierre: una prueba verde solo validaria la suma actual de saldos 24 y provisiones, no el requisito solicitado de reservas presupuestales y recibidos sin obligacion.
- La evidencia de analisis y build se registra a continuacion.

### Salida cruda: flutter analyze

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
warning - The declaration '_migrarDB' isn't referenced - lib\core\database\database_initializer.dart:234:10 - unused_element
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
   info - Don't invoke 'print' in production code - lib\db_helper.dart:675:7 - avoid_print
   info - Don't invoke 'print' in production code - lib\db_helper.dart:689:7 - avoid_print
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
   info - The type name 'DatosCGN2015_001' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:87:7 - camel_case_types
   info - The type name 'DatosCGN2015_002' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:144:7 - camel_case_types
   info - The type name 'DatosCGN2015_003' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:195:7 - camel_case_types
   info - The type name 'DatosCGN2015_004' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:231:7 - camel_case_types
   info - The type name 'DatosCGN2015_005' isn't an UpperCamelCase identifier - lib\sector_publico\auditoria\models\reporte_chip.dart:273:7 - camel_case_types
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\auditoria\pages\auditoria_forense_page.dart:509:17 - deprecated_member_use
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\sector_publico\auditoria\pages\auditoria_forense_page.dart:673:52 - deprecated_member_use
warning - Unused import: 'dart:convert' - lib\sector_publico\auditoria\services\fut_territorial_service.dart:5:8 - unused_import
warning - Unused import: 'dart:convert' - lib\sector_publico\auditoria\services\sia_observa_service.dart:5:8 - unused_import
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:211:19 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:237:50 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:245:51 - unnecessary_string_interpolations
   info - Unnecessary use of string interpolation - lib\sector_publico\contabilidad\pages\contabilidad_nicsp_page.dart:297:15 - unnecessary_string_interpolations
warning - The value of the local variable 'fechaUltimoDia' isn't used - lib\sector_publico\contabilidad\services\depreciacion_job_service.dart:29:11 - unused_local_variable
   info - Unnecessary use of string interpolation - lib\sector_publico\contratacion\pages\contratacion_publica_page.dart:430:19 - unnecessary_string_interpolations
warning - The value of the field '_uuid' isn't used - lib\sector_publico\contratacion\services\secop_service.dart:20:14 - unused_field
   info - Use the null-aware marker '?' rather than a null check via an 'if' - lib\sector_publico\contratacion\services\secop_service.dart:43:7 - use_null_aware_elements
   info - Unnecessary use of string interpolation - lib\sector_publico\nomina\pages\nomina_publica_page.dart:321:15 - unnecessary_string_interpolations
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
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:391:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:462:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:602:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\regalias\pages\regalias_sgp_page.dart:769:17 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\rentas\pages\predial_ica_page.dart:793:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\rentas\pages\predial_ica_page.dart:864:19 - deprecated_member_use
warning - The value of the field '_dio' isn't used - lib\sector_publico\rentas\services\intereses_moratorios_service.dart:12:13 - unused_field
warning - The declaration '_validarPermiso' isn't referenced - lib\sector_publico\rentas\services\predial_service.dart:27:28 - unused_element
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:450:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:522:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:617:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\salud\pages\salud_publica_page.dart:754:19 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\siif\pages\siif_page.dart:199:17 - deprecated_member_use
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre - lib\sector_publico\siif\pages\siif_page.dart:268:17 - deprecated_member_use
warning - Unused import: 'dart:convert' - lib\sector_publico\siif\services\siif_service.dart:5:8 - unused_import
   info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\sector_publico\transparencia\pages\transparencia_page.dart:375:56 - deprecated_member_use
   info - Unnecessary use of string interpolation - lib\sector_publico\transparencia\pages\transparencia_page.dart:445:23 - unnecessary_string_interpolations
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
warning - The value of the local variable 'currentFingerprint' isn't used - lib\services\licencia_service.dart:322:11 - unused_local_variable
warning - The value of the field '_publicKeyPEM' isn't used - lib\services\license_validation_service.dart:11:23 - unused_field
warning - The value of the local variable 'headerEncoded' isn't used - lib\services\license_validation_service.dart:23:13 - unused_local_variable
warning - The value of the local variable 'signatureEncoded' isn't used - lib\services\license_validation_service.dart:25:13 - unused_local_variable
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

flutter : 184 issues found. (ran in 8.8s)
En línea: 2 Carácter: 1
+ flutter analyze *> A_analyze_output.txt; exit $LASTEXITCODE
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (184 issues found. (ran in 8.8s):String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
```

### Salida cruda: flutter build windows

```text
Building Windows application...                                 
flutter : Nuget.exe not found, trying to download or use cached version.
En línea: 2 Carácter: 1
+ flutter build windows *> A_build_windows_output.txt; exit $LASTEXITCO ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (Nuget.exe not f...cached version.:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
Building Windows application...                                    20.9s
√ Built build\windows\x64\runner\Release\MerkaERP.exe
```
