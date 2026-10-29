#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path "$PSScriptRoot/.."

Write-Host "==> [1/5] Validando sincronizacao de contratos e DTOs (/shared)..." -ForegroundColor Cyan
node "$RootDir/scripts/generate-shared-contracts.mjs" --check

Write-Host "==> [2/5] Verificando lint do Painel Web (/web)..." -ForegroundColor Cyan
Push-Location "$RootDir/web"
npm run lint

Write-Host "==> [3/5] Executando testes automatizados do Painel Web (/web)..." -ForegroundColor Cyan
npm test

Write-Host "==> [4/5] Gerando build de producao do Painel Web (/web)..." -ForegroundColor Cyan
npm run build
Pop-Location

Write-Host "==> [5/5] Executando formatacao, analise estatica e testes do App Mobile (/mobile)..." -ForegroundColor Cyan
Push-Location "$RootDir/mobile"
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
Pop-Location

Write-Host "==> Monorepo PREVER validado com sucesso!" -ForegroundColor Green
