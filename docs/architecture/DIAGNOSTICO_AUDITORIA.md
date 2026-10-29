# Diagnóstico Técnico e Auditoria DevSecOps — PREVER (SMDN)

Este documento consolida o diagnóstico realizado nas **Etapas 1, 2 e 3** da auditoria arquitetural, de qualidade e de segurança do repositório `Prever`.

---

## 1. Problemas Críticos e Erros de Compilação Encontrados e Corrigidos

1. **Erro de Sintaxe em [`mobile/lib/telas/Relatos.dart`](../../mobile/lib/telas/Relatos.dart)**:
   - A lista inicializadora do construtor `_DashedBorderPainter` utilizava dois-pontos (`: strokeWidth = 1.4 : dashWidth = 6 : dashSpace = 4;`) em vez de vírgulas, gerando 10 erros fatais de compilação no Dart.
2. **Erro de Construtor Constante em [`mobile/lib/telas/tela_principal.dart`](../../mobile/lib/telas/tela_principal.dart)**:
   - `CustomAnimatedBottomBar` possuía construtor `const`, mas inicializava os campos `corFundoMenu` e `corIconeInativo` com `Color(...)` sem `const`, gerando 2 erros fatais de compilação.
3. **Manifesto Android Inválido em [`mobile/android/app/src/main/AndroidManifest.xml`](../../mobile/android/app/src/main/AndroidManifest.xml)**:
   - Comentário XML sem tag de abertura `<!--` na linha 49, quebrando o parser XML do Gradle durante o build Android.
4. **Incompatibilidade Case-Sensitive em [`mobile/lib/telas/exportador_import.dart`](../../mobile/lib/telas/exportador_import.dart)**:
   - Exportações referenciavam `SLogCad.dart`, `ConfEmail.dart`, `ChangePassword.dart` e `WriteChangedPassword.dart` com iniciais maiúsculas, enquanto os arquivos físicos no disco são `sLogCad.dart`, `confEmail.dart`, `changePassword.dart` e `writeChangedPassword.dart`, causando falha de compilação em ambientes Linux (CI/CD).
5. **Sobrescrita Acidental de Edge Function em [`supabase/functions/approve-web-access-request/index.ts`](../../supabase/functions/approve-web-access-request/index.ts)**:
   - O arquivo na raiz `/supabase` continha o código da função de IA (`smdn-ai`) em vez da lógica de aprovação administrativa de acesso web. Foi restaurado e a função `smdn-ai` foi devidamente isolada em [`supabase/functions/smdn-ai/index.ts`](../../supabase/functions/smdn-ai/index.ts).
6. **Bug de Asset em Build de Produção Web em [`web/src/screens/Login.jsx`](../../web/src/screens/Login.jsx)**:
   - Uso de `url('/src/assets/map-bg.png')` hardcoded em estilo inline, que falha no pacote de produção gerado pelo Vite (`dist/`). Corrigido via importação de módulo ES (`import mapBg from '../assets/map-bg.png'`).
7. **Erros de Linter e Referência Global em [`web/src/components/MapView.jsx`](../../web/src/components/MapView.jsx)**:
   - Uso de `new google.maps.Circle` sem qualificação `window.google.maps.Circle` (`no-undef`), importação `useCallback` não utilizada e variável `err` não utilizada no bloco `catch`.

---

## 2. Vulnerabilidades de Segurança Corrigidas (OWASP Top 10)

1. **Chave de API Hardcoded (`OPENWEATHER_API_KEY`) em [`mobile/lib/telas/clima_tela.dart`](../../mobile/lib/telas/clima_tela.dart)**:
   - A chave da API OpenWeatherMap estava exposta diretamente no código-fonte. Substituída por leitura via `dotenv.env['OPENWEATHER_API_KEY']` com tratamento de erro amigável caso ausente.
2. **Credenciais Fallback Hardcoded do Supabase em [`mobile/lib/main.dart`](../../mobile/lib/main.dart)**:
   - URL e Anon Key reais do projeto Supabase estavam embutidas como fallback no `Supabase.initialize`. Removidas para exigir configuração via `.env`.
3. **Vazamento de Senha em Logs (`CWE-532`) em [`mobile/lib/telas/tela_principal.dart`](../../mobile/lib/telas/tela_principal.dart)**:
   - `debugPrint("RECEBI SENHA NA TELA PRINCIPAL: $senha")` imprimia a senha em texto claro no console do dispositivo. Removido.
4. **Exposição de Detalhes Internos de Exceção na UI (`CWE-209`) em [`mobile/lib/telas/formatadores/default_widgets.dart`](../../mobile/lib/telas/formatadores/default_widgets.dart)**:
   - `CarregarDadosPin` exibia `e.toString()` diretamente nos campos de tipo e magnitude do pino. Substituído por mensagem segura (`'Indisponível'`).
5. **Falha na Confirmação de Identidade SOS em [`mobile/lib/telas/Home.dart`](../../mobile/lib/telas/Home.dart)**:
   - O diálogo de confirmação de SOS pedia os 3 primeiros dígitos do CPF, mas comparava igualdade estrita com o CPF completo (11 dígitos), impedindo o acionamento legítimo ou falhando silenciosamente. Corrigido para validar os 3 primeiros dígitos (ou os 11 dígitos) com feedback visual claro.

---

## 3. Limpeza de Código Morto, Duplicatas e Artefatos Efêmeros

- Removidos da raiz do monorepo: diretórios gerados acidentalmente (`.dart_tool/`, `.flutter-plugins-dependencies`, `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `lib/` duplicado) e `SUPABASE_PASSO_A_PASSO.md`.
- Removidos de `/mobile`: scripts temporários (`bulk_fix.py`, `bulk_fix_2.py`, `rename_classes.py`), tela descartada (`lib/telas/discarded/discarded_home.dart`), `MainActivity.kt` duplicado no namespace antigo `com.example.teste`, relatório de build HTML e dependências não utilizadas (`image_picker`, `location`).
- Removidos de `/web`: `src/components/MapView_leaflet_backup.jsx`, arquivos vazios (`alertasService.js`, `auditoriaService.js`, `profileService.js`), cliente duplicado (`src/lib/supabase.js`), cliente Axios quebrado (`src/backend/api/api.js`) e `domContextService.js` sem uso.
- Removidos de `/supabase` e `/docs`: `05_user_list_activity (1).sql` e cópias duplicadas de SQL/Edge Function.
