import { useEffect, useMemo, useState } from 'react'
import Card from '../components/Card'
import Modal from '../components/Modal'
import authIcon from '../assets/menu/inativo/lock.svg'
import alertIcon from '../assets/auditoria/alert-triangle.svg'
import recordIcon from '../assets/auditoria/flag.svg'
import userIcon from '../assets/auditoria/user.svg'
import { listAuditEvents } from '../backend/auditoria/auditService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'

const TYPE_CONFIG = {
  auth: { color: 'bg-text-main', light: 'bg-blue-50', text: 'text-text-main', icon: <img src={authIcon} width="20" height="20" alt="lock" /> },
  alert: { color: 'bg-status-critical', light: 'bg-red-50', text: 'text-status-critical', icon: <img src={alertIcon} width="20" height="20" alt="alerta" /> },
  record: { color: 'bg-status-success', light: 'bg-green-50', text: 'text-status-success', icon: <img src={recordIcon} width="20" height="20" alt="registro" /> },
  profile: { color: 'bg-status-regular', light: 'bg-yellow-50', text: 'text-status-regular', icon: <img src={userIcon} width="20" height="20" alt="perfil" /> },
}

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function initials(name) {
  return String(name || 'PREVER')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}


function normalizeAiSearch(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
}

function eventMatchesAiQuery(entry, query) {
  const search = normalizeAiSearch(query)
  if (!search) return false

  const content = normalizeAiSearch([
    entry?.action,
    entry?.actionLabel,
    entry?.actor?.name,
    entry?.actor?.email,
    entry?.target?.name,
    entry?.target?.email,
    entry?.detail,
    entry?.role,
    entry?.searchText,
  ].filter(Boolean).join(' '))

  return content.includes(search) || search.split(/\s+/).filter((part) => part.length >= 3).every((part) => content.includes(part))
}

function PersonBadge({ person, label }) {
  return (
    <div className="flex items-center gap-2 min-w-0">
      {person?.avatar ? (
        <img src={person.avatar} alt={person.name || label} className="h-7 w-7 rounded-full object-cover border border-white/70 bg-white" />
      ) : (
        <div className="h-7 w-7 rounded-full bg-white/80 border border-border-soft flex items-center justify-center text-[0.625rem] font-bold text-slate-500">
          {initials(person?.name)}
        </div>
      )}
      <div className="min-w-0">
        <p className="text-[0.625rem] uppercase tracking-[0.12em] text-slate-400 font-bold leading-none">{label}</p>
        <p className="text-xs text-slate-700 font-bold truncate">{person?.name || '—'}</p>
      </div>
    </div>
  )
}

