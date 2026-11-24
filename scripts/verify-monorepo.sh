#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [1/5] Validando sincronizacao de contratos e DTOs (/shared)..."
node "$ROOT_DIR/scripts/generate-shared-contracts.mjs" --check

echo "==> [2/5] Verificando lint do Painel Web (/web)..."
cd "$ROOT_DIR/web"
npm run lint

echo "==> [3/5] Executando testes automatizados do Painel Web (/web)..."
npm test

echo "==> [4/5] Gerando build de producao do Painel Web (/web)..."
npm run build

echo "==> [5/5] Executando formatacao, analise estatica e testes do App Mobile (/mobile)..."
cd "$ROOT_DIR/mobile"
CREATED_ENV=0
if [ ! -f .env ]; then
  cp .env.example .env
  CREATED_ENV=1
fi
trap '[ "$CREATED_ENV" -eq 1 ] && rm -f "$ROOT_DIR/mobile/.env"' EXIT
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test

echo "==> Monorepo PREVER validado com sucesso!"
