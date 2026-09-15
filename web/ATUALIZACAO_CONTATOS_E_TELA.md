# PREVER — contatos separados e contexto da tela no Nimbo

Extraia este ZIP dentro de `web`, substituindo os arquivos e preservando as subpastas. Ele complementa o pacote anterior `Prever-nimbo-e-relatorios-web.zip`. Não há novas dependências. O banco SMDN já foi atualizado; `supabase/contacts_setup.sql` documenta as alterações aplicadas.

## Cadastros e relatórios

- Ocupantes: campos separados para nome do responsável e contato do responsável, na edição, cadastro, busca, tabela e relatórios PDF/Excel.
- O campo antigo misturava nome e contato. Seu conteúdo foi preservado sem alterações e aparece identificado como registro anterior para conferência. Não houve separação automática nem exclusão de informações.
- Doações: novo campo de contato do doador (telefone ou e-mail). Ele aparece no histórico de doações e nos relatórios.
- Abrigos: nome do coordenador/responsável e contato próprio são separados no cadastro geral, na edição do gerente e na exibição dos dados. O telefone do abrigo continua independente.
- Contatos são opcionais; se desconhecidos, aparecem como não informados.

## Nimbo

Esta versão substitui a restrição a contagens da atualização anterior. Os registros autorizados do abrigo incluem nomes, idades, categorias, responsáveis, contatos, entradas/saídas, doadores e suas informações de contato.

O Nimbo também recebe o texto da tela atual e os valores dos formulários e janelas abertas quando a pergunta é enviada. Isso permite explicar campos, considerar filtros e acompanhar o que está sendo preenchido. Valores ainda não salvos são identificados como tal.

O acesso continua limitado à conta e às permissões atuais. Senhas, tokens, controles ocultos, armazenamento do navegador e o próprio chat não entram na captura da tela. Não se trata de visão por imagem: fotos e detalhes visuais não são interpretados por esse mecanismo.

Listas grandes podem ser reduzidas para caber no contexto, com limites informados. A identificação dos ocupantes mais novos e mais velhos considera todos os ativos carregados do abrigo, incluindo empates e ignorando idades não informadas. Perguntas sobre a lista filtrada na tela devem usar o contexto dessa tela.

A nova versão inicia uma conversa separada para não reaproveitar as antigas respostas que negavam acesso às idades. As informações utilizadas na conversa são enviadas ao serviço de IA do Google já configurado no projeto.

## Validação

- Compilação de produção passou.
- 17 testes passaram, incluindo idade mínima, empates, contatos nos relatórios, proteção de campos secretos e isolamento por conta.
- No Supabase, um teste transacional verificou cadastro com nome/contato separados, doação com contato e atualização de estoque, edição do responsável pelo abrigo e bloqueio de outra conta. Todos os registros temporários foram revertidos.
- ESLint: sem erros; permanecem dois avisos anteriores sobre dependências de hooks.
- Não foi validada uma conversa real com o Gemini nem a aparência no navegador nesta atualização. Após instalar, pergunte “Quem é o ocupante mais novo?” e confira a resposta com a tabela. Teste também a pergunta com um formulário aberto.

Para os testes locais: `node --experimental-test-module-mocks --test tests/*.test.js` em uma versão compatível do Node. Para compilar: `npm run build`.
