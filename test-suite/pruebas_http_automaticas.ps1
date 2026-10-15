# =============================================================================
# Proposito: Suite completa de pruebas de integracion en vivo (PowerShell)
#            que ejecuta las 20 pruebas de uso real EXCLUSIVAMENTE a traves
#            del API Gateway (puerto 8099) sobre los 4 microservicios de EduSaldo 2.0.
# Prerrequisitos: Los 5 servicios deben estar activos en puertos 8081-8084 y 8099.
# Ejecucion:
#   powershell -ExecutionPolicy Bypass -File .\edusaldo-api-gateway\test-suite\pruebas_http_automaticas.ps1
# =============================================================================

$Gateway = "http://localhost:8099"
$Passed = 0
$Failed = 0

function Format-Json($obj) {
    if ($null -eq $obj) { return "            (vacio)" }
    try {
        $json = $obj | ConvertTo-Json -Depth 6
        $lines = $json -split "`r?`n"
        if ($lines.Count -gt 20) {
            $lines = $lines[0..15] + @("            ... ($($lines.Count - 16) lineas adicionales) ...", $lines[-1])
        }
        return ($lines | ForEach-Object { "            $_" }) -join "`r`n"
    } catch {
        return "            $obj"
    }
}

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Endpoint,
        $Body = $null
    )
    $url = "$Gateway$Endpoint"
    $statusCode = 0
    $resObj = $null

    try {
        $headers = @{ "Content-Type" = "application/json" }
        if ($null -ne $Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 5 -Compress
            $response = Invoke-RestMethod -Uri $url -Method $Method -Body $jsonBody -Headers $headers -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers -ErrorAction Stop
        }
        $statusCode = 200
        $resObj = $response
    } catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $raw = $reader.ReadToEnd()
                $resObj = $raw | ConvertFrom-Json
            } catch {
                $resObj = @{ error = $_.Exception.Message }
            }
        } else {
            $statusCode = 0
            $resObj = @{ error = $_.Exception.Message }
        }
    }

    return @{ StatusCode = $statusCode; Body = $resObj; Url = $url; Method = $Method; Sent = $Body }
}

function Check-Result {
    param(
        [string]$Num,
        [string]$Title,
        [bool]$Success,
        $Detail,
        [string]$ExtraInfo = ""
    )
    if ($Success) {
        $script:Passed++
        Write-Host "  [PASS] $Num. $Title $ExtraInfo" -ForegroundColor Green
    } else {
        $script:Failed++
        Write-Host "  [FAIL] $Num. $Title $ExtraInfo" -ForegroundColor Red
        if ($Detail) {
            Write-Host "       -> [$($Detail.Method)] $($Detail.Url)" -ForegroundColor DarkGray
            if ($Detail.Sent) {
                Write-Host "          Payload Enviado:" -ForegroundColor DarkGray
                Write-Host (Format-Json $Detail.Sent) -ForegroundColor DarkGray
            }
            Write-Host "       <- HTTP $($Detail.StatusCode)" -ForegroundColor DarkGray
            Write-Host "          Respuesta:" -ForegroundColor DarkGray
            Write-Host (Format-Json $Detail.Body) -ForegroundColor DarkGray
        }
    }
}

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "  EDUSALDO 2.0 - BATERIA DE PRUEBAS EN VIVO VIA API GATEWAY (8099)" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 1. MS USUARIOS Y AUTH (Puerto 8081)
# -----------------------------------------------------------------------------
Write-Host "`n--- 1. MS USUARIOS Y AUTH (Puerto 8081) ---" -ForegroundColor Yellow

# Caso 01: Login exitoso
$r1 = Invoke-Api -Method POST -Endpoint "/api/auth/login" -Body @{ identificador = "admin@colegio.cl"; password = "admin123" }
$ok1 = ($r1.StatusCode -eq 200 -and $null -ne $r1.Body.token)
Check-Result -Num "01" -Title "Login Administrador exitoso" -Success $ok1 -Detail $r1 -ExtraInfo "(Usuario: $($r1.Body.nombreCompleto))"

# Caso 02: Login fallido controlado
$r2 = Invoke-Api -Method POST -Endpoint "/api/auth/login" -Body @{ identificador = "admin@colegio.cl"; password = "clave_invalida_xyz" }
$ok2 = ($r2.StatusCode -in @(400, 401))
Check-Result -Num "02" -Title "Login fallido controlado con rechazo" -Success $ok2 -Detail $r2

