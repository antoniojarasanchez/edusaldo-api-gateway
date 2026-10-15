# =============================================================================
# Propósito: Realiza un FRESH START completo de las bases de datos de EduSaldo.
#            Elimina bases de datos obsoletas y recrea limpiamente los 4 esquemas
#            canónicos (db_usuarios, db_saldos, db_inventario, db_reservas)
#            ejecutando sus respectivos scripts schema.sql y seeds iniciales.
# Ejecución: python edusaldo-api-gateway/scripts/reset_bases_datos.py
# =============================================================================

import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_root_dir():
    candidates = [
        os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..')),
        os.path.abspath(os.path.join(SCRIPT_DIR, '..')),
        os.path.abspath('.')
    ]
    for c in candidates:
        if os.path.exists(os.path.join(c, 'edusaldo-api-gateway')):
            return c
    return candidates[0]

ROOT_DIR = find_root_dir()

MYSQL_PATH = r"C:\xampp\mysql\bin\mysql.exe"
if not os.path.exists(MYSQL_PATH):
    MYSQL_PATH = "mysql"

schemas = [
    ("db_usuarios", os.path.join(ROOT_DIR, "edusaldo-ms-auth-usuarios", "src", "main", "resources", "schema.sql")),
    ("db_saldos", os.path.join(ROOT_DIR, "edusaldo-ms-alumnos-saldos", "src", "main", "resources", "schema.sql")),
    ("db_inventario", os.path.join(ROOT_DIR, "edusaldo-ms-productos-inventario", "src", "main", "resources", "schema.sql")),
    ("db_reservas", os.path.join(ROOT_DIR, "edusaldo-ms-ventas-reservas", "src", "main", "resources", "schema.sql")),
]

legacy_dbs = [
    "db_alumnos_saldos",
    "db_productos_inventario",
    "db_auth_usuarios",
    "db_ventas_reservas",
    "db_compras",
    "db_finanzas_config"
]

print("=============================================================================")
print("  EDUSALDO 2.0 - REINICIO LIMPIO (FRESH START) DE BASES DE DATOS")
print("=============================================================================")

# 1. Eliminar bases de datos obsoletas y recrear las 4 canónicas
clean_sql = ""
for db in legacy_dbs:
    clean_sql += f"DROP DATABASE IF EXISTS {db};\n"
for db, _ in schemas:
    clean_sql += f"DROP DATABASE IF EXISTS {db};\nCREATE DATABASE {db} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n"

print("[1/3] Limpiando esquemas en MySQL/MariaDB...")
try:
    p = subprocess.run([MYSQL_PATH, "-u", "root", "-e", clean_sql], capture_output=True, text=True, check=True)
    print("      Bases de datos obsoletas eliminadas y esquemas canónicos recreados.")
except subprocess.CalledProcessError as e:
    print(f"[ERROR] Error al recrear bases de datos: {e.stderr}")
    sys.exit(1)

# 2. Cargar schemas y seeds
print("[2/3] Cargando schema.sql y seeds para los 4 microservicios...")
for db_name, sql_file in schemas:
    if not os.path.exists(sql_file):
        print(f"      [AVISO] No se encontró {sql_file}")
        continue
    with open(sql_file, "r", encoding="utf-8") as f:
        sql_content = f.read()
    try:
        p = subprocess.run([MYSQL_PATH, "-u", "root", db_name], input=sql_content, capture_output=True, text=True, check=True)
        print(f"      [OK] {db_name} poblada exitosamente desde {os.path.basename(sql_file)}")
    except subprocess.CalledProcessError as e:
        print(f"      [ERROR] Fallo al cargar {db_name}: {e.stderr}")

# 3. Resumen de conteos
print("[3/3] Resumen de registros iniciales creados:")
summary_sql = """
SELECT 'db_usuarios' AS 'Base de Datos', count(*) AS 'Registros Iniciales' FROM db_usuarios.usuarios
UNION ALL
SELECT 'db_saldos', count(*) FROM db_saldos.cuentas_saldo
UNION ALL
SELECT 'db_inventario', count(*) FROM db_inventario.productos
UNION ALL
SELECT 'db_reservas', count(*) FROM db_reservas.reservas;
"""
res = subprocess.run([MYSQL_PATH, "-u", "root", "-e", summary_sql], capture_output=True, text=True)
print(res.stdout)
print("[OK] FRESH START COMPLETADO EXITOSAMENTE.")
