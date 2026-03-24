# Problema de Negocio — RetailPro S.A.S.

## Empresa

**RetailPro S.A.S.** es una empresa colombiana del sector retail que opera un sistema transaccional
para la gestión de clientes, productos, pedidos y pagos. Con más de 35,000 transacciones mensuales,
la precisión de los datos es crítica para los reportes financieros a la junta directiva.

---

## Situación Detectada

El equipo de Auditoría Interna detectó **diferencias recurrentes** entre:

- Los ingresos registrados en el sistema transaccional (PostgreSQL)
- Los reportes financieros oficiales presentados a la junta directiva

La diferencia promedio mensual fue de aproximadamente **COP 8.5 millones**, sin una causa
claramente identificada.

---

## Hipótesis de Trabajo

| # | Hipótesis | Impacto estimado |
|---|-----------|-----------------|
| H1 | Pagos no asociados correctamente a pedidos (pagos huérfanos) | Medio |
| H2 | Transacciones duplicadas a nivel de clientes (emails duplicados) | Bajo-Medio |
| H3 | Registros incompletos (campos críticos nulos) | Alto |
| H4 | Fallas de integridad referencial (órdenes sin cliente válido) | Alto |
| H5 | Órdenes marcadas como completadas sin ningún pago | Alto |
| H6 | Desajustes entre el monto del pedido y el monto del pago | Alto |
| H7 | Ventas de productos descontinuados por falta de controles | Medio |

---

## Alcance del Análisis

**Tablas analizadas:**
- `customers` — 35 registros
- `products` — 20 registros
- `orders` — 44 registros
- `payments` — 40 registros

**Periodo:** Septiembre 2023 — Octubre 2023

**Metodología:**
1. Análisis SQL directo sobre la base de datos transaccional
2. Exportación de resultados a CSV para visualización en Power BI
3. Cuantificación del impacto financiero de cada tipo de error
4. Generación de reporte ejecutivo con recomendaciones técnicas

---

## Stakeholders

| Rol | Interés principal |
|-----|-------------------|
| Junta Directiva | Impacto financiero y riesgo operativo |
| Gerencia Financiera | Reconciliación de ingresos |
| Gerencia de TI | Causas técnicas y correcciones |
| Auditoría Interna | Evidencia y control interno |

---

## Criterio de Éxito

El proyecto se considerará exitoso si:

1. Se identifican y cuantifican **todos** los tipos de errores de calidad de datos
2. Se calcula un **Data Quality Score** por tabla y global
3. Se estima el **Revenue at Risk** en COP con respaldo de queries SQL
4. Se propone un **Plan de Mejora** con controles preventivos a nivel de BD
