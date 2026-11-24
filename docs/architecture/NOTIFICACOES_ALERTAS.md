# Notificações de Alerta_Web em um raio de 20 km

## Estado da integração

O cliente Flutter, a migração SQL e a função de envio estão implementados no projeto.
**A entrega real depende da instalação da migração, da configuração dos segredos e da publicação da função no Supabase.**
O arquivo `google-services.json` existente identifica o aplicativo; ele não é uma conta de serviço e não autoriza o servidor a enviar push.

## Funcionamento

1. Após a permissão de localização e o login, o celular solicita a permissão de notificações e obtém um token Firebase Cloud Messaging (FCM).
2. O aplicativo registra token e coordenadas por uma função autenticada do Supabase. Atualiza a posição ao abrir/retomar o aplicativo, a cada cinco minutos enquanto aberto e ao se deslocar aproximadamente 100 metros.
3. Um novo registro em `public."Alerta_Web"`, com `alw_status = 'disparado'`, usa `alw_lat` e `alw_lng` para selecionar os celulares a uma distância menor ou igual a 20.000 metros. O cálculo é Haversine, com tolerância numérica de um micrômetro apenas para arredondamento.
4. A fila guarda os destinatários elegíveis na emissão. Uma função no Supabase envia o push pelo Firebase, revalidando status do alerta, localização recente e dispositivo ativo antes do envio.
5. Com o app aberto, o celular confere novamente sua posição atual antes de mostrar a notificação. Ao tocar na notificação, abre o mapa do aplicativo.

Não há mudança necessária no site se ele já insere os alertas nessa tabela. O gatilho `trg_record_alerta_web_activity` é preservado. Alertas antigos, cancelados, resolvidos ou sem coordenadas válidas não são disparados. Alterar um registro existente para `disparado` não cria outro envio.

### Limite da localização em segundo plano

**Em segundo plano ou com o app fechado, a seleção usa a última localização enviada pelo celular, válida por até 30 minutos.** Depois desse prazo, o dispositivo deixa de ser elegível até enviar uma nova posição. Não há rastreamento contínuo em segundo plano nem solicitação de permissão de localização permanente. Se a pessoa se mover com o app fechado, a posição registrada pode divergir da atual. Portanto, esta implementação não garante o raio da posição exata naquele instante com o app fechado.

O sistema operacional apresenta as notificações FCM em segundo plano. O aplicativo precisa ter sido aberto e ter permissões concedidas. Um encerramento forçado pelo Android, a falta de internet ou as restrições do sistema podem impedir/atrasar entregas. Push não substitui os canais oficiais de emergência.

## Ativação no Supabase e Firebase

Execute os passos em um ambiente de teste primeiro. Os testes automatizados usam dados sintéticos e não publicam alertas reais.

### 1. Banco de dados

No SQL Editor do projeto Supabase usado pelo aplicativo, execute:

`supabase/migrations/202611040001_alertas_push.sql`

A migração cria tabelas privadas e funções de registro de dispositivos/fila. Não é necessário habilitar Realtime nem expor tokens/localizações na Data API. Cada usuário só pode registrar/desativar seu próprio dispositivo. Os dados privados não podem ser consultados por usuários do aplicativo.

### 2. Credencial Firebase para o servidor

Use o projeto Firebase **chatbot-ia---smdn**, o mesmo configurado no aplicativo.

- No Firebase Console, abra **Configurações do projeto > Contas de serviço** e obtenha a credencial JSON de uma conta autorizada a enviar pelo Firebase Cloud Messaging HTTP v1.
- Confirme que a **Firebase Cloud Messaging API** está habilitada no projeto Google Cloud.
- Guarde o JSON fora do repositório. Não o coloque no `.env` do Flutter, em `assets`, em código, em commits ou em mensagens de chat.

Em **Supabase > Edge Functions > Secrets**, configure:

