# =============================================================================
# Propósito: Suite rápida de pruebas de integración en vivo (PowerShell) que ejecuta
#            casos de uso reales y de borde (edge cases) EXCLUSIVAMENTE a
#            través del API Gateway (puerto 8099) sobre los 6 microservicios.
# Prerrequisitos: Los 7 servicios deben estar corriendo en puertos 8081-8086 y 8099.
# Ejecución: .\edusaldo-api-gateway\test-suite\pruebas_http_automaticas.ps1
# =============================================================================

$Gateway = "http://localhost:8099"
$Passed = 0
$Failed = 0

function Format-MultilineJson($data, $indent = "            ") {
    if ($null -eq $data -or $data -eq "") {
        return "$indent(vacio)"
    }
    $text = ""
    try {
        if ($data -is [string]) {
            try {
                $obj = $data | ConvertFrom-Json
                $text = $obj | ConvertTo-Json -Depth 10
            } catch {
                $text = $data
            }
        } else {
            $text = $data | ConvertTo-Json -Depth 10
        }
    } catch {
        $text = "$data"
    }

    $lines = $text -split "`r?`n"
    if ($lines.Count -gt 25) {
        $lines = $lines[0..22] + @("... ($($lines.Count - 24) líneas adicionales) ...", $lines[-1])
    }
    return ($lines | ForEach-Object { "$indent$_" }) -join "`r`n"
}

function Invoke-ApiTest {
    param(
        [string]$Num,
        [string]$Name,
        [string]$Method,
        [string]$Endpoint,
        [string]$Body = $null,
        [scriptblock]$Validator
    )
    $url = "$Gateway$Endpoint"
    $statusCode = 0
    $respRaw = ""
    $respJson = $null

    try {
        $params = @{
            Uri = $url
            Method = $Method
            UseBasicParsing = $true
        }
        if ($Body) {
            $params["ContentType"] = "application/json; charset=utf-8"
            $params["Body"] = $Body
        }
        $res = Invoke-WebRequest @params
        $statusCode = [int]$res.StatusCode
        $respRaw = $res.Content
        try { $respJson = $respRaw | ConvertFrom-Json } catch { $respJson = $null }
    } catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respRaw = $reader.ReadToEnd()
                try { $respJson = $respRaw | ConvertFrom-Json } catch { $respJson = $null }
            } catch {
                $respRaw = $_.Exception.Message
            }
        } else {
            $statusCode = 0
            $respRaw = $_.Exception.Message
        }
    }

    $ok = & $Validator $statusCode $respJson $respRaw
    if ($ok) {
        $global:Passed++
        Write-Host "[PASS] $Num. $Name" -ForegroundColor Green
    } else {
        $global:Failed++
        Write-Host "[FAIL] $Num. $Name" -ForegroundColor Red
    }

    Write-Host "       -> [$Method] $url" -ForegroundColor DarkCyan
    if ($Body) {
        Write-Host "          Payload Enviado:" -ForegroundColor DarkGray
        Write-Host (Format-MultilineJson $Body "            ") -ForegroundColor Gray
    }
    Write-Host "       <- HTTP $statusCode" -ForegroundColor DarkYellow
    Write-Host "          Respuesta del Microservicio:" -ForegroundColor DarkGray
    Write-Host (Format-MultilineJson $respRaw "            ") -ForegroundColor Gray
}

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "  EDUSALDO 2.0 - BATERIA DE PRUEBAS EN VIVO VIA API GATEWAY (8099)" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

# 1. MS AUTH Y USUARIOS
Write-Host "`n--- 1. MS AUTH Y USUARIOS (Puerto 8081) ---" -ForegroundColor Yellow

Invoke-ApiTest "01" "Login Administrador exitoso" "Post" "/api/auth/login" `
    '{"identificador":"admin@colegio.cl","password":"admin123"}' `
    { param($st, $res, $raw) ($st -eq 200) -and ($res.token -ne $null) }

Invoke-ApiTest "02" "Login fallido controlado con 400" "Post" "/api/auth/login" `
    '{"identificador":"admin@colegio.cl","password":"clave_incorrecta"}' `
    { param($st, $res, $raw) $st -eq 400 }

$rand = Get-Random -Minimum 100 -Maximum 999
$time = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$userBody = @{
    rut = "18.$rand.000-1"
    primerNombre = "Claudio"
    primerApellido = "Valenzuela"
    correo = "profesor_${time}_$rand@colegio.cl"
    rol = "ENCARGADO"
} | ConvertTo-Json
Invoke-ApiTest "03" "Creacion de usuario en PRIMER_ACCESO" "Post" "/api/usuarios" `
    $userBody `
    { param($st, $res, $raw) ($st -eq 201) -and ($res.estado -eq "PRIMER_ACCESO") }

