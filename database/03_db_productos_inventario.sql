-- =============================================================================
-- EduSaldo · MS Productos e Inventario (Puerto 8083)
-- Base de Datos: db_productos_inventario
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_productos_inventario 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE db_productos_inventario;

-- Tabla: categorias
CREATE TABLE IF NOT EXISTS categorias (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: productos
CREATE TABLE IF NOT EXISTS productos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    categoria_id BIGINT NOT NULL,
    sku VARCHAR(50) NOT NULL UNIQUE,
    codigo_barras VARCHAR(50) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255) NULL,
    imagen_url VARCHAR(255) NULL,
    curso_nivel VARCHAR(100) NOT NULL,
    materia VARCHAR(100) NOT NULL,
    precio_venta BIGINT NOT NULL,
    margen_utilidad DECIMAL(5,2) NOT NULL DEFAULT 30.00,
    cpp BIGINT NOT NULL, -- Costo Promedio Ponderado con IVA incluido (Long)
    stock_fisico INT NOT NULL DEFAULT 0,
    stock_reservado INT NOT NULL DEFAULT 0,
    stock_critico INT NOT NULL DEFAULT 5,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE RESTRICT,
    INDEX idx_productos_sku (sku),
    INDEX idx_productos_codigo_barras (codigo_barras)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: movimientos_inventario
CREATE TABLE IF NOT EXISTS movimientos_inventario (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    producto_id BIGINT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    cantidad INT NOT NULL,
    costo_unitario BIGINT NOT NULL,
    stock_fisico_resultante INT NOT NULL,
    stock_reservado_resultante INT NOT NULL,
    cpp_resultante BIGINT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia_tipo VARCHAR(50) NOT NULL,
    referencia_id BIGINT NULL,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    usuario_id BIGINT NOT NULL,
    CONSTRAINT fk_movimiento_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT,
    INDEX idx_mov_inv_tipo (tipo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: inventarios_fisicos (HU44)
CREATE TABLE IF NOT EXISTS inventarios_fisicos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha_conteo DATE NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responsable_id BIGINT NOT NULL,
    categoria_filtro VARCHAR(100) NULL,
    observaciones TEXT NULL,
    respaldo_url VARCHAR(255) NULL, -- URL de la foto/PDF escaneado firmado
    estado VARCHAR(30) NOT NULL DEFAULT 'EN_CURSO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: detalles_conteo
CREATE TABLE IF NOT EXISTS detalles_conteo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    inventario_fisico_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    stock_sistema INT NOT NULL,
    stock_contado INT NOT NULL,
    CONSTRAINT fk_detalle_inventario FOREIGN KEY (inventario_fisico_id) REFERENCES inventarios_fisicos(id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: reportes_diferencia_stock (HU45 - Paso 1: Encargado reporta)
CREATE TABLE IF NOT EXISTS reportes_diferencia_stock (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    producto_id BIGINT NOT NULL,
    cantidad_diferencia INT NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    evidencia_url VARCHAR(255) NULL,
    reportado_por_id BIGINT NOT NULL,
    fecha_reporte DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    atendido_por_id BIGINT NULL,
    observacion VARCHAR(255) NULL,
    CONSTRAINT fk_reporte_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla: solicitudes_ajuste_stock (HU45 - Paso 2: Admin solicita -> Paso 3: Autorizador aprueba)
CREATE TABLE IF NOT EXISTS solicitudes_ajuste_stock (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    producto_id BIGINT NOT NULL,
    cantidad INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    evidencia_url VARCHAR(255) NULL,
    solicitante_id BIGINT NOT NULL,
    autorizador_id BIGINT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_resolucion DATETIME NULL,
    comentario_resolucion VARCHAR(255) NULL,
    reporte_diferencia_id BIGINT NULL,
    CONSTRAINT fk_solicitud_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT,
    CONSTRAINT fk_solicitud_reporte FOREIGN KEY (reporte_diferencia_id) REFERENCES reportes_diferencia_stock(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seeds iniciales del catálogo escolar
INSERT INTO categorias (id, nombre, descripcion) VALUES
  (1, 'Cuadernos', 'Cuadernos universitarios y college'),
  (2, 'Escritura', 'Lápices, gomas, bolígrafos'),
  (3, 'Papeles', 'Blocks de dibujo, resmas, cartulinas'),
  (4, 'Arte', 'Lápices de colores, témperas, pinceles'),
  (5, 'Geometría', 'Reglas, escuadras, transportadores')
ON DUPLICATE KEY UPDATE descripcion=VALUES(descripcion);

INSERT INTO productos (id, categoria_id, sku, codigo_barras, nombre, descripcion, curso_nivel, materia, precio_venta, cpp, stock_fisico, stock_reservado, stock_critico) VALUES
  (101, 1, 'CUAD-UNI-01', '7800000000101', 'Cuaderno universitario', 'Cuaderno espiral 100 hojas', 'Todos', 'General', 1250, 950, 25, 0, 5),
  (102, 1, 'CUAD-COL-MAT', '7800000000102', 'Cuaderno College Matemática', 'College 80h cuadro 7mm', 'Básica', 'Matemática', 900, 680, 18, 0, 5),
  (104, 3, 'BLOC-DIB-14', '7800000000104', 'Block de dibujo 1/4', 'Medium 20 hojas 140g', 'Básica/Media', 'Artes', 1500, 1100, 12, 0, 4),
  (105, 2, 'LAP-GRAF-HB', '7800000000105', 'Lápiz grafito HB', 'Punta resistente graduación HB', 'Todos', 'General', 450, 280, 30, 0, 8),
  (106, 2, 'GOM-BORR-40', '7800000000106', 'Goma de borrar', 'Libre de látex para lápiz grafito', 'Todos', 'General', 350, 210, 25, 0, 5),
  (107, 4, 'CAJ-LAP-COL12', '7800000000107', 'Caja lápices de colores 12', 'Largos surtidos 12 colores', 'Básica', 'Artes', 2800, 1950, 10, 0, 3),
  (108, 5, 'REG-30-CM', '7800000000108', 'Regla 30 cm', 'Acrílica transparente biselada', 'Todos', 'Geometría', 750, 480, 14, 0, 4)
ON DUPLICATE KEY UPDATE precio_venta=VALUES(precio_venta);
