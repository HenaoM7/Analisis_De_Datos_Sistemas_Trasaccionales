-- =============================================================================
-- RetailPro S.A.S. - Sistema Transaccional
-- Script 02: Datos de Prueba con Errores Intencionales
-- Autor: Data Analytics Team
-- Fecha: 2024-01-15
--
-- ERRORES INTENCIONALES EMBEBIDOS (etiquetados para trazabilidad):
--   [ERROR-1] Emails duplicados en customers
--   [ERROR-2] Orders con customer_id inexistente (violacion referencial)
--   [ERROR-3] total_amount != payment_amount (diferencia monetaria)
--   [ERROR-4] Payments con order_id inexistente (pago huerfano)
--   [ERROR-5] Orders status='Completed' sin ningun pago asociado
--   [ERROR-6] NULL en campos criticos (name, total_amount)
--   [ERROR-7] Orders para productos con active=FALSE (descontinuados)
-- =============================================================================

-- =============================================================================
-- SECCION 1: CUSTOMERS (35 filas — incluye duplicados y NULLs)
-- =============================================================================
INSERT INTO customers (name, email, created_at) VALUES
-- Clientes legitimos (customer_id 1-25)
('Alejandro Martinez',    'alejandro.martinez@gmail.com',   '2023-01-10 08:30:00'),
('Valentina Torres',      'valentina.torres@hotmail.com',   '2023-01-15 09:00:00'),
('Carlos Ramirez',        'carlos.ramirez@outlook.com',     '2023-01-20 11:00:00'),
('Sofia Lopez',           'sofia.lopez@gmail.com',          '2023-02-01 10:30:00'),
('Andres Gomez',          'andres.gomez@yahoo.com',         '2023-02-10 14:00:00'),
('Isabella Herrera',      'isabella.herrera@gmail.com',     '2023-02-15 16:00:00'),
('Juan Pablo Vargas',     'jp.vargas@empresa.co',           '2023-03-01 08:00:00'),
('Mariana Castillo',      'mariana.castillo@gmail.com',     '2023-03-05 09:30:00'),
('Felipe Mendoza',        'felipe.mendoza@hotmail.com',     '2023-03-10 12:00:00'),
('Daniela Rios',          'daniela.rios@outlook.com',       '2023-03-15 15:00:00'),
('Santiago Pena',         'santiago.pena@gmail.com',        '2023-04-01 08:00:00'),
('Camila Ortega',         'camila.ortega@yahoo.com',        '2023-04-05 10:00:00'),
('Julian Reyes',          'julian.reyes@empresa.co',        '2023-04-10 11:30:00'),
('Laura Morales',         'laura.morales@gmail.com',        '2023-04-15 14:00:00'),
('Nicolas Parra',         'nicolas.parra@hotmail.com',      '2023-04-20 16:30:00'),
('Maria Jose Suarez',     'mj.suarez@gmail.com',            '2023-05-01 09:00:00'),
('Diego Fernandez',       'diego.fernandez@outlook.com',    '2023-05-05 10:30:00'),
('Gabriela Silva',        'gabriela.silva@gmail.com',       '2023-05-10 12:00:00'),
('Sebastian Cruz',        'sebastian.cruz@yahoo.com',       '2023-05-15 14:30:00'),
('Ana Lucia Varon',       'ana.varon@empresa.co',           '2023-05-20 16:00:00'),
('Ricardo Molina',        'ricardo.molina@gmail.com',       '2023-06-01 08:30:00'),
('Natalia Ospina',        'natalia.ospina@hotmail.com',     '2023-06-05 10:00:00'),
('Esteban Munoz',         'esteban.munoz@gmail.com',        '2023-06-10 11:30:00'),
('Paola Aguilar',         'paola.aguilar@outlook.com',      '2023-06-15 14:00:00'),
('Cristian Lozano',       'cristian.lozano@gmail.com',      '2023-06-20 16:30:00'),

-- [ERROR-1a] Email duplicado — mismo email que customer_id=1 (Alejandro Martinez)
('Alejandro M. Duplicado', 'alejandro.martinez@gmail.com',  '2023-07-01 09:00:00'),

-- [ERROR-1b] Email duplicado — mismo email que customer_id=4 (Sofia Lopez)
('Sofia Lopez Cuenta2',    'sofia.lopez@gmail.com',         '2023-07-05 10:00:00'),

