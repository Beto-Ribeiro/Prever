import { useEffect, useMemo, useState } from 'react'
import Card from '../components/Card'
import Modal from '../components/Modal'
import SettingsPanel from '../components/SettingsPanel'
import { useAuth } from '../hooks/useAuth.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import { formatBrazilPhone } from '../utils/phone.js'
import { formatActivityDate, formatUserActivity, getActivityDetails, listUserActivities } from '../backend/perfil/profileActivityService.js'
import { uploadAvatarFile } from '../backend/perfil/avatarService.js'
import { supabase } from '../backend/supabase/client.js'
import {
  buildProfileChanges,
  hasProfileChanges,
  requestProfileChange,
  updateOwnProfileDirect,
} from '../backend/perfil/profileChangeService.js'

const PERMISSIONS = [
  { key: 'dashboard', label: 'Dashboard', granted: true },
  { key: 'reportar', label: 'Reportar / Disparar Alertas', granted: true },
  { key: 'ocorrencias', label: 'Gerenciar Ocorrências', granted: true },
  { key: 'relatorios', label: 'Relatórios Analíticos', granted: true },
  { key: 'auditoria', label: 'Auditoria', granted: true },
  { key: 'admin', label: 'Administração de Usuários', granted: true },
]


function maskEmail(value) {
  const email = String(value || '').trim()
  if (!email || !email.includes('@')) return 'e####@mail.com'

  const [name, domain] = email.split('@')
  const visible = name.slice(0, Math.min(2, Math.max(1, name.length)))
  return `${visible}####@${domain}`
}

function maskPhone(value) {
  const digits = String(value || '').replace(/\D/g, '')
  if (digits.length < 4) return '12#######10'
  return `${digits.slice(0, 2)}#######${digits.slice(-2)}`
}

const FALLBACK_ACTIVITY = [
  { action: 'Login', target: 'Acesso autorizado', at: 'Agora' },
  { action: 'Perfil', target: 'Dados sincronizados', at: 'Hoje' },
]

function makeInitialForm(user) {
  return {
    name: user?.name || '',
    email: user?.contactEmail || user?.perfil?.prf_email_contato || user?.email || '',
    role: user?.roleLabel || user?.role || '',
    phone: formatBrazilPhone(user?.phone || user?.perfil?.prf_telefone || ''),
    avatarUrl: user?.avatar || user?.perfil?.prf_avatar_url || '',
    cpf: '***.***.***-00',
    institution: user?.instituicao?.ins_numero || 'PREVER',
    newPassword: '',
    requestPasswordReset: false,
  }
}

function ChangePreview({ changes }) {
  const entries = Object.entries(changes || {})
  if (entries.length === 0) return null

  return (
    <div className="rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-xs text-blue-800 space-y-1">
      <p className="font-bold">Alterações detectadas</p>
      {entries.map(([key, change]) => (
        <p key={key}>
          <strong>{change.label}:</strong> {change.old} → {change.new}
        </p>
      ))}
    </div>
  )
}

