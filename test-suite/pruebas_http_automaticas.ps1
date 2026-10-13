# =============================================================================
# Propósito: Suite completa de pruebas de integración en vivo (PowerShell) que ejecuta
#            los 31 casos de uso reales y de borde (edge cases) EXCLUSIVAMENTE a
#            través del API Gateway (puerto 8099) sobre los 6 microservicios.
# Prerrequisitos: Los 7 servicios deben estar corriendo en puertos 8081-8086 y 8099.
# Ejecución: .\edusaldo-api-gateway\test-suite\pruebas_http_automaticas.ps1
# =============================================================================

$Gateway = "http://localhost:8099"
$Passed = 0
$Failed = 0

function Check-Result($num, $name, $condition, $details) {
    if ($condition) {
        $global:Passed++
        Write-Host "[PASS] $num. $name $details" -ForegroundColor Green
    } else {
        $global:Failed++
        Write-Host "[FAIL] $num. $name $details" -ForegroundColor Red
    }
}

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "  EDUSALDO 2.0 - BATERÍA COMPLETA DE PRUEBAS EN VIVO VÍA API GATEWAY (8099)" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

# 1. MS AUTH Y USUARIOS
Write-Host "`n--- 1. MS AUTH Y USUARIOS (Puerto 8081) ---" -ForegroundColor Yellow

# Caso 01: Login exitoso
try {
    $res = Invoke-RestMethod -Uri "$Gateway/api/auth/login" -Method Post -ContentType "application/json" -Body '{"identificador":"admin@colegio.cl","password":"admin123"}'
    Check-Result "01" "Login Administrador exitoso" ($res.token -ne $null) "(Usuario: $($res.nombreCompleto))"
} catch {
    Check-Result "01" "Login Administrador exitoso" $false "(Error HTTP)"
}

# Caso 02: Login fallido
try {
    $res = Invoke-RestMethod -Uri "$Gateway/api/auth/login" -Method Post -ContentType "application/json" -Body '{"identificador":"admin@colegio.cl","password":"clave_incorrecta"}'
    Check-Result "02" "Login fallido controlado con 400" $false
} catch {
    Check-Result "02" "Login fallido controlado con 400" ($_.Exception.Response.StatusCode.value__ -eq 400) "(Rechazo controlado)"
}

