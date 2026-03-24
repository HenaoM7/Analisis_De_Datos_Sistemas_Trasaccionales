# Power BI — Guia de Configuracion

## Opcion 1: Conectar a PostgreSQL (recomendado para datos en tiempo real)

1. Abrir Power BI Desktop
2. **Inicio > Obtener datos > Base de datos > PostgreSQL**
3. Ingresar:
   - Servidor: `localhost` (o el host de tu BD)
   - Base de datos: `retailpro`
4. Autenticarse con usuario y contraseña de PostgreSQL
5. Seleccionar las tablas: `customers`, `products`, `orders`, `payments`

### Crear las vistas de auditoria directamente

En Power BI, usar **Nueva tabla** con la siguiente M Query para cada resultado:

```
= Value.NativeQuery(
    PostgreSQL.Database("localhost", "retailpro"),
    "SELECT ... FROM orders WHERE ...",
    null,
    [EnableFolding=true]
)
```

---

## Opcion 2: Conectar a CSV (sin necesidad de PostgreSQL activo)

1. Ejecutar primero: `py -3 python/export_to_csv.py`
2. Los archivos se generan en `data/processed/`
3. En Power BI: **Inicio > Obtener datos > Texto/CSV**
4. Importar cada archivo:

| Archivo CSV | Descripcion |
|-------------|-------------|
| `01_emails_duplicados_YYYYMMDD.csv` | Clientes con email duplicado |
| `02_ordenes_sin_cliente_YYYYMMDD.csv` | Violaciones de integridad referencial |
| `03_completadas_sin_pago_YYYYMMDD.csv` | Revenue at risk — ordenes sin pago |
| `04_pagos_huerfanos_YYYYMMDD.csv` | Pagos no conciliados |
| `05_diferencia_monetaria_YYYYMMDD.csv` | Desajustes Overpaid / Underpaid |
| `06_revenue_at_risk_YYYYMMDD.csv` | Consolidado financiero |
| `07_data_quality_score_YYYYMMDD.csv` | Score por tabla |
| `08_campos_nulos_criticos_YYYYMMDD.csv` | Campos NULL |
| `09_ordenes_producto_inactivo_YYYYMMDD.csv` | Productos descontinuados |
| `10_auditoria_consolidada_YYYYMMDD.csv` | Vista completa para tabla detalle |

---

## Estructura del Dashboard (sugerida)

### Pagina 1: Resumen Ejecutivo
- **KPI Card:** Data Quality Score Global (83.2%)
- **KPI Card:** Revenue at Risk Total (COP 7,565,000)
- **KPI Card:** Total Registros con Problemas (20)
- **KPI Card:** % Registros Inconsistentes (16.8%)
- **Grafico de barras:** Revenue at Risk por categoria

### Pagina 2: Detalle por Tipo de Error
- **Segmentador:** filtro por tipo de problema
- **Grafico de dona:** distribucion de errores por tabla
- **Tabla detalle:** `10_auditoria_consolidada.csv` con formato condicional

### Pagina 3: Analisis Financiero
- **Grafico de barras apiladas:** Overpaid vs Underpaid por orden
- **Linea de tendencia:** errores por fecha de orden
- **Tabla:** comparativo monto_orden vs monto_pagado

### Pagina 4: Calidad por Tabla
- **Grafico de barras horizontales:** quality_score por tabla
- **Indicador tipo gauge:** score global vs objetivo (98%)

---

## Medidas DAX Clave

```dax
-- Revenue at Risk Total
Revenue at Risk =
SUMX(
    FILTER('06_revenue_at_risk', TRUE()),
    '06_revenue_at_risk'[monto_riesgo_cop]
)

-- Data Quality Score Global
Quality Score Global =
AVERAGE('07_data_quality_score'[quality_score])

-- % Registros con Problemas
Pct Problemas =
DIVIDE(
    SUMX('07_data_quality_score', '07_data_quality_score'[registros_con_problemas]),
    SUMX('07_data_quality_score', '07_data_quality_score'[total_registros]),
    0
) * 100
```

---

## Formato Condicional en Tabla de Auditoria

En la columna `flag_sin_pago`, `flag_cliente_inexistente`, etc.:
- Valor = 1 → fondo **rojo** (#FF4444)
- Valor = 0 → fondo **verde** (#44CC44)

Esto visualiza de inmediato qué registros tienen problemas.
