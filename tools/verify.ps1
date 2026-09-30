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
Step 'luau syntax (luau-lsp analyze)' {
    $files = @(Get-ChildItem -Recurse -Include *.luau src, tests | ForEach-Object { $_.FullName })
    $out = & luau-lsp analyze --platform=standard @files 2>&1 | Out-String
    $syntax = @($out -split "`n" | Where-Object { $_ -match 'SyntaxError' })
    if ($syntax.Count -gt 0) { $syntax | ForEach-Object { Write-Host $_ }; $global:LASTEXITCODE = 1 } else { Write-Host "no syntax errors in $($files.Count) files"; $global:LASTEXITCODE = 0 }
}
Step 'unit tests (lune)' { lune run tests/run }
Step 'lint (selene src)' { selene src }
New-Item -ItemType Directory -Force build | Out-Null
Step 'build development place' { rojo build default.project.json -o build/development.rbxlx }
Step 'build production place' { rojo build production.project.json -o build/production.rbxlx }
Step 'production excludes dev code' {
    # Match instance names (not source text: production code may mention the fixture in DevGate-guarded paths).
    $x = Get-Content build/production.rbxlx -Raw
    $found = [regex]::Matches($x, 'name="Name">(Dev|TestKit|PaintLab|TestRunner|ClientTestRunner|specs|engine|unit|fixtures)<') | ForEach-Object { $_.Groups[1].Value }
    if ($found.Count -gt 0) { Write-Host "dev/test instances in production build: $($found -join ', ')"; $global:LASTEXITCODE = 1 } else {
        $dev = Get-Content build/development.rbxlx -Raw
        $devFound = [regex]::Matches($dev, 'name="Name">(TestKit|PaintLab|TestRunner|ClientTestRunner)<').Count
        if ($devFound -lt 4) { Write-Host "sanity: expected dev instances in development build, found $devFound"; $global:LASTEXITCODE = 1 } else { Write-Host 'production build has no dev instances (dev build has them)'; $global:LASTEXITCODE = 0 }
    }
}

Step 'client surface scan (SEC-10)' {
    $py = if (Test-Path tools/.venv/Scripts/python.exe) { 'tools/.venv/Scripts/python.exe' } else { 'python' }
    & $py tools/scan_client_surface.py build/production.rbxlx
}

if ($failed.Count -gt 0) { Write-Host "VERIFY FAILED: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host 'VERIFY PASSED' -ForegroundColor Green
exit 0
