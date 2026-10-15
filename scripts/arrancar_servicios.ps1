# =============================================================================
# Proposito: Levanta concurrentemente los 4 microservicios Spring Boot y el
#            API Gateway, verifica puertos y mantiene la consola abierta para
#            monitorear el estado y logs de los servicios en vivo.
# Puertos: 8099 (Gateway), 8081 (Auth/Usuarios), 8082 (Saldos/Abonos),
#          8083 (Productos/Inventario), 8084 (Reservas/Entregas).
# Ejecucion:
#   powershell -ExecutionPolicy Bypass -File .\edusaldo-api-gateway\scripts\arrancar_servicios.ps1
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolucion dinamica de la carpeta raiz
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
Write-Host "  EDUSALDO 2.0 - INICIANDO 4 MICROSERVICIOS Y GATEWAY" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Directorio raiz: $RootDir`n" -ForegroundColor DarkGray

# 1. Verificar MySQL
Write-Host "=== VERIFICANDO MYSQL (PUERTO 3306) ===" -ForegroundColor Yellow
$mysqlConn = Test-NetConnection -ComputerName localhost -Port 3306 -WarningAction SilentlyContinue

if (!$mysqlConn.TcpTestSucceeded) {
    Write-Host "  [MYSQL] MySQL no responde en 3306. Intentando iniciar XAMPP MySQL..." -ForegroundColor Yellow
    if (Test-Path "C:\xampp\mysql\bin\mysqld.exe") {
        Start-Process -FilePath "C:\xampp\mysql\bin\mysqld.exe" -ArgumentList "--defaults-file=`"C:\xampp\mysql\bin\my.ini`" --standalone" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        $mysqlConn = Test-NetConnection -ComputerName localhost -Port 3306 -WarningAction SilentlyContinue
    }
}

if ($mysqlConn.TcpTestSucceeded) {
    Write-Host "  [ONLINE] MySQL activo en puerto 3306.`n" -ForegroundColor Green
} else {
    Write-Host "  [WARN] MySQL no responde en 3306.`n" -ForegroundColor Yellow
}

# 2. Servicios a levantar
$Services = @(
    @{ Name = "edusaldo-ms-auth-usuarios"; Port = 8081; Color = "Cyan" },
    @{ Name = "edusaldo-ms-alumnos-saldos"; Port = 8082; Color = "Green" },
    @{ Name = "edusaldo-ms-productos-inventario"; Port = 8083; Color = "Yellow" },
    @{ Name = "edusaldo-ms-ventas-reservas"; Port = 8084; Color = "Magenta" },
    @{ Name = "edusaldo-api-gateway"; Port = 8099; Color = "White" }
)

$LogsDir = "$RootDir\edusaldo-api-gateway\logs"
if (!(Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

Write-Host "=== LANZANDO PROCESOS JAVA ===" -ForegroundColor Yellow
$RunningProcesses = @()

foreach ($s in $Services) {
    $svcName = $s.Name
    $svcPort = $s.Port
    $svcPath = "$RootDir\$svcName"
    $targetDir = "$svcPath\target"

    if (!(Test-Path $svcPath)) {
        Write-Host "  [WARN] No se encontro la carpeta $svcName. Omitiendo..." -ForegroundColor Yellow
        continue
    }

    $jar = Get-ChildItem -Path $targetDir -Filter "*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1

    if (!$jar) {
        Write-Host "  [BUILD] Compilando $svcName..." -ForegroundColor Yellow
        Push-Location $svcPath
        & mvn package -DskipTests -B | Out-Null
        Pop-Location
        $jar = Get-ChildItem -Path $targetDir -Filter "*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1
    }

    if (!$jar) {
        Write-Host "  [ERROR] No se encontro JAR en $svcName." -ForegroundColor Red
        continue
    }

    $jarPath = $jar.FullName
    $logPath = "$LogsDir\$svcName.log"
    $errPath = "$LogsDir\$svcName.err.log"

    $p = Start-Process -FilePath "java" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $svcPath -RedirectStandardOutput $logPath -RedirectStandardError $errPath -WindowStyle Hidden -PassThru
    $RunningProcesses += @{ Name = $svcName; Port = $svcPort; Process = $p; Log = $logPath; Color = $s.Color }
    Write-Host "  [START] $svcName (PID: $($p.Id)) -> Puerto $svcPort" -ForegroundColor Green
}

Write-Host "`n=== ESPERANDO DISPONIBILIDAD DE PUERTOS ===" -ForegroundColor Yellow
$Timeout = 60
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($rp in $RunningProcesses) {
    $port = $rp.Port
    $name = $rp.Name
    $online = $false

    while (!$online -and ($Stopwatch.Elapsed.TotalSeconds -lt $Timeout)) {
        $conn = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
        if ($conn.TcpTestSucceeded) {
            $online = $true
            Write-Host "  [ONLINE] $name respondiendo en puerto $port ($([Math]::Round($Stopwatch.Elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
        } else {
            Start-Sleep -Milliseconds 1200
        }
    }

    if (!$online) {
        Write-Host "  [TIMEOUT] $name no respondio en puerto $port tras $($Timeout)s" -ForegroundColor Red
    }
}

Write-Host "`n=============================================================================" -ForegroundColor Cyan
Write-Host "  SISTEMA EDUSALDO 2.0 ACTIVO Y LISTO" -ForegroundColor Cyan
Write-Host "  * API Gateway:              http://localhost:8099" -ForegroundColor White
Write-Host "  * MS Auth y Usuarios:       http://localhost:8081/swagger-ui.html" -ForegroundColor White
Write-Host "  * MS Saldos y Abonos:       http://localhost:8082/swagger-ui.html" -ForegroundColor White
Write-Host "  * MS Productos Inventario:  http://localhost:8083/swagger-ui.html" -ForegroundColor White
Write-Host "  * MS Reservas Entregas:     http://localhost:8084/swagger-ui.html" -ForegroundColor White
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Ventana de monitoreo activa. Presiona Ctrl+C para detener todos los servicios.`n" -ForegroundColor Yellow

# Monitoreo continuo de procesos
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Host "`n[DETENIENDO] Cerrando procesos de EduSaldo..." -ForegroundColor Yellow
    foreach ($rp in $RunningProcesses) {
        if ($rp.Process -and !$rp.Process.HasExited) {
            Stop-Process -Id $rp.Process.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "[OK] Todos los servicios fueron detenidos." -ForegroundColor Green
}