# Caso 03: Alta atomica Alumno + Apoderado (HU15)
$ts = [int](Get-Date -UFormat %s)
$r3 = Invoke-Api -Method POST -Endpoint "/api/usuarios/alumnos" -Body @{
    rutAlumno = "25.$($ts % 900 + 100).111-K"
    primerNombreAlumno = "Tomas"
    primerApellidoAlumno = "Gonzalez"
    fechaNacimiento = "2012-05-15"
    curso = "7 Basico"
    rutApoderado = "16.$($ts % 900 + 100).222-3"
    primerNombreApoderado = "Carlos"
    primerApellidoApoderado = "Gonzalez"
    correoApoderado = "apoderado_$ts@gmail.com"
    telefonoApoderado = "+56912345678"
    parentesco = "PADRE"
}
$ok3 = ($r3.StatusCode -in @(200, 201) -and $null -ne $r3.Body.alumnoId)
$alumnoId = if ($ok3) { $r3.Body.alumnoId } else { 1 }
$apoderadoId = if ($ok3) { $r3.Body.apoderadoId } else { 1 }
Check-Result -Num "03" -Title "Alta atomica Alumno + Apoderado (HU15)" -Success $ok3 -Detail $r3 -ExtraInfo "(Alumno: $alumnoId, Apoderado: $apoderadoId)"

# Caso 04: Consulta de alumnos de un apoderado (HU17)
$r4 = Invoke-Api -Method GET -Endpoint "/api/usuarios/apoderados/$apoderadoId/alumnos"
$ok4 = ($r4.StatusCode -eq 200 -and $r4.Body.Count -ge 1)
Check-Result -Num "04" -Title "Consulta de pupilos asociados a apoderado (HU17)" -Success $ok4 -Detail $r4

# Caso 05: Consulta de configuracion institucional y auditoria
$r5_cfg = Invoke-Api -Method GET -Endpoint "/api/configuracion"
$r5_aud = Invoke-Api -Method GET -Endpoint "/api/auditoria"
$ok5 = ($r5_cfg.StatusCode -eq 200 -and $r5_aud.StatusCode -eq 200)
Check-Result -Num "05" -Title "Consulta de configuracion institucional y auditoria" -Success $ok5 -Detail $r5_cfg

# Caso 06: Consulta de usuario Alumno por ID
$r6 = Invoke-Api -Method GET -Endpoint "/api/usuarios/$alumnoId"
$ok6 = ($r6.StatusCode -eq 200 -and $r6.Body.id -eq $alumnoId)
Check-Result -Num "06" -Title "Consulta de usuario Alumno por ID (HU04 Autonomia >= 12 anos)" -Success $ok6 -Detail $r6

# Caso 07: Verificacion de auditoria
$r7 = Invoke-Api -Method GET -Endpoint "/api/auditoria"
$ok7 = ($r7.StatusCode -eq 200 -and $r7.Body.Count -ge 1)
Check-Result -Num "07" -Title "Verificacion de registro de auditoria de seguridad" -Success $ok7 -Detail $r7

# -----------------------------------------------------------------------------
# 2. MS SALDOS Y ABONOS (Puerto 8082)
# -----------------------------------------------------------------------------
Write-Host "`n--- 2. MS SALDOS Y ABONOS (Puerto 8082) ---" -ForegroundColor Yellow

# Caso 08: Consulta saldo
$r8 = Invoke-Api -Method GET -Endpoint "/api/saldos/cuenta/$alumnoId"
$ok8 = ($r8.StatusCode -eq 200 -and $null -ne $r8.Body.saldoDisponible)
Check-Result -Num "08" -Title "Consulta de saldo inicial de pupilo" -Success $ok8 -Detail $r8

# Caso 09: Iniciar abono
$r9 = Invoke-Api -Method POST -Endpoint "/api/saldos/abonos/iniciar" -Body @{
    alumnoId = $alumnoId
    apoderadoId = $apoderadoId
    monto = 15000
}
$ok9 = ($r9.StatusCode -in @(200, 201) -and $null -ne $r9.Body.tokenTransaccion)
$tokenAbono = if ($ok9) { $r9.Body.tokenTransaccion } else { "" }
Check-Result -Num "09" -Title "Inicio de abono Webpay simulado (Token UUID generado)" -Success $ok9 -Detail $r9

