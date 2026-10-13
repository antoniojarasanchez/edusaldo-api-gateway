-- =============================================================================
-- EduSaldo · MS Ventas y Reservas (Puerto 8084)
-- Base de Datos: db_ventas_reservas
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_ventas_reservas 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE db_ventas_reservas;

-- Tabla: reservas
CREATE TABLE IF NOT EXISTS reservas (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    codigo_bolsa VARCHAR(50) NULL, -- Código de barras Code39 asignado al preparar
    alumno_id BIGINT NOT NULL,     -- Ref escalar a MS Alumnos
    apoderado_id BIGINT NOT NULL,  -- Ref escalar a MS Auth
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    fecha_inicio_preparacion DATETIME NULL,
    fecha_lista_retiro DATETIME NULL,
    preparada_por_id BIGINT NULL,
    fecha_entrega DATETIME NULL,
    entregada_por_id BIGINT NULL,
    fecha_cancelacion DATETIME NULL,
    cancelada_por_id BIGINT NULL,
    motivo_cancelacion VARCHAR(255) NULL,
    INDEX idx_reservas_alumno (alumno_id),
    INDEX idx_reservas_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_reserva
CREATE TABLE IF NOT EXISTS detalles_reserva (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    reserva_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,   -- Ref escalar a MS Productos
    nombre_producto VARCHAR(150) NOT NULL,
    cantidad INT NOT NULL,
    cantidad_preparada INT NOT NULL DEFAULT 0,
    precio_unitario BIGINT NOT NULL,
    CONSTRAINT fk_detalle_reserva FOREIGN KEY (reserva_id) REFERENCES reservas(id) ON DELETE CASCADE,
    INDEX idx_det_res_producto (producto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: ventas
CREATE TABLE IF NOT EXISTS ventas (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    numero VARCHAR(50) NOT NULL UNIQUE,
    reserva_id BIGINT NULL,        -- Opcional si el origen es RESERVA
    alumno_id BIGINT NOT NULL,     -- Ref escalar a MS Alumnos
    origen VARCHAR(20) NOT NULL,   -- 'RESERVA' o 'DIRECTA'
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total BIGINT NOT NULL,
    encargado_id BIGINT NOT NULL,  -- Ref escalar a MS Auth
    INDEX idx_ventas_alumno (alumno_id),
    INDEX idx_ventas_fecha (fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_venta
CREATE TABLE IF NOT EXISTS detalles_venta (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    venta_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,   -- Ref escalar a MS Productos
    nombre_producto VARCHAR(150) NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario BIGINT NOT NULL,
    cantidad_devuelta INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_detalle_venta FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: devoluciones (HU37)
CREATE TABLE IF NOT EXISTS devoluciones (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo_devolucion VARCHAR(50) NOT NULL UNIQUE,
    venta_id BIGINT NOT NULL,
    alumno_id BIGINT NOT NULL,     -- Ref escalar a MS Alumnos
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255) NOT NULL,
    total_reintegro BIGINT NOT NULL,
    encargado_id BIGINT NOT NULL,
    CONSTRAINT fk_devolucion_venta FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_devolucion
CREATE TABLE IF NOT EXISTS detalles_devolucion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    devolucion_id BIGINT NOT NULL,
    detalle_venta_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,   -- Ref escalar a MS Productos
    nombre_producto VARCHAR(150) NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario_reintegro BIGINT NOT NULL,
    monto_reintegro BIGINT NOT NULL,
    CONSTRAINT fk_detalle_dev FOREIGN KEY (devolucion_id) REFERENCES devoluciones(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
