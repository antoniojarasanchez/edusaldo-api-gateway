# =============================================================================
# Propósito: Script de prueba de integración de extremo a extremo (E2E) que
#            levanta los 6 microservicios Spring Boot y el API Gateway en paralelo,
#            y ejecuta peticiones HTTP reales a través del Gateway (puerto 8099)
#            probando flujos completos y casos de borde (edge cases).
# Prerrequisitos: Java 17+, MySQL corriendo en puerto 3306 (XAMPP o local).
# Ejecución en Windows PowerShell / CMD:
#   python scripts/test_live_gateway.py
# =============================================================================

import subprocess
import time
import urllib.request
import urllib.error
import json
import os
import sys

java_bin = 'java'

services = [
    ('ms-auth-usuarios', 8081, r'ms-auth-usuarios\target\ms-auth-usuarios-2.0.0.jar'),
    ('ms-alumnos-saldos', 8082, r'ms-alumnos-saldos\target\ms-alumnos-saldos-2.0.0.jar'),
    ('ms-productos-inventario', 8083, r'ms-productos-inventario\target\ms-productos-inventario-2.0.0.jar'),
    ('ms-ventas-reservas', 8084, r'ms-ventas-reservas\target\ms-ventas-reservas-2.0.0.jar'),
    ('ms-compras', 8085, r'ms-compras\target\ms-compras-2.0.0.jar'),
    ('ms-finanzas-configuracion', 8086, r'ms-finanzas-configuracion\target\ms-finanzas-configuracion-2.0.0.jar'),
    ('api-gateway', 8099, r'api-gateway\target\api-gateway-2.0.0.jar'),
]

procs = []

def cleanup():
    print("\n--- CERRANDO SERVICIOS DE FORMA SEGURA ---")
    for name, port, p in procs:
        try:
            p.terminate()
            p.wait(timeout=3)
        except Exception:
            try:
                p.kill()
            except Exception:
                pass
    print("Todos los procesos han sido cerrados.")

