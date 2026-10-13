-- =============================================================================
-- EduSaldo · MS Auth y Usuarios (Puerto 8081)
-- Base de Datos: db_auth_usuarios
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_auth_usuarios 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE db_auth_usuarios;

-- Tabla: usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rut VARCHAR(12) NOT NULL UNIQUE,
    primer_nombre VARCHAR(100) NOT NULL,
    segundo_nombre VARCHAR(100) NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100) NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    telefono VARCHAR(30) NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(30) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PRIMER_ACCESO',
    intentos_fallidos INT NOT NULL DEFAULT 0,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso DATETIME NULL,
    INDEX idx_usuarios_rol (rol),
    INDEX idx_usuarios_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: tokens_recuperacion
CREATE TABLE IF NOT EXISTS tokens_recuperacion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_token_recuperacion_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    INDEX idx_token_vigencia (token, usado, fecha_expiracion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: tokens_revocados (JWT Blacklist)
CREATE TABLE IF NOT EXISTS tokens_revocados (
    jti VARCHAR(100) PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    fecha_revocacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME NOT NULL,
    INDEX idx_tokens_revocados_exp (fecha_expiracion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: consentimientos_privacidad (HU69)
CREATE TABLE IF NOT EXISTS consentimientos_privacidad (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    version_aviso VARCHAR(50) NOT NULL,
    fecha_aceptacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(45) NULL,
    CONSTRAINT fk_consentimiento_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seeds iniciales de staff y apoderado de demostración
INSERT INTO usuarios (id, rut, primer_nombre, primer_apellido, correo, password_hash, rol, estado)
VALUES 
  (1, '15.666.777-8', 'Antonio', 'Jara', 'admin@colegio.cl', '$2a$10$wE9o2aVzJ8ZzM/3k0Fz3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe', 'ADMINISTRADOR', 'ACTIVA'),
  (2, '11.222.333-4', 'Marta', 'Gómez', 'libreria@colegio.cl', '$2a$10$wE9o2aVzJ8ZzM/3k0Fz3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe', 'ENCARGADO', 'ACTIVA'),
  (3, '16.777.888-9', 'Rodrigo', 'Valdés', 'autorizador@colegio.cl', '$2a$10$wE9o2aVzJ8ZzM/3k0Fz3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe', 'AUTORIZADOR', 'ACTIVA'),
  (4, '9.876.543-2', 'Carlos', 'Pérez', 'apoderado@colegio.cl', '$2a$10$wE9o2aVzJ8ZzM/3k0Fz3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe8Z3Oe', 'APODERADO', 'ACTIVA')
ON DUPLICATE KEY UPDATE correo=VALUES(correo);
