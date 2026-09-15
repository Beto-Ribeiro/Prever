import test from 'node:test'
import assert from 'node:assert/strict'
import { allowedScreens, chatKey, permittedActions, assistantError, boundedContext, summarizeShelter, occurrencePriority, queryTopics } from '../src/backend/ai/assistantPolicy.js'
import { activityIcon, activityTime } from '../src/screens/manager/activityPresentation.js'
const manager = { id: 'a', role: 'shelter_manager', permissions: { admin: true, auditoria: true } }
test('gerente não ganha telas globais nem ações administrativas por JSON de permissões', () => {
  assert.deepEqual(allowedScreens(manager), ['dashboard', 'ocupantes', 'estoque', 'pedidos', 'relatorios', 'perfil'])
  assert.deepEqual(permittedActions([{ type:'navigate', screen:'users' }, { type:'open_user', query:'x' }, { type:'filter_audit' }, { type:'open_dashboard_occurrence' }], manager), [])
  assert.deepEqual(permittedActions([{type:'navigate',screen:'estoque'}],manager), [{type:'navigate',screen:'estoque'}])
  assert.deepEqual(allowedScreens({role:'citizen',permissions:{admin:true}}), [])
  assert.deepEqual(permittedActions([{type:'filter_audit'}],{role:'employee',permissions:{auditoria:false}}), [])
})
test('histórico muda de chave por conta e por redução de permissões', () => {
  assert.notEqual(chatKey(manager), chatKey({...manager,id:'b'}))
  assert.notEqual(chatKey({id:'a',role:'employee',permissions:{auditoria:true}}),chatKey({id:'a',role:'employee',permissions:{auditoria:false}}))
  assert.equal(chatKey(null), null)
})
test('contexto volumoso mantém JSON válido, totais e aviso de redução', () => {
  const input = { total: 100, items:Array.from({length:100},()=>({text:'á'.repeat(300)})) }
  const output = boundedContext(input, 1500)
  assert.ok(output.length <= 1500)
  assert.equal(JSON.parse(output).total, 100)
  assert.equal(JSON.parse(output).contextCoverage.reduced, true)
  assert.equal(input.items.length, 100)
})
test('resumo do abrigo inclui idade, nomes e contatos autorizados', () => {
  const summary = summarizeShelter({ shelter:{abr_nome:'Teste',abr_ocupacao:7,abr_capacidade:20}, residents:[{name:'Ana',age:7,responsible_name:'João',responsible_contact:'11999990000',contact:'Registro antigo',active:true,category:'Criança'},{active:false}], inventory:[{id:'i',name:'Água',quantity:2,target:20,unit:'L'}], requests:[{id:'r',inventory_id:'i',target:10,received:3,priority:'Urgente'},{id:'done',target:4,received:4}], donations:[{donor:'SEGREDO',request_id:'r',quantity:3}], activity:[] }, 'água')
  assert.equal(summary.vacancies,13)
  assert.equal(summary.requests.open,1)
  assert.equal(summary.requests.urgent,1)
  assert.equal(summary.requests.items[0].remaining,7)
  assert.equal(summary.inventory.criticalCount,1)
  assert.equal(summary.residents.active,1)
  assert.equal(summary.residents.items[0].name,'Ana')
  assert.equal(summary.residents.items[0].age,7)
  assert.equal(summary.residents.items[0].responsibleName,'João')
  assert.equal(summary.residents.youngest[0].age,7)
  assert.deepEqual(summarizeShelter(null),{linked:false})
})
test('prioridade não favorece foto/coordenada nem ocorrência encerrada', () => {
  const result = occurrencePriority([{id:'closed',status:'resolved',severity:'critical'},{id:'minor',status:'active',severity:'regular',lat:0,lng:0,photoUrl:'photo'},{id:'critical',status:'active',severity:'critical'}])
  assert.equal(result.recommendedOccurrence.id,'critical')
  assert.match(result.method,/Não é avaliação técnica/)
  assert.equal(occurrencePriority([{status:'resolved'}]).recommendedOccurrence,null)
})
test('erros não expõem configuração ou mensagens do provedor', () => {
  for (const e of ['Configuração Firebase incompleta no .env: apiKey','Vertex AI internal failure','GEMINI_API_KEY missing']) assert.equal(assistantError(e),'O Nimbo está indisponível no momento. Tente novamente em instantes.')
  assert.equal(assistantError('Supabase failure'),'Erro interno no banco de dados.')
  assert.match(assistantError('Failed to fetch'),/conexão/)
  assert.match(assistantError('JWT expired'),/sessão expirou/)
})
test('consulta do perfil não carrega automaticamente fontes globais', () => {
  assert.deepEqual(queryTopics('Explique minhas permissões','perfil'),{dashboard:false,users:false,audit:false,profile:true})
})
test('atividades têm ícones por tipo e tempo legível', () => {
  for (const [text,icon] of [['Ana doou água','gift'],['Cadastro de ocupante atualizado','user-plus'],['Pedido criado','file-plus'],['Estoque crítico','alert-triangle'],['Dados do abrigo atualizados','edit-2']]) assert.equal(activityIcon(text),icon)
  assert.equal(activityTime('2026-09-15T12:00:00Z',Date.parse('2026-09-15T12:12:00Z')),'Há 12 min')
})