-- [ERROR-1c] Email duplicado — mismo email que customer_id=6 (Isabella Herrera)
('Isabella H. Duplicada',  'isabella.herrera@gmail.com',    '2023-07-10 11:00:00'),

-- [ERROR-6a] NULL en campo critico: name
(NULL,                     'anonimo1@gmail.com',            '2023-07-15 12:00:00'),

-- [ERROR-6b] NULL en campos criticos: name y email
(NULL,                     NULL,                            '2023-07-20 13:00:00'),

-- Clientes adicionales legitimos (customer_id 31-35)
('Tatiana Bejarano',       'tatiana.bejarano@gmail.com',    '2023-08-01 08:00:00'),
('Mauricio Cardona',       'mauricio.cardona@outlook.com',  '2023-08-05 09:30:00'),
('Adriana Quintero',       'adriana.quintero@yahoo.com',    '2023-08-10 11:00:00'),
('Hernan Bedoya',          'hernan.bedoya@gmail.com',       '2023-08-15 14:00:00'),
('Claudia Espinosa',       'claudia.espinosa@hotmail.com',  '2023-08-20 16:00:00');


-- =============================================================================
-- SECCION 2: PRODUCTS (20 filas — incluye productos inactivos)
-- =============================================================================
INSERT INTO products (product_name, price, active) VALUES
-- Productos activos (product_id 1-15)
('Laptop Lenovo IdeaPad 15',         2850000.00, TRUE),
('Mouse Inalambrico Logitech M185',  45000.00,   TRUE),
('Teclado Mecanico Redragon K552',   189000.00,  TRUE),
('Monitor Samsung 24 FHD',           850000.00,  TRUE),
('Audifonos Sony WH-1000XM4',        1200000.00, TRUE),
('Webcam Logitech C920 HD',          380000.00,  TRUE),
('Disco SSD Samsung 1TB',            420000.00,  TRUE),
('Memoria RAM Kingston 16GB DDR4',   310000.00,  TRUE),
('Hub USB-C 7 en 1',                 125000.00,  TRUE),
('Cable HDMI 2.0 Premium 2m',        35000.00,   TRUE),
('Impresora HP LaserJet M107a',      680000.00,  TRUE),
('Tablet Samsung Galaxy A8',         980000.00,  TRUE),
('Cargador USB-C 65W GaN',           95000.00,   TRUE),
('Soporte Portatil Ajustable',       75000.00,   TRUE),
('Mousepad XL Gaming',               60000.00,   TRUE),

-- [ERROR-7] Productos INACTIVOS (descontinuados) — apareceran en ordenes
('Laptop Dell Inspiron 15 DISC',     2200000.00, FALSE),  -- product_id=16
('Proyector Epson X49 DISC',         1950000.00, FALSE),  -- product_id=17
('Router TP-Link Archer DISC',       320000.00,  FALSE),  -- product_id=18
('Altavoz Bluetooth JBL DISC',       450000.00,  FALSE),  -- product_id=19
('UPS 750VA APC DISC',               580000.00,  FALSE);  -- product_id=20


-- =============================================================================
-- SECCION 3: ORDERS (44 filas — incluye todos los tipos de error)
-- Columnas: (customer_id, product_id, order_date, status, total_amount)
-- =============================================================================
INSERT INTO orders (customer_id, product_id, order_date, status, total_amount) VALUES
-- Ordenes legitimas completadas (order_id 1-10) — pagos coinciden exactamente
(1,  1,  '2023-09-01 10:00:00', 'Completed',   2850000.00),
(2,  2,  '2023-09-02 11:00:00', 'Completed',   45000.00),
(3,  3,  '2023-09-03 12:00:00', 'Completed',   189000.00),
(4,  4,  '2023-09-04 13:00:00', 'Completed',   850000.00),
(5,  5,  '2023-09-05 14:00:00', 'Completed',   1200000.00),
(6,  6,  '2023-09-06 15:00:00', 'Completed',   380000.00),
(7,  7,  '2023-09-07 09:00:00', 'Completed',   420000.00),
(8,  8,  '2023-09-08 10:30:00', 'Completed',   310000.00),
(9,  9,  '2023-09-09 11:00:00', 'Completed',   125000.00),
(10, 11, '2023-09-10 14:00:00', 'Completed',   680000.00),

