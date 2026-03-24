# Impacto Financiero — RetailPro S.A.S.

**Fecha de análisis:** 2024-01-15
**Período analizado:** Septiembre — Octubre 2023
**Moneda:** Pesos Colombianos (COP)

---

## Resumen Ejecutivo

La auditoría identificó un **Revenue at Risk total de COP $7,565,000** en un período de dos meses.
Proyectado anualmente, esto representa aproximadamente **COP $45,390,000** (≈ USD 11,350) en
ingresos potencialmente comprometidos por problemas de calidad de datos.

---

## Desglose por Categoría

### 1. Órdenes Completadas Sin Pago Registrado

```sql
-- Query de soporte
SELECT COUNT(*), COALESCE(SUM(total_amount), 0)
FROM orders
WHERE status = 'Completed'
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = orders.order_id);
```

| Order ID | Customer | Monto (COP) |
|----------|----------|-------------|
| 19 | customer_id=16 | 2,200,000 |
| 20 | customer_id=17 | 1,950,000 |
| 21 | customer_id=18 | 680,000 |
| 22 | customer_id=19 | 420,000 |
| **TOTAL** | | **5,250,000** |

**Interpretación:** Estas órdenes están marcadas como entregadas/completadas en el sistema
pero no tienen ningún pago asociado. El sistema reporta el ingreso, pero el dinero nunca
fue recibido o no fue registrado correctamente.

---

### 2. Pagos No Conciliados (Pagos Huérfanos)

```sql
-- Query de soporte
SELECT COUNT(*), SUM(payment_amount)
FROM payments
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = payments.order_id);
```

| Payment ID | Order ID (inválido) | Monto (COP) | Estado |
|------------|---------------------|-------------|--------|
| 33 | 5000 | 150,000 | Paid |
| 34 | 6000 | 980,000 | Paid |
| 35 | 7777 | 420,000 | Pending |
| 36 | 8888 | 65,000 | Failed |
| **TOTAL** | | **1,615,000** | |

**Interpretación:** Estos pagos existen en el sistema pero no corresponden a ninguna orden.
Los pagos con estado `Paid` (COP $1,130,000) representan dinero recibido que no puede
atribuirse a ninguna venta — posible error de digitación o registro en sistema incorrecto.

---

### 3. Desajuste Monetario (Underpaid — Déficit de Cobro)

```sql
-- Query de soporte
SELECT SUM(o.total_amount - p.payment_amount)
FROM orders o JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'Paid'
  AND o.total_amount IS NOT NULL
  AND p.payment_amount < o.total_amount;
```

| Order ID | Monto Orden | Monto Pagado | Déficit (COP) |
|----------|-------------|--------------|----------------|
| 29 | 980,000 | 750,000 | **230,000** |
| 31 | 680,000 | 500,000 | **180,000** |
| 32 | 420,000 | 380,000 | **40,000** |
| **TOTAL** | | | **450,000** |

**Interpretación:** El cliente pagó menos de lo que debía. El ingreso registrado en la orden
es mayor al dinero realmente recibido.

---

### 4. Desajuste Monetario (Overpaid — Pasivo de Devolución)

```sql
-- Query de soporte
SELECT SUM(p.payment_amount - o.total_amount)
FROM orders o JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'Paid'
  AND o.total_amount IS NOT NULL
  AND p.payment_amount > o.total_amount;
```

| Order ID | Monto Orden | Monto Pagado | Exceso (COP) |
|----------|-------------|--------------|--------------|
| 30 | 1,200,000 | 1,450,000 | **250,000** |
| **TOTAL** | | | **250,000** |

**Interpretación:** El cliente pagó más de lo que debía. La empresa tiene un pasivo
(obligación de devolución) de COP $250,000 que no está registrado en los libros.

---

## Consolidado de Revenue at Risk

| Categoría | Registros | Monto (COP) | % del Total |
|-----------|-----------|-------------|-------------|
| Órdenes completadas sin pago | 4 | 5,250,000 | 69.4% |
| Pagos huérfanos no conciliados | 4 | 1,615,000 | 21.4% |
| Underpaid (déficit de cobro) | 3 | 450,000 | 5.9% |
| Overpaid (pasivo — devolución) | 1 | 250,000 | 3.3% |
| **TOTAL** | **12** | **7,565,000** | **100%** |

---

## Proyección Anual

| Escenario | Base de cálculo | Monto Anual (COP) |
|-----------|----------------|-------------------|
| Optimista | Solo período analizado × 6 | 45,390,000 |
| Moderado | Crecimiento 20% trimestral | 58,500,000 |
| Conservador | Igual al período × 12 | 90,780,000 |

> **Nota:** Estos son estimados indicativos basados únicamente en el período analizado
> (2 meses). Un análisis histórico completo requeriría datos de los últimos 12 meses.

---

## Cálculo del Data Quality Score

```
Data Quality Score = 100 - (% de registros con al menos un problema)
```

| Tabla | Total | c/Problemas | Score |
|-------|-------|-------------|-------|
| customers | 35 | 6 | 82.9% |
| orders | 44 | 10 | 77.3% |
| payments | 40 | 4 | 90.0% |
| **Global** | **119** | **20** | **83.2%** |

**Interpretación:** Un score de **83.2%** significa que aproximadamente **1 de cada 6 registros**
del sistema transaccional presenta algún problema de calidad detectable.

Para cumplir estándares financieros, el objetivo debería ser alcanzar un **score ≥ 98%**.

---

## Costo Estimado de Corrección vs. Costo de No Corrección

| Concepto | Estimado (COP) |
|----------|----------------|
| Corrección técnica (DBA + Dev, 2 semanas) | 4,000,000 |
| Pérdida anual proyectada sin corrección | 45,390,000 |
| **ROI de implementar controles** | **>11x** |

> Implementar los controles técnicos recomendados tiene un retorno estimado de más de
> 11 veces la inversión en el primer año.
