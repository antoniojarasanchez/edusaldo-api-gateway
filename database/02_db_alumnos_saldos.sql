-- =============================================================================
-- EduSaldo · MS Alumnos y Saldos (Puerto 8082)
-- Base de Datos: db_alumnos_saldos
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_alumnos_saldos 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE db_alumnos_saldos;

-- Tabla: alumnos
CREATE TABLE IF NOT EXISTS alumnos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rut VARCHAR(12) NOT NULL UNIQUE,
    primer_nombre VARCHAR(100) NOT NULL,
    segundo_nombre VARCHAR(100) NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100) NULL,
    fecha_nacimiento DATE NOT NULL,
    curso VARCHAR(50) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
    INDEX idx_alumnos_curso (curso),
    INDEX idx_alumnos_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: apoderados_alumnos (Relación N:M sin borrado físico)
CREATE TABLE IF NOT EXISTS apoderados_alumnos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alumno_id BIGINT NOT NULL,
    apoderado_id BIGINT NOT NULL, -- Ref escalar a MS Auth (Usuario.id)
    parentesco VARCHAR(30) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVA',
    fecha_asociacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    asociado_por_id BIGINT NOT NULL,
    fecha_desvinculacion DATETIME NULL,
    desvinculado_por_id BIGINT NULL,
    motivo_desvinculacion VARCHAR(255) NULL,
    CONSTRAINT fk_apoderado_alumno FOREIGN KEY (alumno_id) REFERENCES alumnos(id) ON DELETE CASCADE,
    INDEX idx_apoderado_ref (apoderado_id),
    UNIQUE KEY uq_asociacion_activa (alumno_id, apoderado_id, estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: cuentas_saldo
CREATE TABLE IF NOT EXISTS cuentas_saldo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alumno_id BIGINT NOT NULL UNIQUE,
    saldo_actual BIGINT NOT NULL DEFAULT 0,
    saldo_comprometido BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_cuenta_alumno FOREIGN KEY (alumno_id) REFERENCES alumnos(id) ON DELETE CASCADE,
    INDEX idx_cuenta_alumno (alumno_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: movimientos_saldo
CREATE TABLE IF NOT EXISTS movimientos_saldo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cuenta_saldo_id BIGINT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    monto BIGINT NOT NULL,
    saldo_resultante BIGINT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia_tipo VARCHAR(50) NOT NULL,
    referencia_id BIGINT NULL,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    usuario_id BIGINT NULL, -- Operador en MS Auth
    descripcion VARCHAR(255) NOT NULL,
    CONSTRAINT fk_movimiento_cuenta FOREIGN KEY (cuenta_saldo_id) REFERENCES cuentas_saldo(id) ON DELETE RESTRICT,
    INDEX idx_movimientos_tipo (tipo),
    INDEX idx_movimientos_fecha (fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: alertas_saldo_bajo (HU23)
CREATE TABLE IF NOT EXISTS alertas_saldo_bajo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cuenta_saldo_id BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVA',
    umbral_aplicado BIGINT NOT NULL DEFAULT 3000,
    saldo_al_activar BIGINT NOT NULL,
    saldo_actual BIGINT NOT NULL,
    fecha_activacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    correo_enviado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_envio_correo DATETIME NULL,
    fecha_resolucion DATETIME NULL,
    CONSTRAINT fk_alerta_cuenta FOREIGN KEY (cuenta_saldo_id) REFERENCES cuentas_saldo(id) ON DELETE CASCADE,
    INDEX idx_alerta_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: devoluciones_saldo (HU18)
CREATE TABLE IF NOT EXISTS devoluciones_saldo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    monto BIGINT NOT NULL,
    apoderado_id BIGINT NOT NULL,
    medio VARCHAR(30) NOT NULL, -- EFECTIVO o TRANSFERENCIA
    comprobante VARCHAR(100) NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    registrada_por_id BIGINT NOT NULL,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: abonos (HU21 - Webpay simulado)
CREATE TABLE IF NOT EXISTS abonos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alumno_id BIGINT NOT NULL,
    apoderado_id BIGINT NOT NULL,
    monto BIGINT NOT NULL,
    token_transaccion VARCHAR(100) NOT NULL UNIQUE,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_resolucion DATETIME NULL,
    INDEX idx_abonos_alumno (alumno_id),
    INDEX idx_abonos_apoderado (apoderado_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: importaciones_nomina (HU14)
CREATE TABLE IF NOT EXISTS importaciones_nomina (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre_archivo VARCHAR(255) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_id BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PREVISUALIZADA'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_importacion
CREATE TABLE IF NOT EXISTS detalles_importacion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    importacion_id BIGINT NOT NULL,
    numero_fila INT NOT NULL,
    rut_alumno VARCHAR(12) NOT NULL,
    rut_apoderado VARCHAR(12) NOT NULL,
    datos_originales TEXT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'VALIDA',
    observacion VARCHAR(255) NULL,
    apoderado_nuevo BOOLEAN NOT NULL DEFAULT FALSE,
    apoderado_id BIGINT NULL,
    alumno_id BIGINT NULL,
    CONSTRAINT fk_detalle_importacion FOREIGN KEY (importacion_id) REFERENCES importaciones_nomina(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seeds iniciales de demostración
INSERT INTO alumnos (id, rut, primer_nombre, primer_apellido, fecha_nacimiento, curso, estado)
VALUES 
  (1, '12.345.678-5', 'Sofía', 'Pérez', '2017-04-15', '3° Básico', 'ACTIVO'),
  (2, '23.456.789-6', 'Tomás', 'Pérez', '2013-08-20', '8° Básico', 'ACTIVO')
ON DUPLICATE KEY UPDATE curso=VALUES(curso);

INSERT INTO cuentas_saldo (alumno_id, saldo_actual, saldo_comprometido)
VALUES 
  (1, 18000, 0),
  (2, 12500, 0)
ON DUPLICATE KEY UPDATE saldo_actual=VALUES(saldo_actual);

INSERT INTO apoderados_alumnos (alumno_id, apoderado_id, parentesco, estado, asociado_por_id)
VALUES 
  (1, 4, 'PADRE', 'ACTIVA', 1),
  (2, 4, 'PADRE', 'ACTIVA', 1)
ON DUPLICATE KEY UPDATE parentesco=VALUES(parentesco);
