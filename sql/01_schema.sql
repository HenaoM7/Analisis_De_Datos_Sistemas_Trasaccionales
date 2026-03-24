-- =============================================================================
-- RetailPro S.A.S. - Sistema Transaccional
-- Script 01: Definicion del Esquema (DDL)
-- Autor: Data Analytics Team
-- Fecha: 2024-01-15
-- Descripcion: Crea las tablas transaccionales base para la auditoria de
--              calidad de datos. Las FK se omiten intencionalmente a nivel
--              de BD (como ocurre en sistemas legacy reales) para permitir
--              la insercion de datos con errores de integridad referencial.
-- =============================================================================

-- Eliminar tablas en orden inverso a las dependencias para poder re-ejecutar
DROP TABLE IF EXISTS payments  CASCADE;
DROP TABLE IF EXISTS orders    CASCADE;
DROP TABLE IF EXISTS products  CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- -----------------------------------------------------------------------------
-- TABLA: customers
-- Clientes registrados en RetailPro S.A.S.
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id  SERIAL         PRIMARY KEY,
    name         VARCHAR(100),                     -- NULL permitido: objetivo de auditoria [ERROR-6]
    email        VARCHAR(150),                     -- NULL permitido: sin restriccion UNIQUE (objetivo auditoria [ERROR-1])
    created_at   TIMESTAMP      DEFAULT NOW()
);

COMMENT ON TABLE  customers           IS 'Clientes registrados en RetailPro S.A.S.';
COMMENT ON COLUMN customers.name      IS 'Nombre completo — campo critico, no debe ser NULL';
COMMENT ON COLUMN customers.email     IS 'Correo de contacto — deberia ser unico pero sin restriccion DB (objetivo auditoria)';

-- -----------------------------------------------------------------------------
-- TABLA: products
-- Catalogo de productos de RetailPro S.A.S.
-- -----------------------------------------------------------------------------
CREATE TABLE products (
    product_id   SERIAL          PRIMARY KEY,
    product_name VARCHAR(150)    NOT NULL,
    price        NUMERIC(10, 2)  NOT NULL,
    active       BOOLEAN         DEFAULT TRUE
);

COMMENT ON TABLE  products         IS 'Catalogo de productos de RetailPro S.A.S.';
COMMENT ON COLUMN products.active  IS 'FALSE = producto descontinuado. Ordenes sobre productos inactivos son objetivo de auditoria [ERROR-7]';

-- -----------------------------------------------------------------------------
-- TABLA: orders
-- Pedidos de clientes.
-- NOTA: customer_id y product_id son enteros simples sin FK a nivel de BD.
-- Esto permite insertar ordenes con clientes/productos inexistentes para auditoria.
-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id      SERIAL          PRIMARY KEY,
    customer_id   INTEGER,                         -- Sin REFERENCES (objetivo auditoria [ERROR-2])
    product_id    INTEGER,                         -- Sin REFERENCES (requerido para query [ERROR-7])
    order_date    TIMESTAMP,
    status        VARCHAR(20)     CHECK (status IN ('Pending', 'Processing', 'Completed', 'Cancelled')),
    total_amount  NUMERIC(10, 2)                   -- NULL permitido: objetivo de auditoria [ERROR-6]
);

COMMENT ON TABLE  orders              IS 'Pedidos de compra de clientes';
COMMENT ON COLUMN orders.customer_id  IS 'Referencia a customers.customer_id — sin FK a nivel DB (auditoria)';
COMMENT ON COLUMN orders.product_id   IS 'Referencia a products.product_id — sin FK a nivel DB (auditoria)';
COMMENT ON COLUMN orders.total_amount IS 'Monto total del pedido — campo critico, no debe ser NULL';

-- -----------------------------------------------------------------------------
-- TABLA: payments
-- Pagos asociados a pedidos.
-- NOTA: order_id es un entero simple sin FK a nivel de BD.
-- -----------------------------------------------------------------------------
CREATE TABLE payments (
    payment_id      SERIAL          PRIMARY KEY,
    order_id        INTEGER,                       -- Sin REFERENCES (objetivo auditoria [ERROR-4])
    payment_date    TIMESTAMP,
    payment_amount  NUMERIC(10, 2),
    payment_status  VARCHAR(20)     CHECK (payment_status IN ('Paid', 'Failed', 'Pending'))
);

COMMENT ON TABLE  payments                IS 'Pagos asociados a pedidos';
COMMENT ON COLUMN payments.order_id       IS 'Referencia a orders.order_id — sin FK a nivel DB (auditoria)';
COMMENT ON COLUMN payments.payment_status IS 'Paid=confirmado | Failed=rechazado | Pending=en espera';

-- =============================================================================
-- Fin del script 01_schema.sql
-- Siguiente paso: ejecutar 02_seed_data.sql
-- =============================================================================
