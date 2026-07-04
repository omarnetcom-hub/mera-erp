# Script para compilar MerkaERP y generar instalador Windows (Inno Setup)
# Requisitos: Flutter SDK, Inno Setup 6+ instalado en el PATH (ISCC.exe)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "==> Flutter pub get" -ForegroundColor Cyan
Push-Location $ProjectRoot
flutter pub get

Write-Host "==> Flutter build windows --release" -ForegroundColor Cyan
flutter build windows --release

$IsccCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$Iscc = $IsccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Iscc) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { $Iscc = $cmd.Source }
}
if (-not $Iscc) {
    Write-Error "Inno Setup no encontrado. Instale desde https://jrsoftware.org/isinfo.php"
}

Write-Host "==> Generando instalador MerkaERP-Setup.exe" -ForegroundColor Cyan
& $Iscc "$ProjectRoot\installer\merkaerp.iss"

$Output = Join-Path $ProjectRoot "build\installer\MerkaERP-Setup.exe"
if (-not (Test-Path $Output)) {
    $Output = Join-Path $ProjectRoot "build\installer\MerkaERP-Setup-1.0.2.exe"
}
if (Test-Path $Output) {
    Write-Host ""
    Write-Host "Instalador generado:" -ForegroundColor Green
    Write-Host $Output
} else {
    Write-Error "No se encontró el instalador en build\installer\"
}

Pop-Location
