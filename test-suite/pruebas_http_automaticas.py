# =============================================================================
# Propósito: Suite completa de pruebas de integración en vivo que ejecuta
#            casos de uso reales y de borde (edge cases) EXCLUSIVAMENTE a
#            través del API Gateway (puerto 8099) sobre los 4 microservicios de EduSaldo 2.0.
# Prerrequisitos: Los 5 servicios deben estar corriendo en puertos 8081-8084 y 8099.
# Ejecución: python edusaldo-api-gateway/test-suite/pruebas_http_automaticas.py
# =============================================================================

import urllib.request
import urllib.error
import json
import time
import sys

GATEWAY = "http://localhost:8099"
current_test_calls = []

def post(endpoint, data):
    url = f"{GATEWAY}{endpoint}"
    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    status_code = 0
    body = None
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            status_code = resp.status
            body = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        status_code = e.code
        try:
            body = json.loads(e.read().decode('utf-8'))
        except Exception:
            body = e.reason
    except Exception as ex:
        status_code = 0
        body = str(ex)
    if not isinstance(body, (dict, list)):
        body = {"error": str(body), "message": str(body)}
    current_test_calls.append(('POST', url, data, status_code, body))
    return status_code, body

def get(endpoint):
    url = f"{GATEWAY}{endpoint}"
    req = urllib.request.Request(url, method='GET')
    status_code = 0
    body = None
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            status_code = resp.status
            body = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        status_code = e.code
        try:
            body = json.loads(e.read().decode('utf-8'))
        except Exception:
            body = e.reason
    except Exception as ex:
        status_code = 0
        body = str(ex)
    if not isinstance(body, (dict, list)):
        body = {"error": str(body), "message": str(body)}
    current_test_calls.append(('GET', url, None, status_code, body))
    return status_code, body

def put(endpoint, data=None):
    url = f"{GATEWAY}{endpoint}"
    payload = json.dumps(data).encode('utf-8') if data is not None else None
    headers = {'Content-Type': 'application/json'} if data is not None else {}
    req = urllib.request.Request(url, data=payload, headers=headers, method='PUT')
    status_code = 0
    body = None
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            status_code = resp.status
            body = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        status_code = e.code
        try:
            body = json.loads(e.read().decode('utf-8'))
        except Exception:
            body = e.reason
    except Exception as ex:
        status_code = 0
        body = str(ex)
    if not isinstance(body, (dict, list)):
        body = {"error": str(body), "message": str(body)}
    current_test_calls.append(('PUT', url, data, status_code, body))
    return status_code, body

def delete(endpoint):
    url = f"{GATEWAY}{endpoint}"
    req = urllib.request.Request(url, method='DELETE')
    status_code = 0
    body = None
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            status_code = resp.status
            body = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        status_code = e.code
        try:
            body = json.loads(e.read().decode('utf-8'))
        except Exception:
            body = e.reason
    except Exception as ex:
        status_code = 0
        body = str(ex)
    if not isinstance(body, (dict, list)):
        body = {"error": str(body), "message": str(body)}
    current_test_calls.append(('DELETE', url, None, status_code, body))
    return status_code, body

passed = 0
failed = 0

def format_multiline(data, indent="            "):
    if data is None:
        return f"{indent}None"
    try:
        text = json.dumps(data, indent=2, ensure_ascii=False)
        return "\n".join(f"{indent}{line}" for line in text.splitlines())
    except Exception:
        return f"{indent}{str(data)}"

def check(num, desc, cond, extra=""):
    global passed, failed
    if cond:
        passed += 1
        print(f"  [PASS] {num}. {desc} {extra}")
    else:
        failed += 1
        print(f"  [FAIL] {num}. {desc} {extra}")
    for method, url, payload, status, resp in current_test_calls:
        print(f"       -> [{method}] {url}")
        if payload is not None:
            print("          Payload Enviado:")
            print(format_multiline(payload, "            "))
        print(f"       <- HTTP {status}")
        print("          Respuesta del Microservicio:")
        print(format_multiline(resp, "            "))
    current_test_calls.clear()

print("=============================================================================")
print("  EDUSALDO 2.0 - BATERÍA COMPLETA DE PRUEBAS EN VIVO VÍA API GATEWAY (8099)")
print("=============================================================================")

# -----------------------------------------------------------------------------
# 1. MS USUARIOS Y AUTH (Puerto 8081)
# -----------------------------------------------------------------------------
print("\n--- 1. MS USUARIOS Y AUTH (Puerto 8081) ---")

