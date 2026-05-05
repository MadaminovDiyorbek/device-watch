# DeviceWatch - mahalliy muhitni tayyorlash (server + agent .env, ixtiyoriy Docker).
# Ishlatish:  powershell -ExecutionPolicy Bypass -File tools\deploy\Setup-DeviceWatch.ps1
#            powershell ... -TryDocker
#            powershell ... -CloudUrl https://watch.example.com

param(
    [string] $CloudUrl = "",
    [switch] $TryDocker,
    [switch] $RegenerateSecrets
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$serverDir = Join-Path $root "server"
$agentDir = Join-Path $root "agent"
$credFile = Join-Path $serverDir ".deploy-credentials.txt"

function Get-RandomBytes([int] $Count) {
    $b = New-Object byte[] $Count
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $rng.GetBytes($b)
    return $b
}

function New-Base64Secret([int] $ByteCount = 48) {
    [Convert]::ToBase64String((Get-RandomBytes $ByteCount))
}

function New-HexKey([int] $ByteCount = 32) {
    -join ((Get-RandomBytes $ByteCount) | ForEach-Object { $_.ToString("x2") })
}

function New-AdminPassword {
    # Admin parol (tasodifiy)
    $raw = New-Base64Secret 24
    return ($raw -replace '[+/=]', '').Substring(0, [Math]::Min(20, ($raw -replace '[+/=]', '').Length))
}

$serverExample = Join-Path $serverDir ".env.example"
$serverEnv = Join-Path $serverDir ".env"
$agentExample = Join-Path $agentDir ".env.example"
$agentEnv = Join-Path $agentDir ".env"

if (-not (Test-Path $serverExample)) { throw "Topilmadi: $serverExample" }

$shouldWriteServer = $RegenerateSecrets -or -not (Test-Path $serverEnv)
$weakJwt = $false
if (Test-Path $serverEnv) {
    $cur = Get-Content $serverEnv -Raw
    if ($cur -match "JWT_SECRET=o'zgartiring" -or $cur -match "ENROLLMENT_KEY=demo-enroll-secret" -or $cur -match 'ADMIN_PASSWORD=admin123') {
        $weakJwt = $true
    }
}
if ($weakJwt -and -not $RegenerateSecrets) {
    Write-Host "[*] server/.env da zaif standart qiymatlar aniqlandi - yangilanadi."
    $shouldWriteServer = $true
}

if ($shouldWriteServer) {
    $jwt = New-Base64Secret 48
    $enroll = New-HexKey 32
    $adminPass = New-AdminPassword
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content $serverExample) {
        if ($line -match '^\s*#') { $out.Add($line); continue }
        if ($line -match '^JWT_SECRET=') { $out.Add("JWT_SECRET=$jwt"); continue }
        if ($line -match '^ENROLLMENT_KEY=') { $out.Add("ENROLLMENT_KEY=$enroll"); continue }
        if ($line -match '^ADMIN_PASSWORD=') { $out.Add("ADMIN_PASSWORD=$adminPass"); continue }
        if ($line -match '^TRUST_PROXY=') { continue }
        if ([string]::IsNullOrWhiteSpace($line)) { $out.Add($line); continue }
        $out.Add($line)
    }
    Set-Content -Path $serverEnv -Value ($out -join "`n") -Encoding UTF8
    $cred = (@'
DeviceWatch - yaratilgan kirish (SAQLANG)
Admin panel: http://localhost:5050/admin/  (cloud URL ni o'zingiz qo'shasiz)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=
ENROLLMENT_KEY=
(JWT_SECRET server/.env faylida)
'@).Replace('ADMIN_PASSWORD=', "ADMIN_PASSWORD=$adminPass").Replace('ENROLLMENT_KEY=', "ENROLLMENT_KEY=$enroll")
    Set-Content -Path $credFile -Value $cred -Encoding UTF8
    Write-Host "[OK] server/.env yangilandi. Parol va enrollment: $credFile"
}
else {
    Write-Host "[=] server/.env o'zgartirilmadi (-RegenerateSecrets bilan majburiy qilish mumkin)."
}

# ENROLLMENT_KEY ni server .env dan o'qib agentga yozish
$enrollmentFromServer = ""
if (Test-Path $serverEnv) {
    Get-Content $serverEnv | ForEach-Object {
        if ($_ -match '^ENROLLMENT_KEY=(.+)$') { $enrollmentFromServer = $Matches[1].Trim() }
    }
}

if (-not (Test-Path $agentExample)) {
    Write-Warning "agent/.env.example yo'q - agent o'tkazib yuborildi."
}
else {
    $agentLines = Get-Content $agentExample
    $aOut = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $agentLines) {
        if ($line -match '^SERVER_URL=') {
            if ($CloudUrl) {
                $u = $CloudUrl.TrimEnd('/')
                $aOut.Add("SERVER_URL=$u")
            }
            elseif (Test-Path $agentEnv) {
                $aOut.Add($line)
            }
            else {
                $aOut.Add("SERVER_URL=http://localhost:5050")
            }
            continue
        }
        if ($line -match '^ENROLLMENT_KEY=' -and $enrollmentFromServer) {
            $aOut.Add("ENROLLMENT_KEY=$enrollmentFromServer")
            continue
        }
        $aOut.Add($line)
    }
    Set-Content -Path $agentEnv -Value ($aOut -join "`n") -Encoding UTF8
    Write-Host "[OK] agent/.env server bilan mos ENROLLMENT_KEY."
}

if ($TryDocker) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        Write-Warning "Docker topilmadi. O'rnating yoki serverni: cd server; npm start"
    }
    else {
        Push-Location $serverDir
        try {
            docker compose up -d --build
            Write-Host "[OK] Docker: docker compose up -d --build (server papkasi)."
        }
        finally {
            Pop-Location
        }
    }
}
else {
    Write-Host "Docker uchun:  -TryDocker  qo'shing yoki:  cd server; docker compose up -d --build"
}

Write-Host "OK. VPS: server/scripts/bootstrap-vps.sh | server/DEPLOY.md"
