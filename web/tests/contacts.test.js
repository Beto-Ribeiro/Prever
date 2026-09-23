import test from 'node:test'
import assert from 'node:assert/strict'
import { summarizeShelter, boundedContext } from '../src/backend/ai/assistantPolicy.js'
import { isProtectedField, captureScreenContext } from '../src/backend/ai/screenContextService.js'
import { buildReport } from '../src/screens/manager/reportExport.js'
const data = { shelter:{abr_nome:'Abrigo',abr_capacidade:100,abr_ocupacao:4},residents:[
  {id:'a',name:'Ana',age:7,active:true,responsible_name:'João',responsible_contact:'11988887777',entered_on:'2026-09-15'},
  {id:'b',name:'Bruno',age:7,active:true},
  {id:'c',name:'Cris',age:0,active:false},
  {id:'d',name:'Dani',age:null,active:true},
  {id:'e',name:'Eva',age:75,active:true},
],inventory:[],requests:[],donations:[{donor:'Pedro',donor_contact:'contato@example.test',quantity:1,created_at:'2026-09-15T10:00:00Z'}],activity:[] }
test('mais novo considera todos os ativos, empates e idade ausente sem virar zero',()=>{
  const s=summarizeShelter(data)
  assert.deepEqual(s.residents.youngest.map(r=>r.name),['Ana','Bruno'])
  assert.equal(s.residents.oldest[0].name,'Eva')
  assert.equal(s.donations.recent[0].contact,'contato@example.test')
})
test('exportação separa nome e contato do responsável e inclui contato doador',()=>{
  const report=buildReport(data,'2026-09-01','2026-09-30','Completo')
  assert.equal(report.Ocupantes[0].Responsável,'João')
  assert.equal(report.Ocupantes[0]['Contato do responsável'],'11988887777')
  assert.equal(report.Doações[0].Contato,'contato@example.test')
})
test('campos secretos continuam excluídos, mesmo com senha revelada como texto',()=>{
  const field=props=>({type:'text',name:'',id:'',labels:[],getAttribute:()=>null,...props})
  assert.equal(isProtectedField(field({type:'password'})),true)
  assert.equal(isProtectedField(field({name:'password',type:'text'})),true)
  assert.equal(isProtectedField(field({labels:[{textContent:'Confirmar senha'}]})),true)
  assert.equal(isProtectedField(field({name:'responsible_contact'})),false)
  assert.equal(isProtectedField(field({name:'age',type:'number'})),false)
})
test('captura recusa tela de outra conta ou navegação desatualizada',()=>{
  const doc={querySelector:()=>({dataset:{nimboAccount:'a',nimboScreen:'ocupantes'}})}
  assert.equal(captureScreenContext({document:doc,accountId:'b',currentScreen:'ocupantes'}),null)
  assert.equal(captureScreenContext({document:doc,accountId:'a',currentScreen:'estoque'}),null)
})
test('idade mínima não depende da página enviada para listas grandes',()=>{
  const big={...data,residents:Array.from({length:200},(_,i)=>({name:`Pessoa ${i}`,age:i===199?1:30,active:true}))}
  const summary=summarizeShelter(big)
  assert.equal(summary.residents.items.length,120)
  assert.equal(summary.residents.youngest[0].name,'Pessoa 199')
  assert.equal(JSON.parse(boundedContext({shelter:summary})).shelter.residents.youngest[0].age,1)
})