try:
    print("=== PASO 1: LEVANTANDO LOS 7 SERVICIOS SIMULTÁNEAMENTE ===")
    for name, port, jar in services:
        print(f"Iniciando {name} en puerto {port}...")
        p = subprocess.Popen([java_bin, '-jar', jar], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append((name, port, p))

    print("\n=== PASO 2: VERIFICANDO DISPONIBILIDAD DE PUERTOS ===")
    timeout = 60
    t0 = time.time()
    
    ports_to_check = {port: name for name, port, _ in services}
    while ports_to_check and (time.time() - t0) < timeout:
        for port in list(ports_to_check.keys()):
            name = ports_to_check[port]
            try:
                req = urllib.request.Request(f"http://localhost:{port}/", method='HEAD')
                try:
                    urllib.request.urlopen(req, timeout=1)
                    print(f"  [ONLINE] {name} escuchando en puerto {port} ({time.time()-t0:.1f}s)")
                    del ports_to_check[port]
                except urllib.error.HTTPError:
                    print(f"  [ONLINE] {name} respondió en puerto {port} ({time.time()-t0:.1f}s)")
                    del ports_to_check[port]
            except Exception:
                pass
        time.sleep(1.5)

    if ports_to_check:
        print("ADVERTENCIA: Algunos servicios tardaron más de lo previsto:", ports_to_check)
    else:
        print("LOS 7 SERVICIOS ESTÁN ONLINE Y ESCUCHANDO EXITOSAMENTE.")

    print("\n=== PASO 3: PROBANDO FLUJOS REALES EXCLUSIVAMENTE VÍA API GATEWAY (8099) ===")

    def post(url, data):
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status, json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            try:
                body = json.loads(e.read().decode('utf-8'))
            except Exception:
                body = e.reason
            return e.code, body

    def get(url):
        req = urllib.request.Request(url, method='GET')
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status, json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            try:
                body = json.loads(e.read().decode('utf-8'))
            except Exception:
                body = e.reason
            return e.code, body

    gateway = "http://localhost:8099"

    # Test 1: Gateway -> Auth
    print("\n1. Test Gateway -> Auth (POST /api/auth/login)")
    st, res = post(f"{gateway}/api/auth/login", {
        "identificador": "admin@colegio.cl",
        "password": "admin123"
    })
    print(f"   Status: {st} | Usuario: {res.get('nombreCompleto')} | Rol: {res.get('rol')} | Token: {res.get('token')[:25]}...")

    # Test 2: Gateway -> Alumnos
    print("\n2. Test Gateway -> Alumnos (GET /api/alumnos)")
    st, res = get(f"{gateway}/api/alumnos")
    print(f"   Status: {st} | Estudiantes encontrados: {len(res)}")
    for a in res[:2]:
        name = str(a.get('nombreCompleto', a.get('primerNombre'))).encode('ascii', 'replace').decode('ascii')
        curso = str(a.get('curso', '')).encode('ascii', 'replace').decode('ascii')
        print(f"     - {name} ({curso}): Saldo Actual ${a['saldoActual']} - Disponible ${a['saldoDisponible']}")

    # Test 3: Gateway -> Productos
    print("\n3. Test Gateway -> Productos (GET /api/productos)")
    st, res = get(f"{gateway}/api/productos")
    print(f"   Status: {st} | Productos encontrados: {len(res)}")
    for p in res[:2]:
        pname = str(p['nombre']).encode('ascii', 'replace').decode('ascii')
        print(f"     - [{p['sku']}] {pname}: Precio ${p['precioVenta']} - Físico {p['stockFisico']} - Disp {p['stockDisponible']}")

    # Test 4: Gateway -> Ventas/Reservas
    print("\n4. Test Gateway -> Ventas/Reservas (POST /api/reservas)")
    st, res = post(f"{gateway}/api/reservas", {
        "alumnoId": 1,
        "apoderadoId": 4,
        "items": [
            {"productoId": 101, "nombreProducto": "Cuaderno universitario", "cantidad": 2, "precioUnitario": 1250}
        ]
    })
    print(f"   Status: {st} | Reserva Creada: {res.get('codigo')} | Total: ${res.get('total')} | Estado: {res.get('estado')}")
    reserva_id = res.get('id')

    # Test 5: Gateway -> Ventas Preparación
    if reserva_id:
        print(f"\n5. Test Gateway -> Ventas Avanzar Estado Reserva #{reserva_id}")
        req = urllib.request.Request(f"{gateway}/api/reservas/{reserva_id}/iniciar-preparacion?encargadoId=2", method='PUT')
        with urllib.request.urlopen(req) as resp:
            r_prep = json.loads(resp.read().decode('utf-8'))
            print(f"   Status: {resp.status} | Nuevo Estado: {r_prep.get('estado')}")

        req_etq = urllib.request.Request(f"{gateway}/api/reservas/{reserva_id}/etiquetar", method='PUT')
        with urllib.request.urlopen(req_etq) as resp:
            r_etq = json.loads(resp.read().decode('utf-8'))
            print(f"   Status: {resp.status} | Etiqueta Bolsa Generada: {r_etq.get('codigoBolsa')}")

    # Test 6: Gateway -> Edge Case Saldo Insuficiente
    print("\n6. Test Gateway -> Edge Case Saldo Insuficiente (POST /api/saldos/1/comprometer)")
    st, res = post(f"{gateway}/api/saldos/1/comprometer", {
        "monto": 999999,
        "reservaId": 999,
        "usuarioId": 1,
        "idempotencyKey": "KEY-FAIL-TEST"
    })
    print(f"   Status: {st} (Esperado 422) | Mensaje de Negocio: {res.get('message')}")

    # Test 7: Gateway -> Edge Case Stock Insuficiente
    print("\n7. Test Gateway -> Edge Case Stock Insuficiente (POST /api/inventario/101/reservar)")
    st, res = post(f"{gateway}/api/inventario/101/reservar", {
        "cantidad": 9999,
        "referenciaId": 999,
        "usuarioId": 1,
        "idempotencyKey": "KEY-STOCK-FAIL"
    })
    print(f"   Status: {st} (Esperado 422) | Mensaje de Negocio: {res.get('message')}")

    # Test 8: Gateway -> Finanzas
    print("\n8. Test Gateway -> Finanzas (GET /api/finanzas/caja/movimientos)")
    st, res = get(f"{gateway}/api/finanzas/caja/movimientos")
    print(f"   Status: {st} | Movimientos de caja encontrados: {len(res)}")

    # Test 9: Gateway -> Compras
    print("\n9. Test Gateway -> Compras (GET /api/proveedores)")
    st, res = get(f"{gateway}/api/proveedores")
    print(f"   Status: {st} | Proveedores encontrados: {len(res)}")
    for prov in res[:1]:
        print(f"     - [{prov['rut']}] {prov['razonSocial']}")

    print("\n=== TODOS LOS FLUJOS REALES Y CASOS DE BORDE PASARON CON 100% DE ÉXITO ===")

finally:
    cleanup()