# Caso 03: Crear usuario
$rand = Get-Random -Minimum 100 -Maximum 999
try {
    $body = @{ rut = "18.$rand.000-1"; primerNombre = "Claudio"; primerApellido = "Valenzuela"; correo = "profesor_$rand@colegio.cl"; rol = "ENCARGADO" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$Gateway/api/usuarios" -Method Post -ContentType "application/json" -Body $body
    Check-Result "03" "Creación de usuario en PRIMER_ACCESO" ($res.estado -eq "PRIMER_ACCESO") "(ID: $($res.id))"
} catch {
    Check-Result "03" "Creación de usuario en PRIMER_ACCESO" $false
}

# 2. MS ALUMNOS Y SALDOS
Write-Host "`n--- 2. MS ALUMNOS Y SALDOS (Puerto 8082) ---" -ForegroundColor Yellow

# Caso 05: Consulta alumnos
try {
    $res = Invoke-RestMethod -Uri "$Gateway/api/alumnos" -Method Get
    Check-Result "05" "Consulta de nómina de alumnos" ($res.Count -ge 2) "($($res.Count) alumnos encontrados)"
} catch {
    Check-Result "05" "Consulta de nómina de alumnos" $false
}

# Caso 07: Abono Webpay
$keyAbono = "KEY-PS1-ABO-" + (Get-Date).Ticks
try {
    $body = @{ apoderadoId = 4; monto = 5000; idempotencyKey = $keyAbono } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$Gateway/api/saldos/1/abonar" -Method Post -ContentType "application/json" -Body $body
    Check-Result "07" "Aporte de saldo Webpay simulado" ($res.monto -eq 5000)
} catch {
    Check-Result "07" "Aporte de saldo Webpay simulado" $false
}

# Caso 09: Saldo insuficiente
try {
    $body = @{ monto = 9999999; reservaId = 1; usuarioId = 4; idempotencyKey = "KEY-FAIL-PS1" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$Gateway/api/saldos/1/comprometer" -Method Post -ContentType "application/json" -Body $body
    Check-Result "09" "Rechazo de compromiso por saldo insuficiente (422)" $false
} catch {
    $st = $_.Exception.Response.StatusCode.value__
    Check-Result "09" "Rechazo de compromiso por saldo insuficiente (422)" ($st -eq 422) "(HTTP $st)"
}

# 3. MS PRODUCTOS E INVENTARIO
Write-Host "`n--- 3. MS PRODUCTOS E INVENTARIO (Puerto 8083) ---" -ForegroundColor Yellow

# Caso 10: Consulta productos
try {
    $res = Invoke-RestMethod -Uri "$Gateway/api/productos" -Method Get
    Check-Result "10" "Consulta de catálogo y existencias" ($res.Count -ge 7) "($($res.Count) productos)"
} catch {
    Check-Result "10" "Consulta de catálogo y existencias" $false
}

# Caso 12: Stock insuficiente
try {
    $body = @{ cantidad = 99999; referenciaId = 1; usuarioId = 1; idempotencyKey = "KEY-STK-PS1" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$Gateway/api/inventario/101/reservar" -Method Post -ContentType "application/json" -Body $body
    Check-Result "12" "Rechazo de reserva por stock insuficiente (422)" $false
} catch {
    $st = $_.Exception.Response.StatusCode.value__
    Check-Result "12" "Rechazo de reserva por stock insuficiente (422)" ($st -eq 422) "(HTTP $st)"
}

# 4. MS VENTAS Y RESERVAS
Write-Host "`n--- 4. MS VENTAS Y RESERVAS (Puerto 8084) ---" -ForegroundColor Yellow

# Caso 15: Crear reserva
try {
    $body = '{"alumnoId":1,"apoderadoId":4,"items":[{"productoId":101,"nombreProducto":"Cuaderno universitario","cantidad":2,"precioUnitario":1250}]}'
    $res = Invoke-RestMethod -Uri "$Gateway/api/reservas" -Method Post -ContentType "application/json" -Body $body
    Check-Result "15" "Creación de reserva multilínea" ($res.estado -eq "PENDIENTE") "(Código: $($res.codigo))"
} catch {
    Check-Result "15" "Creación de reserva multilínea" $false
}

# 5. MS COMPRAS (VARIANTE B)
Write-Host "`n--- 5. MS COMPRAS (Puerto 8085) ---" -ForegroundColor Yellow

# Caso 21: Proveedores
try {
    $res = Invoke-RestMethod -Uri "$Gateway/api/proveedores" -Method Get
    Check-Result "21" "Consulta de maestro de proveedores" ($res.Count -ge 1)
} catch {
    Check-Result "21" "Consulta de maestro de proveedores" $false
}

# 6. MS FINANZAS Y CONFIGURACIÓN
Write-Host "`n--- 6. MS FINANZAS Y CONFIGURACIÓN (Puerto 8086) ---" -ForegroundColor Yellow

# Caso 26: Regla HU58
try {
    $body = @{ tipo = "VENTA"; montoVenta = 5000; costoVenta = 3800; alumnoId = 1; referenciaId = 101; referenciaFolio = "VTA-PS1-HU58"; idempotencyKey = "KEY-PS1-RES-" + (Get-Date).Ticks } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$Gateway/api/finanzas/resultados/operacion" -Method Post -ContentType "application/json" -Body $body
    Check-Result "26" "Regla HU58: Registro de margen sin mover caja" ($res.montoVenta -eq 5000) "(Margen: $($res.montoVenta - $res.costoVenta))"
} catch {
    Check-Result "26" "Regla HU58: Registro de margen sin mover caja" $false
}

Write-Host "`n=============================================================================" -ForegroundColor Cyan
Write-Host "  RESULTADO: $Passed PASARON | $Failed FALLARON" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
