# Hallazgos de Auditoría — RetailPro S.A.S.

**Fecha:** 2024-01-15
**Analista:** Data Analytics Team
**Alcance:** Sistema transaccional PostgreSQL — Sep–Oct 2023

---

## 1. Resumen Ejecutivo

La auditoría de calidad de datos del sistema transaccional de RetailPro S.A.S. identificó
**7 categorías de problemas** que afectan la integridad, exactitud y completitud de los datos.

### Data Quality Score Global: **79.0%**

| Tabla | Total Registros | c/ Problemas | Score |
|-------|----------------|--------------|-------|
| customers | 35 | 6 | 82.9% |
| orders | 44 | 10 | 77.3% |
| payments | 40 | 4 | 90.0% |

> **Interpretación:** El 21% de los registros del sistema presentan al menos un problema
> de calidad de datos detectable con las queries de auditoría.

---

## 2. Problemas Detectados

### 2.1 Emails Duplicados [ERROR-1]

| Métrica | Valor |
|---------|-------|
| Emails duplicados encontrados | 3 |
| Registros afectados | 6 clientes |
| % del total de clientes | 17.1% |

**Detalle:**
- `alejandro.martinez@gmail.com` → 2 registros (IDs: 1, 26)
- `sofia.lopez@gmail.com` → 2 registros (IDs: 4, 27)
- `isabella.herrera@gmail.com` → 2 registros (IDs: 6, 28)

**Riesgo:** Duplicación de campañas de marketing, historial de compras fragmentado,
posibilidad de fraude por cuentas duplicadas.

---

### 2.2 Órdenes Sin Cliente Válido [ERROR-2]

| Métrica | Valor |
|---------|-------|
| Órdenes con customer_id inexistente | 3 |
| % del total de órdenes | 6.8% |
| customer_ids inválidos | 999, 1000, 888 |

**Riesgo:** Ingresos no asociados a ningún cliente real. Imposibilidad de auditoría
de trazabilidad cliente → pedido → pago.

---

### 2.3 Diferencia Monetaria [ERROR-3]

| Métrica | Valor |
|---------|-------|
| Órdenes con desajuste | 4 |
| Discrepancia total | COP 700,000 |
| Underpaid (déficit) | COP 450,000 |
| Overpaid (exceso — pasivo) | COP 250,000 |

**Detalle por orden:**

| Order ID | Monto Orden | Monto Pagado | Diferencia | Tipo |
|----------|-------------|--------------|------------|------|
| 29 | COP 980,000 | COP 750,000 | -COP 230,000 | Underpaid |
| 30 | COP 1,200,000 | COP 1,450,000 | +COP 250,000 | Overpaid |
| 31 | COP 680,000 | COP 500,000 | -COP 180,000 | Underpaid |
| 32 | COP 420,000 | COP 380,000 | -COP 40,000 | Underpaid |

---

### 2.4 Pagos Huérfanos [ERROR-4]

| Métrica | Valor |
|---------|-------|
| Pagos sin orden válida | 4 |
| Monto no conciliado | COP 1,615,000 |

**Detalle:** Pagos con order_id 5000, 6000, 7777, 8888 que no existen en la tabla `orders`.
Estos fondos no pueden reconciliarse con ningún pedido del sistema.

---

### 2.5 Órdenes Completadas Sin Pago [ERROR-5]

| Métrica | Valor |
|---------|-------|
| Órdenes completadas sin pago | 4 |
| Revenue at Risk | COP 5,250,000 |

**Detalle:**
- Order 19: COP 2,200,000
- Order 20: COP 1,950,000
- Order 21: COP 680,000
- Order 22: COP 420,000

**Riesgo:** Ingresos registrados en el sistema que nunca fueron cobrados. Mayor fuente
individual de revenue at risk.

---

### 2.6 Campos Críticos Nulos [ERROR-6]

| Campo | Registros Afectados |
|-------|---------------------|
| customers.name | 2 |
| customers.email | 1 |
| orders.total_amount | 3 |

**Riesgo:** Imposibilidad de identificar clientes, calcular ingresos reales,
o ejecutar reportes financieros correctos.

---

### 2.7 Órdenes para Productos Inactivos [ERROR-7]

| Métrica | Valor |
|---------|-------|
| Órdenes para productos descontinuados | 3 |
| Monto total involucrado | COP 2,970,000 |

**Productos inactivos vendidos:**
- Laptop Dell Inspiron 15 DISC (product_id=16): COP 2,200,000
- Router TP-Link Archer DISC (product_id=18): COP 320,000
- Altavoz Bluetooth JBL DISC (product_id=19): COP 450,000

---

## 3. Impacto Financiero

Ver [financial_impact.md](financial_impact.md) para análisis completo.

| Categoría | Monto (COP) |
|-----------|-------------|
| Órdenes completadas sin pago | 5,250,000 |
| Pagos huérfanos no conciliados | 1,615,000 |
| Underpaid (déficit de cobro) | 450,000 |
| Overpaid (pasivo — devolución) | 250,000 |
| **TOTAL REVENUE AT RISK** | **7,565,000** |

---

## 4. Riesgo Operativo

| Riesgo | Probabilidad | Impacto | Nivel |
|--------|-------------|---------|-------|
| Diferencias en cierre contable mensual | Alta | Alto | CRITICO |
| Fraude por cuentas de cliente duplicadas | Media | Medio | ALTO |
| Incumplimiento de obligaciones fiscales | Media | Alto | ALTO |
| Pérdida de trazabilidad auditable | Alta | Alto | CRITICO |
| Reputación ante clientes (cobros incorrectos) | Media | Alto | ALTO |

---

## 5. Recomendaciones Técnicas

### Inmediatas (0-30 días)
1. **Agregar restricción UNIQUE** en `customers.email` con manejo de duplicados existentes
2. **Agregar FK** `orders.customer_id REFERENCES customers(customer_id)`
3. **Agregar FK** `payments.order_id REFERENCES orders(order_id)`
4. **Agregar CHECK NOT NULL** en `customers.name` y `orders.total_amount`
5. **Trigger de validación**: impedir que `status='Completed'` si no existe pago asociado

### Corto plazo (30-90 días)
6. **Proceso de conciliación diaria**: job automático que compare `orders.total_amount` vs `SUM(payments.payment_amount)` y alerte discrepancias
7. **Validación de producto activo**: constraint o trigger que impida orders con `products.active = FALSE`
8. **Dashboard de monitoreo** en Power BI con alertas cuando el Data Quality Score caiga por debajo de 95%

### Mediano plazo (90-180 días)
9. **Data governance**: definir propietarios de datos por tabla
10. **Proceso ETL de limpieza**: script Python programado para detección y reporte automático de anomalías

---

## 6. Plan de Mejora

| Fase | Acción | Responsable | Plazo |
|------|--------|-------------|-------|
| 1 | Corregir registros duplicados manualmente | DBA | Semana 1 |
| 2 | Implementar constraints en BD | DBA | Semana 2 |
| 3 | Diseñar triggers de validación | Dev Backend | Semana 3-4 |
| 4 | Automatizar reporte diario de calidad | Analytics | Mes 2 |
| 5 | Publicar dashboard Power BI con alertas | Analytics | Mes 2-3 |
| 6 | Capacitación a equipo de ingreso de datos | RRHH | Mes 3 |
| 7 | Auditoría de seguimiento (re-evaluación) | Auditoría | Mes 6 |
