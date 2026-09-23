# Passo a passo no Supabase - SMDN Web Admin

Este pacote não altera o Supabase automaticamente. Você roda os SQLs manualmente no Dashboard.

## Ordem recomendada

### 1. Corrigir trigger do Auth

No Supabase:

```txt
SQL Editor > New query
```

Rode:

```txt
supabase/sql/01_fix_auth_trigger.sql
```

Por quê?

A trigger antiga falhava ao criar usuário pelo Dashboard porque tentava inserir `Perfis.prf_nome = null`.
A nova trigger continua aceitando os metadados do mobile, mas usa fallback quando o usuário é criado manualmente.

### 2. Criar tabelas do painel administrativo

Ainda no SQL Editor, rode:

```txt
supabase/sql/02_web_admin_tables.sql
```

Isso cria:

```txt
Solicitacao_Acesso_Web
Audit_Log
policies iniciais
```

### 3. Criar o primeiro usuário Auth

No Supabase:

```txt
Authentication > Users > Add user
```

Preencha:

```txt
Email
Password
Auto Confirm User: marcado
```

Crie o usuário e copie o UUID.

### 4. Transformar o usuário em administrador

Abra:

```txt
supabase/sql/03_create_first_admin_TEMPLATE.sql
```

Substitua:

```txt
UUID_DO_AUTH_USER
NOME_DO_ADMIN
APELIDO_DO_ADMIN
```

Rode no SQL Editor.

### 5. Testar no web

No `web/.env.local`:

```env
VITE_SUPABASE_URL=https://robfgvtnoooivihlnomr.supabase.co
VITE_SUPABASE_ANON_KEY=sua_publishable_key_ou_anon_public
VITE_DEV_BYPASS_AUTH=false
VITE_DEV_BYPASS_ADMIN=false
```

Rode:

```bash
cd web
npm install @supabase/supabase-js
npm run dev
```

Faça login com o email e senha do admin.

Se tudo estiver certo, o menu mostra:

```txt
Painel do Administrador
```

## Bypass local opcional

Para abrir as telas sem login no localhost:

```env
VITE_DEV_BYPASS_AUTH=true
VITE_DEV_BYPASS_ADMIN=false
```

Para também mostrar o painel admin localmente:

```env
VITE_DEV_BYPASS_AUTH=true
VITE_DEV_BYPASS_ADMIN=true
```

Nunca use esses dois em produção.

## Observação sobre mobile

A correção da trigger foi feita para não quebrar o mobile:

- Se o mobile mandar `prf_nome` e `prf_tipo`, a trigger usa esses dados.
- Se o Dashboard não mandar metadata, a trigger usa fallback.

## RLS das tabelas antigas

O Supabase apontou RLS desativado em tabelas antigas:

```txt
Cidadao
Historico_Medicacao_Cidadao
Relato
Foto
Perfis
```

Não ative RLS nelas agora sem criar policies, porque isso pode quebrar o app.
