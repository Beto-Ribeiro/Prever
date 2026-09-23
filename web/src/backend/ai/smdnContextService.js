import { supabase } from '../supabase/client.js'
import { getWebAccessForUser } from '../auth/webAccessService.js'
import { loadManagerAssistantData } from '../manager/managerService.js'
import { allowedScreens, queryTopics, summarizeShelter, occurrencePriority } from './assistantPolicy.js'

const text = (value, limit = 350) => String(value || '').slice(0, limit)
async function read(query) {
  const result = await query
  if (result.error) throw result.error
  return result
}
export async function buildSmdnOperationalContext({ question = '', currentScreen = '', accountId, screenContext = null } = {}) {
  const { data, error } = await supabase.auth.getUser()
  if (error || !data?.user || data.user.id !== accountId) throw new Error('Sessão expirada.')
  const access = await getWebAccessForUser(data.user)
  if (!access.allowed) throw new Error('Sessão sem acesso. Faça login novamente.')
  const user = access.user
  const screens = allowedScreens(user)
  const context = {
    generatedAt: new Date().toISOString(), currentScreen,
    currentAskingAccount: { id: user.id, name: user.name, role: user.role },
    allowedScreens: screens,
    currentProfile: { name: user.name, role: user.roleLabel, allowedScreens: screens },
    sources: {},
    screenContext: screens.includes(currentScreen) && screenContext?.accountId === accountId && screenContext?.currentScreen === currentScreen ? screenContext : null,
    limits: 'Cada fonte indica o que foi consultado. Não interpretar falha, fonte não consultada ou amostra parcial como ausência de registros. screenContext contém o texto exibido e os campos de formulários no momento da pergunta, inclusive janelas abertas. Campos não salvos não substituem dados do banco.',
  }
  const jobs = []
  function load(key, label, loader) {
    context.sources[key] = { label, status: 'loading' }
    jobs.push((async () => {
      try { context[key] = await loader(); context.sources[key].status = 'loaded' }
      catch { context.sources[key] = { label, status: 'error', message: 'Erro interno no banco de dados.' } }
    })())
  }
  if (user.role === 'shelter_manager') {
    load('shelter', 'Dados do seu abrigo', async () => summarizeShelter(await loadManagerAssistantData(user.id), question))
  } else {
    const topics = queryTopics(question, currentScreen)
    if (topics.dashboard && screens.includes('dashboard')) load('dashboard', 'Painel operacional', async () => {
      const { data: dashboard } = await read(supabase.rpc('get_dashboard_data'))
      if (!dashboard?.stats) throw new Error('Dados indisponíveis')
      const rows = (dashboard.recentOccurrences || []).map(r => ({ id: r.id, relatoId: r.relatoId, title: text(r.title || r.type, 120), severity: r.severity, status: r.status, city: r.city, reportedAt: r.reportedAt, description: text(r.description) }))
      return { stats: dashboard.stats, priority: occurrencePriority(rows), recentOccurrences: rows.slice(0, 25), loadedOccurrences: rows.length, limit: 25, coverage: 'Ocorrências recentes retornadas pelo painel; não representa todo o histórico.' }
    })
    if (topics.users && screens.includes('users')) load('users', 'Usuários', async () => {
      const { data: profiles, count } = await read(supabase.from('Perfis').select('prf_id,prf_nome,prf_tipo,prf_email_contato,prf_telefone,prf_permissoes', { count: 'exact' }).order('prf_nome').limit(60))
      return { total: count, profiles, limit: 60, coverage: 'Primeiros 60 perfis por nome. Se não encontrar alguém, abra a lista e pesquise; não afirme que a pessoa não existe.' }
    })
    if (topics.audit && screens.includes('auditoria')) {
      load('audit', 'Auditoria', async () => {
        const { data: events } = await read(supabase.from('Audit_Log').select('log_id,action,detail,created_at').order('created_at', { ascending: false }).limit(25))
        return { recentEvents: events.map(e => ({ id: e.log_id, action: e.action, detail: text(e.detail), at: e.created_at })), limit: 25, coverage: 'Últimos 25 eventos administrativos; não é o histórico completo.' }
      })
      load('globalHistory', 'Atividades recentes', async () => {
        const { data: activities } = await read(supabase.from('Atividade_Usuario').select('atu_action,atu_detail,atu_created_at').order('atu_created_at', { ascending: false }).limit(25))
        return { recent: activities.map(a => ({ action: a.atu_action, detail: text(a.atu_detail), at: a.atu_created_at })), limit: 25, coverage: 'Últimas 25 atividades autorizadas; não permite totais de todos os tempos.' }
      })
    }
    if (topics.profile) load('profileActivities', 'Suas atividades recentes', async () => {
      const { data: activities } = await read(supabase.from('Atividade_Usuario').select('atu_action,atu_detail,atu_created_at').eq('atu_user_id', user.id).order('atu_created_at', { ascending: false }).limit(15))
      return { recent: activities.map(a => ({ action: a.atu_action, detail: text(a.atu_detail), at: a.atu_created_at })), limit: 15 }
    })
  }
  await Promise.all(jobs)
  return context
}