# 2. MS ALUMNOS Y SALDOS
Write-Host "`n--- 2. MS ALUMNOS Y SALDOS (Puerto 8082) ---" -ForegroundColor Yellow

Invoke-ApiTest "05" "Consulta de nomina de alumnos" "Get" "/api/alumnos" `
    $null `
    { param($st, $res, $raw) ($st -eq 200) -and ($res.Count -ge 2) }

$keyAbono = "KEY-PS1-ABO-" + (Get-Date).Ticks
$abonoBody = @{ apoderadoId = 4; monto = 5000; idempotencyKey = $keyAbono } | ConvertTo-Json
Invoke-ApiTest "07" "Aporte de saldo Webpay simulado" "Post" "/api/saldos/1/abonar" `
    $abonoBody `
    { param($st, $res, $raw) ($st -in 200, 201) -and ($res.monto -eq 5000) }

$keyFail = "KEY-FAIL-PS1-" + (Get-Date).Ticks
$comprometerBody = @{ monto = 9999999; reservaId = 1; usuarioId = 4; idempotencyKey = $keyFail } | ConvertTo-Json
Invoke-ApiTest "09" "Rechazo de compromiso por saldo insuficiente (422)" "Post" "/api/saldos/1/comprometer" `
    $comprometerBody `
    { param($st, $res, $raw) $st -eq 422 }

# 3. MS PRODUCTOS E INVENTARIO
Write-Host "`n--- 3. MS PRODUCTOS E INVENTARIO (Puerto 8083) ---" -ForegroundColor Yellow

Invoke-ApiTest "10" "Consulta de catalogo y existencias" "Get" "/api/productos" `
    $null `
    { param($st, $res, $raw) ($st -eq 200) -and ($res.Count -ge 7) }

$keyStk = "KEY-STK-PS1-" + (Get-Date).Ticks
$reservarInvBody = @{ cantidad = 99999; referenciaId = 1; usuarioId = 1; idempotencyKey = $keyStk } | ConvertTo-Json
Invoke-ApiTest "12" "Rechazo de reserva por stock insuficiente (422)" "Post" "/api/inventario/101/reservar" `
    $reservarInvBody `
    { param($st, $res, $raw) $st -eq 422 }

# 4. MS VENTAS Y RESERVAS
Write-Host "`n--- 4. MS VENTAS Y RESERVAS (Puerto 8084) ---" -ForegroundColor Yellow

$reservaBody = '{"alumnoId":1,"apoderadoId":4,"items":[{"productoId":101,"nombreProducto":"Cuaderno universitario","cantidad":2,"precioUnitario":1250}]}'
Invoke-ApiTest "15" "Creacion de reserva multilineal" "Post" "/api/reservas" `
    $reservaBody `
    { param($st, $res, $raw) ($st -eq 201) -and ($res.estado -eq "PENDIENTE") }

# 5. MS COMPRAS
Write-Host "`n--- 5. MS COMPRAS (Puerto 8085) ---" -ForegroundColor Yellow

Invoke-ApiTest "21" "Consulta de maestro de proveedores" "Get" "/api/proveedores" `
    $null `
    { param($st, $res, $raw) ($st -eq 200) -and ($res.Count -ge 1) }

# 6. MS FINANZAS Y CONFIGURACION
Write-Host "`n--- 6. MS FINANZAS Y CONFIGURACION (Puerto 8086) ---" -ForegroundColor Yellow

$keyHu58 = "KEY-PS1-RES-" + (Get-Date).Ticks
$hu58Body = @{
    tipo = "VENTA"
    montoVenta = 5000
    costoVenta = 3800
    alumnoId = 1
    referenciaId = 101
    referenciaFolio = "VTA-PS1-HU58"
    idempotencyKey = $keyHu58
} | ConvertTo-Json
Invoke-ApiTest "26" "Regla HU58: Registro de margen sin mover caja" "Post" "/api/finanzas/resultados/operacion" `
    $hu58Body `
    { param($st, $res, $raw) ($st -eq 201) -and ($res.montoVenta -eq 5000) }

Write-Host "`n=============================================================================" -ForegroundColor Cyan
Write-Host "  RESULTADO: $Passed PASARON | $Failed FALLARON" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

if ($Failed -eq 0) {
    Write-Host "[OK] TODOS LOS SERVICIOS Y EL GATEWAY OPERAN AL 100% CON TOLERANCIA CERO A ERRORES." -ForegroundColor Green
} else {
    Write-Host "ALERTA: Se detectaron fallos en la bateria de pruebas." -ForegroundColor Red
}

Write-Host "`n=============================================================================" -ForegroundColor Cyan
if (-not [Console]::IsInputRedirected) {
    Write-Host "Presione [Enter] para salir..." -ForegroundColor Gray
    try { [void][Console]::ReadLine() } catch {}
}
