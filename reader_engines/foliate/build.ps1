# Reproducible offline asset build for Foliate-js.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "foliate-js"
$out = Join-Path $here "assets"
Push-Location $src
try {
  if (-not (Test-Path "node_modules")) {
    npm ci
  }
  npm run build
} finally {
  Pop-Location
}
Write-Host "Build output in $out"
