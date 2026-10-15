<#
 =============================================================================
 Propósito: Realiza un FRESH START completo de las bases de datos de EduSaldo.
            Elimina bases de datos obsoletas y recrea limpiamente los 4 esquemas
            canónicos (db_usuarios, db_saldos, db_inventario, db_reservas)
            ejecutando sus respectivos scripts schema.sql y seeds iniciales.
 Ejecución: .\edusaldo-api-gateway\scripts\reset_bases_datos.ps1
 =============================================================================
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
if (-not (Test-Path "$RootDir\edusaldo-api-gateway")) {
    $RootDir = Split-Path -Parent $ScriptDir
}

$MysqlExe = "C:\xampp\mysql\bin\mysql.exe"
if (-not (Test-Path $MysqlExe)) {
    $MysqlExe = "mysql"
}

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "  EDUSALDO 2.0 - REINICIO LIMPIO (FRESH START) DE BASES DE DATOS" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

$LegacyDbs = @(
    "db_alumnos_saldos",
    "db_productos_inventario",
    "db_auth_usuarios",
    "db_ventas_reservas",
    "db_compras",
    "db_finanzas_config"
)

$Schemas = @(
    @{ Name = "db_usuarios"; Sql = "$RootDir\edusaldo-ms-auth-usuarios\src\main\resources\schema.sql" },
    @{ Name = "db_saldos"; Sql = "$RootDir\edusaldo-ms-alumnos-saldos\src\main\resources\schema.sql" },
    @{ Name = "db_inventario"; Sql = "$RootDir\edusaldo-ms-productos-inventario\src\main\resources\schema.sql" },
    @{ Name = "db_reservas"; Sql = "$RootDir\edusaldo-ms-ventas-reservas\src\main\resources\schema.sql" }
)

Write-Host "[1/3] Limpiando esquemas obsoletos y recreando canónicos..." -ForegroundColor Yellow
$CleanSql = ""
foreach ($db in $LegacyDbs) {
    $CleanSql += "DROP DATABASE IF EXISTS $db;`n"
}
foreach ($s in $Schemas) {
    $CleanSql += "DROP DATABASE IF EXISTS $($s.Name);`nCREATE DATABASE $($s.Name) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`n"
}

& $MysqlExe -u root -e $CleanSql
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la recreación de esquemas en MySQL." -ForegroundColor Red
    exit 1
}

Write-Host "[2/3] Cargando schema.sql y seeds iniciales..." -ForegroundColor Yellow
foreach ($s in $Schemas) {
    if (Test-Path $s.Sql) {
        Get-Content $s.Sql -Raw | & $MysqlExe -u root $($s.Name)
        Write-Host "      [OK] $($s.Name) poblada desde $(Split-Path $s.Sql -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "      [AVISO] Archivo no encontrado: $($s.Sql)" -ForegroundColor Red
    }
}

Write-Host "[3/3] Resumen de tablas y datos iniciales creados:" -ForegroundColor Yellow
$SummarySql = @"
SELECT 'db_usuarios' AS 'Base de Datos', count(*) AS 'Registros Iniciales' FROM db_usuarios.usuarios
UNION ALL
SELECT 'db_saldos', count(*) FROM db_saldos.cuentas_saldo
UNION ALL
SELECT 'db_inventario', count(*) FROM db_inventario.productos
UNION ALL
SELECT 'db_reservas', count(*) FROM db_reservas.reservas;
"@

& $MysqlExe -u root -e $SummarySql
Write-Host "`n[OK] FRESH START COMPLETADO EXITOSAMENTE." -ForegroundColor Green
