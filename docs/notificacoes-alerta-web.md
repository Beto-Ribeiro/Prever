# Notificações do Alerta_Web

## O que foi implementado

- `Alerta_Web.alw_status = 'disparado'` enfileira um envio na inserção ou na transição de outro status para `disparado`.
- Destino exclusivo da cidade em `alw_cidade`. O aplicativo pede a cidade e a autorização de notificações. É possível mudar/desativar em **Perfil → engrenagem → Cidade dos alertas**.
- Bairro é mostrado no aviso, mas não restringe os destinatários. A cidade é escolhida manualmente; o aplicativo não rastreia deslocamentos em segundo plano.
- `alw_destinatarios` não é usado como filtro nem alterado. FCM confirma aceitação do envio, não quantas pessoas receberam ou leram.
- Android: canal de alta importância, som, vibração e banner quando permitido pelo sistema. Com o app aberto, cria uma notificação local; em segundo plano/encerrado normalmente, o sistema exibe o payload FCM.
- iOS: push com som e banner, sujeito às permissões/APNs. Tocar no aviso abre seus detalhes públicos, inclusive quando o app estava encerrado.
- A fila evita reenviar o mesmo `alw_id` por edições/repetições de status. Há até seis tentativas, lease de três minutos e retomada a cada minuto. Não retroenvia registros existentes quando a migration é aplicada.
- Validade da tentativa e da entrega: até uma hora após enfileirar. Alerta cancelado/removido é descartado antes da próxima tentativa; uma notificação já aceita pelo FCM não pode ser retirada de todos os aparelhos.

## Ainda necessário para ativar em produção

**Os arquivos locais não publicam a função nem alteram o banco remoto.** As etapas abaixo exigem acesso administrativo ao projeto Supabase e ao projeto Firebase `chatbot-ia---smdn`.

1. No Firebase/Google Cloud, habilitar a **Firebase Cloud Messaging API (HTTP v1)**. Criar uma conta de serviço com a permissão de envio FCM (por exemplo, papel Firebase Cloud Messaging API Admin). Guardar seu JSON **fora do repositório**. Não usar a chave pública do Firebase como credencial de envio.
2. Criar um segredo aleatório com pelo menos 32 caracteres para `PUSH_DISPATCH_SECRET` (preferencialmente 32 bytes aleatórios em hexadecimal).
3. Preparar, fora do repositório, um arquivo de segredos para a função. `FIREBASE_SERVICE_ACCOUNT_JSON` deve conter o JSON completo em uma única linha; os `\n` dentro da chave privada permanecem escapados:

   ```dotenv
   PUSH_DISPATCH_SECRET=SEU_SEGREDO_ALEATORIO
   FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"chatbot-ia---smdn","private_key":"...","client_email":"..."}
   ```

4. Instalar/autenticar a CLI Supabase e executar na raiz do projeto (substituir o caminho do arquivo):

   ```powershell
   npx supabase login
   npx supabase secrets set --project-ref robfgvtnoooivihlnomr --env-file C:\CAMINHO_PRIVADO\prever-push.env
   npx supabase functions deploy alerta-web-push --project-ref robfgvtnoooivihlnomr --no-verify-jwt
   ```

   `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são disponibilizadas automaticamente pelo ambiente da função. A função exige `x-dispatch-secret`; ignorar JWT aqui não significa aceitar chamadas públicas sem autenticação. Não enviar segredos pelo aplicativo ou pela página web.

5. Aplicar **somente** `supabase/migrations/20261020_alerta_web_push.sql` no SQL Editor do projeto correto. Ele usa `pg_net`, `pg_cron` e o Vault do Supabase. Conferir antes que a tabela possui as colunas informadas e que **somente operadores autorizados podem gravar/publicar em Alerta_Web** nas políticas RLS existentes. Esta migration não modifica as permissões dessa tabela.

6. No Vault, criar dois segredos:

   - `push_dispatch_url`: `https://robfgvtnoooivihlnomr.supabase.co/functions/v1/alerta-web-push`
   - `push_dispatch_secret`: exatamente o mesmo valor configurado em `PUSH_DISPATCH_SECRET`.

   Pode usar a interface do Vault ou SQL, sem versionar o segredo:

   ```sql
   select vault.create_secret('https://robfgvtnoooivihlnomr.supabase.co/functions/v1/alerta-web-push', 'push_dispatch_url');
   select vault.create_secret('MESMO_SEGREDO_DA_FUNCAO', 'push_dispatch_secret');
   ```

   Se esses nomes já existem, atualizar os segredos em vez de criar duplicatas. O trigger faz o primeiro pedido imediatamente após o commit. O cron retoma filas pendentes.

7. Executar `flutter pub get`, reconstruir e instalar o aplicativo. Abrir uma vez, escolher a cidade e aceitar notificações. Não basta hot reload para instalar plugins/permissões nativas. O `.env` local é obrigatório pelo aplicativo; o arquivo ignorado pelo Git foi recriado com os valores públicos de Supabase já existentes em `main.dart`, pois estava ausente.

## Configuração Android

