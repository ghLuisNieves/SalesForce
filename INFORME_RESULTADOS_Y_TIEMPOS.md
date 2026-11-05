# Resultados y tiempos de optimización de la integración CRM

**Fecha:** 5 de noviembre de 2026. Horarios de los registros: Ciudad de México.

La colaboración entre Luis Nieves y Codex produjo un índice de apoyo, ajustes al procedimiento de integración CRM y dos variantes de prueba publicadas en este repositorio. V4 redujo la CPU total un **52.4 % frente a V3** en las ejecuciones compartidas. El intervalo documentado entre la primera medición y la prueba de V4 fue de **47 minutos y 46 segundos**.

El ahorro de tiempo de trabajo frente a hacerlo sin asistencia es una **estimación por escenarios**, no una medición de productividad personal. Se distingue del tiempo de ejecución del procedimiento SQL.

## Alcance del trabajo realizado

- Revisión de filtros, joins, paginación y duplicados del procedimiento original.
- Cambio del filtro de fecha a `ZMOV.FECHMOV`, conservando la ventana de 170 días y excluyendo el día actual. `@FechaCorte` permanece sin uso.
- Revisión de índices y prueba de `IX_ZMOV_CRM_Pais_Fecha`.
- Diagnóstico de consumo de CPU, memoria, paralelismo y bloqueos a partir de estadísticas y planes reales.
- Evaluación de `MAXDOP 2` y `RECOMPILE`, sin adoptarlos como solución definitiva.
- V3: sustitución de `COUNT(*) OVER()` por materialización y conteo mediante `@@ROWCOUNT`.
- V4: materialización previa de movimientos pendientes para mejorar la planificación de los joins.
- Creación del repositorio local y publicación de los scripts V3 y V4 en GitHub.

Luis ejecutó las pruebas en SQL Server, proporcionó estadísticas y planes, y completó la autenticación de GitHub. Codex propuso los cambios, analizó los planes, preparó los scripts y realizó las operaciones de Git autorizadas. Los resultados corresponden a ese trabajo conjunto.

## Tiempo documentado de trabajo con asistencia

| Hito | Hora de finalización registrada |
|---|---|
| Primera medición detallada compartida | 12:50:49 |
| Medición con índice y sin `MAXDOP 2` | 13:16:52 |
| Prueba con `MAXDOP 2` | 13:19:29 |
| Prueba con `RECOMPILE` | 13:27:53 |
| Prueba de V3 | 13:34:46 |
| Prueba de V4 | 13:38:35 |

**Intervalo verificable: 13:38:35 − 12:50:49 = 00:47:46.** Se usan los horarios truncados a segundos de las salidas compartidas.

Este intervalo incluye análisis, intercambio de resultados y pruebas entre esos hitos; no equivale a trabajo activo cronometrado. Excluye la revisión y los cambios anteriores a la primera medición, la publicación posterior en Git y la elaboración de este informe. La fecha de generación del script original no se considera una hora de inicio del trabajo.

Por lo tanto, **no se puede afirmar que todo el proyecto tomó exactamente 48 minutos**. Tampoco se registró el esfuerzo activo total de la sesión.

## Estimación del trabajo sin asistencia

Para comparar el mismo alcance técnico y la publicación en Git, se plantea el siguiente presupuesto de esfuerzo para una persona que conoce SQL Server y el modelo de datos, dispone de los mismos accesos y debe investigar, implementar y evaluar las alternativas por su cuenta. No incluye la validación concurrente pendiente ni este informe.

| Actividad | Esfuerzo sin asistencia estimado |
|---|---:|
| Revisar reglas, joins y paginación | 30–60 min |
| Revisar índices y preparar una prueba de acceso | 45–90 min |
| Interpretar estadísticas, planes y síntomas de concurrencia | 60–120 min |
| Implementar y comparar variantes de consulta | 60–120 min |
| Revisar resultados y seleccionar la siguiente prueba | 30–60 min |
| Preparar y publicar los scripts en Git | 15–30 min |
| **Total estimado** | **240–480 min, equivalentes a 4–8 horas** |

Los rangos son supuestos de planificación de Codex, no un benchmark externo ni una evaluación de la capacidad de Luis. Un especialista familiarizado con esta consulta podría resolverla en menos tiempo; investigar un entorno desconocido podría requerir más. No se realizó una prueba equivalente sin asistencia.

## Escenarios de ahorro de esfuerzo

Para ilustrar el cálculo se adopta un **supuesto de 1.5 horas de esfuerzo activo total con asistencia**, incluyendo revisión previa y publicación. Este valor no está medido ni validado por Luis y no debe confundirse con el intervalo documentado de 47:46. Debe sustituirse por su registro de trabajo si se utilizará para reportar productividad.

