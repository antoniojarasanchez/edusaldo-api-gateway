# =============================================================================
# Propósito: Levanta concurrentemente los 4 microservicios Spring Boot y el
#            API Gateway en segundo plano con detección dinámica de carpetas hermanas.
# Puertos: 8099 (Gateway), 8081 (Auth/Usuarios), 8082 (Saldos/Abonos),
#          8083 (Productos/Inventario), 8084 (Reservas/Entregas).
# Ejecución: python edusaldo-api-gateway/scripts/arrancar_servicios.py
# =============================================================================

import subprocess
import time
import urllib.request
import urllib.error
import json
import os
import sys

DETACHED_PROCESS = 0x00000008
CREATE_NEW_PROCESS_GROUP = 0x00000200

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_root_dir():
    candidates = [
        os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..')),
        os.path.abspath(os.path.join(SCRIPT_DIR, '..')),
        os.path.abspath('.')
    ]
    for c in candidates:
        if os.path.exists(os.path.join(c, 'edusaldo-api-gateway')) or os.path.exists(os.path.join(c, 'edusaldo-ms-auth-usuarios')):
            return c
    return candidates[0]

ROOT_DIR = find_root_dir()

services = [
    ('edusaldo-ms-auth-usuarios', 8081),
    ('edusaldo-ms-alumnos-saldos', 8082),
    ('edusaldo-ms-productos-inventario', 8083),
    ('edusaldo-ms-ventas-reservas', 8084),
    ('edusaldo-api-gateway', 8099),
]

logs_dir = os.path.join(ROOT_DIR, 'edusaldo-api-gateway', 'logs')
os.makedirs(logs_dir, exist_ok=True)
pids = {}

print("=============================================================================")
print("  EDUSALDO 2.0 - INICIANDO 4 MICROSERVICIOS Y GATEWAY EN SEGUNDO PLANO")
print("=============================================================================")
print(f"Directorio raíz detectado: {ROOT_DIR}\n")

for name, port in services:
    svc_dir = os.path.join(ROOT_DIR, name)
    jar_file = None
    target_dir = os.path.join(svc_dir, 'target')
    if os.path.exists(target_dir):
        for f in os.listdir(target_dir):
            if f.endswith('.jar') and not f.endswith('.original'):
                jar_file = os.path.join(target_dir, f)
                break

    if not jar_file or not os.path.exists(jar_file):
        print(f"[ERROR] No se encontró el archivo JAR en {target_dir}. Ejecuta 'mvn package -DskipTests' primero.")
        continue

    log_path = os.path.join(logs_dir, f'{name}.log')
    log_fp = open(log_path, 'w', encoding='utf-8')
    p = subprocess.Popen(
        ['java', '-jar', jar_file],
        cwd=svc_dir,
        stdout=log_fp,
        stderr=log_fp,
        creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP
    )
    pids[name] = {'pid': p.pid, 'port': port}
    print(f"  [START] {name} (PID: {p.pid}) -> Puerto {port}")

pid_file = os.path.join(ROOT_DIR, 'edusaldo-api-gateway', 'services_pids.json')
with open(pid_file, 'w', encoding='utf-8') as f:
    json.dump(pids, f, indent=2)

print("\n=== VERIFICANDO CONECTIVIDAD DE PUERTOS ===")
timeout = 60
t0 = time.time()
ports_to_check = {port: name for name, port in services}

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
    print("\n[ALERTA] Algunos servicios aún no responden:", ports_to_check)
else:
    print("\n[OK] LOS 4 MICROSERVICIOS Y EL GATEWAY ESTÁN ONLINE Y LISTOS.")

if "--daemon" in sys.argv or "--wait" in sys.argv:
    print("\n[SUPERVISOR] Modo daemon activo. Manteniendo procesos vivos en segundo plano...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[SUPERVISOR] Deteniendo procesos...")
