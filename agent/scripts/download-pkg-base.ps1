param(
  [string] $PkgCachePath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PkgCachePath)) {
  $PkgCachePath = Join-Path (Resolve-Path ".") ".pkg-cache"
}

# pkg@5.8.x uses pkg-fetch tag v3.4 and node v18.5.0 for node18-win-x64 target.
$tag = "v3.4"
$assetName = "node-v18.5.0-win-x64"
$outDir = Join-Path $PkgCachePath $tag
$outFile = Join-Path $outDir ("fetched-v18.5.0-win-x64")
$url = "https://github.com/vercel/pkg-fetch/releases/download/$tag/$assetName"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (Test-Path $outFile) {
  Write-Host "[pkg] Base binary already present: $outFile"
  $env:PKG_CACHE_PATH = $PkgCachePath
  exit 0
}

Write-Host "[pkg] Downloading base binary..."
Write-Host "      $url"

if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
  & curl.exe -L --fail --output $outFile $url
  if ($LASTEXITCODE -ne 0) { throw "curl.exe failed with exit code $LASTEXITCODE" }
} else {
  try {
    Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
  } catch {
    # Some environments require explicit TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
  }
}

Write-Host "[pkg] Saved: $outFile"

# Ensure pkg uses this cache
$env:PKG_CACHE_PATH = $PkgCachePath