O projeto inclui POST_NOTIFICATIONS, INTERNET, plugin Google Services, ícone de notificação, canal de alta importância e desugaring necessário. `google-services.json` já corresponde a `com.example.branch1`.

O usuário deve permitir **Alertas Prever** nas configurações Android, inclusive exibição flutuante/som caso o fabricante tenha opções separadas. O canal usa o ID `prever_alertas_urgentes_v1`; alterações futuras de importância de um canal já criado dependem das configurações do usuário ou de um novo ID.

Se o Flutter reclamar de symlinks no Windows, habilitar o Modo de Desenvolvedor do Windows. Emulador precisa ter Google Play Services. Aparelhos sem serviços Google não recebem este canal FCM.

## Configuração iOS (requer Mac e conta Apple Developer)

Foram adicionados `UIBackgroundModes = remote-notification`, entitlements APNs e assinatura de ambiente de desenvolvimento/produção por configuração. Abrir `ios/Runner.xcworkspace`, confirmar **Push Notifications** e **Background Modes → Remote notifications** no target Runner e selecionar o time de assinatura.

Enviar a chave APNs `.p8` ao Firebase → configurações do projeto → Cloud Messaging para o aplicativo iOS correto. Sem essa associação/assinatura, a configuração Dart não habilita pushes em iPhones.

## Cidades e privacidade

Exemplo: `São José dos Campos`, `SAO JOSE DOS CAMPOS` e a mesma palavra com acentos Unicode decompostos geram `prever_cidade_sao-jose-dos-campos`. `Jacareí` gera outro destino. A escolha deve usar o nome completo que o painel grava em `alw_cidade`; abreviações diferentes não são inferidas.

Como o schema informado não tem UF, cidades homônimas precisam ser distinguidas consistentemente no próprio valor, por exemplo `Santa Helena - PR`, tanto no painel quanto na escolha do aplicativo.

Topics FCM são apropriados para **alertas públicos**, não para informações confidenciais ou controle de acesso. Não são enviados `alw_metadata`, operador, contagem de destinatários ou outros dados privados. A seleção de cidade é deste aparelho e continua após logout porque os avisos são públicos; pode ser desativada nas configurações.

Uma mudança de cidade precisa de internet para remover a inscrição anterior. Avisos antigos já aceitos/em trânsito podem aparecer; não é possível revogá-los no sistema remotamente. Dentro do app, avisos de outra cidade não são mostrados/abertos.

## Validação após publicar (usar ambiente de teste)

1. Em dois celulares, escolher cidades diferentes e autorizar notificações.
2. Publicar pelo painel um alerta de teste com `alw_status='disparado'` e a cidade do primeiro aparelho. Confirmar que só ele recebe.
3. Repetir com aplicativo aberto, em segundo plano e encerrado normalmente; tocar no aviso e verificar título, descrição, severidade e local.
4. Editar um campo do mesmo alerta sem mudar o ID: não deve gerar novo push. Um novo comunicado exige outro `alw_id`.
5. Testar permissão negada, cidade alterada, desativação e rede indisponível.
6. Consultar a fila:

   ```sql
   select alerta_id, status, tentativas, criado_em, enviado_em, ultimo_erro
   from public.push_alerta_fila order by id desc limit 50;
   ```

   `enviado` = aceito pelo FCM, não comprovante de leitura. `falhou` = examinar erro e logs. `expirado` = não enviar um alerta antigo. Dados de operador/credenciais não são registrados nos logs.

Se FCM aceitar e a confirmação no banco falhar, uma nova tentativa pode repetir a notificação (não existe garantia de exatamente uma entrega entre os dois serviços). Android substitui avisos do mesmo ID/tag; iOS pode apresentar mais de um. Configure retenção/limpeza de registros antigos da fila conforme a operação do projeto.

Testes locais:

```powershell
flutter test --no-pub test/alertas_notificacoes_test.dart
node --test supabase/functions/alerta-web-push/payload.test.ts supabase/functions/alerta-web-push/worker.test.ts
npm install --prefix build/push-validation --no-save --package-lock=false @electric-sql/pglite
node --test supabase/tests/push_fila.test.mjs
```

## Limites do sistema operacional

Este é um push do aplicativo, não Cell Broadcast oficial da Defesa Civil. Não força tela cheia, não ignora Não Perturbe e não exige permissão para desenhar sobre outros aplicativos. O banner depende da autorização e das configurações do sistema. Internet, bateria, modo foco e encerramento forçado podem atrasar/bloquear entrega. A entrega imediata não é garantida.

O teste PostgreSQL usa um banco em memória e substitui somente pg_net/cron/Vault por interfaces locais: valida gatilhos, fila, permissões e retries, sem realizar envios externos. Não substitui a validação do deploy no Supabase e nos aparelhos.

Referências oficiais: [Firebase Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [recebimento](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [prioridade Android](https://firebase.google.com/docs/cloud-messaging/android-message-priority), [notificações Android](https://developer.android.com/develop/ui/views/notifications), [pg_net/Supabase](https://supabase.com/docs/guides/database/webhooks).
