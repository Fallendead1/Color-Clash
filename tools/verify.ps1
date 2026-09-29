# Color Clash local verification: pure unit tests, lint, and reproducible builds of both Rojo projects.
# Usage (repo root):  powershell -ExecutionPolicy Bypass -File tools\verify.ps1
# Exit code is non-zero if any step fails. Engine/integration tests run in Studio (see docs/QA_MATRIX.md).

$ErrorActionPreference = 'Continue'
Set-Location (Split-Path $PSScriptRoot -Parent)
$failed = @()

function Step($name, [scriptblock]$body) {
    Write-Host "== $name" -ForegroundColor Cyan
    & $body
    if ($LASTEXITCODE -ne 0) { $script:failed += $name; Write-Host "FAILED: $name" -ForegroundColor Red }
}

Step 'toolchain (rokit install)' { rokit install | Out-Null }
Step 'unit tests (lune)' { lune run tests/run }
Step 'lint (selene src)' { selene src }
New-Item -ItemType Directory -Force build | Out-Null
Step 'build development place' { rojo build default.project.json -o build/development.rbxlx }
Step 'build production place' { rojo build production.project.json -o build/production.rbxlx }
Step 'production excludes dev code' {
    $x = Get-Content build/production.rbxlx -Raw
    if ($x -match 'ColorClashDev|TestKit|paint_lab|PaintLab') { Write-Host 'dev/test content found in production build'; $global:LASTEXITCODE = 1 } else { $global:LASTEXITCODE = 0 }
}

if ($failed.Count -gt 0) { Write-Host "VERIFY FAILED: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host 'VERIFY PASSED' -ForegroundColor Green
exit 0
