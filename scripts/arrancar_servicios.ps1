# =============================================================================
# Propósito: Levanta concurrentemente los 6 microservicios Spring Boot y el
#            API Gateway en segundo plano con detección dinámica de carpetas hermanas.
# Puertos: 8099 (Gateway), 8081 (Auth), 8082 (Alumnos), 8083 (Productos),
#          8084 (Ventas), 8085 (Compras), 8086 (Finanzas).
# Ejecución en PowerShell:
#   .\edusaldo-api-gateway\scripts\arrancar_servicios.ps1
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Búsqueda dinámica de la carpeta raíz contenedora
$Candidates = @(
    (Resolve-Path "$ScriptDir\..\..").Path,
    (Resolve-Path "$ScriptDir\..").Path,
    (Resolve-Path ".").Path
)

$RootDir = $Candidates[0]
foreach ($c in $Candidates) {
    if (Test-Path "$c\edusaldo-api-gateway" -or Test-Path "$c\edusaldo-ms-auth-usuarios") {
        $RootDir = $c
        break
    }
}

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "  EDUSALDO 2.0 - INICIANDO SERVICIOS SPRING BOOT EN SEGUNDO PLANO (POWERSHELL)" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Directorio raíz detectado: $RootDir`n" -ForegroundColor DarkGray

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
if (!(Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir | Out-Null }

foreach ($s in $Services) {
    $svcName = $s.Name
    $svcPort = $s.Port
    $targetDir = "$RootDir\$svcName\target"

    $jar = Get-ChildItem -Path $targetDir -Filter "*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1

    if (!$jar) {
        Write-Host "[ERROR] No se encontró el archivo JAR en $targetDir. Ejecuta 'mvn package' primero." -ForegroundColor Red
        continue
    }

    $jarPath = $jar.FullName
    $logPath = "$LogsDir\$svcName.log"

    $process = Start-Process -FilePath "java" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory "$RootDir\$svcName" -RedirectStandardOutput $logPath -RedirectStandardError $logPath -WindowStyle Hidden -PassThru
    Write-Host "  [START] $svcName (PID: $($process.Id)) -> Puerto $svcPort" -ForegroundColor Green
}

Write-Host "`n=== VERIFICANDO CONECTIVIDAD DE PUERTOS ===" -ForegroundColor Yellow
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

Write-Host "`n[OK] VERIFICACIÓN COMPLETADA." -ForegroundColor Cyan
