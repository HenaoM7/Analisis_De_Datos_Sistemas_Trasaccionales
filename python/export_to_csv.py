"""
export_to_csv.py
================
RetailPro S.A.S. -- Data Quality Audit
Conecta a PostgreSQL, ejecuta cada query de auditoria y exporta los
resultados como archivos CSV a data/processed/ para consumo en Power BI.

Uso:
    py -3 python/export_to_csv.py

Requisitos:
    pip install -r requirements.txt

Variables de entorno (via archivo .env):
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
"""

import os
import sys
import logging
from datetime import datetime
from pathlib import Path

import psycopg2
import pandas as pd
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Configuracion
# ---------------------------------------------------------------------------
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)

DB_CONFIG = {
    "host":     os.getenv("DB_HOST",     "localhost"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "dbname":   os.getenv("DB_NAME",     "retailpro"),
    "user":     os.getenv("DB_USER",     "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR   = PROJECT_ROOT / "data" / "processed"

# ---------------------------------------------------------------------------
# Queries de auditoria
# Cada entrada: nombre_archivo -> query SQL
# ---------------------------------------------------------------------------
AUDIT_QUERIES = {

    "01_emails_duplicados": """
        SELECT
            email,
            COUNT(*)                                        AS total_ocurrencias,
            COUNT(*) - 1                                    AS duplicados_extra,
            STRING_AGG(customer_id::TEXT, ', '
                       ORDER BY customer_id)                AS customer_ids,
            MIN(created_at)                                 AS primer_registro,
            MAX(created_at)                                 AS ultimo_duplicado
        FROM customers
        WHERE email IS NOT NULL
        GROUP BY email
        HAVING COUNT(*) > 1
        ORDER BY total_ocurrencias DESC
    """,

    "02_ordenes_sin_cliente": """
        SELECT
            o.order_id,
            o.customer_id                                   AS customer_id_referenciado,
            o.order_date,
            o.status,
            o.total_amount,
            'Cliente no existe'                              AS descripcion_problema
        FROM orders o
        WHERE NOT EXISTS (
            SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id
        )
        ORDER BY o.order_id
    """,

    "03_completadas_sin_pago": """
        SELECT
            o.order_id,
            o.customer_id,
            c.name                                          AS nombre_cliente,
            o.order_date,
            o.total_amount,
            'Completada sin pago'                            AS descripcion_problema
        FROM orders o
        LEFT JOIN customers c ON c.customer_id = o.customer_id
        WHERE o.status = 'Completed'
          AND NOT EXISTS (
              SELECT 1 FROM payments p WHERE p.order_id = o.order_id
          )
        ORDER BY o.total_amount DESC NULLS LAST
    """,

    "04_pagos_huerfanos": """
        SELECT
            p.payment_id,
            p.order_id                                      AS order_id_referenciado,
            p.payment_date,
            p.payment_amount,
            p.payment_status,
            'Orden no existe'                                AS descripcion_problema
        FROM payments p
        WHERE NOT EXISTS (
            SELECT 1 FROM orders o WHERE o.order_id = p.order_id
        )
        ORDER BY p.payment_amount DESC
    """,

    "05_diferencia_monetaria": """
        SELECT
            o.order_id,
            o.customer_id,
            c.name                                          AS nombre_cliente,
            o.order_date,
            o.total_amount                                  AS monto_orden,
            p.payment_amount                                AS monto_pagado,
            (p.payment_amount - o.total_amount)             AS discrepancia_cop,
            CASE
                WHEN p.payment_amount > o.total_amount THEN 'Overpaid'
                WHEN p.payment_amount < o.total_amount THEN 'Underpaid'
            END                                             AS tipo_discrepancia,
            ROUND(
                ABS(p.payment_amount - o.total_amount) /
                NULLIF(o.total_amount, 0) * 100, 2
            )                                               AS discrepancia_pct
        FROM orders o
        JOIN payments p       ON p.order_id    = o.order_id
        LEFT JOIN customers c ON c.customer_id = o.customer_id
        WHERE p.payment_status = 'Paid'
          AND o.total_amount IS NOT NULL
          AND ABS(p.payment_amount - o.total_amount) > 0
        ORDER BY ABS(p.payment_amount - o.total_amount) DESC
    """,

    "06_revenue_at_risk": """
        SELECT 'Completadas sin pago'               AS categoria_riesgo,
               COUNT(*)                             AS registros_afectados,
               COALESCE(SUM(o.total_amount), 0)    AS monto_riesgo_cop
        FROM orders o
        WHERE o.status = 'Completed'
          AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id)
        UNION ALL
        SELECT 'Underpaid (deficit cobro)',
               COUNT(*),
               SUM(o.total_amount - p.payment_amount)
        FROM orders o JOIN payments p ON p.order_id = o.order_id
        WHERE p.payment_status = 'Paid' AND o.total_amount IS NOT NULL
          AND p.payment_amount < o.total_amount
        UNION ALL
        SELECT 'Overpaid (pasivo devolucion)',
               COUNT(*),
               SUM(p.payment_amount - o.total_amount)
        FROM orders o JOIN payments p ON p.order_id = o.order_id
        WHERE p.payment_status = 'Paid' AND o.total_amount IS NOT NULL
          AND p.payment_amount > o.total_amount
        UNION ALL
        SELECT 'Pagos huerfanos no conciliados',
               COUNT(*),
               SUM(payment_amount)
        FROM payments p
        WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = p.order_id)
        ORDER BY monto_riesgo_cop DESC
    """,

    "07_data_quality_score": """
        SELECT
            nombre_tabla,
            total_registros,
            registros_con_problemas,
            ROUND(100.0 * registros_con_problemas
                  / NULLIF(total_registros, 0), 2)          AS pct_con_problemas,
            ROUND(100.0 - 100.0 * registros_con_problemas
                  / NULLIF(total_registros, 0), 2)          AS quality_score
        FROM (
            SELECT 'customers' AS nombre_tabla,
                   (SELECT COUNT(*) FROM customers)         AS total_registros,
                   (SELECT COUNT(*) FROM customers
                    WHERE name IS NULL
                       OR (email IS NOT NULL AND email IN (
                           SELECT email FROM customers
                           WHERE email IS NOT NULL
                           GROUP BY email HAVING COUNT(*) > 1
                       ))
                   )                                        AS registros_con_problemas
            UNION ALL
            SELECT 'orders',
                   (SELECT COUNT(*) FROM orders),
                   (SELECT COUNT(*) FROM orders
                    WHERE total_amount IS NULL
                       OR NOT EXISTS (SELECT 1 FROM customers c
                                      WHERE c.customer_id = orders.customer_id)
                       OR (status = 'Completed' AND NOT EXISTS (
                               SELECT 1 FROM payments p
                               WHERE p.order_id = orders.order_id))
                   )
            UNION ALL
            SELECT 'payments',
                   (SELECT COUNT(*) FROM payments),
                   (SELECT COUNT(*) FROM payments
                    WHERE NOT EXISTS (SELECT 1 FROM orders o
                                      WHERE o.order_id = payments.order_id)
                   )
        ) resumen
        ORDER BY quality_score ASC
    """,

    "08_campos_nulos_criticos": """
        SELECT 'customers.name nulo'          AS verificacion,
               COUNT(*)                       AS registros_afectados
        FROM customers WHERE name IS NULL
        UNION ALL
        SELECT 'customers.email nulo',         COUNT(*) FROM customers WHERE email IS NULL
        UNION ALL
        SELECT 'orders.total_amount nulo',     COUNT(*) FROM orders WHERE total_amount IS NULL
        ORDER BY registros_afectados DESC
    """,

    "09_ordenes_producto_inactivo": """
        SELECT
            o.order_id,
            o.customer_id,
            c.name                                          AS nombre_cliente,
            o.order_date,
            o.status,
            o.total_amount,
            pr.product_id,
            pr.product_name,
            pr.price                                        AS precio_producto,
            'Producto descontinuado'                         AS descripcion_problema
        FROM orders o
        JOIN products pr       ON pr.product_id  = o.product_id
        LEFT JOIN customers c  ON c.customer_id  = o.customer_id
        WHERE pr.active = FALSE
        ORDER BY o.order_date DESC
    """,

    "10_auditoria_consolidada": """
        SELECT
            o.order_id,
            o.customer_id,
            c.name                                          AS nombre_cliente,
            o.order_date,
            o.status,
            o.total_amount,
            COALESCE(p.payment_amount, 0)                  AS monto_pagado,
            pr.product_name,
            pr.active                                       AS producto_activo,
            CASE WHEN NOT EXISTS (SELECT 1 FROM customers cx
                                  WHERE cx.customer_id = o.customer_id)
                 THEN 1 ELSE 0 END                         AS flag_cliente_inexistente,
            CASE WHEN o.status = 'Completed'
                  AND NOT EXISTS (SELECT 1 FROM payments px
                                  WHERE px.order_id = o.order_id)
                 THEN 1 ELSE 0 END                         AS flag_sin_pago,
            CASE WHEN p.payment_id IS NOT NULL
                  AND o.total_amount IS NOT NULL
                  AND ABS(p.payment_amount - o.total_amount) > 0
                 THEN 1 ELSE 0 END                         AS flag_monto_desajustado,
            CASE WHEN o.total_amount IS NULL THEN 1 ELSE 0 END AS flag_total_nulo,
            CASE WHEN pr.active = FALSE THEN 1 ELSE 0 END  AS flag_producto_inactivo,
            CASE WHEN p.payment_id IS NOT NULL AND o.total_amount IS NOT NULL
                 THEN (p.payment_amount - o.total_amount) ELSE NULL
            END                                             AS discrepancia_cop
        FROM orders o
        LEFT JOIN customers c  ON c.customer_id = o.customer_id
        LEFT JOIN payments p   ON p.order_id    = o.order_id
                               AND p.payment_status = 'Paid'
        LEFT JOIN products pr  ON pr.product_id = o.product_id
        ORDER BY o.order_id
    """,
}


# ---------------------------------------------------------------------------
# Funciones
# ---------------------------------------------------------------------------

def get_connection():
    logger.info("Conectando a PostgreSQL: %(host)s:%(port)s/%(dbname)s", DB_CONFIG)
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        logger.info("Conexion establecida correctamente.")
        return conn
    except psycopg2.OperationalError as exc:
        logger.error("No se pudo conectar a la base de datos: %s", exc)
        sys.exit(1)


def run_query(conn, query: str) -> pd.DataFrame:
    return pd.read_sql_query(query, conn)


def export_to_csv(df: pd.DataFrame, filename_stem: str) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp   = datetime.now().strftime("%Y%m%d")
    output_path = OUTPUT_DIR / f"{filename_stem}_{timestamp}.csv"
    df.to_csv(output_path, index=False, encoding="utf-8-sig")
    return output_path


def run_all_exports() -> dict:
    conn    = get_connection()
    results = {}

    logger.info("Iniciando exportacion de %d queries...", len(AUDIT_QUERIES))

    for name, query in AUDIT_QUERIES.items():
        try:
            logger.info("Ejecutando: %s", name)
            df   = run_query(conn, query)
            path = export_to_csv(df, name)
            results[name] = {"rows": len(df), "path": path, "status": "OK"}
            logger.info("  -> %d filas exportadas a %s", len(df), path.name)
        except Exception as exc:
            logger.error("  -> ERROR: %s", exc)
            results[name] = {"rows": 0, "path": None, "status": f"ERROR: {exc}"}

    conn.close()
    logger.info("Exportacion completa. Conexion cerrada.")
    return results


def print_summary(results: dict) -> None:
    print("\n" + "=" * 72)
    print("  RESUMEN EXPORTACION -- RetailPro S.A.S. Data Quality Audit")
    print("=" * 72)
    print(f"  {'Query':<45} {'Filas':>6}  Status")
    print("  " + "-" * 68)
    for name, info in results.items():
        filas  = str(info["rows"]) if info["rows"] else "-"
        status = info["status"]
        print(f"  {name:<45} {filas:>6}  {status}")
    print("=" * 72)
    failed = [n for n, i in results.items() if i["status"] != "OK"]
    if failed:
        print(f"\n  ADVERTENCIA: {len(failed)} query(s) fallaron: {', '.join(failed)}")
    else:
        print(f"\n  Todas las {len(results)} queries exportadas correctamente.")
    print(f"  Directorio de salida: {OUTPUT_DIR}\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    results = run_all_exports()
    print_summary(results)
