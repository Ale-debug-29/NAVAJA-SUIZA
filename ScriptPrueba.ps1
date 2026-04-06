# ============================================================
# Script de gestión de interfaz de red para Windows PowerShell
# ============================================================

# Funcion para comprobar si se ejecuta como Administrador
function Test-Administrador {
    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidad)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Funcion para relanzar una seccion concreta como Administrador
function Invoke-ComoAdministrador {
    param([string]$Codigo)
    if (Test-Administrador) {
        Invoke-Expression $Codigo
    } else {
        $scriptTemporal = "$env:TEMP\sec_audit_temp.ps1"
        $Codigo | Out-File -FilePath $scriptTemporal -Encoding UTF8 -Force
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptTemporal`"" `
            -Verb RunAs `
            -Wait
        Remove-Item $scriptTemporal -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# DATOS GLOBALES
# ============================================================
$servers = @("8.8.8.8", "www.marca.com", "9.9.9.9", "www.google.com", "www.pepitoerror.com")

$serviciosCriticos = @{
    "Sistema" = @(
        @{ Nombre = "Spooler";           Desc = "Servicio de Impresion"          }
        @{ Nombre = "wuauserv";          Desc = "Windows Update"                 }
        @{ Nombre = "EventLog";          Desc = "Registro de Eventos de Windows" }
        @{ Nombre = "Schedule";          Desc = "Programador de Tareas"          }
    )
    "Red" = @(
        @{ Nombre = "Dnscache";          Desc = "Cliente DNS"                    }
        @{ Nombre = "LanmanServer";      Desc = "Servidor de Archivos (SMB)"     }
        @{ Nombre = "LanmanWorkstation"; Desc = "Estacion de Trabajo (SMB)"      }
        @{ Nombre = "W32Time";           Desc = "Sincronizacion de Hora"         }
    )
    "Seguridad" = @(
        @{ Nombre = "WinDefend";         Desc = "Windows Defender Antivirus"     }
        @{ Nombre = "MpsSvc";            Desc = "Firewall de Windows"            }
        @{ Nombre = "wlidsvc";           Desc = "Servicio de Cuenta Microsoft"   }
    )
    "Base de Datos" = @(
        @{ Nombre = "MSSQLSERVER";       Desc = "SQL Server (instancia default)" }
        @{ Nombre = "SQLSERVERAGENT";    Desc = "SQL Server Agent"               }
        @{ Nombre = "MySQL80";           Desc = "MySQL 8.0"                      }
    )
}

# ============================================================
$salir = $false

while (-not $salir) {

    # Obtener interfaz de red activa
    $activeAdapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and
        $_.InterfaceDescription -notlike "*Virtual*" -and
        $_.InterfaceDescription -notlike "*Loopback*"
    } | Select-Object -First 1

    if ($null -eq $activeAdapter) {
        Write-Host "No se encontro ninguna interfaz de red activa." -ForegroundColor Red
        pause; exit
    }

    $IFACE   = $activeAdapter.Name
    $ifIndex = $activeAdapter.ifIndex
    $ipConfig = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $ip = if ($ipConfig) { $ipConfig.IPAddress } else { "No asignada" }
    $gateway = Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
               Select-Object -ExpandProperty NextHop
    $gw = if ($gateway) { $gateway } else { "No configurada" }

    # ============================================================
    # MENU PRINCIPAL
    # ============================================================
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "        ~~-   Menu Interactivo de Red   -~~              " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  Interfaz : $IFACE  |  IP: $ip  |  GW: $gw" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  1)  RED              - IP, conectividad, puertos, trazado"    -ForegroundColor White
    Write-Host "  2)  SISTEMA          - Servicios, eventos, limpieza, parches" -ForegroundColor White
    Write-Host "  3)  SEGURIDAD        - Usuarios, forense, auditorias"         -ForegroundColor White
    Write-Host "  4)  BACKUP           - Exportar y restaurar configuraciones"  -ForegroundColor White
    Write-Host "  5)  RENDIMIENTO      - Procesos CPU/RAM, gestion de tareas"   -ForegroundColor White
    Write-Host "  0)  Salir"                                                    -ForegroundColor DarkGray
    Write-Host "==========================================================" -ForegroundColor Green

    $seleccion = Read-Host "Seleccione una categoria"

    switch ($seleccion) {

# ================================================================
# 1. RED
# ================================================================
        "1" {
            $salirRed = $false
            while (-not $salirRed) {
                Clear-Host
                Write-Host "==========================================================" -ForegroundColor Cyan
                Write-Host "                   RED  -  Herramientas                  " -ForegroundColor Cyan
                Write-Host "==========================================================" -ForegroundColor Cyan
                Write-Host "  1)  Ver IP Publica y geolocalizacion"
                Write-Host "  2)  Comprobar conectividad con servidores (Ping)"
                Write-Host "  3)  Escaneo rapido de puertos"
                Write-Host "  4)  Supertrazador de red (Test-NetConnection)"
                Write-Host "  5)  Puertos en escucha con proceso asociado"
                Write-Host "  6)  Recursos compartidos SMB"
                Write-Host "  7)  Estado del Firewall de Windows"
                Write-Host "  8)  Gestion de cache DNS (ver / vaciar)"
                Write-Host "  0)  Volver al menu principal"
                Write-Host "==========================================================" -ForegroundColor Cyan
                $selRed = Read-Host "Seleccione una opcion"

                switch ($selRed) {

                    "1" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "              IP Publica y Geolocalizacion                " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Consultando IP publica..." -ForegroundColor Yellow
                        try {
                            $ipPublica = (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing -TimeoutSec 10).Content.Trim()
                            Write-Host "  Tu IP publica es: " -NoNewline -ForegroundColor Cyan
                            Write-Host $ipPublica -ForegroundColor White
                            $geoInfo = (Invoke-WebRequest -Uri "https://ipinfo.io/$ipPublica/json" -UseBasicParsing -TimeoutSec 10).Content | ConvertFrom-Json
                            Write-Host "  Pais   : $($geoInfo.country)" -ForegroundColor Cyan
                            Write-Host "  Ciudad : $($geoInfo.city)"    -ForegroundColor Cyan
                            Write-Host "  ISP    : $($geoInfo.org)"     -ForegroundColor Cyan
                        } catch {
                            Write-Host "  Error al obtener la IP publica." -ForegroundColor Red
                        }
                        Write-Host ""; pause
                    }

                    "2" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "           Conectividad con Servidores (Ping)             " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        foreach ($servidor in $servers) {
                            Write-Host -NoNewline "  Ping a $servidor ... "
                            if (Test-Connection -ComputerName $servidor -Count 2 -Quiet) {
                                Write-Host "OK" -ForegroundColor Green
                            } else {
                                Write-Host "SIN CONEXION" -ForegroundColor Red
                            }
                        }
                        Write-Host ""; pause
                    }

                    "3" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "               Escaneo Rapido de Puertos                  " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        $objetivo = Read-Host "  Host o IP a escanear (ej: google.com / 192.168.1.1)"
                        $puertos = @(
                            @{ Puerto = 21;   Desc = "FTP"               }
                            @{ Puerto = 22;   Desc = "SSH"               }
                            @{ Puerto = 23;   Desc = "Telnet"            }
                            @{ Puerto = 25;   Desc = "SMTP"              }
                            @{ Puerto = 53;   Desc = "DNS"               }
                            @{ Puerto = 80;   Desc = "HTTP"              }
                            @{ Puerto = 110;  Desc = "POP3"              }
                            @{ Puerto = 135;  Desc = "RPC"               }
                            @{ Puerto = 139;  Desc = "NetBIOS"           }
                            @{ Puerto = 143;  Desc = "IMAP"              }
                            @{ Puerto = 443;  Desc = "HTTPS"             }
                            @{ Puerto = 445;  Desc = "SMB"               }
                            @{ Puerto = 1433; Desc = "SQL Server"        }
                            @{ Puerto = 3306; Desc = "MySQL"             }
                            @{ Puerto = 3389; Desc = "RDP"               }
                            @{ Puerto = 5432; Desc = "PostgreSQL"        }
                            @{ Puerto = 8080; Desc = "HTTP Alternativo"  }
                            @{ Puerto = 8443; Desc = "HTTPS Alternativo" }
                        )
                        Write-Host ""
                        Write-Host "  Escaneando $objetivo ..." -ForegroundColor Yellow
                        Write-Host "  --------------------------------------------------"
                        $abiertos = 0; $cerrados = 0
                        foreach ($p in $puertos) {
                            $desc = ("$($p.Puerto)/TCP - $($p.Desc)").PadRight(30)
                            Write-Host -NoNewline "  $desc : "
                            try {
                                $tcp  = New-Object System.Net.Sockets.TcpClient
                                $conn = $tcp.BeginConnect($objetivo, $p.Puerto, $null, $null)
                                $wait = $conn.AsyncWaitHandle.WaitOne(500, $false)
                                if ($wait -and $tcp.Connected) { Write-Host "ABIERTO" -ForegroundColor Green; $abiertos++ }
                                else { Write-Host "CERRADO" -ForegroundColor Red; $cerrados++ }
                                $tcp.Close()
                            } catch { Write-Host "CERRADO" -ForegroundColor Red; $cerrados++ }
                        }
                        Write-Host "  --------------------------------------------------"
                        Write-Host "  Resumen -> " -NoNewline
                        Write-Host "Abiertos: $abiertos  " -NoNewline -ForegroundColor Green
                        Write-Host "Cerrados: $cerrados"               -ForegroundColor Red
                        Write-Host ""; pause
                    }

                    "4" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "          Supertrazador de Red (Test-NetConnection)       " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        $trazados = @(
                            @{ Host = "8.8.8.8";           Puerto = 53;   Desc = "Google DNS"     }
                            @{ Host = "8.8.4.4";           Puerto = 53;   Desc = "Google DNS2"    }
                            @{ Host = "www.google.com";    Puerto = 443;  Desc = "Google HTTPS"   }
                            @{ Host = "www.google.com";    Puerto = 80;   Desc = "Google HTTP"    }
                            @{ Host = "windowsupdate.com"; Puerto = 443;  Desc = "Windows Update" }
                            @{ Host = "smtp.gmail.com";    Puerto = 587;  Desc = "Gmail SMTP"     }
                            @{ Host = $gw;                 Puerto = 80;   Desc = "Gateway HTTP"   }
                            @{ Host = $gw;                 Puerto = 443;  Desc = "Gateway HTTPS"  }
                            @{ Host = $gw;                 Puerto = 3389; Desc = "Gateway RDP"    }
                        )
                        Write-Host ""
                        Write-Host "  1) Lista predefinida   2) Introducir manualmente"
                        Write-Host ""
                        $modoTraza = Read-Host "  Modo"
                        if ($modoTraza -eq "2") {
                            $hostCustom   = Read-Host "  Host o IP"
                            $puertosInput = Read-Host "  Puertos separados por coma (ej: 80,443,3389)"
                            $trazados = $puertosInput -split "," | ForEach-Object {
                                @{ Host = $hostCustom; Puerto = [int]$_.Trim(); Desc = "Puerto $($_.Trim())" }
                            }
                        }
                        Write-Host ""
                        Write-Host "  Iniciando trazado..." -ForegroundColor Yellow
                        Write-Host "  --------------------------------------------------"
                        $okCount = 0; $failCount = 0
                        foreach ($t in $trazados) {
                            if ([string]::IsNullOrWhiteSpace($t.Host)) { continue }
                            $etiqueta = ("$($t.Desc) [$($t.Host):$($t.Puerto)]").PadRight(45)
                            Write-Host -NoNewline "  $etiqueta : "
                            try {
                                $res = Test-NetConnection -ComputerName $t.Host -Port $t.Puerto -WarningAction SilentlyContinue
                                if ($res.TcpTestSucceeded) {
                                    Write-Host "ALCANZABLE  " -NoNewline -ForegroundColor Green
                                    Write-Host " | Ping: $([math]::Round($res.PingReplyDetails.RoundtripTime))ms | IP: $($res.RemoteAddress)" -ForegroundColor DarkGray
                                    $okCount++
                                } else { Write-Host "NO ALCANZABLE" -ForegroundColor Red; $failCount++ }
                            } catch { Write-Host "ERROR" -ForegroundColor Red; $failCount++ }
                        }
                        Write-Host "  --------------------------------------------------"
                        Write-Host "  Resumen -> " -NoNewline
                        Write-Host "Alcanzables: $okCount  " -NoNewline -ForegroundColor Green
                        Write-Host "No alcanzables: $failCount"          -ForegroundColor Red
                        Write-Host ""; pause
                    }

                    "5" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "           Puertos en Escucha con Proceso Asociado        " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host ("  {0,-22} {1,-8} {2,-8} {3}" -f "Direccion Local", "Puerto", "PID", "Proceso") -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            Get-NetTCPConnection -State Listen -ErrorAction Stop | Sort-Object LocalPort | ForEach-Object {
                                $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
                                $nombre = if ($proc) { $proc.ProcessName } else { "Sistema" }
                                Write-Host ("  {0,-22} {1,-8} {2,-8} {3}" -f $_.LocalAddress, $_.LocalPort, $_.OwningProcess, $nombre)
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""; pause
                    }

                    "6" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "               Recursos Compartidos SMB                   " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        try {
                            Write-Host ("  {0,-20} {1,-35} {2}" -f "Nombre", "Ruta", "Descripcion") -ForegroundColor Cyan
                            Write-Host "  --------------------------------------------------"
                            Get-SmbShare -ErrorAction Stop | ForEach-Object {
                                $color = if ($_.Name -match "^\$") { "DarkGray" } else { "Yellow" }
                                Write-Host ("  {0,-20} {1,-35} {2}" -f $_.Name, $_.Path, $_.Description) -ForegroundColor $color
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""; pause
                    }

                    "7" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "                Estado del Firewall de Windows            " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        try {
                            Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object {
                                $estado = if ($_.Enabled) { "ACTIVO  " } else { "INACTIVO" }
                                $color  = if ($_.Enabled) { "Green"   } else { "Red"     }
                                Write-Host "  Perfil $($_.Name.PadRight(10)) : " -NoNewline
                                Write-Host $estado -ForegroundColor $color
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""; pause
                    }

                    "8" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host "              Gestion de Cache DNS                        " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  1) Ver entradas actuales de la cache DNS"
                        Write-Host "  2) Vaciar la cache DNS"
                        Write-Host "  3) Ver y vaciar la cache DNS"
                        Write-Host ""
                        $selDns = Read-Host "  Seleccione"

                        if ($selDns -in @("1","3")) {
                            Write-Host ""
                            Write-Host "  [ Entradas en cache DNS ]" -ForegroundColor Cyan
                            Write-Host "  --------------------------------------------------"
                            try {
                                $cache = Get-DnsClientCache -ErrorAction Stop | Sort-Object Name
                                if ($cache.Count -eq 0) {
                                    Write-Host "  La cache DNS esta vacia." -ForegroundColor DarkGray
                                } else {
                                    Write-Host ("  {0,-40} {1,-8} {2}" -f "Nombre","Tipo","Datos") -ForegroundColor Cyan
                                    Write-Host "  --------------------------------------------------"
                                    foreach ($entrada in $cache) {
                                        Write-Host ("  {0,-40} {1,-8} {2}" -f $entrada.Name, $entrada.Type, $entrada.Data)
                                    }
                                    Write-Host ""
                                    Write-Host "  Total de entradas: $($cache.Count)" -ForegroundColor DarkGray
                                }
                            } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        }

                        if ($selDns -in @("2","3")) {
                            Write-Host ""
                            Write-Host "  Vaciando cache DNS..." -NoNewline -ForegroundColor Yellow
                            try {
                                Clear-DnsClientCache -ErrorAction Stop
                                Write-Host " OK - Cache DNS vaciada correctamente." -ForegroundColor Green
                            } catch { Write-Host " FALLO: $($_.Exception.Message)" -ForegroundColor Red }
                        }

                        if ($selDns -notin @("1","2","3")) {
                            Write-Host "  Opcion no valida." -ForegroundColor Red
                        }

                        Write-Host ""; pause
                    }

                    "0" { $salirRed = $true }

                    default { Write-Host "  Opcion no valida." -ForegroundColor Red; Start-Sleep -Seconds 2 }
                }
            }
        }

# ================================================================
# 2. SISTEMA
# ================================================================
        "2" {
            $salirSistema = $false
            while (-not $salirSistema) {
                Clear-Host
                Write-Host "==========================================================" -ForegroundColor Magenta
                Write-Host "                 SISTEMA  -  Herramientas                " -ForegroundColor Magenta
                Write-Host "==========================================================" -ForegroundColor Magenta
                Write-Host "  1)  Estado de servicios criticos"
                Write-Host "  2)  Errores criticos del sistema (Visor de Eventos)"
                Write-Host "  3)  Limpiador de basura del sistema"
                Write-Host "  4)  Gestion de parches y actualizaciones"
                Write-Host "  5)  Numeros de serie del hardware"
                Write-Host "  6)  Programas y servicios al inicio del sistema"
                Write-Host "  7)  Control de servicios (iniciar / detener / reiniciar)"
                Write-Host "  0)  Volver al menu principal"
                Write-Host "==========================================================" -ForegroundColor Magenta
                $selSis = Read-Host "Seleccione una opcion"

                switch ($selSis) {

                    "1" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "              Estado de Servicios Criticos                " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        $totalOK = 0; $totalFail = 0; $totalNA = 0
                        foreach ($categoria in $serviciosCriticos.Keys | Sort-Object) {
                            Write-Host ""
                            Write-Host "  [ $categoria ]" -ForegroundColor Cyan
                            Write-Host "  --------------------------------------------------"
                            foreach ($svc in $serviciosCriticos[$categoria]) {
                                $servicio    = Get-Service -Name $svc.Nombre -ErrorAction SilentlyContinue
                                $descripcion = $svc.Desc.PadRight(38)
                                Write-Host -NoNewline "  $descripcion : "
                                if ($null -eq $servicio)                   { Write-Host "NO INSTALADO" -ForegroundColor DarkGray; $totalNA++ }
                                elseif ($servicio.Status -eq "Running")    { Write-Host "EN EJECUCION" -ForegroundColor Green;    $totalOK++ }
                                elseif ($servicio.Status -eq "Stopped")    { Write-Host "DETENIDO"     -ForegroundColor Red;      $totalFail++ }
                                else                                        { Write-Host "$($servicio.Status)" -ForegroundColor Yellow; $totalFail++ }
                            }
                        }
                        Write-Host ""
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "  Resumen -> " -NoNewline
                        Write-Host "OK: $totalOK  " -NoNewline -ForegroundColor Green
                        Write-Host "Detenidos: $totalFail  " -NoNewline -ForegroundColor Red
                        Write-Host "No instalados: $totalNA" -ForegroundColor DarkGray
                        Write-Host ""; pause
                    }

                    "2" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "         Errores Criticos del Sistema (Event Log)         " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""
                        Write-Host "  1) Ultimas 24h   2) 3 dias   3) 7 dias   4) 30 dias   5) Personalizado"
                        Write-Host ""
                        $rangoSel = Read-Host "  Seleccione"
                        $dias = switch ($rangoSel) {
                            "1" { 1 }  "2" { 3 }  "3" { 7 }  "4" { 30 }
                            "5" { [int](Read-Host "  Numero de dias") }
                            default { 1 }
                        }
                        $desdeWhen = (Get-Date).AddDays(-$dias)
                        Write-Host ""
                        Write-Host "  Buscando desde: $($desdeWhen.ToString('dd/MM/yyyy HH:mm'))..." -ForegroundColor Yellow
                        Write-Host ""
                        try {
                            $errores = Get-EventLog -LogName System -EntryType Error -After $desdeWhen -ErrorAction Stop |
                                       Select-Object TimeGenerated, Source, Message -First 20
                            if ($errores.Count -eq 0) {
                                Write-Host "  No se encontraron errores. El sistema esta limpio." -ForegroundColor Green
                            } else {
                                Write-Host "  Se encontraron $($errores.Count) error(es):" -ForegroundColor Red
                                Write-Host ""
                                $i = 1
                                foreach ($evento in $errores) {
                                    Write-Host "  [$i] $($evento.TimeGenerated.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Yellow
                                    Write-Host "       Origen  : $($evento.Source)" -ForegroundColor White
                                    $msg = ($evento.Message -replace "`r`n"," " -replace "`n"," ")
                                    if ($msg.Length -gt 200) { $msg = $msg.Substring(0,200) + "..." }
                                    Write-Host "       Mensaje : $msg" -ForegroundColor Gray
                                    Write-Host "  --------------------------------------------------"
                                    $i++
                                }
                            }
                        } catch { Write-Host "  Error. Ejecuta como Administrador." -ForegroundColor Red }
                        Write-Host ""; pause
                    }

                    "3" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "              Limpiador de Basura del Sistema             " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""
                        $objetivos = @(
                            @{ Ruta = "$env:TEMP";                                Desc = "Temp usuario actual"        }
                            @{ Ruta = "C:\Windows\Temp";                          Desc = "Temp del sistema"           }
                            @{ Ruta = "C:\Windows\Prefetch";                      Desc = "Prefetch de Windows"        }
                            @{ Ruta = "C:\Windows\SoftwareDistribution\Download"; Desc = "Cache de Windows Update"    }
                            @{ Ruta = "C:\inetpub\logs\LogFiles";                 Desc = "Logs de IIS"                }
                            @{ Ruta = "C:\Windows\Logs\CBS";                      Desc = "Logs CBS (actualizaciones)" }
                            @{ Ruta = "C:\Windows\Logs\DISM";                     Desc = "Logs DISM"                  }
                        )
                        $totalLiberado = 0
                        foreach ($obj in $objetivos) {
                            $desc = $obj.Desc.PadRight(36)
                            Write-Host -NoNewline "  $desc : "
                            if (-not (Test-Path $obj.Ruta)) { Write-Host "NO EXISTE" -ForegroundColor DarkGray; continue }
                            $tamAntes = (Get-ChildItem $obj.Ruta -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                            if ($null -eq $tamAntes) { $tamAntes = 0 }
                            try {
                                Get-ChildItem $obj.Ruta -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                                $tamDespues = (Get-ChildItem $obj.Ruta -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                                if ($null -eq $tamDespues) { $tamDespues = 0 }
                                $liberado = $tamAntes - $tamDespues; $totalLiberado += $liberado
                                Write-Host "OK  (-$([math]::Round($liberado/1MB,2)) MB)" -ForegroundColor Green
                            } catch { Write-Host "FALLO PARCIAL" -ForegroundColor Yellow }
                        }
                        Write-Host -NoNewline "  $("Papelera de reciclaje".PadRight(36)) : "
                        try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Host "OK" -ForegroundColor Green }
                        catch { Write-Host "VACIA o ERROR" -ForegroundColor DarkGray }
                        Write-Host ""
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "  Espacio liberado: $([math]::Round($totalLiberado/1MB,2)) MB  ($([math]::Round($totalLiberado/1GB,2)) GB)" -ForegroundColor Green
                        Write-Host ""; pause
                    }

                    "4" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "           Gestion de Parches y Actualizaciones           " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""
                        Write-Host "  [ Ultimas 10 actualizaciones instaladas ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
                            Write-Host ("  {0,-15} {1,-15} {2}" -f "HotFixID", "Instalado", "Descripcion") -ForegroundColor Cyan
                            Write-Host "  --------------------------------------------------"
                            foreach ($h in $hotfixes) {
                                $fecha = if ($h.InstalledOn) { $h.InstalledOn.ToString("dd/MM/yyyy") } else { "Desconocida" }
                                Write-Host ("  {0,-15} {1,-15} {2}" -f $h.HotFixID, $fecha, $h.Description)
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""
                        Write-Host "  [ Actualizaciones disponibles (winget) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        if (Get-Command winget -ErrorAction SilentlyContinue) {
                            Write-Host "  Consultando winget..." -ForegroundColor Yellow
                            try { winget upgrade 2>&1 | ForEach-Object { Write-Host "  $_" } }
                            catch { Write-Host "  Error winget: $($_.Exception.Message)" -ForegroundColor Red }
                        } else { Write-Host "  Winget no disponible en este sistema." -ForegroundColor DarkGray }
                        Write-Host ""; pause
                    }

                    "5" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "           Numeros de Serie del Hardware                  " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""

                        # ---- BIOS / Firmware ----
                        Write-Host "  [ BIOS / Firmware ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $bios = Get-CimInstance -ClassName Win32_BIOS
                            Write-Host ("  {0,-28} : {1}" -f "Fabricante",         $bios.Manufacturer)
                            Write-Host ("  {0,-28} : {1}" -f "Version BIOS",       $bios.SMBIOSBIOSVersion)
                            Write-Host ("  {0,-28} : {1}" -f "Numero de serie",    $bios.SerialNumber)
                            Write-Host ("  {0,-28} : {1}" -f "Fecha release",      $bios.ReleaseDate)
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # ---- Placa Base ----
                        Write-Host ""
                        Write-Host "  [ Placa Base (Motherboard) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $mb = Get-CimInstance -ClassName Win32_BaseBoard
                            Write-Host ("  {0,-28} : {1}" -f "Fabricante",         $mb.Manufacturer)
                            Write-Host ("  {0,-28} : {1}" -f "Modelo",             $mb.Product)
                            Write-Host ("  {0,-28} : {1}" -f "Numero de serie",    $mb.SerialNumber)
                            Write-Host ("  {0,-28} : {1}" -f "Version",            $mb.Version)
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # ---- Procesador ----
                        Write-Host ""
                        Write-Host "  [ Procesador (CPU) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $cpus = Get-CimInstance -ClassName Win32_Processor
                            foreach ($cpu in $cpus) {
                                Write-Host ("  {0,-28} : {1}" -f "Nombre",             $cpu.Name.Trim())
                                Write-Host ("  {0,-28} : {1}" -f "Fabricante",         $cpu.Manufacturer)
                                Write-Host ("  {0,-28} : {1}" -f "Numero de serie",    $cpu.ProcessorId)
                                Write-Host ("  {0,-28} : {1} nucleos / {2} hilos" -f "Nucleos", $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
                                Write-Host ("  {0,-28} : {1} MHz" -f "Velocidad max",  $cpu.MaxClockSpeed)
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # ---- Memoria RAM ----
                        Write-Host ""
                        Write-Host "  [ Modulos de Memoria RAM ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $ramModulos = Get-CimInstance -ClassName Win32_PhysicalMemory
                            $i = 1
                            foreach ($ram in $ramModulos) {
                                $capacidadGB = [math]::Round($ram.Capacity / 1GB, 1)
                                Write-Host "  -- Modulo $i --" -ForegroundColor DarkGray
                                Write-Host ("  {0,-28} : {1}" -f "Fabricante",         $ram.Manufacturer)
                                Write-Host ("  {0,-28} : {1}" -f "Numero de serie",    $ram.SerialNumber)
                                Write-Host ("  {0,-28} : {1}" -f "Numero de parte",    $ram.PartNumber.Trim())
                                Write-Host ("  {0,-28} : {1} GB  a  {2} MHz" -f "Capacidad / Velocidad", $capacidadGB, $ram.Speed)
                                Write-Host ("  {0,-28} : {1}" -f "Ranura (Slot)",      $ram.DeviceLocator)
                                $i++
                            }
                            if ($ramModulos.Count -eq 0) { Write-Host "  No se detectaron modulos de RAM." -ForegroundColor DarkGray }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # ---- Discos fisicos ----
                        Write-Host ""
                        Write-Host "  [ Discos Fisicos (HDD / SSD) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $discos = Get-CimInstance -ClassName Win32_DiskDrive
                            $i = 1
                            foreach ($d in $discos) {
                                $tamGB = [math]::Round($d.Size / 1GB, 1)
                                Write-Host "  -- Disco $i --" -ForegroundColor DarkGray
                                Write-Host ("  {0,-28} : {1}" -f "Modelo",             $d.Model)
                                Write-Host ("  {0,-28} : {1}" -f "Numero de serie",    $d.SerialNumber.Trim())
                                Write-Host ("  {0,-28} : {1} GB" -f "Capacidad",       $tamGB)
                                Write-Host ("  {0,-28} : {1}" -f "Interfaz",           $d.InterfaceType)
                                Write-Host ("  {0,-28} : {1}" -f "Particiones",        $d.Partitions)
                                $i++
                            }
                            if ($discos.Count -eq 0) { Write-Host "  No se detectaron discos." -ForegroundColor DarkGray }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # ---- GPU ----
                        Write-Host ""
                        Write-Host "  [ Tarjeta Grafica (GPU) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $gpus = Get-CimInstance -ClassName Win32_VideoController
                            foreach ($gpu in $gpus) {
                                $vramGB = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 1) } else { "N/A" }
                                Write-Host ("  {0,-28} : {1}" -f "Nombre",             $gpu.Name)
                                Write-Host ("  {0,-28} : {1}" -f "Fabricante",         $gpu.AdapterCompatibility)
                                Write-Host ("  {0,-28} : {1} GB" -f "VRAM",            $vramGB)
                                Write-Host ("  {0,-28} : {1}" -f "Version driver",     $gpu.DriverVersion)
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # ---- Sistema Operativo ----
                        Write-Host ""
                        Write-Host "  [ Sistema Operativo ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $so = Get-CimInstance -ClassName Win32_OperatingSystem
                            Write-Host ("  {0,-28} : {1}" -f "Nombre",             $so.Caption)
                            Write-Host ("  {0,-28} : {1}" -f "Version",            $so.Version)
                            Write-Host ("  {0,-28} : {1}" -f "Arquitectura",       $so.OSArchitecture)
                            Write-Host ("  {0,-28} : {1}" -f "Numero de serie",    $so.SerialNumber)
                            Write-Host ("  {0,-28} : {1}" -f "Instalado el",       $so.InstallDate.ToString("dd/MM/yyyy"))
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        Write-Host ""
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""
                        pause
                    }

                    "6" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "          Programas y Servicios al Inicio del Sistema     " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""

                        # Programas de inicio (registro y carpetas)
                        Write-Host "  [ Programas al Inicio (Startup) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $startups = Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction Stop |
                                        Sort-Object Location
                            if ($startups.Count -eq 0) {
                                Write-Host "  No se encontraron entradas de inicio." -ForegroundColor DarkGray
                            } else {
                                Write-Host ("  {0,-30} {1,-15} {2}" -f "Nombre","Usuario","Comando") -ForegroundColor Cyan
                                Write-Host "  --------------------------------------------------"
                                foreach ($s in $startups) {
                                    $cmd = if ($s.Command.Length -gt 55) { $s.Command.Substring(0,55) + "..." } else { $s.Command }
                                    Write-Host ("  {0,-30} {1,-15} {2}" -f $s.Name, $s.User, $cmd)
                                }
                                Write-Host ""
                                Write-Host "  Total: $($startups.Count) entradas de inicio" -ForegroundColor DarkGray
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        # Tareas programadas activas (no del sistema)
                        Write-Host ""
                        Write-Host "  [ Tareas Programadas Activas (no del sistema) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $tareas = Get-ScheduledTask -ErrorAction Stop |
                                      Where-Object {
                                          $_.State -eq "Ready" -and
                                          $_.TaskPath -notlike "\Microsoft\*"
                                      } | Select-Object -First 20

                            if ($tareas.Count -eq 0) {
                                Write-Host "  No se encontraron tareas programadas de usuario." -ForegroundColor DarkGray
                            } else {
                                Write-Host ("  {0,-35} {1,-12} {2}" -f "Nombre","Estado","Ruta") -ForegroundColor Cyan
                                Write-Host "  --------------------------------------------------"
                                foreach ($t in $tareas) {
                                    Write-Host ("  {0,-35} {1,-12} {2}" -f $t.TaskName, $t.State, $t.TaskPath)
                                }
                                Write-Host ""
                                Write-Host "  Mostrando primeras 20 tareas no del sistema." -ForegroundColor DarkGray
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        Write-Host ""; pause
                    }

                    "7" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "       Control de Servicios (Iniciar/Detener/Reiniciar)   " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""

                        # Mostrar servicios en ejecucion y detenidos relevantes
                        Write-Host "  [ Servicios del Sistema (Running / Stopped) ]" -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        Write-Host ("  {0,-35} {1,-12} {2}" -f "Nombre","Estado","DisplayName") -ForegroundColor Cyan
                        Write-Host "  --------------------------------------------------"
                        try {
                            $servicios = Get-Service -ErrorAction Stop |
                                         Where-Object { $_.StartType -ne "Disabled" } |
                                         Sort-Object Status -Descending |
                                         Select-Object -First 30
                            foreach ($s in $servicios) {
                                $color = if ($s.Status -eq "Running") { "Green" } else { "Red" }
                                $estado = $s.Status.ToString().PadRight(12)
                                Write-Host ("  {0,-35} " -f $s.Name) -NoNewline
                                Write-Host ("{0,-12} " -f $estado) -NoNewline -ForegroundColor $color
                                Write-Host $s.DisplayName
                            }
                            Write-Host ""
                            Write-Host "  (Mostrando primeros 30 servicios no deshabilitados)" -ForegroundColor DarkGray
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

                        Write-Host ""
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host "  Acciones disponibles:" -ForegroundColor Cyan
                        Write-Host "  1) Iniciar un servicio"
                        Write-Host "  2) Detener un servicio"
                        Write-Host "  3) Reiniciar un servicio"
                        Write-Host "  0) Volver sin hacer cambios"
                        Write-Host "==========================================================" -ForegroundColor Magenta
                        Write-Host ""
                        $accionSvc = Read-Host "  Seleccione accion"

                        if ($accionSvc -in @("1","2","3")) {
                            $nombreSvc = Read-Host "  Introduce el nombre exacto del servicio (ej: Spooler)"
                            $svcObj = Get-Service -Name $nombreSvc -ErrorAction SilentlyContinue

                            if ($null -eq $svcObj) {
                                Write-Host "  Servicio '$nombreSvc' no encontrado." -ForegroundColor Red
                            } else {
                                Write-Host "  Servicio encontrado: $($svcObj.DisplayName) - Estado actual: $($svcObj.Status)" -ForegroundColor Yellow
                                $conf = Read-Host "  Confirmas la accion? (S/N)"
                                if ($conf -in @("S","s")) {
                                    try {
                                        switch ($accionSvc) {
                                            "1" { Start-Service   -Name $nombreSvc -ErrorAction Stop; Write-Host "  Servicio iniciado correctamente."    -ForegroundColor Green }
                                            "2" { Stop-Service    -Name $nombreSvc -Force -ErrorAction Stop; Write-Host "  Servicio detenido correctamente."   -ForegroundColor Green }
                                            "3" { Restart-Service -Name $nombreSvc -Force -ErrorAction Stop; Write-Host "  Servicio reiniciado correctamente." -ForegroundColor Green }
                                        }
                                    } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                                } else { Write-Host "  Accion cancelada." -ForegroundColor Yellow }
                            }
                        }

                        Write-Host ""; pause
                    }

                    "0" { $salirSistema = $true }
                    default { Write-Host "  Opcion no valida." -ForegroundColor Red; Start-Sleep -Seconds 2 }
                }
            }
        }

