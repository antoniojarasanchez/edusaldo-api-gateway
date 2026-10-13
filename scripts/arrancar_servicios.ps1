# =============================================================================
# Proposito: Levanta concurrentemente los 6 microservicios Spring Boot y el
#            API Gateway en segundo plano con deteccion dinamica de carpetas hermanas.
#            Verifica e inicia MySQL automaticamente si XAMPP esta instalado.
#            Si los archivos JAR no estan compilados, los compila con Maven.
# Puertos: 8099 (Gateway), 8081 (Auth), 8082 (Alumnos), 8083 (Productos),
#          8084 (Ventas), 8085 (Compras), 8086 (Finanzas).
# Ejecucion en PowerShell:
#   .\edusaldo-api-gateway\scripts\arrancar_servicios.ps1
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolucion dinamica de la carpeta raiz contenedora
$Candidates = @(
    (Resolve-Path "$ScriptDir\..\..").Path,
    (Resolve-Path "$ScriptDir\..").Path,
    (Resolve-Path ".").Path
)

$RootDir = $Candidates[0]
foreach ($c in $Candidates) {
    if ((Test-Path "$c\edusaldo-api-gateway") -or (Test-Path "$c\edusaldo-ms-auth-usuarios")) {
        $RootDir = $c
        break
    }
}

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "  EDUSALDO 2.0 - INICIANDO SERVICIOS SPRING BOOT EN SEGUNDO PLANO (POWERSHELL)" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Directorio raiz detectado: $RootDir`n" -ForegroundColor DarkGray

# 1. Verificar MySQL en puerto 3306
Write-Host "=== VERIFICANDO BASE DE DATOS MYSQL (PUERTO 3306) ===" -ForegroundColor Yellow
$mysqlConn = Test-NetConnection -ComputerName localhost -Port 3306 -WarningAction SilentlyContinue

if (!$mysqlConn.TcpTestSucceeded) {
    Write-Host "  [MYSQL] MySQL no esta escuchando. Intentando iniciar XAMPP MySQL..." -ForegroundColor Yellow
    if (Test-Path "C:\xampp\mysql\bin\mysqld.exe") {
        Start-Process -FilePath "C:\xampp\mysql\bin\mysqld.exe" -ArgumentList "--defaults-file=`"C:\xampp\mysql\bin\my.ini`" --standalone" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        $mysqlConn = Test-NetConnection -ComputerName localhost -Port 3306 -WarningAction SilentlyContinue
    }
}

if ($mysqlConn.TcpTestSucceeded) {
    Write-Host "  [ONLINE] MySQL activo en puerto 3306.`n" -ForegroundColor Green
} else {
    Write-Host "  [WARN] MySQL no responde en puerto 3306. Por favor inicia Apache/MySQL en XAMPP Control Panel.`n" -ForegroundColor Red
}

# 2. Detectar ejecutable de Maven
$MvnCmd = "mvn"
if (!(Get-Command "mvn" -ErrorAction SilentlyContinue)) {
    $fallbackMvn = "$env:USERPROFILE\maven\apache-maven-3.9.6\bin\mvn.cmd"
    if (Test-Path $fallbackMvn) {
        $MvnCmd = $fallbackMvn
    }
}

$Services = @(
    @{ Name = "edusaldo-ms-auth-usuarios"; Port = 8081 },
    @{ Name = "edusaldo-ms-alumnos-saldos"; Port = 8082 },
    @{ Name = "edusaldo-ms-productos-inventario"; Port = 8083 },
    @{ Name = "edusaldo-ms-ventas-reservas"; Port = 8084 },
    @{ Name = "edusaldo-ms-compras"; Port = 8085 },
    @{ Name = "edusaldo-ms-finanzas-configuracion"; Port = 8086 },
    @{ Name = "edusaldo-api-gateway"; Port = 8099 }
)

$LogsDir = "$RootDir\edusaldo-api-gateway\logs"
if (!(Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

Write-Host "=== LANZANDO LOS 7 PROCESOS JAVA EN SEGUNDO PLANO ===" -ForegroundColor Yellow

foreach ($s in $Services) {
    $svcName = $s.Name
    $svcPort = $s.Port
    $svcPath = "$RootDir\$svcName"
    $targetDir = "$svcPath\target"

    if (!(Test-Path $svcPath)) {
        Write-Host "  [WARN] No se encontro la carpeta $svcName en $RootDir. Omitiendo..." -ForegroundColor Yellow
        continue
    }

    $jar = Get-ChildItem -Path $targetDir -Filter "*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1

    # Si el JAR no existe (clon reciente), compilar con Maven automaticamente
    if (!$jar) {
        Write-Host "  [BUILD] Compilando $svcName con Maven (primera ejecucion)..." -ForegroundColor Yellow
        Push-Location $svcPath
        & $MvnCmd package -DskipTests -B | Out-Null
        Pop-Location
        $jar = Get-ChildItem -Path $targetDir -Filter "*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1
    }

    if (!$jar) {
        Write-Host "  [ERROR] No se pudo obtener el archivo JAR en $svcName." -ForegroundColor Red
        continue
    }

    $jarPath = $jar.FullName
    $logPath = "$LogsDir\$svcName.out.log"
    $errPath = "$LogsDir\$svcName.err.log"

    $process = Start-Process -FilePath "java" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $svcPath -RedirectStandardOutput $logPath -RedirectStandardError $errPath -WindowStyle Hidden -PassThru
    Write-Host "  [START] $svcName (PID: $($process.Id)) -> Puerto $svcPort" -ForegroundColor Green
}

Write-Host "`n=== VERIFICANDO CONECTIVIDAD DE PUERTOS (TIMEOUT 60S) ===" -ForegroundColor Yellow
$Timeout = 60
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($s in $Services) {
    $port = $s.Port
    $name = $s.Name
    $online = $false

    while (!$online -and ($Stopwatch.Elapsed.TotalSeconds -lt $Timeout)) {
        $conn = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
        if ($conn.TcpTestSucceeded) {
            $online = $true
            Write-Host "  [ONLINE] $name escuchando en puerto $port ($([Math]::Round($Stopwatch.Elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
        } else {
            Start-Sleep -Milliseconds 1500
        }
    }

    if (!$online) {
        Write-Host "  [TIMEOUT] $name no respondio en puerto $port tras $($Timeout)s" -ForegroundColor Red
    }
}

Write-Host "`n[OK] VERIFICACION COMPLETADA. SERVICIOS ACTIVOS." -ForegroundColor Cyan
