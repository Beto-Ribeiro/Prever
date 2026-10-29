# Código-Fonte Mobile (`mobile/lib`)

Por convenção obrigatória do SDK do Flutter/Dart e da ferramenta `flutter pub` / `flutter build`, os arquivos de código-fonte Dart do pacote `prever` residem em [`../lib/`](../lib/main.dart), enquanto este diretório `mobile/src/` documenta o mapeamento arquitetural do monorepo:

- [`../lib/main.dart`](../lib/main.dart): Ponto de entrada da aplicação, inicialização do `.env`, Firebase Core, Supabase e `AccessibilityController`.
- [`../lib/controles/`](../lib/controles/controle_acessibilidade.dart): Gerenciamento de estado global de acessibilidade, alto contraste, daltonismo e escala tipográfica.
- [`../lib/services/`](../lib/services/antifraude_service.dart): Serviços de domínio (`AntiFraudeService` via Firebase AI / Gemini, `RelatosProximosService` com filtro geodésico Haversine).
- [`../lib/telas/`](../lib/telas/tela_principal.dart): Telas modulares do aplicativo cidadão (Home/SOS, Mapa de Alertas, Relatos, Clima, Abrigos, Chatbot Nimbo, Autenticação e Perfil).
