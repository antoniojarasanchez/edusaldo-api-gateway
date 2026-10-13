-- =============================================================================
-- EduSaldo · MS Compras (Puerto 8085)
-- Base de Datos: db_compras · Variante B
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_compras 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE db_compras;

-- Tabla: proveedores
CREATE TABLE IF NOT EXISTS proveedores (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rut VARCHAR(12) NOT NULL UNIQUE,
    razon_social VARCHAR(150) NOT NULL,
    giro VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
    -- Datos bancarios
    banco VARCHAR(100) NOT NULL,
    tipo_cuenta VARCHAR(50) NOT NULL,
    numero_cuenta VARCHAR(50) NOT NULL,
    titular_cuenta VARCHAR(150) NOT NULL,
    rut_titular VARCHAR(12) NOT NULL,
    -- Contacto atomizado
    contacto_primer_nombre VARCHAR(100) NULL,
    contacto_segundo_nombre VARCHAR(100) NULL,
    contacto_primer_apellido VARCHAR(100) NULL,
    contacto_segundo_apellido VARCHAR(100) NULL,
    contacto_correo VARCHAR(150) NULL,
    contacto_telefono VARCHAR(30) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: ordenes_compra
CREATE TABLE IF NOT EXISTS ordenes_compra (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    proveedor_id BIGINT NOT NULL,
    numero VARCHAR(50) NOT NULL UNIQUE,
    fecha_emision DATE NOT NULL,
    emitida_por_id BIGINT NOT NULL, -- Ref escalar a MS Auth
    estado VARCHAR(30) NOT NULL DEFAULT 'EMITIDA',
    fecha_cancelacion DATETIME NULL,
    cancelada_por_id BIGINT NULL,
    motivo_cancelacion VARCHAR(255) NULL,
    CONSTRAINT fk_oc_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores(id) ON DELETE RESTRICT,
    INDEX idx_oc_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_orden_compra
CREATE TABLE IF NOT EXISTS detalles_orden_compra (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    orden_compra_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,    -- Ref escalar a MS Productos
    sku VARCHAR(50) NOT NULL,
    cantidad_pedida INT NOT NULL,
    valor_neto_unitario BIGINT NOT NULL,
    cantidad_recibida INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_det_oc_orden FOREIGN KEY (orden_compra_id) REFERENCES ordenes_compra(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: recepciones
CREATE TABLE IF NOT EXISTS recepciones (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    numero_recepcion VARCHAR(50) NOT NULL UNIQUE,
    orden_compra_id BIGINT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    encargada_id BIGINT NOT NULL,   -- Ref escalar a MS Auth
    tipo VARCHAR(30) NULL,          -- 'COMPLETA' o 'INCOMPLETA'
    estado VARCHAR(30) NOT NULL DEFAULT 'ACEPTADA',
    motivo_rechazo VARCHAR(255) NULL,
    CONSTRAINT fk_recepcion_oc FOREIGN KEY (orden_compra_id) REFERENCES ordenes_compra(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_recepcion
CREATE TABLE IF NOT EXISTS detalles_recepcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recepcion_id BIGINT NOT NULL,
    detalle_orden_compra_id BIGINT NOT NULL,
    cantidad_recibida INT NOT NULL,
    CONSTRAINT fk_det_rec_recepcion FOREIGN KEY (recepcion_id) REFERENCES recepciones(id) ON DELETE CASCADE,
    CONSTRAINT fk_det_rec_det_oc FOREIGN KEY (detalle_orden_compra_id) REFERENCES detalles_orden_compra(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: facturas
CREATE TABLE IF NOT EXISTS facturas (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    proveedor_id BIGINT NOT NULL,
    recepcion_id BIGINT NOT NULL,
    numero VARCHAR(50) NOT NULL,
    fecha_emision DATE NOT NULL,
    monto_neto BIGINT NOT NULL,
    iva BIGINT NOT NULL,
    total BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACEPTADA', -- 'ACEPTADA', 'RECHAZADA', 'PAGADA'
    CONSTRAINT fk_factura_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores(id) ON DELETE RESTRICT,
    CONSTRAINT fk_factura_recepcion FOREIGN KEY (recepcion_id) REFERENCES recepciones(id) ON DELETE RESTRICT,
    INDEX idx_facturas_numero_prov (proveedor_id, numero, estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_factura (Variante B: audita intrusos con producto_id y det_oc nulos)
CREATE TABLE IF NOT EXISTS detalles_factura (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    factura_id BIGINT NOT NULL,
    producto_id BIGINT NULL,        -- Opcional si es artículo no ordenado (CA3)
    detalle_orden_compra_id BIGINT NULL,
    sku VARCHAR(50) NOT NULL,
    descripcion_original VARCHAR(255) NOT NULL,
    cantidad INT NOT NULL,
    valor_neto_unitario BIGINT NOT NULL,
    CONSTRAINT fk_det_fac_factura FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE CASCADE,
    CONSTRAINT fk_det_fac_det_oc FOREIGN KEY (detalle_orden_compra_id) REFERENCES detalles_orden_compra(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seeds iniciales de proveedores
INSERT INTO proveedores (id, rut, razon_social, giro, correo, telefono, direccion, banco, tipo_cuenta, numero_cuenta, titular_cuenta, rut_titular)
VALUES (
    1, '76.123.456-7', 'Distribuidora Escolar Aconcagua S.A.', 'Venta al por mayor de libros y artículos de librería',
    'ventas@aconcagua.cl', '+56 9 8765 4321', 'Av. Libertador Bernardo O''Higgins 1234, Santiago',
    'Banco de Chile', 'Cuenta Corriente', '00-123-45678-9', 'Distribuidora Escolar Aconcagua S.A.', '76.123.456-7'
) ON DUPLICATE KEY UPDATE razon_social=VALUES(razon_social);
