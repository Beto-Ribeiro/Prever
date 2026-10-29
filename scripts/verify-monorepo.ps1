#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

function Assert-LastExitCode([string]$StepName) {
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha na etapa '$StepName' (exit code: $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}

$RootDir = Resolve-Path "$PSScriptRoot/.."

Write-Host "==> [1/5] Validando sincronizacao de contratos e DTOs (/shared)..." -ForegroundColor Cyan
node "$RootDir/scripts/generate-shared-contracts.mjs" --check
Assert-LastExitCode "Contratos /shared"

Write-Host "==> [2/5] Verificando lint do Painel Web (/web)..." -ForegroundColor Cyan
Push-Location "$RootDir/web"
npm run lint
Assert-LastExitCode "Lint Web"

Write-Host "==> [3/5] Executando testes automatizados do Painel Web (/web)..." -ForegroundColor Cyan
npm test
Assert-LastExitCode "Testes Web"

Write-Host "==> [4/5] Gerando build de producao do Painel Web (/web)..." -ForegroundColor Cyan
npm run build
Assert-LastExitCode "Build Web"
Pop-Location

Write-Host "==> [5/5] Executando formatacao, analise estatica e testes do App Mobile (/mobile)..." -ForegroundColor Cyan
Push-Location "$RootDir/mobile"
dart format --output=none --set-exit-if-changed .
Assert-LastExitCode "Formatacao Dart"

flutter analyze --fatal-infos --fatal-warnings
Assert-LastExitCode "Flutter Analyze"

flutter test
Assert-LastExitCode "Flutter Test"
Pop-Location

Write-Host "==> Monorepo PREVER validado com sucesso!" -ForegroundColor Green
