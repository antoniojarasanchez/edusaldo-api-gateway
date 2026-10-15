# =============================================================================
# Propósito: Levanta concurrentemente los 4 microservicios Spring Boot y el
#            API Gateway, verifica puertos y TRANSMITE LOS LOGS EN VIVO en la
#            consola manteniendo la ventana abierta para monitoreo continuo.
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

# Activar soporte de colores ANSI en terminales Windows
try:
    import ctypes
    kernel32 = ctypes.windll.kernel32
    kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
except Exception:
    pass

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
    ('edusaldo-ms-auth-usuarios', 8081, '\033[94m[AUTH 8081]\033[0m '),
    ('edusaldo-ms-alumnos-saldos', 8082, '\033[92m[SALDOS 8082]\033[0m '),
    ('edusaldo-ms-productos-inventario', 8083, '\033[93m[INVENTARIO 8083]\033[0m '),
    ('edusaldo-ms-ventas-reservas', 8084, '\033[95m[RESERVAS 8084]\033[0m '),
    ('edusaldo-api-gateway', 8099, '\033[96m[GATEWAY 8099]\033[0m '),
]

logs_dir = os.path.join(ROOT_DIR, 'edusaldo-api-gateway', 'logs')
os.makedirs(logs_dir, exist_ok=True)

print("=============================================================================")
print("  EDUSALDO 2.0 - ARRANQUE Y MONITOREO DE 4 MICROSERVICIOS Y GATEWAY")
print("=============================================================================")
print(f"Directorio raiz detectado: {ROOT_DIR}\n")

# 1. Comprobar y liberar puertos ocupados previamente
print("[1/3] Verificando estado inicial de puertos...")
def check_port_free(port):
    try:
        req = urllib.request.Request(f"http://localhost:{port}/", method='HEAD')
        urllib.request.urlopen(req, timeout=0.5)
        return False
    except Exception:
        return True

spawned_processes = []
log_handles = []
open_readers = {}

for name, port, tag in services:
    svc_dir = os.path.join(ROOT_DIR, name)
    jar_file = None
    target_dir = os.path.join(svc_dir, 'target')
    if os.path.exists(target_dir):
        for f in os.listdir(target_dir):
            if f.endswith('.jar') and not f.endswith('.original'):
                jar_file = os.path.join(target_dir, f)
                break

    if not jar_file or not os.path.exists(jar_file):
        print(f"[ERROR] No se encontro el archivo JAR en {target_dir}. Compila primero.")
        continue

    log_path = os.path.join(logs_dir, f'{name}.log')
    # Abrir para escritura
    log_fp = open(log_path, 'w', encoding='utf-8')
    log_handles.append(log_fp)

    p = subprocess.Popen(
        ['java', '-jar', jar_file],
        cwd=svc_dir,
        stdout=log_fp,
        stderr=log_fp
    )
    spawned_processes.append((name, port, p, log_path, tag))
    print(f"  [START] {name} (PID: {p.pid}) -> Puerto {port}")

# Guardar PIDs
pids_data = {name: {'pid': p.pid, 'port': port} for name, port, p, _, _ in spawned_processes}
pid_file = os.path.join(ROOT_DIR, 'edusaldo-api-gateway', 'services_pids.json')
with open(pid_file, 'w', encoding='utf-8') as f:
    json.dump(pids_data, f, indent=2)

print("\n[2/3] Esperando que los puertos abran...")
timeout = 60
t0 = time.time()
ports_to_check = {port: name for name, port, _, _, _ in spawned_processes}

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
                print(f"  [ONLINE] {name} respondio en puerto {port} ({time.time()-t0:.1f}s)")
                del ports_to_check[port]
        except Exception:
            pass
    time.sleep(1.2)

print("\n[3/3] Estado del sistema:")
if ports_to_check:
    print("  [ALERTA] Algunos servicios aun no responden en sus puertos:", ports_to_check)
else:
    print("  [OK] LOS 4 MICROSERVICIOS Y EL GATEWAY ESTAN 100% ONLINE Y OPERATIVOS.")

print("\n" + "="*77)
print("  URLS DISPONIBLES:")
print("  * API Gateway Central:      http://localhost:8099")
print("  * MS Usuarios y Auth:       http://localhost:8081 (Swagger: /swagger-ui.html)")
print("  * MS Alumnos y Saldos:      http://localhost:8082 (Swagger: /swagger-ui.html)")
print("  * MS Productos e Inventario: http://localhost:8083 (Swagger: /swagger-ui.html)")
print("  * MS Reservas y Entregas:   http://localhost:8084 (Swagger: /swagger-ui.html)")
print("="*77)
print("  MONITOR DE LOGS EN VIVO (Presiona Ctrl+C en cualquier momento para detener)")
print("="*77 + "\n")

# Abrir lectores de logs
readers = {}
for name, port, p, log_path, tag in spawned_processes:
    try:
        rfp = open(log_path, 'r', encoding='utf-8', errors='replace')
        # Avanzar al final inicial o mostrar inicio
        readers[name] = (rfp, tag)
    except Exception:
        pass

try:
    while True:
        had_line = False
        for name, (rfp, tag) in readers.items():
            line = rfp.readline()
            while line:
                had_line = True
                cleaned = line.rstrip()
                if cleaned:
                    print(f"{tag}{cleaned}")
                line = rfp.readline()
        if not had_line:
            time.sleep(0.3)
except KeyboardInterrupt:
    print("\n\n[DETENIENDO] Cerrando los 4 microservicios y el API Gateway...")
    for name, port, p, _, _ in spawned_processes:
        try:
            p.terminate()
            p.wait(timeout=2)
        except Exception:
            try:
                p.kill()
            except Exception:
                pass
    print("[OK] Todos los procesos fueron detenidos limpiamente.")
finally:
    for fp in log_handles:
        try:
            fp.close()
        except Exception:
            pass
    for rfp, _ in readers.values():
        try:
            rfp.close()
        except Exception:
            pass
    print("\nPresiona Enter para cerrar esta consola...")
    try:
        input()
    except Exception:
        pass
