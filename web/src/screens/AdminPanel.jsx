import { listShelters } from '../backend/abrigos/shelterService.js'
import { useEffect, useMemo, useState } from 'react'
import Modal from '../components/Modal.jsx'
import { supabase } from '../backend/supabase/client.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import {
  approveAccessRequest,
  approveProfileChangeRequest,
  listAccessRequests,
  listAuditLogs,
  listProfileChangeRequests,
  listWebProfiles,
  rejectAccessRequest,
  rejectProfileChangeRequest,
} from '../backend/admin/adminService.js'

const STATUS_LABEL = {
  pendente: 'Pendente',
  aprovado: 'Aprovado',
  recusado: 'Recusado',
  banido: 'Banido',
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

function StatusPill({ status }) {
  const styles = {
    pendente: 'bg-yellow-50 text-yellow-700 border-yellow-100',
    aprovado: 'bg-green-50 text-green-700 border-green-100',
    recusado: 'bg-red-50 text-red-700 border-red-100',
    banido: 'bg-slate-100 text-slate-700 border-slate-200',
  }

  return (
    <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-semibold ${styles[status] || styles.pendente}`}>
      {STATUS_LABEL[status] || status || 'Pendente'}
    </span>
  )
}

function ChangeList({ changes, currentProfile, status }) {
  const entries = Object.entries(changes || {})
  if (entries.length === 0) return <span className="text-slate-400">—</span>

  return (
    <div className="space-y-2 max-w-xl">
      {entries.map(([key, change]) => {
        if (key === 'avatar') {
          const currentAvatar = currentProfile?.prf_avatar_url
          const nextAvatar = change.value || change.newValue || change.new
          const approved = status === 'aprovado'
          const rejected = status === 'recusado'

          return (
            <div key={key} className="text-xs text-slate-600 leading-relaxed">
              <span className="font-bold text-slate-700">{change.label || 'Foto do perfil'}:</span>{' '}
              {approved ? (
                <span className="inline-flex items-center gap-2 align-middle">
                  <span className="font-semibold text-slate-700">alterada para</span>
                  {nextAvatar ? <img src={nextAvatar} alt="Nova foto aprovada" className="h-8 w-8 rounded-full border border-border-soft object-cover" /> : <span className="text-slate-400">nova foto</span>}
                </span>
              ) : rejected ? (
                <span className="inline-flex items-center gap-2 align-middle">
                  {currentAvatar ? <img src={currentAvatar} alt="Foto atual mantida" className="h-8 w-8 rounded-full border border-border-soft object-cover" /> : <span className="text-slate-400">foto atual</span>}
                  <span className="font-semibold text-red-300">solicitação recusada</span>
                </span>
              ) : (
                <span className="inline-flex items-center gap-2 align-middle">
                  <span className="text-slate-400">Atual</span>
                  {currentAvatar ? <img src={currentAvatar} alt="Foto atual" className="h-8 w-8 rounded-full border border-border-soft object-cover" /> : <span className="text-slate-400">sem foto</span>}
                  <span className="text-slate-400">→</span>
                  <span className="text-slate-400">Solicitada</span>
                  {nextAvatar ? <img src={nextAvatar} alt="Nova foto solicitada" className="h-8 w-8 rounded-full border border-border-soft object-cover" /> : <span className="text-slate-400">sem foto</span>}
                </span>
              )}
            </div>
          )
        }

        return (
          <div key={key} className="text-xs text-slate-600 leading-relaxed">
            <span className="font-bold text-slate-700">{change.label || key}:</span>{' '}
            <span className="text-slate-400">{change.old || '—'}</span>{' '}
            <span>→</span>{' '}
            <span className="font-semibold text-slate-700">{change.new || '—'}</span>
            {change.manualOnly && (
              <span className="ml-2 rounded-full bg-orange-50 px-2 py-0.5 text-[0.625rem] font-bold text-orange-700 border border-orange-100">
                manual
              </span>
            )}
          </div>
        )
      })}
    </div>
  )
}

export default function AdminPanel({ initialTab = 'all' }) {
  const [approval, setApproval] = useState(null)
  const [approvalRole, setApprovalRole] = useState('funcionario')
  const [approvalShelter, setApprovalShelter] = useState('')
  const [shelters, setShelters] = useState([])
  const [activeTab, setActiveTab] = useState(initialTab)
  const [requests, setRequests] = useState([])
  const [profileRequests, setProfileRequests] = useState([])
  const [profiles, setProfiles] = useState([])
  const [logs, setLogs] = useState([])
  const [missingSchema, setMissingSchema] = useState(false)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState('')
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [rejectDialog, setRejectDialog] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [passwordDialog, setPasswordDialog] = useState(null)
  const [adminPassword, setAdminPassword] = useState('')
  const [adminPasswordConfirm, setAdminPasswordConfirm] = useState('')

  async function loadAdminData(options = {}) {
    const preserveScroll = Boolean(options.preserveScroll)
    const scrollEl = document.querySelector('main')
    const previousScrollTop = preserveScroll ? scrollEl?.scrollTop : null

    if (!preserveScroll) setLoading(true)
    setError('')
    if (!preserveScroll) setMessage('')

    try {
      const [requestsResult, profileRequestsResult, profilesResult, logsResult] = await Promise.all([
        listAccessRequests(),
        listProfileChangeRequests(),
        listWebProfiles(),
        listAuditLogs(),
      ])

      setRequests(requestsResult.data)
      setProfileRequests(profileRequestsResult.data)
      setProfiles(profilesResult.data)
      setLogs(logsResult.data)
      setMissingSchema(Boolean(requestsResult.missingSchema || profileRequestsResult.missingSchema || logsResult.missingSchema))
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível carregar o painel administrativo. Tente novamente.'))
    } finally {
      if (!preserveScroll) setLoading(false)
      if (preserveScroll && scrollEl && typeof previousScrollTop === 'number') {
        requestAnimationFrame(() => {
          scrollEl.scrollTop = previousScrollTop
        })
      }
    }
  }

  useEffect(() => {
    loadAdminData()
  }, [])

  useEffect(() => {
    const channel = supabase
      .channel('admin-panel-live-preserve-scroll')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'Solicitacao_Acesso_Web' }, () => loadAdminData({ preserveScroll: true }))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'Solicitacao_Alteracao_Perfil' }, () => loadAdminData({ preserveScroll: true }))
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  useEffect(() => {
    setActiveTab(initialTab)
  }, [initialTab])

  const stats = useMemo(() => {
    const allRequests = [...requests.map((item) => item.saw_status), ...profileRequests.map((item) => item.sap_status)]
    const pending = allRequests.filter((status) => status === 'pendente').length
    const approved = allRequests.filter((status) => status === 'aprovado').length
    const rejected = allRequests.filter((status) => status === 'recusado').length

    return { pending, approved, rejected, profiles: profiles.length, logs: logs.length }
  }, [requests, profileRequests, profiles, logs])

  const profileMap = useMemo(() => {
    return new Map(profiles.map((profile) => [profile.prf_id, profile]))
  }, [profiles])

  const allSolicitations = useMemo(() => {
    const accessItems = requests.map((request) => ({
      id: `access-${request.saw_id}`,
      raw: request,
      source: 'access',
      type: 'Conta web',
      requesterName: request.saw_nome,
      requesterEmail: request.saw_email,
      status: request.saw_status,
      createdAt: request.saw_created_at,
      details: `${request.saw_instituicao || 'Sem instituição'} · ${request.saw_cargo || 'Sem cargo'}`,
    }))

    const profileItems = profileRequests.map((request) => ({
      id: `profile-${request.sap_id}`,
      raw: request,
      source: 'profile',
      type: 'Alteração de perfil',
      requesterName: request.sap_nome_solicitante,
      requesterEmail: request.sap_email_solicitante,
      status: request.sap_status,
      createdAt: request.sap_created_at,
      changes: request.sap_alteracoes,
      currentProfile: profileMap.get(request.sap_user_id),
    }))

    return [...accessItems, ...profileItems].sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))
  }, [requests, profileRequests, profileMap])

  async function handleApproveAccess(request) {
    setError('')
    try {
      setShelters(await listShelters())
      setApproval(request); setApprovalRole(/gerente/i.test(request.saw_cargo || '') ? 'gerente_abrigo' : 'funcionario'); setApprovalShelter('')
    } catch (e) { setError(toFriendlyMessage(e)) }
  }

  async function confirmAccessApproval() {
    const request = approval
    setActionLoading(request.saw_id)
    setError('')
    setMessage('')

    try {
      const result = await approveAccessRequest(request.saw_id, { profileType: approvalRole, shelterId: approvalShelter })
      setApproval(null)
      await loadAdminData({ preserveScroll: true })
      setMessage(result.message || 'Solicitação de acesso aprovada.')
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível aprovar a solicitação. Tente novamente.'))
    } finally {
      setActionLoading('')
    }
  }

  function openRejectDialog(type, request) {
    setRejectDialog({ type, request })
    setRejectReason('')
    setError('')
    setMessage('')
  }

  async function handleConfirmReject() {
    if (!rejectDialog) return

    const reason = rejectReason.trim() || 'Recusado pelo painel administrativo.'
    const id = rejectDialog.type === 'access' ? rejectDialog.request.saw_id : rejectDialog.request.sap_id
    setActionLoading(id)
    setError('')
    setMessage('')

    try {
      if (rejectDialog.type === 'access') {
        await rejectAccessRequest(rejectDialog.request.saw_id, reason)
        setMessage('Solicitação de acesso recusada com motivo registrado.')
      } else {
        await rejectProfileChangeRequest(rejectDialog.request, reason)
        setMessage('Alteração de perfil recusada com motivo registrado.')
      }

      setRejectDialog(null)
      setRejectReason('')
      await loadAdminData()
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível recusar a solicitação. Tente novamente.'))
    } finally {
      setActionLoading('')
    }
  }

  function handleApproveProfile(request) {
    setError('')
    setMessage('')

    if (request.sap_alteracoes?.password) {
      setPasswordDialog(request)
      setAdminPassword('')
      setAdminPasswordConfirm('')
      return
    }

    return approveProfileWithoutPasswordDialog(request)
  }

  async function approveProfileWithoutPasswordDialog(request, options = {}) {
    setActionLoading(request.sap_id)
    setError('')
    setMessage('')

    try {
      await approveProfileChangeRequest(request, options)
      setMessage(options.password ? 'Alteração aprovada. Senha atualizada pelo painel.' : 'Alteração de perfil aprovada.')
      await loadAdminData()
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível aprovar a alteração de perfil. Tente novamente.'))
    } finally {
      setActionLoading('')
    }
  }

  async function handleConfirmPasswordApproval() {
    if (!passwordDialog) return

    const password = adminPassword.trim()
    const confirmation = adminPasswordConfirm.trim()

    if (password.length < 6) {
      setError('A nova senha precisa ter pelo menos 6 caracteres.')
      return
    }

    if (password !== confirmation) {
      setError('As senhas não conferem.')
      return
    }

    await approveProfileWithoutPasswordDialog(passwordDialog, { password })
    setPasswordDialog(null)
    setAdminPassword('')
    setAdminPasswordConfirm('')
  }

  return (
    <div className="p-6 space-y-5">
      {missingSchema && (
        <div className="rounded-2xl border border-yellow-100 bg-yellow-50 px-5 py-4 text-sm text-yellow-800 leading-relaxed">
          Esta área administrativa ainda não está disponível.
          Avise o responsável pelo painel para finalizar essa etapa.
        </div>
      )}

      <Modal isOpen={Boolean(approval)} onClose={() => !actionLoading && setApproval(null)} title="Aprovar acesso">
        <p className="mb-4">{approval?.saw_nome} · {approval?.saw_email}</p>
        <label className="block mb-4">Perfil de acesso<select className="input-field mt-2" value={approvalRole} onChange={e => setApprovalRole(e.target.value)}><option value="funcionario">Funcionário</option><option value="instituicao">Instituição</option><option value="gerente_abrigo">Gerente de Abrigo</option></select></label>
        {approvalRole === 'gerente_abrigo' && <label className="block mb-4">Abrigo responsável<select className="input-field mt-2" value={approvalShelter} onChange={e => setApprovalShelter(e.target.value)}><option value="">Selecione um abrigo</option>{shelters.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}</select>{!shelters.length && <p>Cadastre um abrigo na tela Abrigos antes de aprovar este perfil.</p>}</label>}
        {error && <p role="alert" className="mb-3 text-red-700">{error}</p>}
        <button className="btn-primary" disabled={Boolean(actionLoading) || (approvalRole === 'gerente_abrigo' && !approvalShelter)} onClick={confirmAccessApproval}>{actionLoading ? 'Aprovando…' : 'Confirmar aprovação'}</button>
      </Modal>
      {error && (
        <div role="alert" className="rounded-2xl border border-red-100 bg-red-50 px-5 py-4 text-sm text-red-700 leading-relaxed">
          {error}
        </div>
      )}

      {message && (
        <div role="status" aria-live="polite" className="rounded-2xl border border-green-100 bg-green-50 px-5 py-4 text-sm text-green-700 leading-relaxed">
          {message}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div className="bg-white rounded-2xl shadow-card p-5 border border-border-soft">
          <p className="text-xs text-slate-400 font-semibold uppercase">Pendentes</p>
          <p className="text-2xl font-bold text-slate-800 mt-2">{stats.pending}</p>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 border border-border-soft">
          <p className="text-xs text-slate-400 font-semibold uppercase">Aprovados</p>
          <p className="text-2xl font-bold text-slate-800 mt-2">{stats.approved}</p>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 border border-border-soft">
          <p className="text-xs text-slate-400 font-semibold uppercase">Recusados</p>
          <p className="text-2xl font-bold text-slate-800 mt-2">{stats.rejected}</p>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 border border-border-soft">
          <p className="text-xs text-slate-400 font-semibold uppercase">Perfis</p>
          <p className="text-2xl font-bold text-slate-800 mt-2">{stats.profiles}</p>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 border border-border-soft">
          <p className="text-xs text-slate-400 font-semibold uppercase">Logs</p>
          <p className="text-2xl font-bold text-slate-800 mt-2">{stats.logs}</p>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-card border border-border-soft overflow-hidden">
        <div className="flex flex-wrap gap-2 border-b border-border-soft p-4">
          {[
            ['all', 'Todas as Solicitações'],
            ['requests', 'Solicitações de Acesso'],
            ['profileChanges', 'Alterações de Perfil'],
            ['logs', 'Registros'],
          ].map(([id, label]) => (
            <button
              key={id}
              onClick={() => setActiveTab(id)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition-all ${activeTab === id ? 'bg-bg-sidebar text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}
            >
              {label}
            </button>
          ))}
          <button
            onClick={loadAdminData}
            className="ml-auto rounded-full px-4 py-2 text-sm font-semibold bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
          >
            Atualizar
          </button>
        </div>

        {loading ? (
          <div className="p-8 text-sm text-slate-500">Carregando dados administrativos...</div>
        ) : activeTab === 'all' ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-500">
                <tr>
                  <th className="px-5 py-3 text-left font-semibold">Tipo</th>
                  <th className="px-5 py-3 text-left font-semibold">Solicitante</th>
                  <th className="px-5 py-3 text-left font-semibold">Detalhes</th>
                  <th className="px-5 py-3 text-left font-semibold">Status</th>
                  <th className="px-5 py-3 text-left font-semibold">Criado em</th>
                  <th className="px-5 py-3 text-right font-semibold">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-soft">
                {allSolicitations.length === 0 && (
                  <tr><td colSpan="6" className="px-5 py-8 text-center text-slate-400">Nenhuma solicitação encontrada.</td></tr>
                )}
                {allSolicitations.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/60 align-top">
                    <td className="px-5 py-4"><span className="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-600">{item.type}</span></td>
                    <td className="px-5 py-4"><p className="font-semibold text-slate-700">{item.requesterName || '—'}</p><p className="text-xs text-slate-400">{item.requesterEmail || '—'}</p></td>
                    <td className="px-5 py-4 text-slate-600">{item.source === 'profile' ? <ChangeList changes={item.changes} currentProfile={item.currentProfile} status={item.status} /> : item.details}</td>
                    <td className="px-5 py-4"><StatusPill status={item.status} /></td>
                    <td className="px-5 py-4 text-slate-500">{formatDate(item.createdAt)}</td>
                    <td className="px-5 py-4">
                      <div className="flex justify-end gap-2">
                        {item.source === 'profile' ? (
                          <>
                            <button disabled={item.status !== 'pendente' || actionLoading === item.raw.sap_id} onClick={() => handleApproveProfile(item.raw)} className="rounded-lg bg-green-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Aprovar</button>
                            <button disabled={item.status !== 'pendente' || actionLoading === item.raw.sap_id} onClick={() => openRejectDialog('profile', item.raw)} className="rounded-lg bg-red-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Recusar</button>
                          </>
                        ) : (
                          <>
                            <button disabled={item.status !== 'pendente' || actionLoading === item.raw.saw_id} onClick={() => handleApproveAccess(item.raw)} className="rounded-lg bg-green-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Aprovar</button>
                            <button disabled={item.status !== 'pendente' || actionLoading === item.raw.saw_id} onClick={() => openRejectDialog('access', item.raw)} className="rounded-lg bg-red-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Recusar</button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'requests' ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-500">
                <tr>
                  <th className="px-5 py-3 text-left font-semibold">Solicitante</th>
                  <th className="px-5 py-3 text-left font-semibold">Instituição</th>
                  <th className="px-5 py-3 text-left font-semibold">Cargo</th>
                  <th className="px-5 py-3 text-left font-semibold">Status</th>
                  <th className="px-5 py-3 text-left font-semibold">Criado em</th>
                  <th className="px-5 py-3 text-right font-semibold">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-soft">
                {requests.length === 0 && (
                  <tr><td colSpan="6" className="px-5 py-8 text-center text-slate-400">Nenhuma solicitação encontrada.</td></tr>
                )}
                {requests.map((request) => (
                  <tr key={request.saw_id} className="hover:bg-slate-50/60">
                    <td className="px-5 py-4"><p className="font-semibold text-slate-700">{request.saw_nome}</p><p className="text-xs text-slate-400">{request.saw_email}</p></td>
                    <td className="px-5 py-4 text-slate-600">{request.saw_instituicao || '—'}</td>
                    <td className="px-5 py-4 text-slate-600">{request.saw_cargo || '—'}</td>
                    <td className="px-5 py-4"><StatusPill status={request.saw_status} /></td>
                    <td className="px-5 py-4 text-slate-500">{formatDate(request.saw_created_at)}</td>
                    <td className="px-5 py-4">
                      <div className="flex justify-end gap-2">
                        <button disabled={request.saw_status !== 'pendente' || actionLoading === request.saw_id} onClick={() => handleApproveAccess(request)} className="rounded-lg bg-green-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Aprovar</button>
                        <button disabled={request.saw_status !== 'pendente' || actionLoading === request.saw_id} onClick={() => openRejectDialog('access', request)} className="rounded-lg bg-red-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Recusar</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'profileChanges' ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-500">
                <tr>
                  <th className="px-5 py-3 text-left font-semibold">Solicitante</th>
                  <th className="px-5 py-3 text-left font-semibold">Alterações</th>
                  <th className="px-5 py-3 text-left font-semibold">Status</th>
                  <th className="px-5 py-3 text-left font-semibold">Criado em</th>
                  <th className="px-5 py-3 text-right font-semibold">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-soft">
                {profileRequests.length === 0 && (
                  <tr><td colSpan="5" className="px-5 py-8 text-center text-slate-400">Nenhuma solicitação de alteração de perfil encontrada.</td></tr>
                )}
                {profileRequests.map((request) => (
                  <tr key={request.sap_id} className="hover:bg-slate-50/60 align-top">
                    <td className="px-5 py-4"><p className="font-semibold text-slate-700">{request.sap_nome_solicitante || '—'}</p><p className="text-xs text-slate-400">{request.sap_email_solicitante || request.sap_user_id}</p></td>
                    <td className="px-5 py-4"><ChangeList changes={request.sap_alteracoes} currentProfile={profileMap.get(request.sap_user_id)} status={request.sap_status} /></td>
                    <td className="px-5 py-4"><StatusPill status={request.sap_status} /></td>
                    <td className="px-5 py-4 text-slate-500">{formatDate(request.sap_created_at)}</td>
                    <td className="px-5 py-4">
                      <div className="flex justify-end gap-2">
                        <button disabled={request.sap_status !== 'pendente' || actionLoading === request.sap_id} onClick={() => handleApproveProfile(request)} className="rounded-lg bg-green-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Aprovar</button>
                        <button disabled={request.sap_status !== 'pendente' || actionLoading === request.sap_id} onClick={() => openRejectDialog('profile', request)} className="rounded-lg bg-red-600 px-3 py-2 text-xs font-semibold text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed">Recusar</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-500"><tr><th className="px-5 py-3 text-left font-semibold">Ação</th><th className="px-5 py-3 text-left font-semibold">Entidade</th><th className="px-5 py-3 text-left font-semibold">Detalhes</th><th className="px-5 py-3 text-left font-semibold">Data</th></tr></thead>
              <tbody className="divide-y divide-border-soft">
                {logs.length === 0 && (<tr><td colSpan="4" className="px-5 py-8 text-center text-slate-400">Nenhum registro de auditoria encontrado.</td></tr>)}
                {logs.map((log) => (
                  <tr key={log.log_id} className="hover:bg-slate-50/60"><td className="px-5 py-4 font-semibold text-slate-700">{log.action}</td><td className="px-5 py-4 text-slate-600">{log.entity_type || '—'}</td><td className="px-5 py-4 text-slate-500 max-w-lg truncate">{log.detail || '—'}</td><td className="px-5 py-4 text-slate-500">{formatDate(log.created_at)}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        isOpen={Boolean(passwordDialog)}
        onClose={() => {
          if (!actionLoading) {
            setPasswordDialog(null)
            setAdminPassword('')
            setAdminPasswordConfirm('')
          }
        }}
        title="Definir nova senha"
        size="sm"
      >
        <div className="space-y-4">
          <p className="text-sm text-slate-500">
            O e-mail de redefinição pode demorar ou não chegar. Defina uma senha temporária aqui e oriente o usuário a trocar depois que entrar.
          </p>
          <label className="block space-y-2">
            <span className="text-xs font-bold uppercase tracking-[0.14em] text-slate-500">Nova senha</span>
            <input
              className="input-field"
              type="password"
              value={adminPassword}
              onChange={(event) => setAdminPassword(event.target.value)}
              placeholder="Mínimo de 6 caracteres"
              autoFocus
            />
          </label>
          <label className="block space-y-2">
            <span className="text-xs font-bold uppercase tracking-[0.14em] text-slate-500">Confirmar senha</span>
            <input
              className="input-field"
              type="password"
              value={adminPasswordConfirm}
              onChange={(event) => setAdminPasswordConfirm(event.target.value)}
              placeholder="Digite novamente"
            />
          </label>
          <div className="rounded-2xl border border-yellow-100 bg-yellow-50 px-4 py-3 text-xs leading-relaxed text-yellow-800">
            Não compartilhe a senha em locais públicos. Use uma senha temporária e peça para o usuário alterar depois.
          </div>
          <div className="flex justify-end gap-3 border-t border-border-soft pt-3">
            <button className="btn-ghost" onClick={() => setPasswordDialog(null)} disabled={Boolean(actionLoading)}>Cancelar</button>
            <button className="rounded-lg bg-green-600 px-4 py-2 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50" onClick={handleConfirmPasswordApproval} disabled={Boolean(actionLoading)}>
              {actionLoading ? 'Atualizando...' : 'Aprovar e trocar senha'}
            </button>
          </div>
        </div>
      </Modal>

      <Modal
        isOpen={Boolean(rejectDialog)}
        onClose={() => setRejectDialog(null)}
        title="Motivo da recusa"
        size="sm"
      >
        <div className="space-y-4">
          <p className="text-sm text-slate-500">
            Escreva o motivo. Ele será salvo na auditoria e, em alterações de perfil, também aparecerá na atividade recente do usuário.
          </p>
          <textarea
            className="input-field min-h-28 resize-y"
            value={rejectReason}
            onChange={(event) => setRejectReason(event.target.value)}
            placeholder="Ex.: documento incompatível, dados insuficientes, solicitação duplicada..."
            autoFocus
          />
          <div className="flex justify-end gap-3 border-t border-border-soft pt-3">
            <button className="btn-ghost" onClick={() => setRejectDialog(null)} disabled={Boolean(actionLoading)}>Cancelar</button>
            <button className="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50" onClick={handleConfirmReject} disabled={Boolean(actionLoading)}>
              {actionLoading ? 'Recusando...' : 'Confirmar recusa'}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
