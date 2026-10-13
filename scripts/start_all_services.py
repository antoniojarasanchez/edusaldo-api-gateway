# =============================================================================
# Propósito: Levanta los 6 microservicios Spring Boot y el API Gateway en segundo plano
#            en Windows como procesos independientes desacoplados.
# Puertos: 8099 (Gateway), 8081 (Auth), 8082 (Alumnos), 8083 (Productos),
#          8084 (Ventas), 8085 (Compras), 8086 (Finanzas).
# Ejecución: python api-gateway/scripts/start_all_services.py
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

# Ubicación raíz del proyecto EduSaldo
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

services = [
    ('ms-auth-usuarios', 8081, os.path.join(ROOT_DIR, 'ms-auth-usuarios', 'target', 'ms-auth-usuarios-2.0.0.jar')),
    ('ms-alumnos-saldos', 8082, os.path.join(ROOT_DIR, 'ms-alumnos-saldos', 'target', 'ms-alumnos-saldos-2.0.0.jar')),
    ('ms-productos-inventario', 8083, os.path.join(ROOT_DIR, 'ms-productos-inventario', 'target', 'ms-productos-inventario-2.0.0.jar')),
    ('ms-ventas-reservas', 8084, os.path.join(ROOT_DIR, 'ms-ventas-reservas', 'target', 'ms-ventas-reservas-2.0.0.jar')),
    ('ms-compras', 8085, os.path.join(ROOT_DIR, 'ms-compras', 'target', 'ms-compras-2.0.0.jar')),
    ('ms-finanzas-configuracion', 8086, os.path.join(ROOT_DIR, 'ms-finanzas-configuracion', 'target', 'ms-finanzas-configuracion-2.0.0.jar')),
    ('api-gateway', 8099, os.path.join(ROOT_DIR, 'api-gateway', 'target', 'api-gateway-2.0.0.jar')),
]

logs_dir = os.path.join(ROOT_DIR, 'api-gateway', 'logs')
os.makedirs(logs_dir, exist_ok=True)
pids = {}

print("=== INICIANDO LOS 7 SERVICIOS SPRING BOOT EN SEGUNDO PLANO ===")

for name, port, jar in services:
    log_file = open(os.path.join(logs_dir, f'{name}.log'), 'w', encoding='utf-8')
    p = subprocess.Popen(
        ['java', '-jar', jar],
        stdout=log_file,
        stderr=log_file,
        creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP
    )
    pids[name] = {'pid': p.pid, 'port': port}
    print(f"Lanzado {name} (PID: {p.pid}) en puerto {port}...")

pid_file = os.path.join(ROOT_DIR, 'api-gateway', 'services_pids.json')
with open(pid_file, 'w') as f:
    json.dump(pids, f, indent=2)

print("\n=== VERIFICANDO QUE TODOS LOS PUERTOS ESTÉN ESCUCHANDO ===")
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
    print("ADVERTENCIA: Algunos servicios tardaron más:", ports_to_check)
else:
    print("LOS 7 SERVICIOS ESTÁN ONLINE, ACTIVOS Y ESCUCHANDO EN SUS PUERTOS.")
