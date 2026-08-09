# UI-6: Simulador de impacto

## Alcance y decisiones

El simulador cruza datos operativos reales de CRM, MRP y HRM, pero guarda los
escenarios en una tabla separada (`impact_scenarios`). Guardar una simulacion no
actualiza oportunidades, empleados ni workstations.

### Capacidad productiva

La tabla `mrp_workstations` tiene `hour_rate`, que representa costo por hora,
y `production_capacity`, que no tiene semantica documentada de horas por turno,
calendario, disponibilidad o capacidad temporal. Por eso el simulador no
interpreta ninguno de esos campos como horas disponibles y devuelve
`capacidad_no_configurada`. No se inventa una cifra para hacer parecer que la
factibilidad esta calculada.

Ademas, CRM no tiene una relacion oportunidad-producto-cantidad. El simulador
calcula una demanda monetaria incremental como proxy, pero no la convierte a
unidades MRP ni afirma que la capacidad alcance. Para cerrar esa parte se
necesita configurar horas por workstation/turno y una relacion entre oportunidad,
producto y cantidad.

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
resultado con estado ambar cuando la capacidad no esta configurada y el libro
local. La entrada de workspace usa `FeatureKey.impactSimulator` y el permiso
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

Configurar horas disponibles por workstation/turno y vincular oportunidades a
productos/cantidades antes de presentar una capacidad productiva numerica.
