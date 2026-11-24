import test from 'node:test'
import assert from 'node:assert/strict'
import { normalizeRole, canAccessWeb, canAccessAdmin } from '../src/utils/webRoles.js'
import { toFriendlyMessage } from '../src/utils/friendlyMessages.js'
import { buildReport } from '../src/screens/manager/reportExport.js'
import { buildXlsxBytes, sanitizeSpreadsheetText } from '../src/utils/xlsxWriter.js'

test('gerente entra no web sem receber administração; perfis canônicos preservados', () => {
  for (const role of ['gerente_abrigo', 'Gerente de Abrigo', 'shelter_manager']) {
    assert.equal(normalizeRole(role), 'shelter_manager')
    assert.equal(canAccessWeb(role), true)
    assert.equal(canAccessAdmin(role), false)
  }
  for (const role of ['employee', 'institution', 'admin']) assert.equal(canAccessWeb(role), true)
  for (const role of ['citizen', 'pendente', '', 'unknown']) assert.equal(canAccessWeb(role), false)
})

test('erros técnicos têm mensagem acessível sem perder orientação de login ou permissão', () => {
  assert.equal(toFriendlyMessage('Supabase não está linkado'), 'Erro interno no banco de dados.')
  assert.equal(toFriendlyMessage({ code: '42P01', message: 'relation missing' }), 'Erro interno no banco de dados.')
  assert.match(toFriendlyMessage({ code: '42501', message: 'permission denied' }), /Acesso não autorizado/)
  assert.match(toFriendlyMessage('Invalid login credentials'), /E-mail ou senha incorretos/)
  assert.match(toFriendlyMessage('Failed to fetch'), /Verifique sua internet/)
  assert.equal(toFriendlyMessage('stack trace internal failure'), 'Não foi possível concluir a ação agora. Tente novamente em instantes.')
})

test('relatório inclui limites do período, mantém estoque atual e exclui registros externos', () => {
  const data = {
    residents: [{ name:'Primeiro', entered_on:'2026-09-01', active:true }, { name:'Último', entered_on:'2026-09-30', active:false }, { name:'Anterior', entered_on:'2026-08-31' }],
    inventory:[{id:'i',name:'Água',quantity:4,target:10,unit:'L'}],
    requests:[{id:'r',inventory_id:'i',created_at:'2026-09-30T23:59:59Z',received:4,target:10}],
    donations:[{request_id:'r',created_at:'2026-09-01T00:00:00Z',donor:'Teste',quantity:4}], activity:[],
  }
  const result = buildReport(data,'2026-09-01','2026-09-30','Completo')
  assert.equal(result.Ocupantes.length,2)
  assert.equal(result.Pedidos.length,1)
  assert.equal(result.Doações[0].Recurso,'Água')
  assert.equal(result.Estoque[0].Quantidade,4)
  assert.deepEqual(Object.keys(buildReport(data,'2026-09-01','2026-09-30','Estoque')), ['Estoque'])
  assert.throws(()=>buildReport(data,'2026-10-01','2026-09-30','Completo'),/período válido/)
  assert.throws(()=>buildReport(data,'','2026-09-30','Completo'),/período válido/)
})

test('gerador .xlsx nativo produz arquivo PKZIP/OpenXML válido e bloqueia Formula Injection', () => {
  assert.equal(sanitizeSpreadsheetText('=HYPERLINK("http://evil")'), '\'=HYPERLINK("http://evil")')
  assert.equal(sanitizeSpreadsheetText('+1+1'), '\'+1+1')
  assert.equal(sanitizeSpreadsheetText('Água Potável'), 'Água Potável')

  const bytes = buildXlsxBytes({
    Estoque: [{ Recurso: 'Água', Quantidade: 25, Nota: '=CMD()' }],
    Vazia: [],
  })

  // Assinatura PK\x03\x04
  assert.equal(bytes[0], 0x50)
  assert.equal(bytes[1], 0x4b)
  assert.equal(bytes[2], 0x03)
  assert.equal(bytes[3], 0x04)

  const rawText = new TextDecoder().decode(bytes)
  assert.match(rawText, /xl\/workbook\.xml/)
  assert.match(rawText, /xl\/worksheets\/sheet1\.xml/)
  assert.match(rawText, /&apos;=CMD\(\)/)
})
