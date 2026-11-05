# Resultados y tiempos de optimización de Tickets CRM

**Fecha:** 5 de noviembre de 2026. Horarios de los registros: Ciudad de México.

La mejora de `Sp_Sel_IntegrationCRMTickets` se desarrolló mediante trabajo conjunto de Luis Nieves y Codex, aprovechando el conocimiento del modelo y el índice de movimientos revisados previamente. La versión candidata es **Tickets V5**: mantiene la paginación y, en el plan probado, elimina el ordenamiento interno del SELECT final y su concesión de memoria de aproximadamente 386 MiB.

El intervalo documentado desde la medición inicial hasta V5 fue de **1 hora, 7 minutos y 49 segundos**. El esfuerzo que habría requerido hacerlo sin asistencia se presenta como una estimación de planificación de **3 a 6 horas**, no como un tiempo medido ni una evaluación de la capacidad de Luis.

## Alcance de las mejoras

- Revisión de la consulta original, estadísticas y seis planes reales de ejecución.
- Cambio autorizado a movimientos de ayer por `ZMOV.FECHMOV`, en lugar de fecha del cliente. `@FechaCorte` permanece sin uso.
- Retiro autorizado del join a `vw_emailduplicate`, que podía multiplicar detalles por correo sin filtrar tickets.
- Materialización por etapas de movimientos del día, tickets elegibles y detalles pendientes.
- Sustitución del conteo con ventana por `@@ROWCOUNT` sobre el resultado materializado.
- Validación de parámetros y cálculo del desplazamiento como `BIGINT`.
- Retiro de `NOLOCK` en las variantes optimizadas, usando el aislamiento de la sesión.
- Evaluación de un índice temporal por `IdRow` y de su uso explícito en el SELECT final.
- Conservación de `ORDER BY IdRow`, `OFFSET`, `FETCH`, columnas de salida y cálculos originales de `Mandante` y `PriceUnity`.

No se crearon ni reconstruyeron índices permanentes durante estas variantes de Tickets. El plan aprovecha `IX_ZMOV_CRM_Pais_Fecha`, creado durante la mejora anterior de Movimientos, y los índices existentes de detalle. La preparación del entorno anterior no se contabiliza como trabajo nuevo de Tickets.

Luis ejecutó las pruebas y compartió planes y estadísticas; también definió el filtro de fecha y autorizó retirar la vista. Codex analizó la evidencia, preparó los scripts, comparó resultados y gestionó la publicación autorizada. Los tiempos reflejan esa colaboración.

## Tiempo documentado con asistencia

| Hito | Hora registrada | Evidencia |
|---|---|---|
| Medición original | 16:16:59 | Estadísticas iniciales y `Plan5_2.sqlplan` |
| Tickets V3 | 16:56:40 | `Plan5_3.sqlplan` |
| Repetición de V3 número 1 | 17:13:13 | `Plan_5_4.sqlplan` |
| Repetición de V3 número 2 | 17:13:59 | `Plan5_5.sqlplan` |
| Tickets V4 | 17:19:01 | `Plan5_6.sqlplan` |
| Tickets V5 | 17:24:48 | `Plan5_7.sqlplan` |

**Intervalo verificable: 17:24:48 − 16:16:59 = 01:07:49**, usando los horarios truncados a segundos de las salidas compartidas.

La tabla enumera los seis registros de ejecución recibidos. No se dispone de una medición adicional de la versión base con fecha del movimiento.

Este intervalo es tiempo transcurrido entre registros: incluye intercambios y posibles pausas, no mide exclusivamente esfuerzo activo. Tampoco incluye toda la preparación anterior a la primera medición, la publicación posterior en Git ni este informe. La validación de páginas posteriores y concurrencia sigue pendiente.

## Estimación del esfuerzo sin asistencia

El siguiente escenario supone que Luis dispone del mismo entorno de pruebas, accesos, índices previos y conocimiento obtenido durante la mejora de Movimientos. Contempla investigar e implementar las alternativas de Tickets hasta seleccionar V5 como candidata, sin desplegarla a producción.

| Actividad | Esfuerzo independiente estimado |
|---|---:|
| Revisar reglas, fechas y efecto de la vista de correos | 20–40 min |
| Analizar planes, estimaciones, memoria y esperas | 30–60 min |
| Revisar índices y tipos de datos | 20–40 min |
| Implementar y comparar consultas por etapas | 50–100 min |
| Evaluar paginación, índice temporal y acceso final | 40–80 min |
| Revisar resultados y preparar la publicación en Git | 20–40 min |
| **Total estimado** | **180–360 min, equivalentes a 3–6 horas** |

Estos rangos son supuestos de Codex para planificación. Un especialista familiarizado con este patrón podría tardar menos; un entorno desconocido podría demandar más. No existe una ejecución del mismo trabajo sin asistencia que permita medir el ahorro real.

## Escenarios de ahorro de tiempo

Para ilustrar el cálculo se utiliza un **supuesto de 1.5 horas de esfuerzo activo con asistencia** para el alcance técnico y su publicación. No es un cronometraje ni un dato validado por Luis. Es distinto del intervalo comprobado de 01:07:49 y debe sustituirse por su registro de trabajo para reportar productividad real.

