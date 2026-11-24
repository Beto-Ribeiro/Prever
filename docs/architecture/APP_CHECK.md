# App Check no Android e iOS

A inicialização em main.dart ativa o App Check antes de usar Firebase AI Logic.
Debug usa AndroidDebugProvider; profile/release usa AndroidPlayIntegrityProvider.
Nenhum segredo de debug deve ser incluído no código ou distribuído em produção.

## Validar o APK de desenvolvimento

1. Instale o APK debug atualizado e abra o aplicativo.
2. No log local do Android, procure a mensagem de DebugAppCheckProvider.
3. Cadastre o token em Firebase Console > App Check > Apps > aplicativo Android
   com.example.branch1 > menu de três pontos > Manage debug tokens.
4. Feche e abra o app novamente. O log do Flutter deve indicar que o dispositivo
   está autorizado. Teste uma conversa com o Nimbo e a análise de relato.

O token identifica esta instalação. Uma reinstalação com remoção dos dados pode
exigir novo cadastro. Não publique esse token nem o envie em relatos.
Não é necessário alterar as chaves do Supabase ou desativar a proteção App Check.

## Produção

Antes de distribuir um APK de produção, configure Play Integrity no App Check,
registre o SHA-256 do certificado correto e valide a distribuição escolhida.
O APK de debug autorizado serve apenas para desenvolvimento neste dispositivo.
No iOS, debug usa AppleDebugProvider; profile/release usa App Attest com fallback
para DeviceCheck. Configure esses provedores no Firebase antes de distribuir.
Web ainda precisa de configuração própria.

Referência: https://firebase.google.com/docs/app-check/flutter/debug-provider


## Token de teste do iOS

Em um Mac com Flutter e Xcode, atualize este projeto e suas dependências.
Abra ios/Runner.xcworkspace. Em Product > Scheme > Edit Scheme > Run > Arguments,
adicione -FIRDebugEnabled em Arguments Passed On Launch somente para testes.
Execute em Debug no iPhone de teste ou simulador. Procure App Check debug token
no console do Xcode e registre o valor no Firebase > App Check > Apps > aplicativo
iOS > Manage debug tokens. Reinicie o app e teste o Nimbo.

Não use o token Android; mantenha o token iOS privado. Esta configuração foi
analisada no Windows, mas a compilação e a validação iOS exigem um Mac.
