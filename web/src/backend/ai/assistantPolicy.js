import { canAccessWeb, normalizeRole } from '../../utils/webRoles.js'

export const LEGACY_CHAT_KEY = 'smdn-nimbo-chat-unico-browser-v1'
export function allowedScreens(user) {
  const role = normalizeRole(user?.role)
  if (!canAccessWeb(role)) return []
  if (role === 'shelter_manager') return ['dashboard', 'ocupantes', 'estoque', 'pedidos', 'relatorios', 'perfil']
  return ['dashboard', 'reportar', 'ocorrencias', 'abrigos', 'relatorios', 'auditoria', 'perfil', 'admin', 'users'].filter(screen => {
    if (screen === 'perfil') return true
    if (['admin', 'users'].includes(screen)) return role === 'admin'
    return Boolean(user?.permissions?.[screen === 'abrigos' ? 'ocorrencias' : screen])
  })
}
export function chatKey(user) {
  return user?.id ? `prever-nimbo-v3:${user.id}:${normalizeRole(user.role)}:${allowedScreens(user).join(',')}` : null
}
export function permittedActions(actions, user) {
  const screens = allowedScreens(user)
  return (Array.isArray(actions) ? actions : []).filter(action => {
    if (!action || typeof action !== 'object') return false
    if (action.type === 'navigate') return screens.includes(action.screen)
    if (normalizeRole(user?.role) === 'shelter_manager') return false
    if (['open_user', 'filter_users'].includes(action.type)) return screens.includes('users')
    if (action.type === 'filter_audit') return screens.includes('auditoria')
    return action.type === 'open_dashboard_occurrence' && screens.includes('dashboard')
  }).slice(0, 1)
}
export function assistantError(error) {
  const text = `${error?.code || ''} ${error?.message || error || ''}`.toLowerCase()
  if (/sessão|session|jwt|login/.test(text)) return 'Sua sessão expirou. Entre novamente para continuar.'
  if (/network|fetch|conexão|timeout/.test(text)) return 'Falha de conexão. Verifique sua internet e tente novamente.'
  if (/429|quota|resource-exhausted|muitas solicitações/.test(text)) return 'O Nimbo está recebendo muitas solicitações. Tente novamente em instantes.'
  if (/database|postgres|supabase|pgrst|banco de dados/.test(text)) return 'Erro interno no banco de dados.'
  return 'O Nimbo está indisponível no momento. Tente novamente em instantes.'
}
export function queryTopics(question, screen) {
  const q = String(question).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  return {
    dashboard: ['dashboard', 'ocorrencias', 'relatorios', 'reportar'].includes(screen) || /ocorrencia|alerta|risco|vitima|prioridade|mapa/.test(q),
    users: ['users', 'admin'].includes(screen) || /usuario|administrador|instituicao|quem e |quem sao /.test(q),
    audit: screen === 'auditoria' || /auditoria|logs|historico global|quem fez|todos os tempos/.test(q),
    profile: screen === 'perfil' || /minh[ao]s? (perfil|conta|atividades|permissoes)/.test(q),
  }
}
// Bound arrays before serialization, preserving valid JSON and explicit coverage.
export function boundedContext(value, budget = 60000) {
  const copy = JSON.parse(JSON.stringify(value || {}))
  copy.contextCoverage = { reduced: false, note: 'Listas podem ser parciais; consulte os totais e limites de cada fonte.' }
  const arrays = []
  function visit(node) {
    if (!node || typeof node !== 'object') return
    if (Array.isArray(node)) arrays.push(node)
    Object.values(node).forEach(visit)
  }
  visit(copy)
  while (JSON.stringify(copy).length > budget) {
    const largest = arrays.filter(a => a.length).sort((a, b) => JSON.stringify(b).length - JSON.stringify(a).length)[0]
    if (!largest) break
    largest.pop()
    copy.contextCoverage.reduced = true
  }
  if (JSON.stringify(copy).length > budget) return JSON.stringify({ generatedAt: copy.generatedAt, sources: copy.sources, contextCoverage: { reduced: true, note: 'Contexto excedeu o limite. Peça uma consulta mais específica; não deduza números.' } })
  return JSON.stringify(copy)
}
export function summarizeShelter(data, question = '') {
  if (!data) return { linked: false }
  const s = data.shelter
  const active = data.residents.filter(r => r.active)
  const inventory = data.inventory.map(i => ({ category: i.category, id: i.id, name: i.name, quantity: Number(i.quantity), target: Number(i.target), unit: i.unit, critical: Number(i.quantity) < Number(i.target) * .25 }))
  const requests = data.requests.map(r => ({ createdAt: r.created_at, id: r.id, item: inventory.find(i => i.id === r.inventory_id)?.name || 'Item não informado', target: Number(r.target), received: Number(r.received), remaining: Math.max(0, Number(r.target) - Number(r.received)), priority: r.priority }))
  const norm = v => String(v || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  const tokens = norm(question).split(/\W+/).filter(t => t.length > 2)
  const relevant = item => tokens.some(t => norm(item.name || item.item).includes(t))
  const residents = data.residents.map(r => ({ id: r.id, name: r.name, age: r.age === null || r.age === undefined || r.age === '' ? null : Number(r.age), category: r.category, responsibleName: r.responsible_name || '', responsibleContact: r.responsible_contact || '', legacyResponsibleContact: r.contact || '', enteredOn: r.entered_on, active: r.active }))
  const aged = residents.filter(r => r.active && Number.isFinite(r.age))
  const ages = aged.map(r => r.age)
  const youngestAge = ages.length ? Math.min(...ages) : null
  const oldestAge = ages.length ? Math.max(...ages) : null
  const relevantPerson = r => tokens.some(t => norm(JSON.stringify(r)).includes(t))
  return {
    linked: true, details: { address: s.abr_bairro, coordinator: s.abr_coordenador, coordinatorContact: s.abr_coordenador_contato, phone: s.abr_telefone_principal, secondaryPhone: s.abr_telefone_secundario, type: s.abr_tipo, accessibility: s.abr_acessibilidade, acceptsPets: s.abr_aceita_pets, notes: s.abr_detalhes }, name: s.abr_nome, city: s.abr_cidade,
    occupancy: Number(s.abr_ocupacao), capacity: Number(s.abr_capacidade), vacancies: Math.max(0, Number(s.abr_capacidade) - Number(s.abr_ocupacao)),
    residents: { total: residents.length, items: residents.sort((a,b) => Number(relevantPerson(b)) - Number(relevantPerson(a)) || Number(b.active) - Number(a.active)).slice(0, 120), limit: 120, youngest: aged.filter(r => r.age === youngestAge), oldest: aged.filter(r => r.age === oldestAge), active: active.length, departed: data.residents.length - active.length, categories: active.reduce((acc, r) => ({ ...acc, [r.category]: (acc[r.category] || 0) + 1 }), {}) },
    inventory: { total: inventory.length, criticalCount: inventory.filter(i => i.critical).length, items: inventory.sort((a, b) => Number(relevant(b)) - Number(relevant(a)) || Number(b.critical) - Number(a.critical)).slice(0, 35), limit: 35 },
    requests: { total: requests.length, open: requests.filter(r => r.remaining > 0).length, urgent: requests.filter(r => r.remaining > 0 && r.priority === 'Urgente').length, items: requests.sort((a, b) => Number(relevant(b)) - Number(relevant(a)) || Number(b.remaining > 0) - Number(a.remaining > 0) || Number(b.priority === 'Urgente') - Number(a.priority === 'Urgente')).slice(0, 30), limit: 30 },
    donations: { total: data.donations.length, recent: data.donations.slice(-15).reverse().map(d => ({ donor: d.donor, contact: d.donor_contact || '', at: d.created_at, quantity: Number(d.quantity), item: requests.find(r => r.id === d.request_id)?.item })), limit: 15 },
    activities: (data.activity || []).slice(-25).reverse().map(a => ({ detail: a.detail, at: a.created_at })),
    note: 'Dados atuais do abrigo vinculado. Os registros individuais dos ocupantes incluem idade e contatos autorizados. youngest/oldest consideram todos os ativos; items pode ser parcial conforme limit. Use screenContext para a lista filtrada exibida. Doações de itens/unidades diferentes não devem ser somadas. Relatórios por período são gerados na tela Relatórios.',
  }
}
export function occurrencePriority(rows = []) {
  const norm = value => String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  const severity = value => ({ critical: 3, critico: 3, critica: 3, severe: 2, grave: 2, severo: 2, regular: 1, moderado: 1 })[norm(value)] || 0
  const candidates = rows.filter(r => ['active', 'ativo', 'ativa', 'monitoring', 'em monitoramento'].includes(norm(r.status)))
  const recommended = [...candidates].sort((a,b) => severity(b.severity) - severity(a.severity) || (Date.parse(b.reportedAt) || 0) - (Date.parse(a.reportedAt) || 0))[0] || null
  return { recommendedOccurrence: recommended, reason: recommended ? `Sugestão entre os registros carregados, por severidade informada (${recommended.severity || 'não informada'}) e recência. Confirme a situação antes de decidir.` : 'Não há ocorrência ativa ou em monitoramento entre os registros carregados.', method: 'Severidade informada; desempate pela data mais recente. Não é avaliação técnica de risco e não usa fotos/localização como peso.', actionSuggestion: recommended ? { type: 'open_dashboard_occurrence', id: recommended.id, relatoId: recommended.relatoId, mapMode: 'heat', zoom: 16, openPopup: true } : null }
}
