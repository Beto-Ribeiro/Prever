import { useEffect, useMemo, useState } from 'react'
import Modal from '../components/Modal'
import { useAuth } from '../hooks/useAuth.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import { formatBrazilPhone } from '../utils/phone.js'
import { uploadAvatarFile } from '../backend/perfil/avatarService.js'
import { formatActivityDate, formatUserActivity, listUserActivities } from '../backend/perfil/profileActivityService.js'
import {
  DEFAULT_PERMISSIONS,
  PERMISSION_LABELS,
  listUsersForAdmin,
  resetUserProfileByAdmin,
  updateUserProfileByAdmin,
} from '../backend/admin/userAdminService.js'

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

function initials(name) {
  return String(name || 'Usuário')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function roleLabel(role) {
  const normalized = String(role || '').toLowerCase()
  const labels = {
    gerente_abrigo: 'Gerente de Abrigo',
    shelter_manager: 'Gerente de Abrigo',
    administrador: 'Administrador',
    admin: 'Administrador',
    funcionario: 'Funcionário',
    agente: 'Agente autorizado',
    instituicao: 'Instituição',
    cidadao: 'Cidadão',
    pendente: 'Sem perfil',
  }

  return labels[normalized] || role || 'Sem tipo'
}

function normalizeProfileType(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

function isAdminType(type) {
  const normalizedType = normalizeProfileType(type)
  return normalizedType === 'administrador' || normalizedType === 'admin'
}

function isBlockedWebType(type) {
  const normalizedType = normalizeProfileType(type)
  return ['pendente', 'sem perfil', 'semperfil', 'cidadao', 'cidada', 'citizen', 'unknown'].includes(normalizedType)
}

function hasAnyGrantedPermission(permissions) {
  return Object.entries(DEFAULT_PERMISSIONS).some(([key]) => Boolean(permissions?.[key]))
}

function userAccessSummary(user) {
  if (isBlockedWebType(user?.prf_tipo)) return null
  const permissions = permissionsForType(user?.prf_permissoes, user?.prf_tipo)
  if (!hasAnyGrantedPermission(permissions)) return 'Acesso ao login, sem módulos'
  return 'Tem acesso'
}

function allPermissions(value) {
  return Object.keys(DEFAULT_PERMISSIONS).reduce((acc, key) => ({ ...acc, [key]: value }), {})
}

function permissionsForType(permissions, type) {
  if (['gerente_abrigo', 'shelter_manager'].includes(normalizeProfileType(type))) return { dashboard: true, ocupantes: true, estoque: true, pedidos: true, relatorios: true, reportar: false, ocorrencias: false, auditoria: false, admin: false }
  const base = { ...DEFAULT_PERMISSIONS, ...(permissions || {}) }

  if (isBlockedWebType(type)) {
    return allPermissions(false)
  }

  if (isAdminType(type)) {
    return allPermissions(true)
  }

  return {
    ...base,
    admin: false,
  }
}

function makeForm(user) {
  return {
    name: user?.prf_nome || '',
    type: user?.prf_tipo || 'funcionario',
    email: user?.prf_email_contato || '',
    phone: formatBrazilPhone(user?.prf_telefone || ''),
    avatarUrl: user?.prf_avatar_url || '',
    permissions: permissionsForType(user?.prf_permissoes, user?.prf_tipo),
  }
}

function Avatar({ user, size = 'lg' }) {
  const classes = size === 'lg' ? 'w-12 h-12 text-sm' : 'w-10 h-10 text-xs'

  if (user?.prf_avatar_url) {
    return (
      <img
        src={user.prf_avatar_url}
        alt={user.prf_nome || 'Foto do usuário'}
        className={`${classes} rounded-full object-cover border border-border-soft bg-slate-100 flex-shrink-0`}
      />
    )
  }

  return (
    <div className={`${classes} rounded-full bg-bg-sidebar/10 text-bg-sidebar font-bold flex items-center justify-center flex-shrink-0`}>
      {initials(user?.prf_nome)}
    </div>
  )
}


function normalizeAiSearch(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
}

function userToAiContext(user) {
  const permissions = permissionsForType(user?.prf_permissoes, user?.prf_tipo)

  return {
    id: user?.prf_id,
    name: user?.prf_nome || 'Usuário sem nome',
    type: roleLabel(user?.prf_tipo),
    rawType: user?.prf_tipo || '',
    email: user?.prf_email_contato || null,
    phone: user?.prf_telefone || null,
    createdAt: user?.prf_created_at || null,
    access: userAccessSummary(user) || 'Sem acesso ao painel web',
    permissions: Object.entries(PERMISSION_LABELS).map(([key, label]) => ({
      key,
      label,
      enabled: Boolean(permissions?.[key]),
    })),
  }
}

function findUserByAiQuery(users, query) {
  const search = normalizeAiSearch(query)
  if (!search) return null

  const exact = users.find((user) => {
    return [user.prf_nome, user.prf_email_contato, user.prf_id]
      .filter(Boolean)
      .some((value) => normalizeAiSearch(value) === search)
  })

  if (exact) return exact

  return users.find((user) => {
    const content = normalizeAiSearch([
      user.prf_nome,
      user.prf_tipo,
      user.prf_email_contato,
      user.prf_telefone,
      user.prf_id,
      roleLabel(user.prf_tipo),
    ].filter(Boolean).join(' '))

    return content.includes(search) || search.split(/\s+/).filter((part) => part.length >= 3).every((part) => content.includes(part))
  }) || null
}

export default function UserList() {
  const { user: currentUser, refreshUser } = useAuth()
  const [users, setUsers] = useState([])
  const [selectedUser, setSelectedUser] = useState(null)
  const [selectedActivities, setSelectedActivities] = useState([])
  const [form, setForm] = useState(makeForm(null))
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [resetting, setResetting] = useState(false)
  const [uploadingAvatar, setUploadingAvatar] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  async function loadUsers() {
    setLoading(true)
    setError('')

    try {
      const result = await listUsersForAdmin()
      setUsers(result.data)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível carregar a lista de usuários. Tente novamente.'))
    } finally {
      setLoading(false)
    }
  }

  async function loadSelectedActivities(userId) {
    if (!userId) return
    try {
      const data = await listUserActivities(userId, 30)
      setSelectedActivities(data)
    } catch (err) {
      console.warn('Não foi possível carregar histórico do usuário:', err.message)
      setSelectedActivities([])
    }
  }

  useEffect(() => {
    loadUsers()
  }, [])

  const filteredUsers = useMemo(() => {
    const search = query.trim().toLowerCase()
    if (!search) return users

    return users.filter((user) => {
      const content = [user.prf_nome, user.prf_tipo, user.prf_email_contato, user.prf_telefone, user.prf_id]
        .join(' ')
        .toLowerCase()

      return content.includes(search)
    })
  }, [users, query])

  useEffect(() => {
    window.__SMDN_AI_USERS = users.map(userToAiContext)
    window.dispatchEvent(new CustomEvent('smdn-ai-users-context-updated', {
      detail: { users: window.__SMDN_AI_USERS },
    }))
  }, [users])

  useEffect(() => {
    function handleAiUserAction(event) {
      const action = event?.detail || window.__SMDN_AI_PENDING_USER_ACTION
      if (!action || users.length === 0) return

      const searchText = action.query || action.name || action.id || ''
      const normalizedMode = String(action.mode || action.type || '').toLowerCase()
      const shouldOpen = normalizedMode === 'open' || normalizedMode === 'open_user'

      if (searchText) {
        setQuery(searchText)
      }

      if (shouldOpen) {
        const match = findUserByAiQuery(users, searchText)
        if (match) {
          openEdit(match)
        }
      }

      window.__SMDN_AI_PENDING_USER_ACTION = null
    }

    window.addEventListener('smdn-ai-users-action', handleAiUserAction)
    handleAiUserAction({ detail: window.__SMDN_AI_PENDING_USER_ACTION })

    return () => {
      window.removeEventListener('smdn-ai-users-action', handleAiUserAction)
    }
  }, [users])

  function openEdit(user) {
    setSelectedUser(user)
    setForm(makeForm(user))
    setSelectedActivities([])
    setError('')
    setMessage('')
    loadSelectedActivities(user.prf_id)
  }

  function closeEdit() {
    setSelectedUser(null)
    setSelectedActivities([])
    setForm(makeForm(null))
  }

  async function handleAvatarFileChange(event) {
    const file = event.target.files?.[0]
    if (!file || !selectedUser) return

    setUploadingAvatar(true)
    setError('')

    try {
      const publicUrl = await uploadAvatarFile({ file, userId: selectedUser.prf_id })
      setForm((current) => ({ ...current, avatarUrl: publicUrl }))
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível enviar a foto. Tente novamente.'))
    } finally {
      setUploadingAvatar(false)
      event.target.value = ''
    }
  }

  function handleTypeChange(nextType) {
    setForm((current) => ({
      ...current,
      type: nextType,
      permissions: permissionsForType(current.permissions, nextType),
    }))
  }

  function togglePermission(permissionKey) {
    setForm((current) => {
      if (isBlockedWebType(current.type)) return current
      if (permissionKey === 'admin' && !isAdminType(current.type)) return current

      return {
        ...current,
        permissions: permissionsForType(
          {
            ...current.permissions,
            [permissionKey]: !current.permissions?.[permissionKey],
          },
          current.type
        ),
      }
    })
  }

  async function handleSave() {
    if (!selectedUser) return

    setSaving(true)
    setError('')
    setMessage('')

    try {
      await updateUserProfileByAdmin({ user: selectedUser, form, actorUser: currentUser })

      if (selectedUser.prf_id === currentUser?.id) {
        await refreshUser()
      }

      setMessage('Perfil do usuário atualizado. A atividade aparecerá no perfil dele.')
      await loadSelectedActivities(selectedUser.prf_id)
      closeEdit()
      await loadUsers()
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível atualizar o usuário. Tente novamente.'))
    } finally {
      setSaving(false)
    }
  }

  async function handleResetProfile() {
    if (!selectedUser) return
    const confirmed = window.confirm('Zerar o perfil deste usuário? Ele ficará sem perfil web autorizado.')
    if (!confirmed) return

    setResetting(true)
    setError('')
    setMessage('')

    try {
      await resetUserProfileByAdmin(selectedUser)
      setMessage('Perfil zerado. O usuário voltou para status sem perfil autorizado.')
      closeEdit()
      await loadUsers()
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível zerar o perfil do usuário. Tente novamente.'))
    } finally {
      setResetting(false)
    }
  }

  return (
    <div className="p-6 space-y-5">
      {error && <div className="rounded-2xl border border-red-100 bg-red-50 px-5 py-4 text-sm text-red-700 leading-relaxed">{error}</div>}
      {message && <div className="rounded-2xl border border-green-100 bg-green-50 px-5 py-4 text-sm text-green-700 leading-relaxed">{message}</div>}

      <div className="bg-white rounded-2xl shadow-card border border-border-soft overflow-hidden">
        <div className="flex flex-col md:flex-row md:items-center gap-3 border-b border-border-soft p-4">
          <div>
            <p className="text-sm font-bold text-slate-800">Usuários cadastrados</p>
            <p className="text-xs text-slate-400">{filteredUsers.length} de {users.length} perfil(is)</p>
          </div>
          <div className="md:ml-auto flex gap-2 w-full md:w-auto">
            <input className="input-field md:w-72" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar por nome, tipo, contato ou ID" />
            <button onClick={loadUsers} className="rounded-xl px-4 py-2 text-sm font-semibold bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all">Atualizar</button>
          </div>
        </div>

        {loading ? (
          <div className="p-8 text-sm text-slate-500">Carregando usuários...</div>
        ) : filteredUsers.length === 0 ? (
          <div className="p-8 text-sm text-slate-400 text-center">Nenhum usuário encontrado.</div>
        ) : (
          <div className="divide-y divide-border-soft">
            {filteredUsers.map((user) => (
              <button key={user.prf_id} onClick={() => openEdit(user)} className="w-full flex items-center gap-4 px-5 py-4 text-left hover:bg-slate-50 transition-all">
                <Avatar user={user} />
                <div className="min-w-0 flex-1">
                  <p className="font-bold text-slate-800 truncate">{user.prf_nome || 'Usuário sem nome'}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    <p className="text-xs text-slate-400 truncate">{roleLabel(user.prf_tipo)}</p>
                    {userAccessSummary(user) && (
                      <span className="rounded-full border border-status-success/30 bg-status-success-bg px-2 py-0.5 text-[10px] font-bold text-status-success">
                        {userAccessSummary(user)}
                      </span>
                    )}
                  </div>
                </div>
                <div className="hidden md:block min-w-[220px] text-sm text-slate-500">
                  <p className="truncate">{user.prf_email_contato || 'Sem e-mail de contato'}</p>
                  <p className="text-xs text-slate-400">{user.prf_telefone || 'Sem telefone'}</p>
                </div>
                <div className="hidden lg:block min-w-[160px] text-xs text-slate-400">Criado em {formatDate(user.prf_created_at)}</div>
                <span className="text-xs font-semibold text-text-main hover:text-action-hover">Editar</span>
              </button>
            ))}
          </div>
        )}
      </div>

      <Modal isOpen={Boolean(selectedUser)} onClose={closeEdit} title="Editar usuário" size="lg">
        <div className="space-y-4">
          {selectedUser && (
            <div className="rounded-2xl bg-slate-50 border border-border-soft p-4 flex items-center gap-3">
              <Avatar user={{ ...selectedUser, prf_avatar_url: form.avatarUrl, prf_nome: form.name }} size="sm" />
              <div className="min-w-0">
                <p className="font-bold text-slate-800 truncate">{form.name || 'Usuário sem nome'}</p>
                <p className="text-xs text-slate-400 font-mono truncate">{selectedUser.prf_id}</p>
              </div>
            </div>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2"><label className="block text-label text-slate-600 mb-1.5">NOME COMPLETO</label><input className="input-field" value={form.name} onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))} /></div>
            <div><label className="block text-label text-slate-600 mb-1.5">TIPO DE PERFIL</label><select className="input-field" value={form.type} onChange={(event) => handleTypeChange(event.target.value)}><option value="pendente">Sem perfil</option><option value="funcionario">Funcionário</option><option value="instituicao">Instituição</option><option value="cidadao">Cidadão</option><option value="administrador">Administrador</option>{['gerente_abrigo', 'shelter_manager'].includes(selectedUser?.prf_tipo) && <option value={selectedUser.prf_tipo}>Gerente de Abrigo</option>}</select></div>
            <div><label className="block text-label text-slate-600 mb-1.5">E-MAIL DE LOGIN / CONTATO</label><input type="email" className="input-field" value={form.email} onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))} /></div>
            <div><label className="block text-label text-slate-600 mb-1.5">TELEFONE</label><input className="input-field" inputMode="numeric" maxLength={15} value={form.phone} placeholder="(12) 98703-7110" onChange={(event) => setForm((current) => ({ ...current, phone: formatBrazilPhone(event.target.value) }))} /></div>
            <div><label className="block text-label text-slate-600 mb-1.5">FOTO DO PERFIL</label><label className="input-field flex items-center justify-between cursor-pointer text-slate-500"><span className="truncate">{uploadingAvatar ? 'Enviando foto...' : form.avatarUrl ? 'Trocar foto' : 'Enviar foto'}</span><input type="file" accept="image/*" className="hidden" disabled={uploadingAvatar} onChange={handleAvatarFileChange} /></label></div>
            <div className="col-span-2"><label className="block text-label text-slate-600 mb-1.5">URL DA FOTO</label><input className="input-field" value={form.avatarUrl} placeholder="Será preenchida automaticamente após upload" onChange={(event) => setForm((current) => ({ ...current, avatarUrl: event.target.value }))} /></div>
          </div>

          <div className="rounded-2xl border border-border-soft p-4">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h3 className="font-bold text-slate-800">Permissões do usuário</h3>
              {!isBlockedWebType(form.type) && (
                <span className="rounded-full border border-status-success/30 bg-status-success-bg px-3 py-1 text-xs font-bold text-status-success">
                  Tem acesso ao painel web
                </span>
              )}
            </div>

            {isBlockedWebType(form.type) ? (
              <div className="rounded-xl border border-border-soft bg-slate-50 px-4 py-3 text-sm text-slate-500">
                Este tipo de perfil não acessa o painel web. Nenhuma permissão de módulo será exibida ou aplicada.
              </div>
            ) : (
              <>
                <p className="text-xs text-slate-400 mb-3 leading-relaxed">
                  Marque apenas os módulos que este usuário pode abrir. Funcionário e Instituição não acessam Administração.
                </p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {Object.entries(PERMISSION_LABELS).map(([key, label]) => {
                    const disabled = key === 'admin' && !isAdminType(form.type)

                    return (
                      <label key={key} className={`flex items-center gap-2 text-sm ${disabled ? 'text-slate-400' : 'text-slate-600'}`}>
                        <input
                          type="checkbox"
                          checked={Boolean(form.permissions?.[key])}
                          disabled={disabled}
                          onChange={() => togglePermission(key)}
                        />
                        {label}
                      </label>
                    )
                  })}
                </div>
              </>
            )}
          </div>

          <div className="rounded-2xl border border-border-soft p-4">
            <h3 className="font-bold text-slate-800 mb-3">Histórico do perfil</h3>
            <div className="space-y-2 max-h-44 overflow-y-auto pr-1">
              {selectedActivities.length === 0 ? <p className="text-sm text-slate-400">Nenhuma atividade registrada.</p> : selectedActivities.map((activity) => (
                <div key={activity.atu_id} className="rounded-xl bg-slate-50 border border-border-soft px-3 py-2 text-sm text-slate-600">
                  <p>{formatUserActivity(activity, currentUser)}</p>
                  <p className="text-xs text-slate-400 mt-1">{formatActivityDate(activity.atu_created_at)}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-xs text-blue-800 leading-relaxed">
            Alterar o e-mail aqui também muda o e-mail usado para entrar no painel. Solicitações de senha aprovadas enviam um e-mail para o usuário redefinir a senha.
          </div>

          <div className="flex flex-wrap items-center justify-end gap-3 pt-2 border-t border-border-soft">
            <button className="rounded-lg px-4 py-2 text-sm font-semibold border border-red-100 text-red-600 hover:bg-red-50" onClick={handleResetProfile} disabled={saving || resetting}>{resetting ? 'Zerando...' : 'Zerar Perfil'}</button>
            <button className="btn-ghost" onClick={closeEdit} disabled={saving || resetting}>Cancelar</button>
            <button className="btn-primary" onClick={handleSave} disabled={saving || resetting}>{saving ? 'Salvando...' : 'Salvar Alterações'}</button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