| Segredo | Valor |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT` | JSON completo da conta de serviço, guardado apenas no servidor |
| `FIREBASE_PROJECT_ID` | `chatbot-ia---smdn` |
| `ALERTAS_WEBHOOK_SECRET` | Valor aleatório com pelo menos 32 caracteres, usado somente entre banco e função |

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são disponibilizados pelo ambiente das Edge Functions; nunca copie a chave de serviço para o aplicativo.

### 3. Publicar a função

Com a CLI do Supabase autenticada e o projeto correto selecionado:

```sh
supabase functions deploy enviar-alertas-web --project-ref SEU_PROJECT_REF
```

Execute a partir da raiz do repositório para aplicar `supabase/config.toml`. A função desabilita a verificação de JWT do gateway porque aceita apenas chamadas autenticadas pelo cabeçalho privado `x-webhook-secret`. Uma chamada sem o segredo correto é recusada. A função não aceita tokens de destino nem conteúdo de alertas enviados pelo chamador: sempre lê sua fila privada.

### 4. Ativar o acionamento e as tentativas

No Supabase Vault, crie `alertas_push_url` com `https://SEU_PROJECT_REF.supabase.co/functions/v1/enviar-alertas-web` e `alertas_webhook_secret` com o mesmo valor de `ALERTAS_WEBHOOK_SECRET`. Execute `supabase/setup/ativar_push_alertas.sql`. Ele liga o acionamento na emissão e a recuperação periódica da fila. A integração não funciona apenas publicando a função: o acionamento também precisa ser instalado.

### 5. Atualizar o aplicativo Android

```sh
flutter pub get
flutter run
```

Faça login no celular, permita localização e notificações e mantenha internet ativa. As permissões devem ser concedidas pela pessoa que usa o dispositivo. Android 13 ou superior exige autorização explícita de notificações.

No Windows, se `flutter pub get` indicar que plugins precisam de suporte a links simbólicos, configure o Modo de Desenvolvedor conforme a política da sua máquina. Essa exigência é do ambiente de desenvolvimento; não do celular.

### iPhone

O código inclui o tratamento de notificações e a descrição de uso da localização no iOS. Para entregar em iPhones, é necessário configurar a chave APNs no Firebase e habilitar **Push Notifications** e **Background Modes / Remote notifications** no Xcode, com a assinatura/provisionamento da conta Apple. A compilação iOS deve ser validada em um Mac; ela não foi validada no Windows.

## Verificações antes do uso

Testes locais, sem envio de mensagens:

```sh
flutter test test/alerta_geografico_test.dart
npm ci --prefix supabase/tests
npm test --prefix supabase/tests
```

Os testes de integração executam PostgreSQL em memória via PGlite; não usam credenciais nem alteram o banco real.

- Em um projeto de teste, registre dois dispositivos com permissões: um a menos de 20 km e outro a mais de 20 km. Emita um alerta de teste identificado como tal e confirme a entrega apenas ao elegível.
- Confira também a borda exata de 20 km, GPS desabilitado, permissão negada, logout, troca de conta e retorno do segundo plano.
- Confirme que alerta cancelado/resolvido antes do processamento é ignorado e que localizações com mais de 30 minutos não são selecionadas.
- Observe as Edge Function logs e os contadores da fila pelo SQL Editor administrativo. Falhas de configuração não podem ser consideradas como entrega concluída.

Uma entrega marcada `enviado` significa **aceita pelo FCM**, não que o usuário a viu. A fila evita repetir sucessos já registrados e usa reserva por entrega para concorrência. Se ocorrer timeout depois de o FCM aceitar a mensagem, uma tentativa posterior ainda pode duplicá-la. O identificador estável da notificação reduz duplicações, mas não oferece garantia de entrega exatamente uma vez.

## Referências

- [Receber mensagens FCM no Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [Configurar FCM no Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Enviar notificações com Supabase Edge Functions](https://supabase.com/docs/guides/functions/examples/push-notifications)


## Vibração perceptível no Android

O canal `alertas_web_v2` usa três pulsos de 800 ms, separados por 300 ms
(total de 3 segundos). Isso muda a duração, não a potência do motor.
O iOS continua usando o comportamento padrão do sistema.

Para atualizar: instale o novo APK, abra o Prever para criar o canal e depois
publique o `push.mjs` atualizado na função `enviar-alertas-web`.
Não é necessário alterar tabelas, SQL, secrets ou o `index.ts`.
Em APKs antigos o FCM usa o canal padrão anterior como fallback.

Na primeira criação, o novo canal copia a importância, som e vibração habilitada
do canal antigo, preservando inclusive bloqueio e silêncio. Não exclui o antigo.
Configurações posteriores do novo canal são mantidas. O sistema e o usuário
continuam controlando som, vibração e Não Perturbe.

Validação no celular: emitir um alerta identificado como teste dentro de 20 km,
primeiro com o app aberto e depois em segundo plano; confirmar os três pulsos.
