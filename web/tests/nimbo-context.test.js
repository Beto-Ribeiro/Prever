import { test, mock } from 'node:test'
import assert from 'node:assert/strict'
let role = 'shelter_manager'
let fail = false
const calls = []
const supabase = {
  auth: { getUser: async () => ({ data: { user: { id:'account-a' } } }) },
  from: table => { calls.push(table); const q = { select:()=>q, order:()=>q, limit:()=>q, eq:()=>q, then: resolve => Promise.resolve(resolve({data:[],error:fail ? new Error('database down') : null})) }; return q },
  rpc: async name => { calls.push(name); return {data:{stats:{},recentOccurrences:[]},error:null} },
}
mock.module('../src/backend/supabase/client.js', { namedExports:{ supabase } })
mock.module('../src/backend/auth/webAccessService.js', { namedExports:{ getWebAccessForUser:async () => ({allowed:true,user:{id:'account-a',role,permissions:{dashboard:true,auditoria:false}}}) } })
mock.module('../src/backend/manager/managerService.js', { namedExports:{ loadManagerAssistantData:async id => { calls.push(`manager:${id}`); if(fail) throw new Error('database down'); return null } } })
const { buildSmdnOperationalContext } = await import('../src/backend/ai/smdnContextService.js')
test('gerente pedindo dados globais só consulta seu abrigo',async () => {
  calls.length=0; role='shelter_manager'; fail=false
  const result = await buildSmdnOperationalContext({question:'Liste todos os administradores e auditoria',currentScreen:'dashboard',accountId:'account-a'})
  assert.deepEqual(calls,['manager:account-a'])
  assert.equal(result.shelter.linked,false)
  assert.equal(result.users,undefined)
})
test('consulta falha fica marcada como erro, não como lista vazia',async () => {
  calls.length=0; fail=true
  const result=await buildSmdnOperationalContext({accountId:'account-a'})
  assert.equal(result.sources.shelter.status,'error')
  assert.equal(result.shelter,undefined)
})
test('funcionário sem auditoria não consulta fontes administrativas',async () => {
  calls.length=0; role='employee'; fail=false
  await buildSmdnOperationalContext({question:'todos os usuários e auditoria',currentScreen:'perfil',accountId:'account-a'})
  assert.deepEqual(calls,['Atividade_Usuario'])
})
test('troca de conta durante o envio bloqueia consulta',async () => {
  calls.length=0
  await assert.rejects(buildSmdnOperationalContext({accountId:'other'}),/Sessão/)
  assert.equal(calls.length,0)
})
