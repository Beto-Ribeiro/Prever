# Arquitetura do Monorepo PREVER (SMDN)

## 1. Visão Arquitetural

O **PREVER — Sistema de Monitoramento de Desastres Naturais (SMDN)** adota uma arquitetura de **Monorepo Modular Orientado a Domínio**, segregando responsabilidades entre o aplicativo móvel voltado ao cidadão (`/mobile`), o painel web tático-operacional e administrativo voltado à Defesa Civil, Corpo de Bombeiros e Gestores de Abrigos (`/web`), a camada de contratos compartilhados (`/shared`) e a infraestrutura serverless e banco de dados relacional (`/supabase`).

## 2. Princípios Aplicados

- **Separation of Concerns (SoC) & Modularidade**:
  - No `/web`, a camada `src/backend/` encapsula toda comunicação com o Supabase, regras de autorização (`webAccessService.js`), políticas de IA (`assistantPolicy.js`, `smdnContextService.js`), gestão de abrigos (`shelterManagerService.js`) e auditoria (`auditLogService.js`), mantendo os componentes React (`src/screens/`, `src/components/`) focados em apresentação e estado de UI.
  - No `/mobile`, os serviços de domínio (`lib/services/antifraude_service.dart` e `lib/services/relatos_proximos_service.dart`) e o controlador de acessibilidade (`lib/controles/controle_acessibilidade.dart`) estão desacoplados das telas (`lib/telas/`).
- **Security by Design & Fail-Closed**:
  - Nenhuma chave sensível é mantida hardcoded no código-fonte.
  - O filtro antifraude multimodal (`AntiFraudeService`) opera em modo *fail-safe* de precaução: qualquer relato com score `< 0.80` ou falha de comunicação com a IA recebe `status_validacao = 'pendente_revisao'`, exigindo validação humana no painel web antes de ser considerado confirmado.
  - O assistente Nimbo no painel web filtra estritamente o contexto enviado ao modelo de linguagem (`assistantPolicy.js` + `screenContextService.js`), mascarando campos sensíveis (CPF, RG, senhas, tokens) e restringindo consultas ao escopo de permissão do operador logado.
- **Acessibilidade Universal (WCAG)**:
  - Suporte nativo a temas claro/escuro, alto contraste, paletas seguras para daltonismo (deuteranopia, protanopia e tritanopia), redução de movimento e escala tipográfica ajustável tanto no Web quanto no Mobile.