| Escenario hipotético | Con asistencia, supuesto | Sin asistencia, supuesto | Ahorro calculado | Reducción calculada |
|---|---:|---:|---:|---:|
| Resolución independiente rápida | 1.5 h | 3 h | 1.5 h | 50.0 % |
| Presupuesto intermedio | 1.5 h | 4.5 h | 3 h | 66.7 % |
| Investigación más extensa | 1.5 h | 6 h | 4.5 h | 75.0 % |

Fórmulas: **ahorro = tiempo sin asistencia − tiempo con asistencia**; **reducción = ahorro / tiempo sin asistencia × 100**.

El escenario intermedio proyecta tres horas de ahorro, condicionado a los supuestos anteriores. No equivale a afirmar que Luis habría tardado necesariamente 4.5 horas ni que se haya medido un ahorro del 66.7 %.

## Resultados técnicos registrados

| Ejecución | Duración total reportada | CPU total reportada | Total de registros |
|---|---:|---:|---:|
| Original con fecha del cliente | 39.989 s | 82.660 s | 4,027 |
| V3, primera prueba | 12.534 s | 1.968 s | 22,943 |
| V3, repetición 1 | 4.882 s | 1.687 s | 22,943 |
| V3, repetición 2 | 4.201 s | 1.362 s | 22,943 |
| V4 | 4.203 s | 1.482 s | 22,943 |
| V5 | 4.015 s | 1.549 s | 22,943 |

**El original y las variantes no consultan el mismo conjunto:** cambió el campo de fecha y se retiró la multiplicación por correo. No se atribuye toda la diferencia de tiempos a una optimización de una consulta equivalente. Las cifras son observaciones individuales, con compilación y carga variables, no un benchmark controlado.

La primera ejecución de V3 incluyó aproximadamente 7.50 segundos de espera por lectura de páginas desde almacenamiento en la fase de tickets. En las dos repeticiones ya no se reportaron lecturas físicas. Por eso el salto de 12.53 a 4.20–4.88 segundos no corresponde a un cambio adicional del código.

### Resultado específico del ajuste de V5

| Métrica | V4 | V5 |
|---|---:|---:|
| Ordenamiento interno final `Sort` | Presente | Ausente |
| Memoria concedida al SELECT final | 395,008 KiB | 0 KiB |
| Lecturas de la temporal en el SELECT final | 869 | 10,025 |
| Filas entregadas en página 1 | 10,000 | 10,000 |
| Total de registros y páginas | 22,943 y 3 | 22,943 y 3 |

V4 creó el índice temporal, pero SQL Server no lo eligió para paginar. V5 utiliza `WITH (INDEX(IX_TicketItems_IdRow))` solo en el SELECT final; el plan lee ese índice y recupera las columnas restantes mediante búsquedas en la temporal. El intercambio observado es más lecturas a cambio de eliminar la concesión de memoria del ordenamiento final.

Los 0 KiB corresponden únicamente a ese SELECT: la fase de detalles todavía recibió 214,792 KiB, aproximadamente 210 MiB. No significa que todo el procedimiento utilice cero memoria. La construcción del índice temporal también forma parte del costo total.

En V5 la entrega final registró 2.879 segundos de `ASYNC_NETWORK_IO`, esperando que el cliente consumiera resultados. El ajuste de SQL no demuestra una mejora en la red o en la aplicación. La pequeña diferencia de duración entre V4 y V5 no basta para afirmar una reducción estable de latencia.

## Versión candidata y trabajo pendiente

**Tickets V5 es la candidata para validación, no un despliegue definitivo.** No se ha medido aún su comportamiento con diez solicitudes simultáneas ni se ha comprobado la igualdad completa de los resultados de todas las páginas.

Antes de adoptarla:

- Validar páginas 2 y 3 desde la aplicación. Con los mismos datos estables y tamaño 10,000, se esperan 10,000 y 2,943 filas.
- Comprobar que `IdRow` es único en el resultado o definir un desempate si otros joins lo repiten.
- Revisar omisiones y repeticiones entre páginas; si se actualiza `ExternalId` mientras se pagina, el conjunto cambia y `OFFSET` puede saltar pendientes.
- Medir concurrencia y costo del índice forzado con tamaños y números de página representativos.

## Archivos del repositorio

| Archivo | Propósito |
|---|---|
| [Diagnóstico](Diagnostico_IntegrationCRMTickets.sql) | Consultas de solo lectura para vista, índices y tipos |
| [Base con fecha del movimiento](Sp_Sel_IntegrationCRMTickets_v2_fecha_mov_prueba.sql) | Referencia con la fecha confirmada; conserva la vista y `NOLOCK` |
| [Tickets V3](Sp_Sel_IntegrationCRMTickets_v3_prueba.sql) | Materialización por etapas, sin vista de correos |
| [Tickets V4](Sp_Sel_IntegrationCRMTickets_v4_prueba.sql) | Prueba del índice temporal sin forzar su uso |
| [Tickets V5](Sp_Sel_IntegrationCRMTickets_v5_prueba.sql) | Candidata con uso explícito del índice final |

Los scripts de prueba apuntan a `SFranquicias_TarjetasCopy`. Los planes y las salidas originales fueron proporcionados por Luis y analizados desde sus archivos locales; no se incorporan a Git en esta publicación. El [informe anterior](INFORME_RESULTADOS_Y_TIEMPOS.md) corresponde a Movimientos y sus tiempos no deben sumarse como si fueran mediciones de Tickets.