-- Ordenes legitimas en proceso o pendientes (order_id 11-15)
(11, 12, '2023-09-11 08:00:00', 'Pending',     980000.00),
(12, 13, '2023-09-12 09:00:00', 'Processing',  95000.00),
(13, 14, '2023-09-13 10:00:00', 'Pending',     75000.00),
(14, 15, '2023-09-14 11:00:00', 'Processing',  60000.00),
(15, 10, '2023-09-15 12:00:00', 'Cancelled',   35000.00),

-- [ERROR-2] Ordenes con customer_id INEXISTENTE (violacion integridad referencial)
(999,  4,  '2023-09-16 08:00:00', 'Completed', 450000.00),  -- order_id=16, cliente 999 no existe
(1000, 4,  '2023-09-17 09:00:00', 'Pending',   850000.00),  -- order_id=17, cliente 1000 no existe
(888,  8,  '2023-09-18 10:00:00', 'Completed', 310000.00),  -- order_id=18, cliente 888 no existe

-- [ERROR-5] Ordenes 'Completed' SIN ningun pago registrado
(16, 16, '2023-09-19 11:00:00', 'Completed',   2200000.00),  -- order_id=19
(17, 17, '2023-09-20 12:00:00', 'Completed',   1950000.00),  -- order_id=20
(18, 11, '2023-09-21 13:00:00', 'Completed',   680000.00),   -- order_id=21
(19, 7,  '2023-09-22 14:00:00', 'Completed',   420000.00),   -- order_id=22

-- [ERROR-6c] NULL en total_amount (campo critico)
(20, 1,  '2023-09-23 15:00:00', 'Completed',   NULL),        -- order_id=23
(21, 5,  '2023-09-24 09:00:00', 'Pending',     NULL),        -- order_id=24
(22, 4,  '2023-10-01 10:00:00', 'Completed',   NULL),        -- order_id=25

-- Ordenes legitimas adicionales completadas (order_id 26-28)
(23, 4,  '2023-10-02 11:00:00', 'Completed',   850000.00),
(24, 5,  '2023-10-03 12:00:00', 'Completed',   1200000.00),
(25, 8,  '2023-10-04 13:00:00', 'Completed',   310000.00),

-- [ERROR-3] Ordenes donde total_amount NO coincide con el pago recibido
(1,  12, '2023-10-05 14:00:00', 'Completed',   980000.00),   -- order_id=29, pago=750000 (underpaid -230000)
(3,  5,  '2023-10-06 15:00:00', 'Completed',   1200000.00),  -- order_id=30, pago=1450000 (overpaid +250000)
(5,  11, '2023-10-07 09:00:00', 'Completed',   680000.00),   -- order_id=31, pago=500000 (underpaid -180000)
(8,  7,  '2023-10-08 10:00:00', 'Completed',   420000.00),   -- order_id=32, pago=380000 (underpaid -40000)

-- Ordenes legitimas finales (order_id 33-41)
(11, 9,  '2023-10-09 11:00:00', 'Completed',   125000.00),
(12, 13, '2023-10-10 12:00:00', 'Completed',   95000.00),
(13, 14, '2023-10-11 13:00:00', 'Completed',   75000.00),
(14, 15, '2023-10-12 14:00:00', 'Completed',   60000.00),
(31, 4,  '2023-10-13 15:00:00', 'Pending',     850000.00),
(32, 1,  '2023-10-14 09:00:00', 'Processing',  2850000.00),
(33, 6,  '2023-10-15 10:00:00', 'Completed',   380000.00),
(34, 8,  '2023-10-16 11:00:00', 'Completed',   310000.00),
(35, 9,  '2023-10-17 12:00:00', 'Completed',   125000.00),

-- [ERROR-7] Ordenes para productos INACTIVOS (descontinuados)
(1,  16, '2023-10-18 13:00:00', 'Completed',   2200000.00),  -- order_id=42, product_id=16 (inactivo)
(2,  18, '2023-10-19 14:00:00', 'Completed',   320000.00),   -- order_id=43, product_id=18 (inactivo)
(3,  19, '2023-10-20 15:00:00', 'Completed',   450000.00);   -- order_id=44, product_id=19 (inactivo)


