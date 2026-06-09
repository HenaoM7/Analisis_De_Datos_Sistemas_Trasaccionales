# Data Quality Audit — Transactional System

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)

---

## Resumen Ejecutivo

Auditoría integral de calidad de datos sobre el sistema transaccional de **RetailPro S.A.S.**,
empresa ficticia del sector retail colombiano. Se simuló un sistema real con errores intencionales,
se diseñaron queries SQL de detección, se cuantificó el impacto financiero y se propusieron
controles preventivos a nivel de base de datos.

**Resultado clave:** Se identificó un **Revenue at Risk de COP $7,565,000** en dos meses,
con un **Data Quality Score global de 83.2%** — equivalente a 1 de cada 6 registros con problemas.

---

## Arquitectura del Proyecto

```
PostgreSQL (fuente de datos)
        |
        +-- sql/01_schema.sql        (DDL: creación de tablas)
        +-- sql/02_seed_data.sql     (datos con errores intencionales)
        +-- sql/03_data_quality_checks.sql  (9 queries de auditoría)
        |
        v
Python (psycopg2 + pandas)
        |
        +-- python/export_to_csv.py       (exporta 10 CSVs a data/processed/)
        +-- python/data_quality_report.py (reporte KPIs en consola)
        |
        v
Power BI
        |
        +-- powerbi/Data_Quality_Dashboard.pbix
        |   (conecta a data/processed/ o directo a PostgreSQL)
        |
        v
Documentación
        +-- docs/business_problem.md
        +-- docs/findings.md
        +-- docs/financial_impact.md
```

---

## Errores de Datos Simulados

| Código | Problema | Registros | Impacto Financiero (COP) |
|--------|----------|-----------|--------------------------|
| ERROR-1 | Emails duplicados en customers | 6 clientes | — |
| ERROR-2 | Orders con customer_id inexistente | 3 órdenes | — |
| ERROR-3 | total_amount != payment_amount | 4 órdenes | 700,000 |
| ERROR-4 | Pagos sin order_id válido (huérfanos) | 4 pagos | 1,615,000 |
| ERROR-5 | Orders Completed sin ningún pago | 4 órdenes | 5,250,000 |
| ERROR-6 | NULL en campos críticos | 6 registros | — |
| ERROR-7 | Orders para productos inactivos | 3 órdenes | 2,970,000 |

---

## Data Quality Score

| Tabla | Total | c/Problemas | Score |
|-------|-------|-------------|-------|
| customers | 35 | 6 | 82.9% |
| orders | 44 | 10 | 77.3% |
| payments | 40 | 4 | 90.0% |
| **Global** | **119** | **20** | **83.2%** |

---

## Revenue at Risk

| Categoria | Registros | Monto (COP) |
|-----------|-----------|-------------|
| Completadas sin pago | 4 | 5,250,000 |
| Pagos huerfanos | 4 | 1,615,000 |
| Underpaid (deficit cobro) | 3 | 450,000 |
| Overpaid (pasivo devolucion) | 1 | 250,000 |
| **TOTAL** | **12** | **7,565,000** |

---

## Queries SQL Destacadas

### Ordenes Completadas Sin Pago
```sql
SELECT o.order_id, o.total_amount
FROM orders o
WHERE o.status = 'Completed'
  AND NOT EXISTS (
      SELECT 1 FROM payments p WHERE p.order_id = o.order_id
  );
```

### Data Quality Score por Tabla
```sql
SELECT
    nombre_tabla,
    ROUND(100.0 - 100.0 * registros_con_problemas / total_registros, 2) AS quality_score
FROM ( ... ) resumen;
```

### Revenue at Risk Consolidado
```sql
SELECT 'Completadas sin pago' AS categoria,
       SUM(total_amount) AS monto_riesgo_cop
FROM orders
WHERE status = 'Completed'
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = orders.order_id)
UNION ALL
-- ... (ver sql/03_data_quality_checks.sql, Query 6)
```

