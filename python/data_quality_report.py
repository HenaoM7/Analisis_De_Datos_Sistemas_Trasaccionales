"""
data_quality_report.py
======================
RetailPro S.A.S. -- Data Quality Audit
Conecta a PostgreSQL y genera un reporte ejecutivo de KPIs directamente
en consola. Util para revision rapida antes de abrir Power BI.

Uso:
    py -3 python/data_quality_report.py

Variables de entorno (via archivo .env):
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
"""

import os
import sys
from datetime import datetime

import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Configuracion
# ---------------------------------------------------------------------------
load_dotenv()

DB_CONFIG = {
    "host":     os.getenv("DB_HOST",     "localhost"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "dbname":   os.getenv("DB_NAME",     "retailpro"),
    "user":     os.getenv("DB_USER",     "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

W = 72  # ancho del reporte


# ---------------------------------------------------------------------------
# Helpers de formato
# ---------------------------------------------------------------------------

def fmt_cop(value) -> str:
    if value is None:
        return "N/A"
    return f"$ {float(value):>15,.0f} COP"


def fmt_pct(value) -> str:
    if value is None:
        return "N/A"
    return f"{float(value):.2f}%"


def header(title: str) -> None:
    print()
    print("=" * W)
    print(f"  {title}")
    print("=" * W)


def subheader(title: str) -> None:
    print(f"\n  -- {title} --\n")


def kv(label: str, value, pad: int = 52) -> None:
    print(f"  {label:<{pad}} {value}")


# ---------------------------------------------------------------------------
# Conexion
# ---------------------------------------------------------------------------

def get_connection():
    try:
        return psycopg2.connect(
            **DB_CONFIG,
            cursor_factory=psycopg2.extras.RealDictCursor,
        )
    except psycopg2.OperationalError as exc:
        print(f"ERROR: No se pudo conectar a la BD -- {exc}", file=sys.stderr)
        sys.exit(1)


def q1(conn, sql: str) -> dict:
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone() or {}


def qall(conn, sql: str) -> list:
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchall() or []


# ---------------------------------------------------------------------------
# Secciones del reporte
# ---------------------------------------------------------------------------

def seccion_encabezado() -> None:
    print()
    print("=" * W)
    print("  RETAILPRO S.A.S. -- REPORTE DE AUDITORIA DE CALIDAD DE DATOS")
    print(f"  Generado: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * W)
    print()
    print("  Alcance : Sistema transaccional -- Customers, Products, Orders, Payments")
    print("  Periodo : Septiembre -- Octubre 2023")
    print("  Analista: Data Analytics Team")


def seccion_kpis(conn) -> None:
    header("SECCION 1 -- KPIs GENERALES")
    r = q1(conn, """
        SELECT
            (SELECT COUNT(*) FROM customers)                AS total_clientes,
            (SELECT COUNT(*) FROM products)                 AS total_productos,
            (SELECT COUNT(*) FROM orders)                   AS total_ordenes,
            (SELECT COUNT(*) FROM payments)                 AS total_pagos,
            (SELECT COALESCE(SUM(total_amount), 0)
             FROM orders WHERE status = 'Completed'
               AND total_amount IS NOT NULL)                AS ingresos_brutos_cop
    """)
    print()
    kv("Total Clientes",   r.get("total_clientes"))
    kv("Total Productos",  r.get("total_productos"))
    kv("Total Ordenes",    r.get("total_ordenes"))
    kv("Total Pagos",      r.get("total_pagos"))
    kv("Ingresos Brutos (ordenes completadas)", fmt_cop(r.get("ingresos_brutos_cop")))


def seccion_emails_duplicados(conn) -> None:
    header("SECCION 2 -- EMAILS DUPLICADOS  [ERROR-1]")
    r = q1(conn, """
        SELECT
            COUNT(*) AS total_clientes,
            SUM(CASE WHEN email IN (
                SELECT email FROM customers WHERE email IS NOT NULL
                GROUP BY email HAVING COUNT(*) > 1
            ) THEN 1 ELSE 0 END) AS afectados,
            ROUND(100.0 * SUM(CASE WHEN email IN (
                SELECT email FROM customers WHERE email IS NOT NULL
                GROUP BY email HAVING COUNT(*) > 1
            ) THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS pct
        FROM customers
    """)
    print()
    kv("Clientes totales",             r.get("total_clientes"))
    kv("Clientes con email duplicado", r.get("afectados"))
    kv("% afectados",                  fmt_pct(r.get("pct")))

    rows = qall(conn, """
        SELECT email, COUNT(*) AS n,
               STRING_AGG(name, ' | ' ORDER BY customer_id) AS nombres
        FROM customers WHERE email IS NOT NULL
        GROUP BY email HAVING COUNT(*) > 1
    """)
    if rows:
        subheader("Detalle")
        for row in rows:
            print(f"  Email: {row['email']}")
            print(f"    Ocurrencias : {row['n']}")
            print(f"    Nombres     : {row['nombres']}")
            print()


def seccion_integridad_referencial(conn) -> None:
    header("SECCION 3 -- INTEGRIDAD REFERENCIAL  [ERROR-2]")
    r = q1(conn, """
        SELECT COUNT(*) AS total_ordenes,
               SUM(CASE WHEN NOT EXISTS (
                   SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id
               ) THEN 1 ELSE 0 END) AS huerfanas
        FROM orders o
    """)
    pct = (float(r["huerfanas"]) / float(r["total_ordenes"]) * 100) if r["total_ordenes"] else 0
    print()
    kv("Ordenes totales",               r.get("total_ordenes"))
    kv("Ordenes sin cliente valido",    r.get("huerfanas"))
    kv("% ordenes sin cliente",         f"{pct:.2f}%")


def seccion_completadas_sin_pago(conn) -> None:
    header("SECCION 4 -- ORDENES COMPLETADAS SIN PAGO  [ERROR-5]")
    r = q1(conn, """
        SELECT COUNT(*) AS ordenes,
               COALESCE(SUM(total_amount), 0) AS revenue_at_risk
        FROM orders
        WHERE status = 'Completed'
          AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = orders.order_id)
    """)
    print()
    kv("Ordenes completadas sin pago", r.get("ordenes"))
    kv("Revenue at Risk",              fmt_cop(r.get("revenue_at_risk")))


def seccion_pagos_huerfanos(conn) -> None:
    header("SECCION 5 -- PAGOS HUERFANOS  [ERROR-4]")
    r = q1(conn, """
        SELECT COUNT(*) AS n, COALESCE(SUM(payment_amount), 0) AS monto
        FROM payments
        WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = payments.order_id)
    """)
    print()
    kv("Pagos sin orden valida",       r.get("n"))
    kv("Monto no conciliado",          fmt_cop(r.get("monto")))


def seccion_diferencia_monetaria(conn) -> None:
    header("SECCION 6 -- DIFERENCIA MONETARIA  [ERROR-3]")
    r = q1(conn, """
        SELECT COUNT(*) AS n,
               SUM(ABS(p.payment_amount - o.total_amount)) AS discrepancia_total,
               SUM(CASE WHEN p.payment_amount > o.total_amount
                        THEN p.payment_amount - o.total_amount ELSE 0 END) AS overpaid,
               SUM(CASE WHEN p.payment_amount < o.total_amount
                        THEN o.total_amount - p.payment_amount ELSE 0 END) AS underpaid
        FROM orders o
        JOIN payments p ON p.order_id = o.order_id
        WHERE p.payment_status = 'Paid'
          AND o.total_amount IS NOT NULL
          AND ABS(p.payment_amount - o.total_amount) > 0
    """)
    print()
    kv("Pagos con desajuste",          r.get("n"))
    kv("Discrepancia total",           fmt_cop(r.get("discrepancia_total")))
    kv("  Overpaid (pasivo)",          fmt_cop(r.get("overpaid")))
    kv("  Underpaid (deficit cobro)",  fmt_cop(r.get("underpaid")))


def seccion_campos_nulos(conn) -> None:
    header("SECCION 7 -- CAMPOS CRITICOS NULOS  [ERROR-6]")
    rows = qall(conn, """
        SELECT 'customers.name nulo'     AS campo, COUNT(*) AS n FROM customers WHERE name IS NULL
        UNION ALL
        SELECT 'customers.email nulo',    COUNT(*) FROM customers WHERE email IS NULL
        UNION ALL
        SELECT 'orders.total_amount nulo', COUNT(*) FROM orders WHERE total_amount IS NULL
        ORDER BY n DESC
    """)
    print()
    for row in rows:
        kv(row["campo"], row["n"])


def seccion_productos_inactivos(conn) -> None:
    header("SECCION 8 -- ORDENES PARA PRODUCTOS INACTIVOS  [ERROR-7]")
    r = q1(conn, """
        SELECT COUNT(*) AS n, COALESCE(SUM(o.total_amount), 0) AS monto
        FROM orders o JOIN products p ON p.product_id = o.product_id
        WHERE p.active = FALSE
    """)
    print()
    kv("Ordenes con producto inactivo", r.get("n"))
    kv("Monto total involucrado",       fmt_cop(r.get("monto")))


def seccion_quality_score(conn) -> None:
    header("SECCION 9 -- DATA QUALITY SCORE GLOBAL")
    rows = qall(conn, """
        SELECT nombre_tabla, total_registros, registros_con_problemas,
               ROUND(100.0 * registros_con_problemas / NULLIF(total_registros, 0), 2) AS pct,
               ROUND(100.0 - 100.0 * registros_con_problemas / NULLIF(total_registros, 0), 2) AS score
        FROM (
            SELECT 'customers' AS nombre_tabla,
                   (SELECT COUNT(*) FROM customers) AS total_registros,
                   (SELECT COUNT(*) FROM customers
                    WHERE name IS NULL OR (email IS NOT NULL AND email IN (
                        SELECT email FROM customers WHERE email IS NOT NULL
                        GROUP BY email HAVING COUNT(*) > 1))) AS registros_con_problemas
            UNION ALL
            SELECT 'orders',
                   (SELECT COUNT(*) FROM orders),
                   (SELECT COUNT(*) FROM orders
                    WHERE total_amount IS NULL
                       OR NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = orders.customer_id)
                       OR (status = 'Completed' AND NOT EXISTS (
                               SELECT 1 FROM payments p WHERE p.order_id = orders.order_id)))
            UNION ALL
            SELECT 'payments',
                   (SELECT COUNT(*) FROM payments),
                   (SELECT COUNT(*) FROM payments
                    WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = payments.order_id))
        ) t ORDER BY score ASC
    """)
    print()
    print(f"  {'Tabla':<15} {'Total':>8} {'c/Problemas':>12} {'% Problemas':>12} {'Score':>8}")
    print("  " + "-" * 60)
    scores = []
    for r in rows:
        score = float(r["score"]) if r["score"] else 100.0
        scores.append(score)
        print(f"  {r['nombre_tabla']:<15} {r['total_registros']:>8} "
              f"{r['registros_con_problemas']:>12} {fmt_pct(r['pct']):>12} {fmt_pct(r['score']):>8}")

    global_score = sum(scores) / len(scores) if scores else 100.0
    print()
    print(f"  {'DATA QUALITY SCORE GLOBAL':<40} {fmt_pct(global_score):>8}")
    print()
    print(f"  Interpretacion: {global_score:.1f}% de los registros estan libres de problemas detectados.")


def seccion_revenue_at_risk(conn) -> None:
    header("SECCION 10 -- REVENUE AT RISK CONSOLIDADO")
    rows = qall(conn, """
        SELECT 'Completadas sin pago'          AS categoria,
               COUNT(*) AS n,
               COALESCE(SUM(o.total_amount), 0) AS monto
        FROM orders o
        WHERE o.status = 'Completed'
          AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id)
        UNION ALL
        SELECT 'Underpaid (deficit cobro)', COUNT(*),
               SUM(o.total_amount - p.payment_amount)
        FROM orders o JOIN payments p ON p.order_id = o.order_id
        WHERE p.payment_status = 'Paid' AND o.total_amount IS NOT NULL
          AND p.payment_amount < o.total_amount
        UNION ALL
        SELECT 'Overpaid (pasivo devolucion)', COUNT(*),
               SUM(p.payment_amount - o.total_amount)
        FROM orders o JOIN payments p ON p.order_id = o.order_id
        WHERE p.payment_status = 'Paid' AND o.total_amount IS NOT NULL
          AND p.payment_amount > o.total_amount
        UNION ALL
        SELECT 'Pagos huerfanos', COUNT(*), SUM(payment_amount)
        FROM payments p
        WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = p.order_id)
        ORDER BY monto DESC
    """)
    print()
    total = 0.0
    for r in rows:
        monto = float(r["monto"]) if r["monto"] else 0.0
        total += monto
        kv(f"  {r['categoria']} ({r['n']} registros)", fmt_cop(monto))
    print()
    print("  " + "-" * 68)
    kv("  TOTAL REVENUE AT RISK", fmt_cop(total))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    conn = get_connection()
    try:
        seccion_encabezado()
        seccion_kpis(conn)
        seccion_emails_duplicados(conn)
        seccion_integridad_referencial(conn)
        seccion_completadas_sin_pago(conn)
        seccion_pagos_huerfanos(conn)
        seccion_diferencia_monetaria(conn)
        seccion_campos_nulos(conn)
        seccion_productos_inactivos(conn)
        seccion_quality_score(conn)
        seccion_revenue_at_risk(conn)
        print()
        print("=" * W)
        print("  Fin del reporte")
        print("=" * W)
        print()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