# ================================================================
# 3. SEGURIDAD
# ================================================================
        "3" {
            $salirSeguridad = $false
            while (-not $salirSeguridad) {
                Clear-Host
                Write-Host "==========================================================" -ForegroundColor Red
                Write-Host "               SEGURIDAD  -  Herramientas                " -ForegroundColor Red
                Write-Host "==========================================================" -ForegroundColor Red
                Write-Host "  1)  Auditoria de usuarios y privilegios"
                Write-Host "  2)  Integridad y forense rapida"
                Write-Host "  3)  Auditoria de eventos criticos (requiere Admin)"
                Write-Host "  0)  Volver al menu principal"
                Write-Host "==========================================================" -ForegroundColor Red
                $selSeg = Read-Host "Seleccione una opcion"

                switch ($selSeg) {

                    "1" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Red
                        Write-Host "          Auditoria de Usuarios y Privilegios             " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Red
                        Write-Host ""
                        Write-Host "  [ Administradores Locales ]" -ForegroundColor Magenta
                        Write-Host "  --------------------------------------------------"
                        try {
                            $admins = Get-LocalGroupMember -Group "Administradores" -ErrorAction Stop
                            foreach ($a in $admins) { Write-Host "  $($a.ObjectClass.PadRight(10)) | $($a.Name)" -ForegroundColor White }
                        } catch {
                            try {
                                $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
                                foreach ($a in $admins) { Write-Host "  $($a.ObjectClass.PadRight(10)) | $($a.Name)" -ForegroundColor White }
                            } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        }
                        Write-Host ""
                        Write-Host "  [ Usuarios Inactivos (sin login en 30+ dias) ]" -ForegroundColor Magenta
                        Write-Host "  --------------------------------------------------"
                        try {
                            $limite = (Get-Date).AddDays(-30)
                            $inactivos = Get-LocalUser | Where-Object { $_.Enabled -eq $true -and ($_.LastLogon -lt $limite -or $_.LastLogon -eq $null) }
                            if ($inactivos.Count -eq 0) {
                                Write-Host "  No se encontraron usuarios inactivos." -ForegroundColor Green
                            } else {
                                foreach ($u in $inactivos) {
                                    $ultimo = if ($u.LastLogon) { $u.LastLogon.ToString("dd/MM/yyyy") } else { "Nunca" }
                                    Write-Host "  $($u.Name.PadRight(25)) | Ultimo login: $ultimo" -ForegroundColor Yellow
                                }
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""
                        Write-Host "  [ Sesiones RDP Activas ]" -ForegroundColor Magenta
                        Write-Host "  --------------------------------------------------"
                        try {
                            $sesiones = query session 2>&1
                            foreach ($linea in $sesiones) {
                                $color = if ($linea -match "rdp|Activ|Active|Conecta") { "Cyan" } else { "DarkGray" }
                                Write-Host "  $linea" -ForegroundColor $color
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""; pause
                    }

                    "2" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Red
                        Write-Host "              Integridad y Forense Rapida                 " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Red
                        Write-Host ""
                        Write-Host "  [ Procesos Sin Firma Digital ]" -ForegroundColor Magenta
                        Write-Host "  Analizando procesos en ejecucion..." -ForegroundColor Yellow
                        Write-Host "  --------------------------------------------------"
                        try {
                            $sinFirma = Get-Process | Where-Object { $_.Path } | ForEach-Object {
                                $sig = Get-AuthenticodeSignature -FilePath $_.Path -ErrorAction SilentlyContinue
                                if ($sig -and $sig.Status -ne "Valid") {
                                    [PSCustomObject]@{ PID = $_.Id; Nombre = $_.ProcessName; Estado = $sig.Status; Ruta = $_.Path }
                                }
                            }
                            if (-not $sinFirma) {
                                Write-Host "  Todos los procesos tienen firma valida." -ForegroundColor Green
                            } else {
                                foreach ($p in $sinFirma) {
                                    Write-Host "  [!] PID $($p.PID) | $($p.Nombre) | $($p.Estado)" -ForegroundColor Red
                                    Write-Host "      Ruta: $($p.Ruta)" -ForegroundColor DarkGray
                                }
                            }
                        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""
                        Write-Host "  [ Monitor del Archivo HOSTS ]" -ForegroundColor Magenta
                        Write-Host "  --------------------------------------------------"
                        try {
                            $lineas = Get-Content "C:\Windows\System32\drivers\etc\hosts" | Where-Object { $_ -notmatch "^\s*#" -and $_ -match "\S" }
                            if ($lineas.Count -eq 0) {
                                Write-Host "  Archivo HOSTS sin entradas activas. Correcto." -ForegroundColor Green
                            } else {
                                foreach ($l in $lineas) {
                                    $color = if ($l -match "^127\.0\.0\.1|^::1") { "DarkGray" } else { "Red" }
                                    Write-Host "  [!] $l" -ForegroundColor $color
                                }
                            }
                        } catch { Write-Host "  Error al leer HOSTS: $($_.Exception.Message)" -ForegroundColor Red }
                        Write-Host ""
                        Write-Host "  [ Calculo de Hash SHA256 ]" -ForegroundColor Magenta
                        Write-Host "  --------------------------------------------------"
                        $rutaHash = Read-Host "  Ruta del archivo sospechoso (Enter para omitir)"
                        if ($rutaHash -and (Test-Path $rutaHash)) {
                            try {
                                $hash = Get-FileHash -Path $rutaHash -Algorithm SHA256
                                Write-Host "  Archivo : $($hash.Path)"  -ForegroundColor Cyan
                                Write-Host "  SHA256  : $($hash.Hash)"  -ForegroundColor Yellow
                                Write-Host "  Contrasta en: https://www.virustotal.com" -ForegroundColor DarkGray
                            } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                        } elseif ($rutaHash) { Write-Host "  Archivo no encontrado." -ForegroundColor Red }
                        Write-Host ""; pause
                    }

                    "3" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Red
                        Write-Host "              Auditoria de Eventos Criticos               " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Red
                        Write-Host ""
                        if (-not (Test-Administrador)) {
                            Write-Host "  Esta opcion requiere Administrador." -ForegroundColor Yellow
                            Write-Host "  Se abrira una ventana elevada (UAC)." -ForegroundColor Yellow
                            Write-Host ""
                            $confirmarElev = Read-Host "  Deseas continuar? (S/N)"
                            if ($confirmarElev -notin @("S","s")) { Write-Host "  Cancelado." -ForegroundColor DarkGray; pause; break }
                        }
                        $diasEvt = Read-Host "  Cuantos dias atras quieres consultar? (ej: 7)"
                        if (-not $diasEvt -or $diasEvt -notmatch "^\d+$") { $diasEvt = 7 }

                        $codigoAuditoria = @"
`$desdeEvt = (Get-Date).AddDays(-$diasEvt)
`$eventosAuditoria = @(
    @{ Id = 4625; Desc = 'Intentos de login FALLIDOS (fuerza bruta)'; Color = 'Red'    }
    @{ Id = 4720; Desc = 'Creacion de nueva cuenta de usuario';       Color = 'Yellow' }
    @{ Id = 1102; Desc = 'Log de auditoria BORRADO (posible intrusion)'; Color = 'Red' }
)
Write-Host ''
Write-Host '==========================================================' -ForegroundColor Red
Write-Host '              Auditoria de Eventos Criticos               ' -ForegroundColor Yellow
Write-Host '==========================================================' -ForegroundColor Red
Write-Host "  Consultando eventos de los ultimos $diasEvt dias..." -ForegroundColor Cyan
Write-Host ''
foreach (`$evt in `$eventosAuditoria) {
    Write-Host "  [ ID `$(`$evt.Id) - `$(`$evt.Desc) ]" -ForegroundColor `$evt.Color
    Write-Host '  --------------------------------------------------'
    try {
        `$registros = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=`$evt.Id; StartTime=`$desdeEvt } -MaxEvents 10 -ErrorAction Stop
        Write-Host "  Se encontraron `$(`$registros.Count) evento(s):" -ForegroundColor `$evt.Color
        foreach (`$r in `$registros) {
            Write-Host "  `$(`$r.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')) | `$(`$r.Message.Split([char]10)[0])" -ForegroundColor DarkGray
        }
    } catch {
        if (`$_.Exception.Message -match 'No events') { Write-Host '  Sin eventos. Correcto.' -ForegroundColor Green }
        else { Write-Host "  Error: `$(`$_.Exception.Message)" -ForegroundColor Red }
    }
    Write-Host ''
}
Write-Host '==========================================================' -ForegroundColor Red
Write-Host ''
Read-Host '  Presiona Enter para cerrar'
"@
                        Invoke-ComoAdministrador -Codigo $codigoAuditoria
                        Write-Host ""
                        Write-Host "  Auditoria completada." -ForegroundColor Green
                        Write-Host ""; pause
                    }

                    "0" { $salirSeguridad = $true }
                    default { Write-Host "  Opcion no valida." -ForegroundColor Red; Start-Sleep -Seconds 2 }
                }
            }
        }

# ================================================================
# 4. BACKUP & RESTAURACION
# ================================================================
        "4" {
            $salirBackup = $false
            while (-not $salirBackup) {
                Clear-Host
                Write-Host "==========================================================" -ForegroundColor Yellow
                Write-Host "              BACKUP & RESTAURACION                       " -ForegroundColor Yellow
                Write-Host "==========================================================" -ForegroundColor Yellow
                Write-Host "  1)  Crear backup de configuraciones criticas"
                Write-Host "  2)  Restaurar backup de configuraciones"
                Write-Host "  0)  Volver al menu principal"
                Write-Host "==========================================================" -ForegroundColor Yellow
                $selBak = Read-Host "Seleccione una opcion"

                switch ($selBak) {

                    "1" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Yellow
                        Write-Host "         Backup Rapido de Configuraciones Criticas        " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Yellow

                        $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
                        $carpetaBackup = "C:\Backup_Red_$timestamp"
                        try {
                            New-Item -ItemType Directory -Path $carpetaBackup -Force -ErrorAction Stop | Out-Null
                        } catch {
                            $carpetaBackup = "$env:PUBLIC\Documents\Backup_Red_$timestamp"
                            try { New-Item -ItemType Directory -Path $carpetaBackup -Force -ErrorAction Stop | Out-Null }
                            catch { Write-Host "  ERROR: No se pudo crear la carpeta." -ForegroundColor Red; pause; break }
                        }

                        Write-Host ""
                        Write-Host "  Carpeta creada en:" -ForegroundColor Cyan
                        Write-Host "  $carpetaBackup" -ForegroundColor White
                        Write-Host ""
                        $totalOK = 0; $totalFail = 0

                        Write-Host "  [1/5] Adaptadores de red ..." -NoNewline
                        try { Get-NetAdapter | Export-CliXml "$carpetaBackup\Adaptadores_Red.xml"; Write-Host " OK -> $carpetaBackup\Adaptadores_Red.xml" -ForegroundColor Green; $totalOK++ }
                        catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }

                        Write-Host "  [2/5] Configuracion IP y DNS ..." -NoNewline
                        try {
                            Get-NetIPConfiguration | Select-Object InterfaceAlias,InterfaceIndex,IPv4Address,IPv6Address,DNSServer,NetProfile |
                                Export-CliXml "$carpetaBackup\Configuracion_IP.xml"
                            Write-Host " OK -> $carpetaBackup\Configuracion_IP.xml" -ForegroundColor Green; $totalOK++
                        } catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }

                        Write-Host "  [3/5] Rutas estaticas ..." -NoNewline
                        try {
                            Get-NetRoute | Where-Object { $_.RouteMetric -ne 256 } | Export-CliXml "$carpetaBackup\Rutas_Estaticas.xml"
                            Write-Host " OK -> $carpetaBackup\Rutas_Estaticas.xml" -ForegroundColor Green; $totalOK++
                        } catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }

                        Write-Host "  [4/5] web.config (IIS) ..." -NoNewline
                        if (Test-Path "C:\inetpub\wwwroot\web.config") {
                            try { Copy-Item "C:\inetpub\wwwroot\web.config" "$carpetaBackup\web.config.bak" -Force; Write-Host " OK -> $carpetaBackup\web.config.bak" -ForegroundColor Green; $totalOK++ }
                            catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }
                        } else { Write-Host " NO DETECTADO (IIS no instalado)" -ForegroundColor DarkGray }

                        Write-Host "  [5/5] Certificados del sistema ..." -NoNewline
                        try {
                            Get-ChildItem Cert:\LocalMachine\My | Select-Object Subject,Thumbprint,NotBefore,NotAfter,Issuer |
                                Export-CliXml "$carpetaBackup\Certificados_Sistema.xml"
                            Write-Host " OK -> $carpetaBackup\Certificados_Sistema.xml" -ForegroundColor Green; $totalOK++
                        } catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }

                        Write-Host ""
                        Write-Host "==========================================================" -ForegroundColor Yellow
                        Write-Host "  Backup completado en:" -ForegroundColor Cyan
                        Write-Host "  $carpetaBackup" -ForegroundColor White
                        Write-Host "  Resumen -> " -NoNewline
                        Write-Host "Correctos: $totalOK  " -NoNewline -ForegroundColor Green
                        Write-Host "Fallidos: $totalFail"              -ForegroundColor Red
                        Write-Host ""; pause
                    }

                    "2" {
                        Clear-Host
                        Write-Host "==========================================================" -ForegroundColor Yellow
                        Write-Host "         Restaurar Backup de Configuraciones              " -ForegroundColor Yellow
                        Write-Host "==========================================================" -ForegroundColor Yellow
                        Write-Host ""

                        $backups = @()
                        $backups += Get-ChildItem "C:\" -Directory -Filter "Backup_Red_*" -ErrorAction SilentlyContinue
                        $backups += Get-ChildItem "$env:PUBLIC\Documents" -Directory -Filter "Backup_Red_*" -ErrorAction SilentlyContinue

                        if ($backups.Count -eq 0) {
                            Write-Host "  No se encontro ningun backup. Crea uno primero (opcion 1)." -ForegroundColor Red
                            pause; break
                        }

                        Write-Host "  Backups disponibles:" -ForegroundColor Cyan
                        Write-Host ""
                        for ($i = 0; $i -lt $backups.Count; $i++) { Write-Host "  [$($i+1)] $($backups[$i].FullName)" -ForegroundColor White }
                        Write-Host ""
                        $selBakNum = Read-Host "  Seleccione el numero del backup"
                        $indice = [int]$selBakNum - 1

                        if ($indice -lt 0 -or $indice -ge $backups.Count) { Write-Host "  Seleccion no valida." -ForegroundColor Red; pause; break }

                        $carpetaRestaurar = $backups[$indice].FullName
                        Write-Host ""
                        Write-Host "  Restaurando desde: $carpetaRestaurar" -ForegroundColor Cyan
                        Write-Host "  ATENCION: Sobreescribira la configuracion de red actual." -ForegroundColor Red
                        $confirmar = Read-Host "  Estas seguro? (S/N)"
                        if ($confirmar -notin @("S","s")) { Write-Host "  Cancelado." -ForegroundColor Yellow; pause; break }

                        Write-Host ""
                        $totalOK = 0; $totalFail = 0; $totalNA = 0

                        Write-Host "  [1/4] Adaptadores ..." -NoNewline
                        $fAdapt = "$carpetaRestaurar\Adaptadores_Red.xml"
                        if (Test-Path $fAdapt) {
                            try {
                                Import-CliXml $fAdapt | ForEach-Object {
                                    $a = Get-NetAdapter -Name $_.Name -ErrorAction SilentlyContinue
                                    if ($a -and $a.Status -eq "Disabled") { Enable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }
                                }
                                Write-Host " OK" -ForegroundColor Green; $totalOK++
                            } catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }
                        } else { Write-Host " NO ENCONTRADO" -ForegroundColor DarkGray; $totalNA++ }

                        Write-Host "  [2/4] IPs y DNS ..." -NoNewline
                        $fIP = "$carpetaRestaurar\Configuracion_IP.xml"
                        if (Test-Path $fIP) {
                            try {
                                Import-CliXml $fIP | ForEach-Object {
                                    $iface = Get-NetAdapter -Name $_.InterfaceAlias -ErrorAction SilentlyContinue
                                    if ($iface) {
                                        Remove-NetIPAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                                        Remove-NetRoute -InterfaceIndex $iface.ifIndex -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
                                        if ($_.IPv4Address) {
                                            $ipAddr = $_.IPv4Address | Select-Object -First 1
                                            New-NetIPAddress -InterfaceIndex $iface.ifIndex -IPAddress $ipAddr.IPAddress -PrefixLength $ipAddr.PrefixLength `
                                                -DefaultGateway ($_.IPv4DefaultGateway | Select-Object -ExpandProperty NextHop -First 1) -ErrorAction SilentlyContinue | Out-Null
                                        }
                                        if ($_.DNSServer) {
                                            Set-DnsClientServerAddress -InterfaceIndex $iface.ifIndex `
                                                -ServerAddresses ($_.DNSServer | Select-Object -ExpandProperty ServerAddresses) -ErrorAction SilentlyContinue
                                        }
                                    }
                                }
                                Write-Host " OK" -ForegroundColor Green; $totalOK++
                            } catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }
                        } else { Write-Host " NO ENCONTRADO" -ForegroundColor DarkGray; $totalNA++ }

                        Write-Host "  [3/4] Rutas estaticas ..." -NoNewline
                        $fRutas = "$carpetaRestaurar\Rutas_Estaticas.xml"
                        if (Test-Path $fRutas) {
                            try {
                                Import-CliXml $fRutas | ForEach-Object {
                                    New-NetRoute -InterfaceIndex $_.ifIndex -DestinationPrefix $_.DestinationPrefix `
                                        -NextHop $_.NextHop -RouteMetric $_.RouteMetric -ErrorAction SilentlyContinue | Out-Null
                                }
                                Write-Host " OK" -ForegroundColor Green; $totalOK++
                            } catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }
                        } else { Write-Host " NO ENCONTRADO" -ForegroundColor DarkGray; $totalNA++ }

                        Write-Host "  [4/4] web.config ..." -NoNewline
                        $fWC = "$carpetaRestaurar\web.config.bak"
                        if (Test-Path $fWC) {
                            try { Copy-Item $fWC "C:\inetpub\wwwroot\web.config" -Force; Write-Host " OK" -ForegroundColor Green; $totalOK++ }
                            catch { Write-Host " FALLO" -ForegroundColor Red; $totalFail++ }
                        } else { Write-Host " NO HABIA BACKUP DE WEB.CONFIG" -ForegroundColor DarkGray; $totalNA++ }

                        Write-Host ""
                        Write-Host "==========================================================" -ForegroundColor Yellow
                        Write-Host "  Restauracion completada." -ForegroundColor Cyan
                        Write-Host "  Resumen -> " -NoNewline
                        Write-Host "Correctos: $totalOK  " -NoNewline -ForegroundColor Green
                        Write-Host "Fallidos: $totalFail  " -NoNewline -ForegroundColor Red
                        Write-Host "No aplicables: $totalNA"           -ForegroundColor DarkGray
                        Write-Host ""; pause
                    }

                    "0" { $salirBackup = $true }
                    default { Write-Host "  Opcion no valida." -ForegroundColor Red; Start-Sleep -Seconds 2 }
                }
            }
        }

# ================================================================
# 5. RENDIMIENTO
# ================================================================
        "5" {
            $salirRendimiento = $false
            while (-not $salirRendimiento) {
                Clear-Host
                Write-Host "==========================================================" -ForegroundColor DarkYellow
                Write-Host "              RENDIMIENTO  -  Estado del Sistema          " -ForegroundColor DarkYellow
                Write-Host "==========================================================" -ForegroundColor DarkYellow
                Write-Host ""

                # ---- Espacio en disco ----
                Write-Host "  [ Espacio en Disco por Unidad ]" -ForegroundColor Magenta
                Write-Host "  --------------------------------------------------"
                Write-Host ("  {0,-6} {1,12} {2,12} {3,12} {4,8}" -f "Unidad","Total (GB)","Usado (GB)","Libre (GB)","% Libre") -ForegroundColor Cyan
                Write-Host "  --------------------------------------------------"
                try {
                    $unidades = Get-PSDrive -PSProvider FileSystem -ErrorAction Stop | Where-Object { $_.Used -ne $null }
                    foreach ($u in $unidades) {
                        $totalGB = [math]::Round(($u.Used + $u.Free) / 1GB, 1)
                        $usadoGB = [math]::Round($u.Used / 1GB, 1)
                        $libreGB = [math]::Round($u.Free / 1GB, 1)
                        $pctLibre = if (($u.Used + $u.Free) -gt 0) { [math]::Round(($u.Free / ($u.Used + $u.Free)) * 100, 1) } else { 0 }
                        $color = if ($pctLibre -lt 10) { "Red" } elseif ($pctLibre -lt 20) { "Yellow" } else { "Green" }
                        Write-Host ("  {0,-6} {1,12} {2,12} {3,12}" -f "$($u.Name):", $totalGB, $usadoGB, $libreGB) -NoNewline
                        Write-Host ("{0,8}" -f "$pctLibre%") -ForegroundColor $color
                    }
                } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                Write-Host ""

                $top5CPU = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.CPU -ne $null } |
                           Sort-Object CPU -Descending | Select-Object -First 5
                $top5RAM = Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending |
                           Select-Object -First 5

                Write-Host "  [ TOP 5 por CPU (segundos acumulados) ]" -ForegroundColor Magenta
                Write-Host "  --------------------------------------------------"
                Write-Host ("  {0,-8} {1,-30} {2,10} {3,12}" -f "PID","Nombre","CPU (s)","RAM (MB)") -ForegroundColor Cyan
                Write-Host "  --------------------------------------------------"
                foreach ($p in $top5CPU) {
                    Write-Host ("  {0,-8} {1,-30} {2,10} {3,12}" -f $p.Id, $p.ProcessName, [math]::Round($p.CPU,1), [math]::Round($p.WorkingSet64/1MB,1))
                }

                Write-Host ""
                Write-Host "  [ TOP 5 por RAM (MB en uso) ]" -ForegroundColor Magenta
                Write-Host "  --------------------------------------------------"
                Write-Host ("  {0,-8} {1,-30} {2,10} {3,12}" -f "PID","Nombre","CPU (s)","RAM (MB)") -ForegroundColor Cyan
                Write-Host "  --------------------------------------------------"
                foreach ($p in $top5RAM) {
                    $cpu = if ($p.CPU) { [math]::Round($p.CPU,1) } else { "N/A" }
                    Write-Host ("  {0,-8} {1,-30} {2,10} {3,12}" -f $p.Id, $p.ProcessName, $cpu, [math]::Round($p.WorkingSet64/1MB,1))
                }

                Write-Host ""
                Write-Host "==========================================================" -ForegroundColor DarkYellow
                Write-Host "  K) Matar proceso por PID   R) Refrescar   V) Volver"
                Write-Host "==========================================================" -ForegroundColor DarkYellow
                Write-Host ""
                $accion = Read-Host "  Opcion"

                switch ($accion.ToUpper()) {
                    "K" {
                        $pidKill    = Read-Host "  PID a detener"
                        $procTarget = Get-Process -Id ([int]$pidKill) -ErrorAction SilentlyContinue
                        if ($null -eq $procTarget) {
                            Write-Host "  No se encontro proceso con PID $pidKill." -ForegroundColor Red
                        } else {
                            Write-Host "  Proceso: $($procTarget.ProcessName) (PID: $pidKill)" -ForegroundColor Yellow
                            $conf = Read-Host "  Confirmas? (S/N)"
                            if ($conf -in @("S","s")) {
                                try { Stop-Process -Id ([int]$pidKill) -Force; Write-Host "  Proceso detenido correctamente." -ForegroundColor Green }
                                catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
                            } else { Write-Host "  Cancelado." -ForegroundColor Yellow }
                        }
                        Start-Sleep -Seconds 2
                    }
                    "R" { continue }
                    "V" { $salirRendimiento = $true }
                    default { Write-Host "  Opcion no valida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
                }
            }
        }

# ================================================================
# 0. SALIR
# ================================================================
        "0" {
            Write-Host ""
            Write-Host "SALIENDO DEL PROGRAMA. Buen dia :) !!" -ForegroundColor Green
            Start-Sleep -Seconds 1
            $salir = $true
        }

        default {
            Write-Host ""
            Write-Host "  !! OPCION NO VALIDA. Elija entre 0 y 5 !!" -ForegroundColor Red
            Write-Host ""
            Start-Sleep -Seconds 2
        }
    }
}