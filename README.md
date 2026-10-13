# EduSaldo · API Gateway Central (Puerto 8099)

El **API Gateway** es el punto único de entrada (*Single Point of Entry*) para la plataforma EduSaldo. Implementa una **topología en estrella (Hub & Spoke)** sobre Spring Cloud Gateway, centralizando el enrutamiento hacia los 6 microservicios de negocio desacoplados, aplicando políticas globales de CORS para la SPA en React y aislando las bases de datos independientes.

---

## 1. Clonación de la Suite Completa de EduSaldo

Para clonar la solución completa con el Gateway, los 6 microservicios y el Frontend SPA en un mismo directorio contenedor:

```bash
mkdir EduSaldo
cd EduSaldo

# 1. API Gateway Central
git clone https://github.com/antoniojarasanchez/edusaldo-api-gateway.git

# 2. Los 6 Microservicios Backend
git clone https://github.com/antoniojarasanchez/edusaldo-ms-auth-usuarios.git
git clone https://github.com/antoniojarasanchez/edusaldo-ms-alumnos-saldos.git
git clone https://github.com/antoniojarasanchez/edusaldo-ms-productos-inventario.git
git clone https://github.com/antoniojarasanchez/edusaldo-ms-ventas-reservas.git
git clone https://github.com/antoniojarasanchez/edusaldo-ms-compras.git
git clone https://github.com/antoniojarasanchez/edusaldo-ms-finanzas-configuracion.git

# 3. Frontend SPA (Repositorio Oficial)
git clone https://github.com/Flosotoo/paginaWeb.git
```

---

## 2. Topología de Red y Enrutamiento

Toda solicitud del frontend o cliente externo apunta exclusivamente a `http://localhost:8099`. El Gateway redirige de forma transparente al microservicio dueño del dominio:

```text
               ┌────────────────────────┐
               │   FRONTEND REACT SPA   │
               │ (http://localhost:5173)│
               └───────────┬────────────┘
                           │
                           ▼
               ┌────────────────────────┐
               │    API GATEWAY 8099    │
               └───────────┬────────────┘
        ┌──────────┬───────┼───────┬──────────┐
        ▼          ▼       ▼       ▼          ▼
   ┌─────────┐┌─────────┐┌───┐┌─────────┐┌─────────┐
   │ MS AUTH ││MS ALUMN ││...││MS COMPR ││ MS FIN  │
   │ (8081)  ││ (8082)  ││   ││ (8085)  ││ (8086)  │
   └─────────┘└─────────┘└───┘└─────────┘└─────────┘
```

| Microservicio | Puerto | Rutas Enrutadas por el Gateway | Swagger UI Local |
| :--- | :---: | :--- | :--- |
| **Auth y Usuarios** | **8081** | `/api/auth/**`<br>`/api/usuarios/**` | `http://localhost:8081/swagger-ui.html` |
| **Alumnos y Saldos** | **8082** | `/api/alumnos/**`<br>`/api/saldos/**` | `http://localhost:8082/swagger-ui.html` |
| **Productos e Inventario** | **8083** | `/api/productos/**`<br>`/api/inventario/**` | `http://localhost:8083/swagger-ui.html` |
| **Ventas y Reservas** | **8084** | `/api/ventas/**`<br>`/api/reservas/**` | `http://localhost:8084/swagger-ui.html` |
| **Compras** | **8085** | `/api/proveedores/**`<br>`/api/ordenes-compra/**`<br>`/api/recepciones/**` | `http://localhost:8085/swagger-ui.html` |
| **Finanzas y Configuración** | **8086** | `/api/finanzas/**`<br>`/api/periodos/**`<br>`/api/config/**` | `http://localhost:8086/swagger-ui.html` |

### Seguridad CORS
El Gateway expone cabeceras `Access-Control-Allow-Origin` para los orígenes permitidos de desarrollo (`http://localhost:5173`, `http://localhost:4173`, `http://localhost:3000`), permitiendo el flujo fluido de peticiones con métodos `GET`, `POST`, `PUT`, `DELETE` y `OPTIONS`.

---

## 3. Scripts de Arranque Simultáneo (Doble Variante)

El Gateway incluye scripts automatizados con **detección dinámica de carpetas hermanas**: no dependen de rutas fijas y funcionan en cualquier directorio (Escritorio, Downloads, pendrive, etc.).

### Variante PowerShell (Recomendada en Windows):
```powershell
.\edusaldo-api-gateway\scripts\arrancar_servicios.ps1
```

### Variante Python (Multiplataforma):
```bash
python edusaldo-api-gateway/scripts/arrancar_servicios.py
```

*Ambos scripts levantan los 7 servicios en segundo plano y esperan hasta que los 7 puertos estén confirmados y respondiendo en pantalla.*

---

## 4. La Trilogía de Pruebas: 3 Variantes con Cuerpos JSON Idénticos

Para facilitar la evaluación del docente, la carpeta `test-suite/` contiene **3 formas de probar exactamente los mismos casos de uso y edge cases**, compartiendo los mismos datos (mismos RUTs, SKUs y montos en pesos):

```text
edusaldo-api-gateway/test-suite/
├── pruebas_http_automaticas.py   <-- Variante 1: Consola automatizada (Python)
├── pruebas_http_automaticas.ps1  <-- Variante 1: Consola automatizada (PowerShell)
├── pruebas_postman_coleccion.json<-- Variante 2: Colección Postman (31 peticiones)
└── pruebas_swagger_manual.md     <-- Variante 3: Guía interactiva paso a paso
```

### Variante 1: Consola Automatizada (E2E en Vivo)
Ejecuta la batería de 31 casos de prueba reales contra `http://localhost:8099`:
- **En Python:** `python edusaldo-api-gateway/test-suite/pruebas_http_automaticas.py`
- **En PowerShell:** `.\edusaldo-api-gateway\test-suite\pruebas_http_automaticas.ps1`

### Variante 2: Colección de Postman
Importa `test-suite/pruebas_postman_coleccion.json` directamente en Postman (*File -> Import*). Dispara las peticiones preconfiguradas agrupadas por microservicio.

### Variante 3: Pruebas Manuales en Swagger UI
Sigue la guía `test-suite/pruebas_swagger_manual.md` que detalla los 6 flujos de negocio organizados (Ciclo feliz de reserva, rechazo por saldo insuficiente, quiebre de stock, doble firma de mermas, Variante B de compras, y regla HU58 en finanzas) con los JSONs listos para copiar y pegar.