# Caso 10: Confirmar abono
$r10 = Invoke-Api -Method POST -Endpoint "/api/saldos/abonos/confirmar" -Body @{ token = $tokenAbono }
$ok10 = ($r10.StatusCode -eq 200 -and $r10.Body.saldoActual -ge 15000)
Check-Result -Num "10" -Title "Confirmacion de abono y acreditacion en CuentaSaldo" -Success $ok10 -Detail $r10

# Caso 11: Rechazo controlado saldo insuficiente
$r11 = Invoke-Api -Method POST -Endpoint "/api/saldos/retener" -Body @{
    alumnoId = $alumnoId
    monto = 99999999
    reservaId = 999
}
$ok11 = ($r11.StatusCode -in @(400, 422))
Check-Result -Num "11" -Title "Rechazo controlado por saldo insuficiente (400/422)" -Success $ok11 -Detail $r11

# Caso 12: Libro mayor movimientos
$r12 = Invoke-Api -Method GET -Endpoint "/api/saldos/cuenta/$alumnoId/movimientos"
$ok12 = ($r12.StatusCode -eq 200 -and $r12.Body.Count -ge 1)
Check-Result -Num "12" -Title "Consulta de libro mayor MovimientoSaldo" -Success $ok12 -Detail $r12

# -----------------------------------------------------------------------------
# 3. MS PRODUCTOS E INVENTARIO (Puerto 8083)
# -----------------------------------------------------------------------------
Write-Host "`n--- 3. MS PRODUCTOS E INVENTARIO (Puerto 8083) ---" -ForegroundColor Yellow

# Caso 13: Consulta catalogo
$r13 = Invoke-Api -Method GET -Endpoint "/api/productos"
$ok13 = ($r13.StatusCode -eq 200 -and $r13.Body.Count -ge 1)
$prodId = if ($ok13) { $r13.Body[0].id } else { 1 }
Check-Result -Num "13" -Title "Consulta de catalogo y existencias" -Success $ok13 -Detail $r13

# Caso 14: Ingreso manual stock (HU46)
$r14 = Invoke-Api -Method POST -Endpoint "/api/inventario/ingresos-manuales" -Body @{
    encargadoId = 2
    proveedor = "Distribuidora Central Escolar"
    documentoReferencia = "GUIA-DESPACHO-4581"
    observacion = "Recepcion de materiales"
    detalles = @(@{ productoId = $prodId; cantidad = 20 })
}
$ok14 = ($r14.StatusCode -in @(200, 201))
Check-Result -Num "14" -Title "Ingreso manual de stock por Encargado (HU46)" -Success $ok14 -Detail $r14

# Caso 15: Solicitud de ajuste en PENDIENTE
$r15 = Invoke-Api -Method POST -Endpoint "/api/inventario/ajustes/solicitar" -Body @{
    productoId = $prodId
    cantidad = -2
    motivo = "Merma por deterioro en estante"
    encargadoId = 2
}
$ok15 = ($r15.StatusCode -in @(200, 201) -and $r15.Body.estado -eq "PENDIENTE")
$solId = if ($ok15) { $r15.Body.id } else { 1 }
Check-Result -Num "15" -Title "Solicitud de ajuste de stock en PENDIENTE" -Success $ok15 -Detail $r15

# Caso 16: Aprobacion de ajuste por Admin
$r16 = Invoke-Api -Method POST -Endpoint "/api/inventario/ajustes/$solId/aprobar" -Body @{ administradorId = 1 }
$ok16 = ($r16.StatusCode -eq 200 -and $r16.Body.estado -eq "APROBADA")
Check-Result -Num "16" -Title "Aprobacion de ajuste por Administrador e impacto en stock" -Success $ok16 -Detail $r16

# Caso 17: Libro mayor inventario
$r17 = Invoke-Api -Method GET -Endpoint "/api/inventario/movimientos"
$ok17 = ($r17.StatusCode -eq 200 -and $r17.Body.Count -ge 1)
Check-Result -Num "17" -Title "Consulta de libro mayor MovimientoInventario" -Success $ok17 -Detail $r17

# -----------------------------------------------------------------------------
# 4. MS RESERVAS Y ENTREGAS (Puerto 8084)
# -----------------------------------------------------------------------------
Write-Host "`n--- 4. MS RESERVAS Y ENTREGAS (Puerto 8084) ---" -ForegroundColor Yellow

