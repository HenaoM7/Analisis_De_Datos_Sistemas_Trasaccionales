-- =============================================================================
-- RetailPro S.A.S. - Sistema Transaccional
-- Script 03: Auditoria de Calidad de Datos
-- Autor: Data Analytics Team
-- Fecha: 2024-01-15
-- Descripcion: 9 bloques de analisis con detalle y metricas resumidas.
--              Los resultados alimentan el dashboard de Power BI y los
--              scripts Python de exportacion.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Emails Duplicados — Integridad de Identidad de Clientes
-- Hallazgo esperado: 3 emails duplicados, 6 registros afectados
-- KPI: % de clientes con email duplicado
-- =============================================================================

-- 1a. Detalle: que emails estan duplicados y cuantas veces
SELECT
    email,
    COUNT(*)                                            AS total_ocurrencias,
    COUNT(*) - 1                                        AS duplicados_extra,
    STRING_AGG(customer_id::TEXT, ', ' ORDER BY customer_id) AS customer_ids,
    STRING_AGG(name,              ', ' ORDER BY customer_id) AS nombres,
    MIN(created_at)                                     AS primer_registro,
    MAX(created_at)                                     AS ultimo_duplicado_creado
FROM customers
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY total_ocurrencias DESC;

-- 1b. Metrica resumen: % de registros afectados
SELECT
    COUNT(*)                                            AS total_clientes,
    SUM(CASE WHEN email IN (
        SELECT email FROM customers
        WHERE email IS NOT NULL
        GROUP BY email
        HAVING COUNT(*) > 1
    ) THEN 1 ELSE 0 END)                               AS clientes_con_email_duplicado,
    ROUND(
        100.0 * SUM(CASE WHEN email IN (
            SELECT email FROM customers
            WHERE email IS NOT NULL
            GROUP BY email
            HAVING COUNT(*) > 1
        ) THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2
    )                                                   AS pct_email_duplicado
FROM customers;


-- =============================================================================
-- QUERY 2: Integridad Referencial — Ordenes Sin Cliente Valido
-- Hallazgo esperado: 3 ordenes con customer_id 999, 1000, 888
-- KPI: # y % de ordenes huerfanas
-- =============================================================================

-- 2a. Detalle
SELECT
    o.order_id,
    o.customer_id                                       AS customer_id_referenciado,
    o.order_date,
    o.status,
    o.total_amount,
    'Cliente no existe en tabla customers'               AS descripcion_problema
FROM orders o
WHERE NOT EXISTS (
    SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id
)
ORDER BY o.order_id;

-- 2b. Metrica resumen
SELECT
    COUNT(*)                                            AS total_ordenes,
    SUM(CASE WHEN NOT EXISTS (
        SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id
    ) THEN 1 ELSE 0 END)                               AS ordenes_sin_cliente,
    ROUND(100.0 * SUM(CASE WHEN NOT EXISTS (
        SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id
    ) THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2)    AS pct_ordenes_sin_cliente
FROM orders o;


-- =============================================================================
-- QUERY 3: Ordenes Completadas Sin Pago
-- Hallazgo esperado: 4 ordenes completadas sin ningun pago (order_id 19-22)
-- KPI: # de ordenes | Revenue at Risk en COP
-- =============================================================================

-- 3a. Detalle
SELECT
    o.order_id,
    o.customer_id,
    c.name                                              AS nombre_cliente,
    o.order_date,
    o.total_amount,
    'Completada sin pago registrado'                     AS descripcion_problema
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status = 'Completed'
  AND NOT EXISTS (
      SELECT 1 FROM payments p WHERE p.order_id = o.order_id
  )
ORDER BY o.total_amount DESC NULLS LAST;

-- 3b. Revenue at risk
SELECT
    COUNT(*)                                            AS ordenes_sin_pago,
    COALESCE(SUM(o.total_amount), 0)                   AS revenue_at_risk_cop,
    COALESCE(AVG(o.total_amount), 0)                   AS valor_promedio_orden_cop
FROM orders o
WHERE o.status = 'Completed'
  AND NOT EXISTS (
      SELECT 1 FROM payments p WHERE p.order_id = o.order_id
  );


-- =============================================================================
-- QUERY 4: Pagos Huerfanos — Pagos Sin Orden Valida
-- Hallazgo esperado: 4 pagos con order_id 5000, 6000, 7777, 8888
-- KPI: # de pagos huerfanos | Monto no conciliado
-- =============================================================================

-- 4a. Detalle
SELECT
    p.payment_id,
    p.order_id                                          AS order_id_referenciado,
    p.payment_date,
    p.payment_amount,
    p.payment_status,
    'Orden no existe en tabla orders'                    AS descripcion_problema
FROM payments p
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.order_id = p.order_id
)
ORDER BY p.payment_amount DESC;

-- 4b. Metrica resumen
SELECT
    COUNT(*)                                            AS pagos_huerfanos,
    SUM(payment_amount)                                 AS monto_no_conciliado_cop
FROM payments p
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.order_id = p.order_id
);