| Escenario hipotético | Con asistencia, supuesto | Sin asistencia, supuesto | Ahorro calculado | Reducción calculada |
|---|---:|---:|---:|---:|
| Resolución independiente rápida | 1.5 h | 4 h | 2.5 h | 62.5 % |
| Presupuesto intermedio | 1.5 h | 6 h | 4.5 h | 75.0 % |
| Investigación más extensa | 1.5 h | 8 h | 6.5 h | 81.3 % |

Fórmulas: **ahorro = tiempo sin asistencia − tiempo con asistencia**; **reducción = ahorro / tiempo sin asistencia × 100**.

El 75 % del escenario intermedio es una proyección condicionada a esos supuestos, **no un ahorro comprobado**. La evidencia disponible sí demuestra que se recorrieron varias alternativas y se llegó a V4 dentro del intervalo documentado.

## Resultados medidos en SQL Server

### Evolución de las pruebas

| Prueba | Duración reportada | CPU reportada | Interpretación |
|---|---:|---:|---|
| Primera medición detallada | 6.947 s | 41.378 s | `ZMOV` registraba 2,743,352 lecturas lógicas |
| Con índice, sin ajuste de paralelismo | 4.580 s | 23.077 s | `ZMOV` bajó a 38,386 lecturas |
| Con `MAXDOP 2` | 12.353 s | 21.972 s | Empeoró la duración individual; apenas redujo CPU |
| Con `RECOMPILE` | 10.655 s | 29.376 s | Total reportado, incluida compilación |
| V3 | 6.211 s | 30.369 s | Total reportado, incluida compilación; eliminó el spool del conteo |
| V4 | 4.730 s | 14.453 s | Total reportado, incluida compilación; redujo el trabajo de los joins |

La CPU puede superar la duración por el trabajo de varios trabajadores en paralelo. Las cifras provienen de ejecuciones individuales bajo una carga no controlada: no son promedios ni garantizan esos tiempos en producción. Las salidas iniciales y las posteriores no desglosan la compilación de la misma manera.

V4 no obtuvo la menor duración individual de todas las pruebas: la medición con índice alcanzó 4.580 s. Su ventaja observada es principalmente el menor consumo de CPU y memoria frente a las variantes analizadas.

### Comparación directa entre V3 y V4

| Métrica | V3 | V4 | Variación |
|---|---:|---:|---:|
| Duración total reportada | 6.211 s | 4.730 s | −23.8 % |
| CPU total reportada | 30.369 s | 14.453 s | −52.4 % |
| Memoria concedida al join principal | 1,981,968 KiB | 510,096 KiB | −74.3 % |
| Filas finales antes de paginar | 241,775 | 241,775 | Misma cantidad |
| Lecturas lógicas de `MFACT` | 132,773 | 772,636 | Aumentaron por búsquedas repetidas |

La reducción de lecturas no es el único criterio: V4 consumió menos CPU aun con más accesos a `MFACT`. La memoria de la tabla corresponde a una sentencia, no a toda la memoria de la sesión ni de la instancia.

## Estado de la mejora y validaciones pendientes

V4 es una candidata para evaluar bajo concurrencia; no se ha demostrado que resuelva la degradación con diez llamadas simultáneas. Su plan todavía muestra un desbordamiento del ordenamiento de `DISTINCT` hacia `tempdb`.

Antes de adoptarla deben compararse los resultados completos sobre datos estables y medirse lotes equivalentes con dos y diez ejecuciones simultáneas. La coincidencia del número de filas no prueba por sí sola la igualdad de todos los valores. También queda pendiente resolver la reserva de movimientos si varios consumidores procesan los mismos pendientes: estas consultas no los reservan.

No se ha documentado un despliegue definitivo a producción. La publicación en Git corresponde a los scripts de prueba.

## Evidencia y archivos

- Salidas de `STATISTICS IO` y `STATISTICS TIME` compartidas durante la sesión del 5 de noviembre de 2026.
- Planes reales `Plan1.sqlplan`, `Plan2.sqlplan`, `Plan3.sqlplan` y `Plan4_1.sqlplan`, analizados desde los archivos proporcionados. No están incluidos en este repositorio.
- [Script V3](Sp_Sel_IntegrationCRMMovimientos_v3_prueba.sql).
- [Script V4](Sp_Sel_IntegrationCRMMovimientos_v4_prueba.sql).
- [Commit inicial de los scripts](https://github.com/ghLuisNieves/SalesForce/commit/be5aae5).

Las estadísticas técnicas son observaciones de las pruebas. Los tiempos de trabajo sin asistencia y los escenarios de ahorro son estimaciones explícitas que deben ajustarse con la experiencia y los registros de Luis.