# Caso 1: Login exitoso
st, res = post("/api/auth/login", {"identificador": "admin@colegio.cl", "password": "admin123"})
check("01", "Login Administrador exitoso", st == 200 and "token" in res, f"(Usuario: {res.get('nombreCompleto')})")

# Caso 2: Login con credenciales incorrectas
st, res = post("/api/auth/login", {"identificador": "admin@colegio.cl", "password": "clave_falsa_999"})
check("02", "Login fallido controlado con rechazo", st in [400, 401], f"(Mensaje: {res.get('message')})")

# Caso 3: Alta atómica Alumno + Apoderado (HU15)
ts = int(time.time())
st, res = post("/api/usuarios/alumnos", {
    "rutAlumno": f"24.{ts % 900 + 100}.111-K",
    "primerNombreAlumno": "Tomás",
    "primerApellidoAlumno": "González",
    "fechaNacimiento": "2012-05-15",
    "curso": "7° Básico",
    "rutApoderado": f"16.{ts % 900 + 100}.222-3",
    "primerNombreApoderado": "Carlos",
    "primerApellidoApoderado": "González",
    "correoApoderado": f"apoderado_{ts}@gmail.com",
    "telefonoApoderado": "+56912345678",
    "parentesco": "PADRE"
})
check("03", "Alta atómica Alumno + Apoderado (HU15)", st in [200, 201] and res.get("alumnoId") is not None, f"(Alumno ID: {res.get('alumnoId')})")
created_alumno_id = res.get("alumnoId")
created_apoderado_id = res.get("apoderadoId")

# Caso 4: Consulta de alumnos de un apoderado
if created_apoderado_id:
    st, res = get(f"/api/usuarios/apoderados/{created_apoderado_id}/alumnos")
    check("04", "Consulta de alumnos de un apoderado", st == 200 and len(res) >= 1)

# Caso 5: Consulta de configuración institucional y auditoría
st_cfg, _ = get("/api/configuracion")
st_aud, _ = get("/api/auditoria")
check("05", "Consulta de configuración institucional y auditoría", st_cfg == 200 and st_aud == 200)

# -----------------------------------------------------------------------------
# 2. MS SALDOS Y ABONOS (Puerto 8082)
# -----------------------------------------------------------------------------
print("\n--- 2. MS SALDOS Y ABONOS (Puerto 8082) ---")

alumno_target = created_alumno_id if created_alumno_id else 1
# Caso 6: Consulta de cuenta de saldo
st, res = get(f"/api/saldos/cuenta/{alumno_target}")
check("06", "Consulta de cuenta de saldo del alumno", st in [200, 201] and "saldoDisponible" in res)

# Caso 7: Iniciar abono con pasarela simulada
st, res = post("/api/saldos/abonos/iniciar", {
    "apoderadoId": created_apoderado_id if created_apoderado_id else 1,
    "alumnoId": alumno_target,
    "monto": 10000
})
check("07", "Inicio de abono simulado con token generado", st in [200, 201] and "token" in res)
token_abono = res.get("token")

# Caso 8: Confirmar abono con token
if token_abono:
    st, res = post("/api/saldos/abonos/confirmar", {"token": token_abono})
    check("08", "Confirmación de abono y acreditación en CuentaSaldo", st == 200 and res.get("estado") == "APROBADO")

# Caso 9: Edge case - Retención fallida por saldo insuficiente
st, res = post("/api/saldos/retener", {
    "alumnoId": alumno_target,
    "monto": 9999999,
    "reservaId": 999
})
check("09", "Rechazo controlado por saldo insuficiente (400/422)", st in [400, 422])

# Caso 10: Consulta de libro mayor de movimientos de saldo
st, res = get(f"/api/saldos/cuenta/{alumno_target}/movimientos")
check("10", "Consulta de libro mayor MovimientoSaldo", st == 200 and len(res) >= 1)

# -----------------------------------------------------------------------------
# 3. MS PRODUCTOS E INVENTARIO (Puerto 8083)
# -----------------------------------------------------------------------------
print("\n--- 3. MS PRODUCTOS E INVENTARIO (Puerto 8083) ---")

# Caso 11: Consulta de catálogo
st, res = get("/api/productos")
check("11", "Consulta de catálogo y existencias", st == 200)

