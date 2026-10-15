# =============================================================================
# Propósito: Levanta concurrentemente los 4 microservicios Spring Boot y el
#            API Gateway en segundo plano con detección dinámica de carpetas hermanas.
#            Verifica e inicia MySQL automáticamente si XAMPP está instalado.
#            Si los archivos JAR no están compilados, los compila con Maven.
# Puertos: 8099 (Gateway), 8081 (Auth/Usuarios), 8082 (Saldos/Abonos),
#          8083 (Productos/Inventario), 8084 (Reservas/Entregas).
# Ejecución en PowerShell:
#   .\edusaldo-api-gateway\scripts\arrancar_servicios.ps1
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolución dinámica de la carpeta raíz contenedora
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
Write-Host "  EDUSALDO 2.0 - INICIANDO 4 MICROSERVICIOS Y GATEWAY EN SEGUNDO PLANO" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Directorio raíz detectado: $RootDir`n" -ForegroundColor DarkGray

# 1. Verificar MySQL en puerto 3306
Write-Host "=== VERIFICANDO BASE DE DATOS MYSQL (PUERTO 3306) ===" -ForegroundColor Yellow
$mysqlConn = Test-NetConnection -ComputerName localhost -Port 3306 -WarningAction SilentlyContinue

if (!$mysqlConn.TcpTestSucceeded) {
    Write-Host "  [MYSQL] MySQL no está escuchando. Intentando iniciar XAMPP MySQL..." -ForegroundColor Yellow
    if (Test-Path "C:\xampp\mysql\bin\mysqld.exe") {
        Start-Process -FilePath "C:\xampp\mysql\bin\mysqld.exe" -ArgumentList "--defaults-file=`"C:\xampp\mysql\bin\my.ini`" --standalone" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        $mysqlConn = Test-NetConnection -ComputerName localhost -Port 3306 -WarningAction SilentlyContinue
    }
}

if ($mysqlConn.TcpTestSucceeded) {
    Write-Host "  [ONLINE] MySQL activo en puerto 3306.`n" -ForegroundColor Green
} else {
    Write-Host "  [WARN] MySQL no responde en puerto 3306. Si usas perfiles H2/in-memory para tests, puedes continuar.`n" -ForegroundColor Yellow
}

# 2. Detectar ejecutable de Maven
$MvnCmd = "mvn"
if (!(Get-Command "mvn" -ErrorAction SilentlyContinue)) {
    $fallbackCandidates = @(
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2025.2.6.2\plugins\maven\lib\maven3\bin\mvn.cmd",
        "$env:USERPROFILE\maven\apache-maven-3.9.6\bin\mvn.cmd"
    )
    foreach ($fb in $fallbackCandidates) {
        if (Test-Path $fb) {
            $MvnCmd = $fb
            break
        }
    }
}

$Services = @(
    @{ Name = "edusaldo-ms-auth-usuarios"; Port = 8081 },
    @{ Name = "edusaldo-ms-alumnos-saldos"; Port = 8082 },
    @{ Name = "edusaldo-ms-productos-inventario"; Port = 8083 },
    @{ Name = "edusaldo-ms-ventas-reservas"; Port = 8084 },
    @{ Name = "edusaldo-api-gateway"; Port = 8099 }
)

$LogsDir = "$RootDir\edusaldo-api-gateway\logs"
if (!(Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

Write-Host "=== LANZANDO LOS 5 PROCESOS JAVA EN SEGUNDO PLANO ===" -ForegroundColor Yellow

foreach ($s in $Services) {
    $svcName = $s.Name
    $svcPort = $s.Port
    $svcPath = "$RootDir\$svcName"
    $targetDir = "$svcPath\target"

    if (!(Test-Path $svcPath)) {
        Write-Host "  [WARN] No se encontró la carpeta $svcName en $RootDir. Omitiendo..." -ForegroundColor Yellow
        continue
    }

    $jar = Get-ChildItem -Path $targetDir -Filter "*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1

    # Si el JAR no existe, compilar con Maven automáticamente
    if (!$jar) {
        Write-Host "  [BUILD] Compilando $svcName con Maven (primera ejecución)..." -ForegroundColor Yellow
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
        Write-Host "  [TIMEOUT] $name no respondió en puerto $port tras $($Timeout)s" -ForegroundColor Red
    }
}

Write-Host "`n[OK] VERIFICACIÓN COMPLETADA. 4 MICROSERVICIOS Y GATEWAY ACTIVOS." -ForegroundColor Cyan
