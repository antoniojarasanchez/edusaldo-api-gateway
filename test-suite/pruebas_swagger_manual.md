# EduSaldo 2.0 · Guía Rápida de Pruebas en Swagger UI & Postman

Esta guía está diseñada para que el docente o evaluador pueda probar **todos los casos de uso, flujos de negocio y casos de borde (edge cases)** de EduSaldo de forma inmediata, copiando y pegando los cuerpos JSON en la interfaz interactiva de Swagger de cada microservicio o importando la colección en Postman.

---

## 1. Enlaces Directos a Swagger UI (Servicios Activos)

Con los microservicios corriendo, abre estos enlaces directamente en tu navegador:

| Microservicio | Puerto | Swagger UI Interactivo |
| :--- | :---: | :--- |
| **01. Auth y Usuarios** | **8081** | [http://localhost:8081/swagger-ui.html](http://localhost:8081/swagger-ui.html) |
| **02. Alumnos y Saldos** | **8082** | [http://localhost:8082/swagger-ui.html](http://localhost:8082/swagger-ui.html) |
| **03. Productos e Inventario** | **8083** | [http://localhost:8083/swagger-ui.html](http://localhost:8083/swagger-ui.html) |
| **04. Ventas y Reservas** | **8084** | [http://localhost:8084/swagger-ui.html](http://localhost:8084/swagger-ui.html) |
| **05. Compras (Variante B)** | **8085** | [http://localhost:8085/swagger-ui.html](http://localhost:8085/swagger-ui.html) |
| **06. Finanzas y Configuración** | **8086** | [http://localhost:8086/swagger-ui.html](http://localhost:8086/swagger-ui.html) |
| **API Gateway Central** | **8099** | Rutas públicas en `http://localhost:8099/api/...` |

> **Nota para Postman:** El archivo `postman/EduSaldo_Postman_Collection.json` está listo para ser importado directamente en Postman (*File -> Import*), con las 31 peticiones preconfiguradas con sus variables y payloads.

---

## 2. Flujo 1: Ciclo Feliz de Pedido y Retiro en Librería (Happy Path)

Demuestra el flujo completo desde que el apoderado reserva hasta que el alumno retira sus materiales en mesón.

### Paso 1: Consultar saldo del alumno
- **Swagger:** `http://localhost:8082/swagger-ui.html`
- **Endpoint:** `GET /api/alumnos/1`
- **Respuesta esperada (HTTP 200):** Alumna Sofía Pérez con saldo disponible (ej. `$18.000`).

### Paso 2: Crear reserva multilínea
- **Swagger:** `http://localhost:8084/swagger-ui.html`
- **Endpoint:** `POST /api/reservas`
- **Cuerpo JSON:**
```json
{
  "alumnoId": 1,
  "apoderadoId": 4,
  "items": [
    {
      "productoId": 101,
      "nombreProducto": "Cuaderno universitario",
      "cantidad": 2,
      "precioUnitario": 1250
    },
    {
      "productoId": 105,
      "nombreProducto": "Lápiz grafito HB",
      "cantidad": 1,
      "precioUnitario": 450
    }
  ]
}
```
- **Respuesta esperada (HTTP 201):** Retorna código `RES-XXXX`, total `$2.950`, estado `PENDIENTE`. Copia el `id` retornado (ej. `1`).

### Paso 3: Iniciar preparación en bodega (Pistoleo)
- **Swagger:** `http://localhost:8084/swagger-ui.html`
- **Endpoint:** `PUT /api/reservas/{id}/iniciar-preparacion`
- **Parámetros:** `id: 1`, `encargadoId: 2`
- **Respuesta esperada (HTTP 200):** Estado cambia a `EN_PREPARACION`.

### Paso 4: Generar rótulo y etiqueta de bolsa
- **Swagger:** `http://localhost:8084/swagger-ui.html`
- **Endpoint:** `PUT /api/reservas/{id}/etiquetar`
- **Parámetros:** `id: 1`
- **Respuesta esperada (HTTP 200):** Retorna código de bolsa único (ej. `BOL-4821`) y estado pasa a `ETIQUETA_PENDIENTE`.

### Paso 5: Marcar lista para retiro
- **Swagger:** `http://localhost:8084/swagger-ui.html`
- **Endpoint:** `PUT /api/reservas/{id}/marcar-lista`
- **Parámetros:** `id: 1`, `encargadoId: 2`
- **Respuesta esperada (HTTP 200):** Estado pasa a `LISTA_PARA_RETIRO`.

### Paso 6: Entrega definitiva en mesón
- **Swagger:** `http://localhost:8084/swagger-ui.html`
- **Endpoint:** `POST /api/reservas/{id}/entregar`
- **Parámetros:** `id: 1`, `encargadoId: 2`
- **Respuesta esperada (HTTP 200):** Se genera la venta definitiva `VTA-XXXX`, origen `RESERVA`, total `$2.950` y estado pasa a `ENTREGADA`.

---

## 3. Flujo 2: Casos de Borde (Edge Cases) y Rechazos Controlados

Demuestra que el sistema no permite violar ninguna invariante financiera o de inventario.

### Caso de Borde A: Intento de comprometer saldo insuficiente (HU35)
- **Swagger:** `http://localhost:8082/swagger-ui.html`
- **Endpoint:** `POST /api/saldos/1/comprometer`
- **Cuerpo JSON:**
```json
{
  "monto": 9999999,
  "reservaId": 999,
  "usuarioId": 4,
  "idempotencyKey": "KEY-FAIL-TEST-01"
}
```
- **Respuesta esperada (HTTP 422 Unprocessable Entity):**
```json
{
  "error": "Unprocessable Entity",
  "message": "Saldo insuficiente. Saldo disponible: $... - Monto requerido: $9999999"
}
```

### Caso de Borde B: Intento de sobreventa / Quiebre de stock (HU41)
- **Swagger:** `http://localhost:8083/swagger-ui.html`
- **Endpoint:** `POST /api/inventario/101/reservar`
- **Cuerpo JSON:**
```json
{
  "cantidad": 99999,
  "referenciaId": 101,
  "idempotencyKey": "KEY-FAIL-STOCK-01",
  "usuarioId": 4
}
```
- **Respuesta esperada (HTTP 422 Unprocessable Entity):**
```json
{
  "error": "Unprocessable Entity",
  "message": "Stock insuficiente para reservar 99999 unidades. Disponible: ..."
}
```

---

## 4. Flujo 3: Doble Firma de Merma de Inventario (HU45)

Demuestra que cambiar el stock físico por merma requiere obligatoriamente solicitud de Administrador y aprobación de Autorizador.

### Paso 1: Administrador solicita ajuste negativo por merma
- **Swagger:** `http://localhost:8083/swagger-ui.html`
- **Endpoint:** `POST /api/inventario/ajustes/solicitar`
- **Cuerpo JSON:**
```json
{
  "productoId": 101,
  "cantidad": -2,
  "motivo": "Daño accidental en bodega por derrame de témpera",
  "evidenciaUrl": "http://servidor/evidencias/merma-101.jpg",
  "solicitanteId": 1
}
```
- **Respuesta esperada (HTTP 201):** Solicitud creada con estado `PENDIENTE`. **El stock físico aún NO ha cambiado**.

### Paso 2: Autorizador revisa y aprueba con segunda firma
- **Swagger:** `http://localhost:8083/swagger-ui.html`
- **Endpoint:** `PUT /api/inventario/ajustes/{solicitudId}/autorizar`
- **Cuerpo JSON:**
```json
{
  "autorizadorId": 3,
  "aprobada": true,
  "comentario": "Merma y evidencia fotográfica comprobada conforme"
}
```
- **Respuesta esperada (HTTP 200):** Estado pasa a `APROBADA`. En ese instante el stock físico se descuenta formalmente en 2 unidades y queda registrado en `MovimientoInventario`.

---

## 5. Flujo 4: Variante B de Compras (Rechazo Atómico de Intrusos y Recepción)

Demuestra que si un proveedor factura un producto no ordenado, la recepción se rechaza de forma atómica auditando el intruso.

### Paso 1: Emitir Orden de Compra en valores netos
- **Swagger:** `http://localhost:8085/swagger-ui.html`
- **Endpoint:** `POST /api/ordenes-compra`
- **Cuerpo JSON:**
```json
{
  "proveedorId": 1,
  "emitidaPorId": 1,
  "items": [
    {
      "productoId": 101,
      "sku": "CUAD-UNI-01",
      "cantidadPedida": 20,
      "valorNetoUnitario": 1000
    }
  ]
}
```
- **Respuesta esperada (HTTP 201):** OC emitida con total neto `$20.000` + IVA 19% `$3.800` = Total `$23.800`. Copia el `id` de la OC.

### Paso 2: Enviar factura con artículo NO ordenado (Intruso)
- **Swagger:** `http://localhost:8085/swagger-ui.html`
- **Endpoint:** `POST /api/recepciones`
- **Cuerpo JSON:**
```json
{
  "ordenCompraId": 1,
  "encargadaId": 2,
  "facturas": [
    {
      "numero": "FAC-RECHAZO-99",
      "fechaEmision": "2026-10-12",
      "montoNeto": 25000,
      "iva": 4750,
      "total": 29750,
      "items": [
        {
          "sku": "CUAD-UNI-01",
          "descripcionOriginal": "Cuaderno universitario",
          "cantidad": 20,
          "valorNetoUnitario": 1000
        },
        {
          "sku": "INTRUSO-CORRECTOR-99",
          "descripcionOriginal": "Lápiz corrector no ordenado",
          "cantidad": 5,
          "valorNetoUnitario": 1000
        }
      ]
    }
  ]
}
```
- **Respuesta esperada (HTTP 422 Unprocessable Entity):**  
  La recepción se rechaza atómicamente con motivo:  
  `"La factura incluye el artículo no ordenado SKU: INTRUSO-CORRECTOR-99"`.  
  La factura queda en estado `RECHAZADA`, y la OC permanece vigente en `EMITIDA`.

---

## 6. Flujo 5: Regla HU58 (No Doble Contabilización en Finanzas)

Demuestra que las ventas en librería calculan margen y NUNCA generan movimientos en la caja de dinero real.

### Paso 1: Registrar resultado de venta en librería
- **Swagger:** `http://localhost:8086/swagger-ui.html`
- **Endpoint:** `POST /api/finanzas/resultados/operacion`
- **Cuerpo JSON:**
```json
{
  "tipo": "VENTA",
  "montoVenta": 5000,
  "costoVenta": 3800,
  "alumnoId": 1,
  "referenciaId": 101,
  "referenciaFolio": "VTA-HU58-DEMO",
  "idempotencyKey": "KEY-HU58-SWAGGER-01"
}
```
- **Respuesta esperada (HTTP 201):** Registra el resultado con margen bruto de `$1.200` (`5000 - 3800`).

### Paso 2: Verificar que la caja NO fue tocada
- **Swagger:** `http://localhost:8086/swagger-ui.html`
- **Endpoint:** `GET /api/finanzas/caja/movimientos`
- **Respuesta esperada (HTTP 200):** La cartola de dinero real NO contiene ningún movimiento de la venta `VTA-HU58-DEMO`. Solo contiene los abonos reales y pagos de facturas.

---

## 7. Flujo 6: Doble Firma de Pago de Facturas a Proveedores (HU56)

### Paso 1: Administrador solicita pago de factura
- **Swagger:** `http://localhost:8086/swagger-ui.html`
- **Endpoint:** `POST /api/finanzas/pagos/solicitar`
- **Cuerpo JSON:**
```json
{
  "facturaPorPagarId": 1,
  "solicitanteId": 1,
  "monto": 11900
}
```
- **Respuesta esperada (HTTP 201):** Solicitud en estado `PENDIENTE`. La caja aún no tiene egresos.

### Paso 2: Autorizador aprueba el pago
- **Swagger:** `http://localhost:8086/swagger-ui.html`
- **Endpoint:** `PUT /api/finanzas/pagos/1/autorizar`
- **Cuerpo JSON:**
```json
{
  "autorizadorId": 3,
  "aprobada": true
}
```
- **Respuesta esperada (HTTP 200):** Solicitud pasa a `APROBADA`.

### Paso 3: Administrador procesa el egreso efectivo
- **Swagger:** `http://localhost:8086/swagger-ui.html`
- **Endpoint:** `POST /api/finanzas/pagos/egreso`
- **Cuerpo JSON:**
```json
{
  "facturaPorPagarId": 1,
  "monto": 11900,
  "comprobanteReferencia": "TEF-BANCO-CHILE-99841",
  "registradoPorId": 1,
  "idempotencyKey": "KEY-EGRESO-SWAGGER-01"
}
```
- **Respuesta esperada (HTTP 201):** Factura pasa a `PAGADA`, el saldo en Cuenta Librería disminuye en `$11.900` y se genera el `MovimientoCaja` de tipo `PAGO_FACTURA`.
