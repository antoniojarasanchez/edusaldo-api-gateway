-- =============================================================================
-- EduSaldo · MS Finanzas y Configuración (Puerto 8086)
-- Base de Datos: db_finanzas_config
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_finanzas_config 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE db_finanzas_config;

-- Tabla: cuentas_libreria
CREATE TABLE IF NOT EXISTS cuentas_libreria (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    saldo_apertura BIGINT NOT NULL DEFAULT 0,
    saldo_actual BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: movimientos_caja (Solo dinero real: HU58)
CREATE TABLE IF NOT EXISTS movimientos_caja (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    naturaleza VARCHAR(20) NOT NULL, -- 'INGRESO' o 'EGRESO'
    tipo VARCHAR(50) NOT NULL,       -- 'SALDO_APERTURA', 'ABONO', 'PAGO_FACTURA', 'DEVOLUCION_SALDO', 'CORRECCION'
    concepto VARCHAR(255) NOT NULL,
    monto BIGINT NOT NULL,
    saldo_resultante BIGINT NOT NULL,
    referencia_tipo VARCHAR(50) NOT NULL,
    referencia_id VARCHAR(100) NOT NULL,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    usuario_id BIGINT NOT NULL,      -- Operador en MS Auth
    INDEX idx_mov_caja_fecha (fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: registros_resultado (Margen de ventas y devoluciones, no mueve caja: HU58)
CREATE TABLE IF NOT EXISTS registros_resultado (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo VARCHAR(30) NOT NULL,       -- 'VENTA' o 'DEVOLUCION'
    monto_venta BIGINT NOT NULL,
    costo_venta BIGINT NOT NULL,     -- cant * CPP con IVA
    alumno_id BIGINT NOT NULL,       -- Ref escalar a MS Alumnos
    referencia_id BIGINT NOT NULL,   -- Ref escalar a MS Ventas
    referencia_folio VARCHAR(50) NOT NULL,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    INDEX idx_reg_res_fecha (fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: periodos_contables (HU61)
CREATE TABLE IF NOT EXISTS periodos_contables (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ABIERTO', -- 'ABIERTO', 'EN_REVISION', 'CERRADO'
    fecha_inicio_revision DATETIME NULL,
    fecha_cierre DATETIME NULL,
    tipo_cierre VARCHAR(30) NULL,    -- 'MANUAL' o 'AUTOMATICO'
    cerrado_por_id BIGINT NULL,
    UNIQUE KEY uq_periodo (anio, mes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: facturas_por_pagar (Pase desde MS Compras)
CREATE TABLE IF NOT EXISTS facturas_por_pagar (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    factura_id BIGINT NOT NULL,      -- Ref escalar a MS Compras (Factura.id)
    orden_compra_folio VARCHAR(50) NOT NULL,
    proveedor_id BIGINT NOT NULL,    -- Ref escalar a MS Compras (Proveedor.id)
    nombre_proveedor VARCHAR(150) NOT NULL,
    rut_proveedor VARCHAR(12) NOT NULL,
    datos_bancarios_proveedor VARCHAR(255) NOT NULL,
    numero_factura VARCHAR(50) NOT NULL,
    fecha_factura DATE NOT NULL,
    monto_total BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE_PAGO',
    INDEX idx_fpp_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: items_factura_por_pagar (Proyección de lectura para auditoría del Autorizador)
CREATE TABLE IF NOT EXISTS items_factura_por_pagar (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    factura_por_pagar_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    nombre_producto VARCHAR(150) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    cantidad_recibida INT NOT NULL,
    costo_unitario_total BIGINT NOT NULL,
    subtotal BIGINT NOT NULL,
    CONSTRAINT fk_item_fpp FOREIGN KEY (factura_por_pagar_id) REFERENCES facturas_por_pagar(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: solicitudes_pago (Doble firma: Admin solicita -> Autorizador aprueba/rechaza)
CREATE TABLE IF NOT EXISTS solicitudes_pago (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    factura_por_pagar_id BIGINT NOT NULL,
    monto BIGINT NOT NULL,
    solicitante_id BIGINT NOT NULL,  -- Ref escalar a MS Auth (Admin)
    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    autorizador_id BIGINT NULL,      -- Ref escalar a MS Auth (Autorizador)
    fecha_resolucion DATETIME NULL,
    motivo_rechazo VARCHAR(255) NULL,
    CONSTRAINT fk_solicitud_fpp FOREIGN KEY (factura_por_pagar_id) REFERENCES facturas_por_pagar(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: pagos (Registro del egreso)
CREATE TABLE IF NOT EXISTS pagos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    factura_por_pagar_id BIGINT NOT NULL,
    fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto BIGINT NOT NULL,
    medio_pago VARCHAR(50) NOT NULL DEFAULT 'TRANSFERENCIA',
    comprobante_referencia VARCHAR(100) NOT NULL,
    registrado_por_id BIGINT NOT NULL,
    CONSTRAINT fk_pago_fpp FOREIGN KEY (factura_por_pagar_id) REFERENCES facturas_por_pagar(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: configuraciones_institucionales (Monotenant por instalación)
CREATE TABLE IF NOT EXISTS configuraciones_institucionales (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre_establecimiento VARCHAR(150) NOT NULL,
    nombre_centro_padres VARCHAR(150) NOT NULL,
    nombre_libreria VARCHAR(150) NOT NULL,
    rut VARCHAR(12) NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    correo_contacto VARCHAR(150) NOT NULL,
    logo_url VARCHAR(255) NULL,
    color_principal VARCHAR(20) NOT NULL DEFAULT '#1F4E79',
    color_acento VARCHAR(20) NOT NULL DEFAULT '#D9E1F2'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: parametros_sistema
CREATE TABLE IF NOT EXISTS parametros_sistema (
    clave VARCHAR(50) PRIMARY KEY,
    valor VARCHAR(255) NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por_id BIGINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: registros_auditoria (HU65)
CREATE TABLE IF NOT EXISTS registros_auditoria (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    microservicio VARCHAR(50) NOT NULL,
    usuario_id BIGINT NOT NULL,
    rol VARCHAR(50) NOT NULL,
    accion VARCHAR(100) NOT NULL,
    entidad VARCHAR(50) NOT NULL,
    entidad_id VARCHAR(50) NOT NULL,
    valor_anterior TEXT NULL,
    valor_nuevo TEXT NULL,
    motivo VARCHAR(255) NULL,
    INDEX idx_auditoria_fecha (fecha_hora)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: consultas_contacto (HU03)
CREATE TABLE IF NOT EXISTS consultas_contacto (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    primer_nombre VARCHAR(100) NOT NULL,
    segundo_nombre VARCHAR(100) NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100) NULL,
    correo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    respondida_por_id BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seeds iniciales
INSERT INTO cuentas_libreria (id, saldo_apertura, saldo_actual)
VALUES (1, 500000, 530500)
ON DUPLICATE KEY UPDATE saldo_actual=VALUES(saldo_actual);

INSERT INTO configuraciones_institucionales (id, nombre_establecimiento, nombre_centro_padres, nombre_libreria, rut, direccion, correo_contacto)
VALUES (
    1, 'Colegio EduSaldo', 'Centro General de Padres y Apoderados', 'Librería Escolar Digital EduSaldo',
    '65.123.456-7', 'Av. Los Canelos 123, San Pedro de la Paz, Biobío', 'contacto@cpadrescolegio.cl'
) ON DUPLICATE KEY UPDATE nombre_establecimiento=VALUES(nombre_establecimiento);

INSERT INTO parametros_sistema (clave, valor, descripcion, modificado_por_id) VALUES
  ('UMBRAL_SALDO_BAJO', '3000', 'Monto en pesos para disparar alerta de saldo bajo a los apoderados', 1),
  ('DIAS_REVISION_CIERRE', '3', 'Días hábiles permitidos en estado EN_REVISION antes del cierre contable automático', 1),
  ('IVA', '19', 'Tasa porcentual de Impuesto al Valor Agregado en Chile', 1),
  ('EDAD_MIN_VENTA_DIRECTA', '12', 'Edad mínima para permitir compras presenciales directas al estudiante', 1)
ON DUPLICATE KEY UPDATE valor=VALUES(valor);
