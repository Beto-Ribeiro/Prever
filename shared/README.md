# Camada Compartilhada (`/shared`) — Monorepo PREVER (SMDN)

Este diretório centraliza a **Fonte Única de Verdade (Single Source of Truth)** para contratos de domínio, DTOs, constantes operacionais, utilitários de validação e especificações do Supabase compartilhados entre:

- **Frontend Web (`/web`)**: Painel tático e administrativo em React 19 + Vite 8 + Tailwind CSS.
- **Aplicativo Mobile (`/mobile`)**: Aplicativo cidadão em Flutter (Dart 3.9).
- **Backend Serverless (`/supabase`)**: Schema PostgreSQL com RLS, Storage Buckets, RPCs e Edge Functions Deno.

## Geração Automatizada de DTOs e Contratos (TypeScript/ESM + Dart)

A definição canônica reside em [`schema/domain.schema.json`](./schema/domain.schema.json). O script [`../scripts/generate-shared-contracts.mjs`](../scripts/generate-shared-contracts.mjs) lê esse schema e gera automaticamente:

1. [`types/domain.d.ts`](./types/domain.d.ts): Interfaces e tipos TypeScript (`PerfilUsuarioDto`, `OcorrenciaRelatoDto`, `AbrigoEmergenciaDto`, `AlertaDefesaCivilDto`, `WebPermissions`).
2. [`constants/domain.js`](./constants/domain.js): Constantes imutáveis (`SEVERITY_LEVELS`, `SEVERITY_VISUAL_TOKENS`, `SHELTER_STATUSES`, `USER_ROLES`, `DEFAULT_WEB_PERMISSIONS`, `ANTIFRAUD_CONFIG`) e factories normalizadoras de DTOs para JavaScript/ESM.
3. [`services/supabaseContracts.js`](./services/supabaseContracts.js): Nomes canônicos de tabelas, buckets do Supabase Storage, RPCs e Edge Functions.
4. [`../mobile/lib/shared/prever_contracts.dart`](../mobile/lib/shared/prever_contracts.dart): Classes constantes (`PreverTables`, `PreverStorageBuckets`, `PreverEdgeFunctions`, `PreverAntifraudConfig`) e DTOs imutáveis em Dart com serialização `fromJson`/`toJson`.

### Comandos

```bash
# Gerar/atualizar contratos em /shared e /mobile/lib/shared
node scripts/generate-shared-contracts.mjs

# Verificar sincronização sem modificar arquivos (usado em CI/CD)
node scripts/generate-shared-contracts.mjs --check
```