function AuditDetails({ entry }) {
  if (!entry) return null

  return (
    <div className="space-y-4">
      <div className="rounded-2xl border border-border-soft bg-slate-50 p-4 flex items-start gap-3">
        {entry.actor?.avatar ? (
          <img src={entry.actor.avatar} alt={entry.actor.name || 'Responsável'} className="h-12 w-12 rounded-full object-cover border border-slate-200" />
        ) : (
          <div className="h-12 w-12 rounded-full bg-white border border-slate-200 flex items-center justify-center text-sm font-bold text-slate-500">
            {initials(entry.actor?.name)}
          </div>
        )}
        <div className="min-w-0">
          <h3 className="font-bold text-slate-800">{entry.actionLabel}</h3>
          <p className="text-sm text-slate-500">Responsável: {entry.actor?.name || 'Sistema'}</p>
          {entry.actor?.email && <p className="text-xs text-slate-400 truncate">{entry.actor.email}</p>}
        </div>
      </div>

      {(entry.details || []).map((section) => (
        <div key={section.title} className="rounded-2xl border border-border-soft p-4">
          <p className="text-[0.625rem] font-bold uppercase tracking-[0.16em] text-slate-400 mb-3">{section.title}</p>
          <div className="space-y-2">
            {section.rows.map((row) => (
              <div key={`${section.title}-${row.label}`} className="grid grid-cols-[140px_1fr] gap-3 text-sm">
                <span className="text-slate-500 font-semibold">{row.label}</span>
                <span className="text-slate-700 break-words">{row.value}</span>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export default function Auditoria() {
  const [entries, setEntries] = useState([])
  const [selectedEntry, setSelectedEntry] = useState(null)
  const [filterType, setFilterType] = useState('all')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  async function loadAudit() {
    setLoading(true)
    setError('')

    try {
      const data = await listAuditEvents()
      setEntries(data)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível carregar auditoria. Tente novamente.'))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadAudit()
  }, [])

  const users = useMemo(() => [...new Set(entries.map((entry) => entry.actor?.name).filter(Boolean))], [entries])

  const filtered = useMemo(() => {
    return entries.filter((entry) => {
      if (filterType !== 'all' && entry.type !== filterType) return false
      if (search) {
        const q = search.toLowerCase()
        const content = entry.searchText || [entry.action, entry.actionLabel, entry.actor?.name, entry.target?.name, entry.detail, entry.role].join(' ').toLowerCase()
        if (!content.includes(q)) return false
      }
      return true
    })
  }, [entries, filterType, search])

  const stats = useMemo(() => ({
    total: entries.length,
    alerts: entries.filter((entry) => entry.type === 'alert').length,
    records: entries.filter((entry) => entry.type === 'record' || entry.type === 'profile').length,
    operators: users.length,
  }), [entries, users])

  useEffect(() => {
    window.__SMDN_AI_AUDIT = entries.slice(0, 80).map((entry) => ({
      id: entry.id,
      action: entry.action,
      actionLabel: entry.actionLabel,
      type: entry.type,
      actor: entry.actor,
      target: entry.target,
      detail: entry.detail,
      at: entry.at,
      searchText: entry.searchText,
    }))
    window.dispatchEvent(new CustomEvent('smdn-ai-audit-context-updated', {
      detail: { entries: window.__SMDN_AI_AUDIT },
    }))
  }, [entries])

  useEffect(() => {
    function handleAiAuditAction(event) {
      const action = event?.detail || window.__SMDN_AI_PENDING_AUDIT_ACTION
      if (!action || entries.length === 0) return

      const query = action.query || ''
      const type = action.type || action.filterType || ''

      if (query) setSearch(query)
      if (type && TYPE_CONFIG[type]) setFilterType(type)

      if (action.openFirst !== false && query) {
        const match = entries.find((entry) => eventMatchesAiQuery(entry, query))
        if (match) setSelectedEntry(match)
      }

      window.__SMDN_AI_PENDING_AUDIT_ACTION = null
    }

    window.addEventListener('smdn-ai-audit-action', handleAiAuditAction)
    handleAiAuditAction({ detail: window.__SMDN_AI_PENDING_AUDIT_ACTION })

    return () => {
      window.removeEventListener('smdn-ai-audit-action', handleAiAuditAction)
    }
  }, [entries])

  return (
    <div className="p-8 space-y-6 animate-fade-in">
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: 'TOTAL DE EVENTOS', value: stats.total, color: 'text-text-main' },
          { label: 'ALERTAS', value: stats.alerts, color: 'text-status-critical' },
          { label: 'REGISTROS', value: stats.records, color: 'text-status-success' },
          { label: 'OPERADORES', value: stats.operators, color: 'text-status-severe' },
        ].map((stat) => (
          <Card key={stat.label} className="py-4 text-center">
            <p className="text-label text-slate-500 mb-1">{stat.label}</p>
            <p className={`text-3xl font-bold ${stat.color}`}>{stat.value}</p>
          </Card>
        ))}
      </div>

      {error && <div className="rounded-2xl border border-red-100 bg-red-50 px-5 py-4 text-sm text-red-700">{error}</div>}

      <Card className="p-0 overflow-hidden">
        <div className="px-6 py-4 border-b border-border-soft flex flex-wrap gap-3 items-center">
          <div className="relative flex-1 min-w-[240px]">
            <svg className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" width="16" height="16" viewBox="0 0 16 16" fill="none">
              <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.4" />
              <path d="M10.5 10.5L13.5 13.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
            </svg>
            <input className="input-field pl-9" placeholder="Buscar ação, responsável, afetado ou detalhe..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>

          <select className="select-field w-auto" value={filterType} onChange={(e) => setFilterType(e.target.value)}>
            <option value="all">Todos os Tipos</option>
            <option value="auth">Autenticação</option>
            <option value="alert">Alertas</option>
            <option value="record">Registros</option>
            <option value="profile">Perfil</option>
          </select>

          <button onClick={loadAudit} className="rounded-xl px-4 py-2 text-sm font-semibold bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all">Atualizar</button>
          <span className="text-xs text-slate-400 ml-auto">{filtered.length} evento(s)</span>
        </div>

        <div className="px-6 py-4">
          <div className="relative">
            <div className="absolute left-[19px] top-0 bottom-0 w-px bg-border-soft" />
            <div className="space-y-4">
              {loading ? (
                <p className="text-center text-slate-400 py-8 text-sm">Carregando auditoria...</p>
              ) : filtered.length === 0 ? (
                <p className="text-center text-slate-400 py-8 text-sm">Nenhum evento encontrado.</p>
              ) : (
                filtered.map((entry) => {
                  const cfg = TYPE_CONFIG[entry.type] || TYPE_CONFIG.record
                  return (
                    <button key={entry.id} onClick={() => setSelectedEntry(entry)} className="w-full flex gap-4 relative text-left group">
                      <div className={`w-10 h-10 rounded-full ${cfg.color} flex items-center justify-center flex-shrink-0 z-10 text-base shadow-sm`}>
                        <span>{cfg.icon}</span>
                      </div>
                      <div className={`flex-1 rounded-lg border border-border-soft ${cfg.light} px-4 py-3 group-hover:shadow-card transition-all`}>
                        <div className="flex items-start justify-between gap-2 flex-wrap">
                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className={`text-xs font-bold ${cfg.text}`}>{entry.actionLabel || entry.action}</span>
                              <span className="text-[0.625rem] text-slate-400 bg-white border border-border-soft rounded px-1.5 py-0.5">{entry.role}</span>
                            </div>
                            <div className="mt-2 grid grid-cols-1 md:grid-cols-2 gap-2">
                              <PersonBadge person={entry.actor} label="Responsável" />
                              <PersonBadge person={entry.target} label="Afetado / alvo" />
                            </div>
                          </div>
                          <div className="flex items-center gap-2 text-[0.6875rem] text-slate-400">
                            <span>{formatDate(entry.at)}</span>
                            <span className="font-mono bg-white border border-border-soft rounded px-1.5 py-0.5">{entry.ip}</span>
                          </div>
                        </div>
                        <p className="text-sm text-slate-600 mt-2">{entry.detail}</p>
                      </div>
                    </button>
                  )
                })
              )}
            </div>
          </div>
        </div>
      </Card>

      <Modal isOpen={Boolean(selectedEntry)} onClose={() => setSelectedEntry(null)} title="Detalhes da auditoria" size="lg">
        <AuditDetails entry={selectedEntry} />
      </Modal>
    </div>
  )
}