-- =============================================================================
-- SECCION 4: PAYMENTS (40 filas — incluye desajustes y pagos huerfanos)
-- =============================================================================
INSERT INTO payments (order_id, payment_date, payment_amount, payment_status) VALUES
-- Pagos legitimos para orders 1-10 (montos exactos)
(1,  '2023-09-01 10:15:00', 2850000.00, 'Paid'),
(2,  '2023-09-02 11:20:00', 45000.00,   'Paid'),
(3,  '2023-09-03 12:30:00', 189000.00,  'Paid'),
(4,  '2023-09-04 13:10:00', 850000.00,  'Paid'),
(5,  '2023-09-05 14:05:00', 1200000.00, 'Paid'),
(6,  '2023-09-06 15:15:00', 380000.00,  'Paid'),
(7,  '2023-09-07 09:20:00', 420000.00,  'Paid'),
(8,  '2023-09-08 10:45:00', 310000.00,  'Paid'),
(9,  '2023-09-09 11:10:00', 125000.00,  'Paid'),
(10, '2023-09-10 14:20:00', 680000.00,  'Paid'),

-- Pagos para orders 26-28 (legitimos)
(26, '2023-10-02 11:20:00', 850000.00,  'Paid'),
(27, '2023-10-03 12:30:00', 1200000.00, 'Paid'),
(28, '2023-10-04 13:10:00', 310000.00,  'Paid'),

-- Pagos para orders 33-41 (legitimos)
(33, '2023-10-09 11:20:00', 125000.00,  'Paid'),
(34, '2023-10-10 12:30:00', 95000.00,   'Paid'),
(35, '2023-10-11 13:10:00', 75000.00,   'Paid'),
(36, '2023-10-12 14:15:00', 60000.00,   'Paid'),
(39, '2023-10-15 10:20:00', 380000.00,  'Paid'),
(40, '2023-10-16 11:30:00', 310000.00,  'Paid'),
(41, '2023-10-17 12:10:00', 125000.00,  'Paid'),

-- Pagos para orders de productos inactivos (orders 42-44)
(42, '2023-10-18 13:20:00', 2200000.00, 'Paid'),
(43, '2023-10-19 14:15:00', 320000.00,  'Paid'),
(44, '2023-10-20 15:10:00', 450000.00,  'Paid'),

-- [ERROR-3] Pagos con montos QUE NO COINCIDEN con el total_amount de la orden
-- order_id=29: total=980000, pago=750000 (underpaid: -230000)
(29, '2023-10-05 14:20:00', 750000.00,  'Paid'),
-- order_id=30: total=1200000, pago=1450000 (overpaid: +250000)
(30, '2023-10-06 15:30:00', 1450000.00, 'Paid'),
-- order_id=31: total=680000, pago=500000 (underpaid: -180000)
(31, '2023-10-07 09:15:00', 500000.00,  'Paid'),
-- order_id=32: total=420000, pago=380000 (underpaid: -40000)
(32, '2023-10-08 10:20:00', 380000.00,  'Paid'),

-- Pagos con estado Failed (escenario legitimo de negocios)
(11, '2023-09-11 08:30:00', 980000.00,  'Failed'),
(12, '2023-09-12 09:15:00', 95000.00,   'Failed'),

-- Pagos con estado Pending
(13, '2023-09-13 10:10:00', 75000.00,   'Pending'),
(14, '2023-09-14 11:20:00', 60000.00,   'Pending'),

-- [ERROR-4] Pagos HUERFANOS — order_id inexistente en tabla orders
(5000, '2023-10-21 08:00:00', 150000.00, 'Paid'),     -- order 5000 no existe
(6000, '2023-10-22 09:00:00', 980000.00, 'Paid'),     -- order 6000 no existe
(7777, '2023-10-23 10:00:00', 420000.00, 'Pending'),  -- order 7777 no existe
(8888, '2023-10-24 11:00:00', 65000.00,  'Failed'),   -- order 8888 no existe

-- Pagos para orders huerfanas (orders 16-18, cuyo customer_id no existe)
(16, '2023-09-16 08:30:00', 450000.00,  'Paid'),
(17, '2023-09-17 09:15:00', 850000.00,  'Paid'),
(18, '2023-09-18 10:10:00', 310000.00,  'Paid');

-- =============================================================================
-- Resumen de datos insertados:
--   customers : 35 filas (25 legitimos + 3 duplicados + 2 NULL + 5 adicionales)
--   products  : 20 filas (15 activos + 5 inactivos [ERROR-7])
--   orders    : 44 filas (15 legitimas + 3 [ERROR-2] + 4 [ERROR-5] + 3 [ERROR-6] + 4 [ERROR-3] + 9 adicionales + 3 [ERROR-7] + 3 adicionales)
--   payments  : 40 filas (legitimos + 4 [ERROR-3] + 4 [ERROR-4] + estados mixed)
-- =============================================================================
