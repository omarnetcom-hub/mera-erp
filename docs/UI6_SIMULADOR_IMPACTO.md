# UI-6: Simulador de impacto

## Alcance y decisiones

El simulador cruza datos operativos reales de CRM, MRP y HRM, pero guarda los
escenarios en una tabla separada (`impact_scenarios`). Guardar una simulacion no
actualiza oportunidades, empleados ni workstations.

### Capacidad productiva

La tabla `mrp_workstations` tiene `hour_rate`, que representa costo por hora,
y `production_capacity`, que sigue siendo una capacidad generica sin semantica
temporal. Desde el esquema v83 cada workstation puede declarar
`available_hours_per_day`; NULL significa que esa estacion aun no esta
configurada. El simulador suma las horas de las workstations en produccion y
las muestra como capacidad diaria real.

Ademas, CRM no tiene una relacion oportunidad-producto-cantidad. El simulador
calcula una demanda monetaria incremental como proxy, pero no la convierte a
unidades MRP ni afirma que la capacidad alcance. Para cerrar esa parte se
necesita una relacion entre oportunidad, producto y cantidad para comparar esa
capacidad horaria con demanda de unidades. Si faltan horas en alguna estacion,
el estado queda parcial y no se afirma factibilidad completa.

### Headcount

`headcount` es el conteo de filas de `empleados` activas (`activo = 1`) para la
empresa activa. El salario base agregado de esas filas se incluye como contexto
de costo laboral. No se filtra por cargo porque no existe hoy una relacion
verificada entre oportunidades y los cargos que las producirian.

## Formula reproducible

Con `uplift_percent` entre 0 y 100, usando siempre unidades menores enteras:

```text
valor_ganado_proyectado = valor_ganado_actual * (100 + uplift_percent) / 100
demanda_incremental_proxy = valor_ganado_proyectado - valor_ganado_actual
```

La division usa `MoneyValue.multiplyRatio`, no `double`. El resultado deja
explicito que la demanda es un proxy monetario y que no hay conversion a
unidades sin producto/cantidad.

## Libro de escenarios

`impact_scenarios` almacena empresa, nombre, fecha, input, snapshot de CRM/MRP/
HRM, resultado, formula y SHA-256 de la representacion estructurada. Es una
tabla append-only desde el servicio de simulacion: no se usa como fuente para
liquidar, vender, producir o modificar datos operativos.

La UI `ImpactSimulatorPage` expone el control de incremento, el snapshot,
resultado con estado ambar cuando la capacidad esta incompleta o no puede
compararse con unidades. La entrada de workspace usa `FeatureKey.impactSimulator` y el permiso
existente de Reportes; la consulta y el guardado siguen el alcance RBAC del
workspace.

## Evidencia

El test `test/impact/impact_simulator_service_test.dart` verifica:

- calculo exacto de 100000 a 120000 y demanda incremental de 20000;
- conteo de empleados activos y costo base en unidades menores;
- estado fail-closed de capacidad no configurada;
- ausencia de mutaciones en CRM, HRM y MRP al guardar;
- persistencia de formula, snapshot y hash del escenario.

## Pendientes

Vincular oportunidades a productos/cantidades antes de presentar una
factibilidad productiva numerica. La capacidad diaria ya es un dato real,
pero la demanda por unidad sigue pendiente.