-- =============================================================================
-- QUERY 5: Diferencia Monetaria — total_amount != payment_amount
-- Hallazgo esperado: 4 ordenes con desajuste (orders 29-32)
-- KPI: # de desajustes | Discrepancia total | Overpaid vs Underpaid
-- =============================================================================

-- 5a. Detalle con tipo de discrepancia y porcentaje
SELECT
    o.order_id,
    o.customer_id,
    c.name                                              AS nombre_cliente,
    o.order_date,
    o.total_amount                                      AS monto_orden,
    p.payment_amount                                    AS monto_pagado,
    (p.payment_amount - o.total_amount)                 AS discrepancia_cop,
    CASE
        WHEN p.payment_amount > o.total_amount THEN 'Overpaid (exceso)'
        WHEN p.payment_amount < o.total_amount THEN 'Underpaid (deficit)'
    END                                                 AS tipo_discrepancia,
    ROUND(
        ABS(p.payment_amount - o.total_amount) /
        NULLIF(o.total_amount, 0) * 100, 2
    )                                                   AS discrepancia_pct
FROM orders o
JOIN payments p       ON p.order_id    = o.order_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE p.payment_status = 'Paid'
  AND o.total_amount IS NOT NULL
  AND ABS(p.payment_amount - o.total_amount) > 0
ORDER BY ABS(p.payment_amount - o.total_amount) DESC;

-- 5b. Resumen financiero
SELECT
    COUNT(*)                                                                AS pagos_con_desajuste,
    SUM(ABS(p.payment_amount - o.total_amount))                            AS discrepancia_total_cop,
    SUM(CASE WHEN p.payment_amount > o.total_amount
             THEN p.payment_amount - o.total_amount ELSE 0 END)            AS total_overpaid_cop,
    SUM(CASE WHEN p.payment_amount < o.total_amount
             THEN o.total_amount - p.payment_amount ELSE 0 END)            AS total_underpaid_cop
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'Paid'
  AND o.total_amount IS NOT NULL
  AND ABS(p.payment_amount - o.total_amount) > 0;


-- =============================================================================
-- QUERY 6: Revenue at Risk Total — Consolidado por Categoria
-- Agrega todas las fuentes de riesgo financiero en una sola vista ejecutiva
-- =============================================================================
SELECT
    'Ordenes completadas sin pago'                      AS categoria_riesgo,
    COUNT(*)                                            AS registros_afectados,
    COALESCE(SUM(o.total_amount), 0)                   AS monto_riesgo_cop
FROM orders o
WHERE o.status = 'Completed'
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id)

UNION ALL

SELECT
    'Ordenes underpaid (deficit de cobro)',
    COUNT(*),
    SUM(o.total_amount - p.payment_amount)
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'Paid'
  AND o.total_amount IS NOT NULL
  AND p.payment_amount < o.total_amount

UNION ALL

SELECT
    'Ordenes overpaid (pasivo — devolucion pendiente)',
    COUNT(*),
    SUM(p.payment_amount - o.total_amount)
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'Paid'
  AND o.total_amount IS NOT NULL
  AND p.payment_amount > o.total_amount

UNION ALL

SELECT
    'Pagos huerfanos no conciliados',
    COUNT(*),
    SUM(payment_amount)
FROM payments p
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = p.order_id)

ORDER BY monto_riesgo_cop DESC;


-- =============================================================================
-- QUERY 7: Data Quality Score Global
-- Formula por tabla: score = 100 - (% registros con al menos un problema)
-- Metrica ejecutiva: un solo numero por tabla
-- =============================================================================
SELECT
    nombre_tabla,
    total_registros,
    registros_con_problemas,
    ROUND(100.0 * registros_con_problemas / NULLIF(total_registros, 0), 2) AS pct_con_problemas,
    ROUND(100.0 - (100.0 * registros_con_problemas / NULLIF(total_registros, 0)), 2) AS quality_score
FROM (
    -- Customers: problemas = name NULL o email duplicado
    SELECT
        'customers'                                         AS nombre_tabla,
        (SELECT COUNT(*) FROM customers)                    AS total_registros,
        (SELECT COUNT(*) FROM customers
         WHERE name IS NULL
            OR (email IS NOT NULL AND email IN (
                SELECT email FROM customers
                WHERE email IS NOT NULL
                GROUP BY email HAVING COUNT(*) > 1
            ))
        )                                                   AS registros_con_problemas

    UNION ALL

    -- Orders: problemas = total_amount NULL, cliente inexistente, o completada sin pago
    SELECT
        'orders',
        (SELECT COUNT(*) FROM orders),
        (SELECT COUNT(*) FROM orders
         WHERE total_amount IS NULL
            OR NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = orders.customer_id)
            OR (status = 'Completed' AND NOT EXISTS (
                    SELECT 1 FROM payments p WHERE p.order_id = orders.order_id))
        )

    UNION ALL

    -- Payments: problemas = orden inexistente
    SELECT
        'payments',
        (SELECT COUNT(*) FROM payments),
        (SELECT COUNT(*) FROM payments
         WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = payments.order_id)
        )

) resumen
ORDER BY quality_score ASC;