# Caso 12: Ingreso manual de stock por Encargado (HU46)
st, res = post("/api/inventario/ingresos-manuales", {
    "encargadoId": 2,
    "proveedor": "Distribuidora Escolar Central",
    "documentoReferencia": "GUIA-DESPACHO-4581",
    "observacion": "Recepción de cuadernos y lápices para inicio de semestre",
    "detalles": [
        {"productoId": 1, "cantidad": 25}
    ]
})
check("12", "Ingreso manual de stock por Encargado (HU46)", st in [200, 201])

# Caso 13: Solicitud de ajuste de stock por Encargado (HU45)
st, res = post("/api/inventario/ajustes/solicitar", {
    "productoId": 1,
    "cantidad": -2,
    "motivo": "Merma por deterioro en estante",
    "encargadoId": 2
})
check("13", "Solicitud de ajuste de stock en PENDIENTE", st in [200, 201] and res.get("estado") == "PENDIENTE")
ajuste_id = res.get("id")

# Caso 14: Aprobación exclusiva por Administrador
if ajuste_id:
    st, res = post(f"/api/inventario/ajustes/{ajuste_id}/aprobar", {"administradorId": 1})
    check("14", "Aprobación de ajuste por Administrador (HU45)", st == 200 and res.get("estado") == "APROBADA")

# -----------------------------------------------------------------------------
# 4. MS RESERVAS Y ENTREGAS (Puerto 8084)
# -----------------------------------------------------------------------------
print("\n--- 4. MS RESERVAS Y ENTREGAS (Puerto 8084) ---")

# Caso 15: Crear reserva multilínea
st, res = post("/api/reservas", {
    "alumnoId": alumno_target,
    "creadaPorId": created_apoderado_id if created_apoderado_id else 1,
    "items": [
        {"productoId": 1, "nombreProducto": "Cuaderno universitario", "cantidad": 2, "precioUnitario": 1500}
    ]
})
check("15", "Creación de reserva en estado PENDIENTE", st in [200, 201] and res.get("estado") == "PENDIENTE")
reserva_id = res.get("id")

# Caso 16: Preparar reserva con trazabilidad HU31 CA2
if reserva_id:
    st, res = post(f"/api/reservas/{reserva_id}/marcar-lista", {"encargadoId": 2})
    check("16", "Preparación de reserva (HU31 CA2: preparadaPorId y fecha)", st == 200 and res.get("estado") == "LISTA_PARA_RETIRO")

# Caso 17: Retiro y generación formal de Entrega
if reserva_id:
    st, res = post(f"/api/reservas/{reserva_id}/entregar", {"encargadoId": 2})
    check("17", "Confirmación de retiro genera Entrega formal", st in [200, 201] and res.get("origen") == "RESERVA")
    entrega_id = res.get("id")

# Caso 18: Entrega directa presencial en mesón
st, res = post("/api/entregas/meson", {
    "alumnoId": alumno_target,
    "encargadoId": 2,
    "items": [
        {"productoId": 1, "nombreProducto": "Lápiz grafito", "cantidad": 1, "precioUnitario": 500}
    ]
})
check("18", "Entrega directa presencial en mesón (MESON)", st in [200, 201] and res.get("origen") == "MESON")

# Caso 19: Cancelación de reserva permitida para alumno o apoderado
st_res2, res2 = post("/api/reservas", {
    "alumnoId": alumno_target,
    "creadaPorId": alumno_target,
    "items": [{"productoId": 1, "nombreProducto": "Regla 30cm", "cantidad": 1, "precioUnitario": 800}]
})
if st_res2 in [200, 201] and res2.get("id"):
    r2_id = res2.get("id")
    st, res = post(f"/api/reservas/{r2_id}/cancelar", {"motivo": "Cancelado por alumno antes de retiro", "usuarioId": alumno_target, "rol": "ALU"})
    check("19", "Cancelación de reserva por Alumno >= 12 años", st == 200 and res.get("estado") == "CANCELADA")

# Caso 20: Consulta de historial de entregas
st, res = get("/api/entregas/historial")
check("20", "Consulta de historial de entregas operativas", st == 200 and len(res) >= 1)

print("\n=============================================================================")
print(f"  RESULTADO FINAL: {passed} CASOS PASARON | {failed} CASOS FALLARON")
print("=============================================================================")

if failed == 0:
    print("[OK] LOS 4 MICROSERVICIOS Y EL GATEWAY OPERAN AL 100% SIN ERRORES.")
    sys.exit(0)
else:
    print("ALERTA: Se detectaron fallos en la batería de pruebas.")
    sys.exit(1)