# Caso 18: Crear reserva
$r18 = Invoke-Api -Method POST -Endpoint "/api/reservas" -Body @{
    alumnoId = $alumnoId
    creadaPorId = $apoderadoId
    items = @(@{ productoId = $prodId; nombreProducto = "Cuaderno universitario"; cantidad = 2; precioUnitario = 1500 })
}
$ok18 = ($r18.StatusCode -in @(200, 201) -and $r18.Body.estado -eq "PENDIENTE")
$reservaId = if ($ok18) { $r18.Body.id } else { 1 }
Check-Result -Num "18" -Title "Creacion de reserva con retencion de saldo y stock" -Success $ok18 -Detail $r18

# Caso 19: Preparacion de reserva (HU31 CA2)
$r19 = Invoke-Api -Method POST -Endpoint "/api/reservas/$reservaId/marcar-lista" -Body @{ encargadoId = 2 }
$ok19 = ($r19.StatusCode -eq 200 -and $r19.Body.preparadaPorId -eq 2 -and $null -ne $r19.Body.fechaPreparacion)
Check-Result -Num "19" -Title "Preparacion de reserva (HU31 CA2: preparadaPorId y fecha)" -Success $ok19 -Detail $r19

# Caso 20: Confirmacion de retiro genera Entrega
$r20 = Invoke-Api -Method POST -Endpoint "/api/reservas/$reservaId/entregar" -Body @{ encargadoId = 2 }
$ok20 = ($r20.StatusCode -in @(200, 201) -and $r20.Body.origen -eq "RESERVA")
Check-Result -Num "20" -Title "Confirmacion de retiro genera Entrega formal" -Success $ok20 -Detail $r20

# Caso 21: Entrega meson
$r21 = Invoke-Api -Method POST -Endpoint "/api/entregas/meson" -Body @{
    alumnoId = $alumnoId
    encargadoId = 2
    items = @(@{ productoId = $prodId; nombreProducto = "Lapiz grafito"; cantidad = 1; precioUnitario = 500 })
}
$ok21 = ($r21.StatusCode -in @(200, 201) -and $r21.Body.origen -eq "MESON")
Check-Result -Num "21" -Title "Entrega directa presencial en meson (MESON)" -Success $ok21 -Detail $r21

# Caso 22: Cancelacion de reserva
$r22_tmp = Invoke-Api -Method POST -Endpoint "/api/reservas" -Body @{
    alumnoId = $alumnoId
    creadaPorId = $alumnoId
    items = @(@{ productoId = $prodId; nombreProducto = "Regla 30cm"; cantidad = 1; precioUnitario = 800 })
}
$res2Id = if ($r22_tmp.Body.id) { $r22_tmp.Body.id } else { 2 }
$r22 = Invoke-Api -Method POST -Endpoint "/api/reservas/$res2Id/cancelar" -Body @{
    motivo = "Cancelado por alumno antes de retiro"
    usuarioId = $alumnoId
    rol = "ALU"
}
$ok22 = ($r22.StatusCode -eq 200 -and $r22.Body.estado -eq "CANCELADA")
Check-Result -Num "22" -Title "Cancelacion de reserva por Alumno >= 12 anos" -Success $ok22 -Detail $r22

# Caso 23: Historial entregas
$r23 = Invoke-Api -Method GET -Endpoint "/api/entregas/historial"
$ok23 = ($r23.StatusCode -eq 200 -and $r23.Body.Count -ge 1)
Check-Result -Num "23" -Title "Consulta de historial de entregas operativas" -Success $ok23 -Detail $r23

Write-Host "`n=============================================================================" -ForegroundColor Cyan
if ($Failed -eq 0) {
    Write-Host "  RESULTADO FINAL: $Passed CASOS PASARON | 0 CASOS FALLARON" -ForegroundColor Green
    Write-Host "  [OK] LOS 4 MICROSERVICIOS Y EL GATEWAY OPERAN AL 100% SIN ERRORES." -ForegroundColor Green
} else {
    Write-Host "  RESULTADO FINAL: $Passed CASOS PASARON | $Failed CASOS FALLARON" -ForegroundColor Red
    Write-Host "  ALERTA: Se detectaron fallos en la bateria de pruebas." -ForegroundColor Red
}
Write-Host "=============================================================================" -ForegroundColor Cyan

Write-Host "`nPresiona Enter para cerrar esta ventana..." -ForegroundColor Yellow
$null = [Console]::ReadLine()