-- =============================================================================
-- QUERY 8: Campos Criticos Nulos
-- Hallazgo esperado: 2 customers sin name, 3 orders sin total_amount
-- =============================================================================

-- 8a. Clientes con campos criticos nulos
SELECT
    customer_id,
    name,
    email,
    created_at,
    CASE
        WHEN name IS NULL AND email IS NULL THEN 'Falta nombre y email'
        WHEN name IS NULL                   THEN 'Falta nombre'
        WHEN email IS NULL                  THEN 'Falta email'
    END                                                 AS campos_nulos
FROM customers
WHERE name IS NULL OR email IS NULL
ORDER BY customer_id;

-- 8b. Ordenes con total_amount nulo
SELECT
    order_id,
    customer_id,
    order_date,
    status,
    'total_amount es NULL'                               AS descripcion_problema
FROM orders
WHERE total_amount IS NULL
ORDER BY order_id;

-- 8c. Resumen de todos los campos nulos criticos
SELECT 'customers.name nulo'        AS verificacion, COUNT(*) AS registros_afectados FROM customers WHERE name IS NULL
UNION ALL
SELECT 'customers.email nulo',       COUNT(*) FROM customers WHERE email IS NULL
UNION ALL
SELECT 'orders.total_amount nulo',   COUNT(*) FROM orders WHERE total_amount IS NULL
UNION ALL
SELECT 'orders.order_date nulo',     COUNT(*) FROM orders WHERE order_date IS NULL
UNION ALL
SELECT 'payments.payment_amount nulo', COUNT(*) FROM payments WHERE payment_amount IS NULL
ORDER BY registros_afectados DESC;


-- =============================================================================
-- QUERY 9: Ordenes Para Productos Inactivos (Descontinuados)
-- Hallazgo esperado: 3 ordenes con product_id 16, 18, 19 (active=FALSE)
-- KPI: # de ordenes | monto total involucrado
-- =============================================================================

-- 9a. Detalle
SELECT
    o.order_id,
    o.customer_id,
    c.name                                              AS nombre_cliente,
    o.order_date,
    o.status,
    o.total_amount,
    pr.product_id,
    pr.product_name,
    pr.price                                            AS precio_producto,
    pr.active,
    'Orden para producto descontinuado'                  AS descripcion_problema
FROM orders o
JOIN products pr       ON pr.product_id   = o.product_id
LEFT JOIN customers c  ON c.customer_id   = o.customer_id
WHERE pr.active = FALSE
ORDER BY o.order_date DESC;

-- 9b. Metrica resumen
SELECT
    COUNT(*)                                            AS ordenes_producto_inactivo,
    COALESCE(SUM(o.total_amount), 0)                   AS monto_total_cop
FROM orders o
JOIN products pr ON pr.product_id = o.product_id
WHERE pr.active = FALSE;


-- =============================================================================
-- VISTA CONSOLIDADA: Todos los problemas en una sola tabla
-- Util para Power BI — tabla de detalle de auditoria completa
-- =============================================================================
SELECT
    o.order_id,
    o.customer_id,
    c.name                                              AS nombre_cliente,
    o.order_date,
    o.status,
    o.total_amount,
    COALESCE(p.payment_amount, 0)                       AS monto_pagado,
    pr.product_name,
    pr.active                                           AS producto_activo,

    -- Flags de problema (1=tiene problema, 0=ok)
    CASE WHEN NOT EXISTS (SELECT 1 FROM customers cx WHERE cx.customer_id = o.customer_id)
         THEN 1 ELSE 0 END                              AS flag_cliente_inexistente,

    CASE WHEN o.status = 'Completed'
          AND NOT EXISTS (SELECT 1 FROM payments px WHERE px.order_id = o.order_id)
         THEN 1 ELSE 0 END                              AS flag_sin_pago,

    CASE WHEN p.payment_id IS NOT NULL
          AND o.total_amount IS NOT NULL
          AND ABS(p.payment_amount - o.total_amount) > 0
         THEN 1 ELSE 0 END                              AS flag_monto_desajustado,

    CASE WHEN o.total_amount IS NULL
         THEN 1 ELSE 0 END                              AS flag_total_nulo,

    CASE WHEN pr.active = FALSE
         THEN 1 ELSE 0 END                              AS flag_producto_inactivo,

    -- Discrepancia monetaria
    CASE WHEN p.payment_id IS NOT NULL AND o.total_amount IS NOT NULL
         THEN (p.payment_amount - o.total_amount) ELSE NULL
    END                                                 AS discrepancia_cop

FROM orders o
LEFT JOIN customers c  ON c.customer_id = o.customer_id
LEFT JOIN payments p   ON p.order_id    = o.order_id AND p.payment_status = 'Paid'
LEFT JOIN products pr  ON pr.product_id = o.product_id
ORDER BY o.order_id;

-- =============================================================================
-- Fin del script 03_data_quality_checks.sql
-- =============================================================================
