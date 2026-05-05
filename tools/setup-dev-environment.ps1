# DeviceWatch: Android SDK + JDK + (ixtiyoriy) VS Build Tools
# PowerShell: odatda oddiy foydalanuvchi huquqi yetadi. VS C++ workload uchun Administrator kerak bo'lishi mumkin.

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$jdkHome = Join-Path $PSScriptRoot "jdk17"
$sdk = Join-Path $env:LOCALAPPDATA "Android\sdk"

function Ensure-Jdk {
    if (Test-Path (Join-Path $jdkHome "bin\java.exe")) {
        Write-Host "[JDK] Bor: $jdkHome"
        return
    }
    Write-Host "[JDK] Yuklab olinmoqda (Microsoft OpenJDK 17)..."
    $zip = Join-Path $PSScriptRoot "microsoft-jdk17.zip"
    $url = "https://aka.ms/download-jdk/microsoft-jdk-17.0.14-windows-x64.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    $tmp = Join-Path $PSScriptRoot "_jdk_tmp"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $tmp -Force
    $inner = Get-ChildItem $tmp | Select-Object -First 1 -ExpandProperty FullName
    Remove-Item $jdkHome -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item $inner $jdkHome
    Remove-Item $tmp -Recurse -Force
    Remove-Item $zip -Force
    Write-Host "[JDK] Tayyor."
}

function Ensure-AndroidCmdline {
    $sm = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sm) {
        Write-Host "[Android cmdline-tools] Bor."
        return
    }
    New-Item -ItemType Directory -Force -Path $sdk | Out-Null
    $zip = Join-Path $sdk "cmdline-tools-download.zip"
    $url = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    Write-Host "[Android] cmdline-tools yuklanmoqda..."
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    $tmp = Join-Path $sdk "_ct_expand"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $tmp -Force
    $inner = Join-Path $tmp "cmdline-tools"
    if (-not (Test-Path $inner)) { throw "Zip ichida cmdline-tools topilmadi" }
    $targetRoot = Join-Path $sdk "cmdline-tools"
    Remove-Item $targetRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
    Move-Item $inner (Join-Path $targetRoot "latest")
    Remove-Item $tmp -Recurse -Force
    Write-Host "[Android] cmdline-tools joylashtirildi."
}

function Install-AndroidPackages {
    $env:JAVA_HOME = $jdkHome
    $env:ANDROID_HOME = $sdk
    $env:ANDROID_SDK_ROOT = $sdk
    $sm = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
    Write-Host "[Android] paketlar o'rnatilmoqda (Flutter 3.41 uchun API 36)..."
    & $sm --sdk_root=$sdk "platform-tools" "platforms;android-35" "build-tools;35.0.0" "platforms;android-36" "build-tools;36.1.0" 2>$null
    $yes = 1..80 | ForEach-Object { 'y' }
    $yes | & $sm --sdk_root=$sdk --licenses 2>$null
    Write-Host "[Android] tayyor."
}

function Try-VsWorkload {
    $setup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
    if (-not (Test-Path $setup)) {
        Write-Host "[VS] setup.exe topilmadi — o'tkazib yuborildi."
        return
    }
    Write-Host "[VS] VCTools + CMake + SDK komponentlari qo'shilmoqda (Administrator kerak bo'lishi mumkin)..."
    $installPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
    if (-not (Test-Path $installPath)) {
        Write-Host "[VS] BuildTools yo'q — Visual Studio 2022 Build Tools o'rnating."
        return
    }
    & $setup modify `
        --installPath $installPath `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --add Microsoft.VisualStudio.Component.VC.CMake.Project `
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.19041 `
        --includeRecommended `
        --quiet `
        --norestart
    Write-Host "[VS] buyruq yuborildi. Agar xato bo'lsa, VS Installer ni Administrator sifatida ishga tushiring."
}

Ensure-Jdk
Ensure-AndroidCmdline
Install-AndroidPackages

[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdk, "User")
Write-Host "Foydalanuvchi muhiti: JAVA_HOME, ANDROID_HOME yangilandi."

Try-VsWorkload

Write-Host ""
Write-Host "Tekshiruv: JAVA_HOME=$jdkHome"
Write-Host "  & `"$repoRoot\tools\flutter\bin\flutter.bat`" doctor"