---

## Estructura del Repositorio

```
data-quality-audit-transactional-system/
├── data/
│   ├── raw/                 # Datos fuente originales
│   └── processed/           # CSVs exportados por Python (para Power BI)
├── sql/
│   ├── 01_schema.sql        # DDL: creación de tablas
│   ├── 02_seed_data.sql     # Datos con errores intencionales
│   └── 03_data_quality_checks.sql  # 9 queries de auditoría
├── python/
│   ├── export_to_csv.py     # Exporta resultados a CSV
│   └── data_quality_report.py      # Reporte KPIs en consola
├── powerbi/
│   └── Data_Quality_Dashboard.pbix # Dashboard Power BI
├── docs/
│   ├── business_problem.md  # Contexto y problema de negocio
│   ├── findings.md          # Hallazgos detallados
│   └── financial_impact.md  # Análisis de impacto financiero
├── .env.example             # Plantilla de variables de entorno
├── .gitignore
├── requirements.txt
└── README.md
```

---

## Setup e Instalación

### Prerrequisitos
- PostgreSQL 14+
- Python 3.9+
- Power BI Desktop (para el dashboard)

### 1. Clonar el repositorio
```bash
git clone https://github.com/HenaoM7/Analisis_De_Datos_Sistemas_Trasaccionales.git
cd Analisis_De_Datos_Sistemas_Trasaccionales
```

### 2. Configurar la base de datos
```bash
# Crear la base de datos
createdb retailpro

# Ejecutar scripts SQL en orden
psql -d retailpro -f sql/01_schema.sql
psql -d retailpro -f sql/02_seed_data.sql

# Ejecutar queries de auditoría
psql -d retailpro -f sql/03_data_quality_checks.sql
```

### 3. Configurar Python
```bash
# Instalar dependencias
pip install -r requirements.txt

# Copiar plantilla de configuración
cp .env.example .env
# Editar .env con tus credenciales de PostgreSQL
```

### 4. Ejecutar el reporte en consola
```bash
py -3 python/data_quality_report.py
```

### 5. Exportar CSVs para Power BI
```bash
py -3 python/export_to_csv.py
# Los CSVs se generan en data/processed/
```

### 6. Abrir el dashboard en Power BI
- Abrir `powerbi/Data_Quality_Dashboard.pbix`
- Actualizar la fuente de datos apuntando a `data/processed/` o
  conectar directamente a PostgreSQL

---

## Insights Clave

1. **La mayor fuente de riesgo** son las órdenes marcadas como "Completed" sin ningún pago
   registrado — representan el **69.4%** del revenue at risk total.

2. **El sistema no tiene FK a nivel de BD**, lo que permite insertar registros huérfanos.
   Implementar constraints reduciría el ~28% de los problemas detectados.

3. **La falta de unicidad en email** crea clientes duplicados que fragmentan el historial
   de compras y complican campañas de CRM.

4. **Proyección anual:** Si estos patrones se mantienen, el impacto estimado supera
   **COP $45 millones** anuales — con un costo de corrección de menos de COP $4 millones.

---

## Documentación Completa

- [Problema de Negocio](docs/business_problem.md)
- [Hallazgos Detallados](docs/findings.md)
- [Impacto Financiero](docs/financial_impact.md)

---

## Habilidades Demostradas

- Diseño de esquemas relacionales en **PostgreSQL** con comentarios profesionales
- Escritura de **queries SQL avanzadas** (CTEs, subqueries correlacionadas, UNION ALL, EXISTS)
- Automatización con **Python** (psycopg2, pandas, dotenv, logging)
- Cuantificación de **impacto financiero** de problemas de calidad de datos
- Pensamiento analítico orientado a **decisiones de negocio**
- Documentación técnica y ejecutiva de nivel profesional

---

> *"No solo detecté errores en los datos — cuantifiqué el impacto financiero
> y propuse controles preventivos a nivel de base de datos."*