function initialsFromName(name) {
  return String(name || 'PREVER')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function flattenDetailRows(details, limit = 4) {
  const rows = []

  for (const section of details?.sections || []) {
    for (const row of section.rows || []) {
      if (!row?.value || row.value === '—') continue
      rows.push({ ...row, section: section.title })
      if (rows.length >= limit) return rows
    }
  }

  return rows
}

function getFloatingPosition(position, width = 340, height = 180) {
  if (typeof window === 'undefined' || !position) return { left: 0, top: 0 }

  return {
    left: Math.min(position.x + 16, window.innerWidth - width - 16),
    top: Math.min(position.y + 16, window.innerHeight - height - 16),
  }
}

function ActivityHoverSummary({ details, position }) {
  if (!details || !position) return null

  const rows = flattenDetailRows(details, 4)
  const style = getFloatingPosition(position)

  return (
    <div
      className="fixed z-[99999] w-[340px] rounded-2xl border border-border-soft bg-bg-surface p-4 text-left shadow-2xl pointer-events-none"
      style={style}
    >
      <div className="flex items-start gap-3">
        {details.actor?.avatar ? (
          <img src={details.actor.avatar} alt={details.actor.name || 'Responsável'} className="h-9 w-9 rounded-full object-cover border border-slate-200" />
        ) : (
          <div className="h-9 w-9 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center text-xs font-bold">
            {initialsFromName(details.actor?.name)}
          </div>
        )}

        <div className="min-w-0">
          <p className="text-sm font-bold text-slate-800 leading-snug line-clamp-2">{details.title}</p>
          {details.actor?.name && <p className="text-xs text-slate-500 truncate">por {details.actor.name}</p>}
        </div>
      </div>

      <div className="mt-3 space-y-1.5">
        {rows.map((row) => (
          <div key={`${row.section}-${row.label}`} className="grid grid-cols-[96px_1fr] gap-2 text-xs">
            <span className="font-semibold text-slate-400 truncate">{row.label}</span>
            <span className="text-slate-700 truncate">{row.value}</span>
          </div>
        ))}
      </div>

      <p className="mt-3 text-[11px] font-semibold text-text-main">Clique na atividade para ver todos os detalhes.</p>
    </div>
  )
}

function ActivityDetailsDialog({ details, onClose }) {
  if (!details) return null

  return (
    <div className="fixed inset-0 z-[100000]" onClick={onClose}>
      <div className="absolute inset-0 bg-slate-900/30 backdrop-blur-[1px]" />

      <div
        className="profile-activity-details-panel absolute right-6 top-6 flex max-h-[calc(100vh-3rem)] w-[min(34rem,calc(100vw-3rem))] flex-col overflow-hidden rounded-3xl border border-border-soft bg-bg-surface shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-start gap-3 border-b border-border-soft p-5">
          {details.actor?.avatar ? (
            <img src={details.actor.avatar} alt={details.actor.name || 'Responsável'} className="h-12 w-12 rounded-full object-cover border border-slate-200" />
          ) : (
            <div className="h-12 w-12 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center text-sm font-bold">
              {initialsFromName(details.actor?.name)}
            </div>
          )}

          <div className="min-w-0 flex-1">
            <p className="text-base font-bold text-slate-800 leading-snug">{details.title}</p>
            {details.actor?.name && <p className="text-xs text-slate-500 truncate">por {details.actor.name}</p>}
            {details.actor?.email && <p className="text-xs text-slate-400 truncate">{details.actor.email}</p>}
          </div>

          <button
            type="button"
            onClick={onClose}
            className="rounded-full px-2 py-1 text-slate-400 hover:bg-slate-100 hover:text-slate-600 transition"
            aria-label="Fechar detalhes"
          >
            ×
          </button>
        </div>

        <div className="flex-1 overflow-y-auto overflow-x-hidden p-5 space-y-4">
          {details.sections.map((section) => (
            <div key={section.title} className="profile-activity-details-section rounded-2xl border border-border-soft bg-slate-50/70 p-4">
              <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-slate-400 mb-2">{section.title}</p>
              <div className="space-y-2">
                {section.rows.map((row) => (
                  <div key={`${section.title}-${row.label}`} className="grid min-w-0 grid-cols-[120px_minmax(0,1fr)] gap-3 text-sm">
                    <span className="font-semibold text-slate-500">{row.label}</span>
                    <span className="profile-activity-detail-value min-w-0 break-all text-slate-700">{row.value}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function ActivityList({ activities, currentUser }) {
  const items = activities.length > 0 ? activities : FALLBACK_ACTIVITY
  const [hoverDetails, setHoverDetails] = useState(null)
  const [hoverPosition, setHoverPosition] = useState(null)
  const [openedDetails, setOpenedDetails] = useState(null)

  function handleMouseMove(event, details) {
    if (!details) return
    setHoverDetails(details)
    setHoverPosition({ x: event.clientX, y: event.clientY })
  }

  function closeHover() {
    setHoverDetails(null)
    setHoverPosition(null)
  }

  return (
    <>
      <div className="space-y-2.5">
        {items.map((activity, index) => {
          const isDatabaseActivity = Boolean(activity.atu_id)
          const action = isDatabaseActivity ? activity.atu_action : activity.action
          const target = isDatabaseActivity ? formatUserActivity(activity, currentUser) : activity.target
          const at = isDatabaseActivity ? formatActivityDate(activity.atu_created_at) : activity.at
          const details = isDatabaseActivity ? getActivityDetails(activity, currentUser) : null

          return (
            <button
              key={activity.atu_id || index}
              type="button"
              className="relative flex w-full items-start gap-3 rounded-xl -mx-2 px-2 py-1.5 text-left text-sm hover:bg-slate-50 transition-all"
              onMouseMove={(event) => handleMouseMove(event, details)}
              onMouseLeave={closeHover}
              onClick={() => {
                if (!details) return
                closeHover()
                setOpenedDetails(details)
              }}
            >
              <div className="w-2 h-2 rounded-full bg-text-main/50 flex-shrink-0 mt-2" />
              <span className="text-slate-600 leading-relaxed">
                <strong className="text-slate-800">{action}</strong> – {target}
              </span>
              <span className="ml-auto text-xs text-slate-400 whitespace-nowrap pt-0.5">{at}</span>
            </button>
          )
        })}
      </div>

      <ActivityHoverSummary details={hoverDetails} position={hoverPosition} />
      <ActivityDetailsDialog details={openedDetails} onClose={() => setOpenedDetails(null)} />
    </>
  )
}

export default function Perfil() {
  const { user, setUser, isAdmin, signOut, recoveryMode, clearRecoveryMode } = useAuth()
  const [isEditing, setIsEditing] = useState(false)
  const [form, setForm] = useState(makeInitialForm(user))
  const [activities, setActivities] = useState([])
  const [saved, setSaved] = useState(false)
  const [notice, setNotice] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [uploadingAvatar, setUploadingAvatar] = useState(false)
  const [showPrivateDetails, setShowPrivateDetails] = useState(false)
  const [recoveryPassword, setRecoveryPassword] = useState('')
  const [recoverySaving, setRecoverySaving] = useState(false)

  useEffect(() => {
    setForm(makeInitialForm(user))
  }, [user])

  useEffect(() => {
    let mounted = true

    async function loadActivities() {
      try {
        const data = await listUserActivities(user?.id)
        if (mounted) setActivities(data)
      } catch (err) {
        console.warn('Não foi possível carregar atividades do usuário:', err.message)
        if (mounted) setActivities([])
      }
    }

    loadActivities()

    if (!user?.id) {
      return () => {
        mounted = false
      }
    }

    const channel = supabase
      .channel(`perfil-atividades-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'Atividade_Usuario',
          filter: `atu_user_id=eq.${user.id}`,
        },
        () => {
          loadActivities()
        },
      )
      .subscribe()

    return () => {
      mounted = false
      supabase.removeChannel(channel)
    }
  }, [user?.id, saved])

  const changes = buildProfileChanges({
    currentUser: user,
    form,
    requestPasswordReset: !isAdmin && form.requestPasswordReset,
  })

  const permissions = useMemo(() => {
    const storedPermissions = user?.permissions || user?.perfil?.prf_permissoes || {}

    return PERMISSIONS.map((permission) => ({
      ...permission,
      granted: permission.key === 'admin' ? isAdmin : (isAdmin ? true : Boolean(storedPermissions[permission.key])),
    }))
  }, [isAdmin, user?.permissions, user?.perfil?.prf_permissoes])

  const grantedPermissions = useMemo(
    () => permissions.filter((permission) => permission.granted),
    [permissions]
  )


  async function handleAvatarFileChange(event) {
    const file = event.target.files?.[0]
    if (!file || !user?.id) return

    setUploadingAvatar(true)
    setError('')

    try {
      const publicUrl = await uploadAvatarFile({ file, userId: user.id })
      setForm((current) => ({ ...current, avatarUrl: publicUrl }))
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível enviar a foto. Tente novamente.'))
    } finally {
      setUploadingAvatar(false)
      event.target.value = ''
    }
  }

  const handleRecoveryPasswordSave = async () => {
    const cleanPassword = String(recoveryPassword || '')
    if (cleanPassword.length < 6) {
      setError('A nova senha precisa ter pelo menos 6 caracteres.')
      return
    }

    setRecoverySaving(true)
    setError('')

    try {
      const { error: passwordError } = await supabase.auth.updateUser({ password: cleanPassword })
      if (passwordError) throw passwordError

      clearRecoveryMode?.()
      setRecoveryPassword('')
      setNotice('Senha atualizada com sucesso.')
      setSaved(true)
      setTimeout(() => setSaved(false), 4000)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível atualizar a senha. Tente novamente.'))
    } finally {
      setRecoverySaving(false)
    }
  }

  const handleSave = async () => {
    setSaving(true)
    setError('')
    setNotice('')

    try {
      if (isAdmin) {
        const updatedProfile = await updateOwnProfileDirect({
          currentUser: user,
          form,
          newPassword: form.newPassword,
        })

        setUser((current) => ({
          ...current,
          name: updatedProfile.prf_nome || current.name,
          contactEmail: updatedProfile.prf_email_contato || current.email,
          phone: updatedProfile.prf_telefone || '',
          avatar: updatedProfile.prf_avatar_url || '',
          perfil: {
            ...(current.perfil || {}),
            ...updatedProfile,
          },
        }))

        setNotice('Perfil atualizado diretamente. Administradores não precisam de aprovação.')
      } else {
        if (!hasProfileChanges(changes)) {
          throw new Error('Nenhuma alteração foi informada.')
        }

        await requestProfileChange({
          currentUser: user,
          form,
          requestPasswordReset: form.requestPasswordReset,
        })

        setNotice('Solicitação enviada. Um administrador precisa aprovar a alteração.')
      }

      setForm((current) => ({ ...current, newPassword: '', requestPasswordReset: false }))
      setIsEditing(false)
      setSaved(true)
      setTimeout(() => setSaved(false), 4000)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível salvar as alterações. Tente novamente.'))
    } finally {
      setSaving(false)
    }
  }

  const initials = form.name?.split(' ').map((n) => n[0]).slice(0, 2).join('').toUpperCase()

  return (
    <div className="p-8 flex flex-col gap-6 animate-fade-in h-full min-h-0 overflow-hidden">
      {saved && (
        <div className="flex items-center gap-3 bg-status-success-bg border border-status-success/30 text-status-success font-semibold text-sm px-4 py-3 rounded-lg animate-slide-up flex-shrink-0">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <circle cx="9" cy="9" r="7" fill="currentColor" opacity=".15" />
            <path d="M5.5 9l2.5 2.5 5-5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          {notice || 'Alteração registrada com sucesso.'}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 flex-1 min-h-0">
        <Card className="profile-contrast-card lg:col-span-1 flex flex-col items-center text-center py-8 gap-4 h-full min-h-0 overflow-hidden">
          {form.avatarUrl ? (
            <img
              src={form.avatarUrl}
              alt={form.name || 'Foto do perfil'}
              className="w-28 h-28 rounded-full object-cover border-4 border-text-main/30 bg-slate-100"
            />
          ) : (
            <div className="w-28 h-28 rounded-full bg-text-main/20 border-4 border-text-main/30 flex items-center justify-center">
              <span className="text-2xl font-bold text-text-main">{initials}</span>
            </div>
          )}
          <div className="w-full text-center">
            <h2 className="text-card-title font-bold text-slate-800">{form.name}</h2>
            <p className="text-sm text-slate-500 mt-0.5">{form.role}</p>
            <button
              type="button"
              className="mx-auto mt-3 flex max-w-[240px] flex-col items-center gap-1 rounded-2xl px-4 py-2 text-xs font-semibold text-slate-500 transition hover:bg-bg-surface/70 hover:text-text-main focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
              onClick={() => setShowPrivateDetails((value) => !value)}
              aria-expanded={showPrivateDetails}
              title={showPrivateDetails ? 'Ocultar dados de contato' : 'Revelar dados de contato'}
            >
              <span className="max-w-full truncate">{showPrivateDetails ? form.email : maskEmail(form.email)}</span>
              <span>{showPrivateDetails ? (form.phone || 'Telefone não informado') : maskPhone(form.phone)}</span>
            </button>
          </div>
          <div className="w-full border-t border-border-soft pt-4">
            <button className="btn-primary w-full" onClick={() => setIsEditing(true)}>
              Editar Perfil
            </button>
          </div>

          <div className="mt-auto grid w-full grid-cols-2 gap-3 pt-2">
            <SettingsPanel
              variant="action"
              label="Acessibilidade"
              className="!py-2.5"
              panelClassName="!left-6 !bottom-6"
            />
            <button
              type="button"
              className="w-full rounded-xl border border-border-soft bg-bg-surface px-3 py-2.5 text-sm font-bold text-slate-600 transition-all hover:bg-slate-50 hover:text-status-critical focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
              onClick={signOut}
            >
              Sair
            </button>
          </div>
        </Card>

        <div className="lg:col-span-2 flex flex-col gap-5 h-full min-h-0 overflow-hidden">
          <Card className="profile-contrast-card flex-shrink-0">
            <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
              <h3 className="text-card-title font-bold text-slate-800">Permissões de Acesso</h3>
              {grantedPermissions.length > 0 && (
                <span className="rounded-full border border-status-success/30 bg-status-success-bg px-3 py-1 text-xs font-bold text-status-success">
                  Tem acesso
                </span>
              )}
            </div>

            {grantedPermissions.length === 0 ? (
              <div className="rounded-xl border border-border-soft bg-slate-50 px-4 py-3 text-sm text-slate-500">
                Nenhum módulo do painel foi liberado para este perfil.
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-2">
                {grantedPermissions.map((p) => (
                  <div key={p.key} className="flex items-center gap-2 text-sm">
                    <span className="w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 bg-status-success-bg">
                      <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                        <path d="M2 5l2 2 4-4" stroke="#02c602" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </span>
                    <span className="text-slate-700">{p.label}</span>
                  </div>
                ))}
              </div>
            )}
          </Card>

          <Card className="profile-contrast-card flex-1 min-h-0 overflow-hidden flex flex-col">
            <h3 className="text-card-title font-bold text-slate-800 mb-4 flex-shrink-0">Atividade Recente</h3>
            <div className="flex-1 min-h-0 overflow-y-auto pr-2 -mr-2">
              <ActivityList activities={activities} currentUser={user} />
            </div>
          </Card>
        </div>
      </div>

      <Modal isOpen={Boolean(recoveryMode)} onClose={() => {}} title="Definir nova senha" size="sm">
        <div className="space-y-4">
          <div className="rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-sm text-blue-800 leading-relaxed">
            Você abriu um link de redefinição de senha. Digite uma nova senha para concluir.
          </div>

          {error && (
            <div className="rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          )}

          <div>
            <label className="block text-label text-slate-600 mb-1.5">NOVA SENHA</label>
            <input
              type="password"
              className="input-field"
              value={recoveryPassword}
              placeholder="Mínimo 6 caracteres"
              onChange={(event) => setRecoveryPassword(event.target.value)}
              autoFocus
            />
          </div>

          <button className="btn-primary w-full" onClick={handleRecoveryPasswordSave} disabled={recoverySaving}>
            {recoverySaving ? 'Atualizando...' : 'Atualizar senha'}
          </button>
        </div>
      </Modal>

      <Modal isOpen={isEditing} onClose={() => setIsEditing(false)} title="Editar Perfil" size="md">
        <div className="space-y-4">
          {error && (
            <div className="rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          )}

          {!isAdmin && (
            <div className="rounded-xl border border-yellow-100 bg-yellow-50 px-4 py-3 text-xs text-yellow-800 leading-relaxed">
              Usuários comuns solicitam alteração para aprovação. Administradores alteram diretamente.
            </div>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2">
              <label className="block text-label text-slate-600 mb-1.5">NOME COMPLETO</label>
              <input className="input-field" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="col-span-2">
              <label className="block text-label text-slate-600 mb-1.5">FOTO DO PERFIL</label>
              <div className="flex items-center gap-3">
                {form.avatarUrl ? (
                  <img src={form.avatarUrl} alt="Prévia da foto" className="w-12 h-12 rounded-full object-cover border border-border-soft" />
                ) : (
                  <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center text-xs font-bold text-slate-500">{initials}</div>
                )}

                <label className="btn-ghost cursor-pointer">
                  {uploadingAvatar ? 'Enviando...' : 'Enviar foto'}
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    disabled={uploadingAvatar}
                    onChange={handleAvatarFileChange}
                  />
                </label>
              </div>
            </div>

            <div>
              <label className="block text-label text-slate-600 mb-1.5">E-MAIL DE CONTATO</label>
              <input type="email" className="input-field" value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} />
            </div>
            <div>
              <label className="block text-label text-slate-600 mb-1.5">TELEFONE</label>
              <input
                className="input-field"
                inputMode="numeric"
                maxLength={15}
                value={form.phone}
                placeholder="(12) 98703-7110"
                onChange={(e) => setForm((f) => ({ ...f, phone: formatBrazilPhone(e.target.value) }))}
              />
            </div>
          </div>

          {isAdmin ? (
            <div>
              <label className="block text-label text-slate-600 mb-1.5">NOVA SENHA DO ADMIN OPCIONAL</label>
              <input
                type="password"
                className="input-field"
                value={form.newPassword}
                placeholder="Deixe em branco para não alterar"
                onChange={(e) => setForm((f) => ({ ...f, newPassword: e.target.value }))}
              />
            </div>
          ) : (
            <label className="flex items-center gap-2 text-sm text-slate-600">
              <input
                type="checkbox"
                checked={form.requestPasswordReset}
                onChange={(e) => setForm((f) => ({ ...f, requestPasswordReset: e.target.checked }))}
              />
              Solicitar redefinição de senha ao administrador
            </label>
          )}

          {!isAdmin && <ChangePreview changes={changes} />}

          <div className="flex items-center justify-end gap-3 pt-2 border-t border-border-soft">
            <button className="btn-ghost" onClick={() => setIsEditing(false)} disabled={saving}>Cancelar</button>
            <button className="btn-primary" onClick={handleSave} disabled={saving}>
              {saving ? 'Salvando...' : isAdmin ? 'Salvar Alterações' : 'Enviar Solicitação'}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
