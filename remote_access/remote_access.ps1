# Remote access setup (Windows): Tailscale + Remote Desktop + OpenSSH server, reachable only through
# Tailscale, plus RustDesk (by RustDesk ID or over Tailscale). Safe to re-run.
#   just remote-access                          set everything up (one admin prompt)
#   just remote-access -AddKey <pubkey|file>    also allow an SSH public key (e.g. from your Mac)
#   just remote-access -Status                  show what is set up
param([string]$AddKey, [switch]$Status, [switch]$Elevated, [Parameter(ValueFromRemainingArguments)] [string[]]$Rest)
$ErrorActionPreference = 'Stop'
if ($Rest) { $AddKey = (@($AddKey) + $Rest) -join ' ' }   # `just` splits an unquoted key at its spaces; rejoin it
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
$tsNets = '100.64.0.0/10', 'fd7a:115c:a1e0::/48'   # Tailscale's address ranges; nothing else gets in
$log = Join-Path $env:TEMP 'remote_access.log'
$rd = 'C:\Program Files\RustDesk\rustdesk.exe'

function Show-Status {
    $rdpOn = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections -eq 0
    'Tailscale:       ' + $(if (Test-Path $ts) { (& $ts status --peers=false 2>&1 | Select-Object -First 1) } else { 'not installed' })
    'Remote Desktop:  ' + $(if ($rdpOn) { 'on' } else { 'off' })
    'SSH server:      ' + ((Get-Service sshd -ErrorAction SilentlyContinue).Status ?? 'not installed')
    'RustDesk:        ' + ((Get-Service RustDesk -ErrorAction SilentlyContinue).Status ?? 'not installed')
}

function Install-MachineSettings {
    Start-Transcript $log -Force | Out-Null
    try {
        # 1. Tailscale runs as a service, so the PC joins your private network before anyone signs in.
        if (-not (Test-Path $ts)) {
            winget install --id Tailscale.Tailscale --exact --silent --accept-package-agreements --accept-source-agreements
        }

        # 2. Allow password sign-in for Microsoft accounts. Remote Desktop can't use a PIN; the PIN still works locally.
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device' DevicePasswordLessBuildVersion 0

        # 3. Remote Desktop, with sign-in required before a session starts.
        Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' fDenyTSConnections 0
        Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' UserAuthentication 1
        Get-NetFirewallRule -Group '@FirewallAPI.dll,-28752' | Set-NetFirewallRule -Enabled True -Profile Any -RemoteAddress $tsNets

        # 4. OpenSSH server: key sign-in only.
        # dism.exe, because the *-WindowsCapability cmdlets fail under PowerShell 7 ("Class not registered").
        if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
            dism.exe /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0 /NoRestart /Quiet
            if ($LASTEXITCODE -notin 0, 3010) { throw "Installing the OpenSSH server failed (dism exit code $LASTEXITCODE)." }
        }
        Set-Service sshd -StartupType Automatic
        Start-Service sshd   # the first start creates the config file and host keys
        $cfg = 'C:\ProgramData\ssh\sshd_config'
        (Get-Content $cfg -Raw) -replace '(?m)^#?\s*PasswordAuthentication\s+\w+', 'PasswordAuthentication no' `
            -replace '(?m)^#?\s*PubkeyAuthentication\s+\w+', 'PubkeyAuthentication yes' | Set-Content $cfg -NoNewline
        $shell = 'C:\Program Files\PowerShell\7\pwsh.exe', "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not (Test-Path 'HKLM:\SOFTWARE\OpenSSH')) { New-Item 'HKLM:\SOFTWARE\OpenSSH' | Out-Null }
        New-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $shell -Force | Out-Null
        if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
        }
        Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True -Profile Any -RemoteAddress $tsNets
        if ($AddKey) {
            $key = if (Test-Path -LiteralPath $AddKey -ErrorAction SilentlyContinue) { (Get-Content -LiteralPath $AddKey -Raw).Trim() } else { $AddKey.Trim() }
            if ($key -notmatch '^(ssh-|ecdsa-|sk-)\S+\s+\S+') { throw "That doesn't look like a full SSH public key: $key" }
            $keys = 'C:\ProgramData\ssh\administrators_authorized_keys'   # the key file sshd reads for administrators
            # Keep only complete key lines, so a key cut off by an earlier bad run gets dropped.
            $lines = @(if (Test-Path $keys) { Get-Content $keys | Where-Object { $_ -match '^\S+\s+\S+' } })
            if ($key -notin $lines) { $lines += $key }
            Set-Content $keys $lines
            icacls $keys /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null   # Administrators, SYSTEM
        }
        Restart-Service sshd

        # 5. RustDesk: controls the real screen (its privacy mode can black it out), works from the login screen,
        #    and is reachable by RustDesk ID or directly over Tailscale. Not in winget, so use the official GitHub release.
        if (-not (Test-Path $rd)) {
            $asset = (Invoke-RestMethod https://api.github.com/repos/rustdesk/rustdesk/releases/latest).assets |
                Where-Object name -match 'x86_64\.msi$' | Select-Object -First 1
            $dl = New-Item -ItemType Directory -Force (Join-Path $env:TEMP 'rustdesk-install')
            $msi = Join-Path $dl $asset.name
            Invoke-WebRequest $asset.browser_download_url -OutFile $msi
            if ('sha256:' + (Get-FileHash $msi).Hash.ToLower() -ne $asset.digest) { throw 'RustDesk download does not match its published checksum.' }
            if ((Get-AuthenticodeSignature $msi).Status -ne 'Valid') { throw 'RustDesk installer signature is not valid.' }
            Start-Process msiexec.exe -ArgumentList '/i', "`"$msi`"", '/qn', '/norestart' -Wait
        }
        & $rd --option direct-server Y | Out-Null   # piping makes PowerShell wait for this GUI exe
        if (-not (Get-NetFirewallRule -Name 'RustDesk-Direct-In' -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name 'RustDesk-Direct-In' -DisplayName 'RustDesk direct IP (Tailscale only)' -Direction Inbound `
                -Protocol TCP -LocalPort 21118 -Action Allow -Profile Any -RemoteAddress $tsNets | Out-Null
        }
    } finally { Stop-Transcript | Out-Null }
}

if ($Status) { Show-Status; return }
if ($Elevated) { Install-MachineSettings; return }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if ($isAdmin) { Install-MachineSettings } else {
    # Machine settings need admin: run this same script elevated (one prompt) and wait for it.
    $argList = @('-NoProfile', '-File', "`"$PSCommandPath`"", '-Elevated')
    if ($AddKey) { $argList += '-AddKey', "`"$AddKey`"" }
    $p = Start-Process pwsh -Verb RunAs -Wait -PassThru -ArgumentList $argList
    if ($p.ExitCode) { throw "Admin setup failed. Details: $log" }
}

# 5. Sign this PC in to Tailscale. --unattended keeps it connected while nobody is signed in to Windows.
& $ts up --unattended

''
Show-Status
''
'Remote Desktop needs your Microsoft account password, and only after it has been used on this PC once'
'(Win+L > Sign-in options > password). SSH needs a key added with -AddKey.'
