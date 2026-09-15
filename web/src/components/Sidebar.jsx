import { useEffect, useRef, useState } from 'react'
import { useAuth } from '../hooks/useAuth.js'
import logoClaro from '../assets/logo-claro.svg'
import logoEscuro from '../assets/logo.svg'
import faviconIcon from '../assets/favicon.svg'
import SettingsPanel from './SettingsPanel.jsx'
import AssistantWidget from './AssistantWidget.jsx'
import { useSmdnSettings } from '../hooks/useSmdnSettings.js'
import { supabase } from '../backend/supabase/client.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'


function FeatherIcon({ name, size = 20 }) {
  const commonProps = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: '2',
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': 'true',
    focusable: 'false',
  }

  const paths = {
    'map-pin': (
      <>
        <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0Z" />
        <circle cx="12" cy="10" r="3" />
      </>
    ),
    flag: (
      <>
        <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" />
        <line x1="4" y1="22" x2="4" y2="15" />
      </>
    ),
    home: (
      <>
        <path d="M3 11.5 12 4l9 7.5" />
        <path d="M5.5 10.5V20h13v-9.5" />
        <path d="M9.5 20v-6h5v6" />
      </>
    ),
    'alert-triangle': (
      <>
        <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z" />
        <line x1="12" y1="9" x2="12" y2="13" />
        <line x1="12" y1="17" x2="12.01" y2="17" />
      </>
    ),
    'pie-chart': (
      <>
        <path d="M21.21 15.89A10 10 0 1 1 8 2.83" />
        <path d="M22 12A10 10 0 0 0 12 2v10z" />
      </>
    ),
    lock: (
      <>
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
      </>
    ),
    user: (
      <>
        <path d="M20 21a8 8 0 0 0-16 0" />
        <circle cx="12" cy="7" r="4" />
      </>
    ),
    shield: (
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
    ),
    users: (
      <>
        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
        <circle cx="9" cy="7" r="4" />
        <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
        <path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </>
    ),
    'log-out': (
      <>
        <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
        <polyline points="16 17 21 12 16 7" />
        <line x1="21" y1="12" x2="9" y2="12" />
      </>
    ),
  }

  return <svg {...commonProps}>{paths[name] || paths.user}</svg>
}

function getLocalDevBypass() {
  const isLocalhost =
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1'

  const devBypassAuth =
    import.meta.env.DEV &&
    import.meta.env.VITE_DEV_BYPASS_AUTH === 'true' &&
    isLocalhost

  const devBypassAdmin =
    devBypassAuth &&
    import.meta.env.VITE_DEV_BYPASS_ADMIN === 'true'

  return { devBypassAuth, devBypassAdmin }
}

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: <FeatherIcon name="map-pin" />, iconWhite: <FeatherIcon name="map-pin" /> },
  { id: 'reportar', label: 'Reportar', icon: <FeatherIcon name="flag" />, iconWhite: <FeatherIcon name="flag" /> },
  { id: 'abrigos', label: 'Abrigos', permissionKey: 'ocorrencias', icon: <FeatherIcon name="home" />, iconWhite: <FeatherIcon name="home" /> },
  { id: 'ocorrencias', label: 'Ocorrências', icon: <FeatherIcon name="alert-triangle" />, iconWhite: <FeatherIcon name="alert-triangle" /> },
  { id: 'relatorios', label: 'Relatórios', icon: <FeatherIcon name="pie-chart" />, iconWhite: <FeatherIcon name="pie-chart" /> },
  { id: 'auditoria', label: 'Auditoria', icon: <FeatherIcon name="lock" />, iconWhite: <FeatherIcon name="lock" /> },
  { id: 'perfil', label: 'Perfil', icon: <FeatherIcon name="user" />, iconWhite: <FeatherIcon name="user" /> },
]

const ADMIN_ITEMS = [
  { id: 'admin', label: 'Painel do Admin', icon: <FeatherIcon name="shield" />, iconWhite: <FeatherIcon name="shield" /> },
  { id: 'users', label: 'Lista de Usuário', icon: <FeatherIcon name="users" />, iconWhite: <FeatherIcon name="users" /> },
]

const DASHBOARD_ALERTS_SEEN_KEY = 'smdn_dashboard_alerts_seen_count'

function readSeenDashboardAlerts() {
  return Number(localStorage.getItem(DASHBOARD_ALERTS_SEEN_KEY) || '0')
}

function writeSeenDashboardAlerts(value) {
  localStorage.setItem(DASHBOARD_ALERTS_SEEN_KEY, String(value || 0))
}

function getInitials(name) {
  return String(name || '')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function UserAvatar({ user, size = 'sm' }) {
  const avatarUrl = user?.avatar || user?.perfil?.prf_avatar_url
  const sizeClasses = {
    sm: 'w-8 h-8 text-xs',
    collapsed: 'w-10 h-10 text-xs',
    lg: 'w-16 h-16 text-xl',
  }
  const sizeClass = sizeClasses[size] || sizeClasses.sm
  const compactClass =
    size === 'collapsed'
      ? 'border-white/70 bg-bg-surface shadow-sm ring-2 ring-white/40'
      : 'border-white/10 bg-text-main/30'

  if (avatarUrl) {
    return (
      <img
        src={avatarUrl}
        alt={user?.name || 'Foto do usuário'}
        className={`${sizeClass} block rounded-full object-cover object-center border ${compactClass} flex-shrink-0`}
      />
    )
  }

  return (
    <div className={`${sizeClass} rounded-full ${compactClass} flex items-center justify-center flex-shrink-0`}>
      <span className="text-text-on-dark font-bold">
        {getInitials(user?.name)}
      </span>
    </div>
  )
}

function NavButton({ item, currentScreen, setCurrentScreen, badge, collapsed = false }) {
  const active = currentScreen === item.id

  return (
    <button
      key={item.id}
      type="button"
      title={collapsed ? item.label : undefined}
      onClick={() => setCurrentScreen(item.id)}
      aria-current={active ? 'page' : undefined}
      className={`
        group relative w-full flex items-center gap-3 rounded-lg text-sm font-medium text-left transition-all duration-200 ease-out ${collapsed ? 'h-9 justify-center px-0 py-0' : 'h-9 px-3 py-0'}
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main
        ${active
          ? 'bg-text-main text-white shadow-sm'
          : `text-text-on-dark hover:bg-text-main/10 hover:text-text-main hover:shadow-sm ${collapsed ? '' : 'hover:translate-x-1'}`
        }
      `}
    >
      <span className="transition-transform duration-200 ease-out group-hover:scale-105">{active ? item.iconWhite : item.icon}</span>
      <span className={collapsed ? 'sr-only' : 'truncate'}>{item.label}</span>
      {badge && (
        <span className={`notification-badge inline-flex min-w-5 items-center justify-center rounded-full px-1.5 py-0.5 text-[10px] font-black leading-none ${collapsed ? 'absolute -right-1 -top-1' : 'ml-auto'}`}>
          {badge}
        </span>
      )}
    </button>
  )
}

export default function Sidebar({ currentScreen, setCurrentScreen, onLogout }) {
  const { user, isAdmin, savedAccounts, switchAccount, startAddAccount } = useAuth()
  const { effectiveTheme } = useSmdnSettings()
  const { devBypassAuth, devBypassAdmin } = getLocalDevBypass()
  const showAdmin = isAdmin || devBypassAdmin

  const displayUser =
    user ||
    (devBypassAuth
      ? {
          name: 'Dev Local',
          roleLabel: devBypassAdmin ? 'Administrador local' : 'Bypass local',
        }
      : null)

  const permissions = displayUser?.permissions || {}
  const managerItems = [['dashboard', 'Visão geral', 'home'], ['ocupantes', 'Ocupantes', 'users'], ['estoque', 'Estoque', 'home'], ['pedidos', 'Pedidos de ajuda', 'flag'], ['relatorios', 'Relatórios', 'pie-chart'], ['perfil', 'Perfil', 'user']].map(([id, label, icon]) => ({ id, label, icon: <FeatherIcon name={icon} />, iconWhite: <FeatherIcon name={icon} /> }))
  const visibleNavItems = user?.role === 'shelter_manager' ? managerItems : NAV_ITEMS.filter((item) => {
    if (item.id === 'perfil') return true
    return Boolean(permissions[item.permissionKey || item.id]) || devBypassAuth
  })

  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false)
  const [showProfilePopup, setShowProfilePopup] = useState(false)
  const [accountSwitchError, setAccountSwitchError] = useState('')
  const [notifications, setNotifications] = useState({ dashboard: '', admin: 0 })
  const [collapsed, setCollapsed] = useState(() => localStorage.getItem('smdn_sidebar_collapsed') === 'true')

  const popupRef = useRef(null)
  const buttonRef = useRef(null)

  useEffect(() => {
    function handleClickOutside(event) {
      if (
        showProfilePopup &&
        popupRef.current &&
        !popupRef.current.contains(event.target) &&
        buttonRef.current &&
        !buttonRef.current.contains(event.target)
      ) {
        setShowProfilePopup(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showProfilePopup])

  useEffect(() => {
    let mounted = true

    async function loadNotifications() {
      try {
        const [{ count: alertCount }, { count: accessCount }, { count: profileCount }] = await Promise.all([
          supabase
            .from('Alerta_Web')
            .select('alw_id', { count: 'exact', head: true })
            .eq('alw_status', 'disparado'),
          showAdmin
            ? supabase
                .from('Solicitacao_Acesso_Web')
                .select('saw_id', { count: 'exact', head: true })
                .eq('saw_status', 'pendente')
            : Promise.resolve({ count: 0 }),
          showAdmin
            ? supabase
                .from('Solicitacao_Alteracao_Perfil')
                .select('sap_id', { count: 'exact', head: true })
                .eq('sap_status', 'pendente')
            : Promise.resolve({ count: 0 }),
        ])

        if (!mounted) return

        const totalAlerts = alertCount || 0
        if (currentScreen === 'dashboard') {
          writeSeenDashboardAlerts(totalAlerts)
        }

        const seenAlerts = currentScreen === 'dashboard' ? totalAlerts : readSeenDashboardAlerts()
        setNotifications({
          dashboard: totalAlerts > seenAlerts ? '!' : '',
          admin: (accessCount || 0) + (profileCount || 0),
        })
      } catch (error) {
        console.warn('Não foi possível carregar notificações da sidebar:', error.message)
      }
    }

    loadNotifications()

    const channel = supabase
      .channel('sidebar-notifications')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'Alerta_Web' }, loadNotifications)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'Solicitacao_Acesso_Web' }, loadNotifications)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'Solicitacao_Alteracao_Perfil' }, loadNotifications)
      .subscribe()

    return () => {
      mounted = false
      supabase.removeChannel(channel)
    }
  }, [currentScreen, showAdmin])

  useEffect(() => {
    localStorage.setItem('smdn_sidebar_collapsed', collapsed ? 'true' : 'false')
  }, [collapsed])

  async function handleSwitchAccount(accountId) {
    setAccountSwitchError('')

    try {
      await switchAccount(accountId)
      setShowProfilePopup(false)
    } catch (error) {
      setAccountSwitchError(toFriendlyMessage(error, 'Não foi possível alternar a conta. Faça login novamente.'))
    }
  }

  async function handleAddAccount() {
    setAccountSwitchError('')
    setShowProfilePopup(false)
    await startAddAccount()
  }

  return (
    <>
      <aside
        className={`sidebar-scroll relative flex h-screen flex-col overflow-hidden bg-bg-sidebar shadow-sidebar z-[10000] transition-[width,min-width] duration-200 ${collapsed ? 'w-[76px] min-w-[76px]' : 'w-[220px] min-w-[220px]'}`}
      >
        <div className={`relative shrink-0 border-b border-white/5 ${collapsed ? 'px-2 pt-9 pb-3' : 'px-5 pt-5 pb-4'}`}>
          <img
            src={collapsed ? faviconIcon : (effectiveTheme === 'light' ? logoEscuro : logoClaro)}
            alt="PREVER Logo"
            className={collapsed ? 'mx-auto h-10 w-10 max-w-[40px] rounded-xl object-contain' : 'mx-auto h-12 w-full max-w-[160px] object-contain object-center'}
          />
          <button
            type="button"
            onClick={() => setCollapsed((value) => !value)}
            className={`absolute ${collapsed ? 'left-1/2 top-2 -translate-x-1/2' : 'right-2 top-2'} inline-flex h-7 w-7 items-center justify-center rounded-lg border border-white/10 bg-white/5 text-text-on-dark/80 hover:bg-white/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-white`}
            aria-label={collapsed ? 'Expandir menu lateral' : 'Minimizar menu lateral'}
            title={collapsed ? 'Expandir menu' : 'Minimizar menu'}
          >
            {collapsed ? (
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <line x1="5" y1="12" x2="19" y2="12" />
                <polyline points="12 5 19 12 12 19" />
              </svg>
            ) : (
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <line x1="19" y1="12" x2="5" y2="12" />
                <polyline points="12 19 5 12 12 5" />
              </svg>
            )}
          </button>
        </div>

        <nav className={`min-h-0 flex-1 overflow-hidden ${collapsed ? 'px-2 py-2 space-y-1' : 'px-3 py-2.5 space-y-0.5'}`}>
          {visibleNavItems.map((item) => (
            <NavButton
              key={item.id}
              item={item}
              currentScreen={currentScreen}
              setCurrentScreen={setCurrentScreen}
              badge={notifications[item.id]}
              collapsed={collapsed}
            />
          ))}

          {showAdmin && (
            <div className={collapsed ? 'mt-2 border-t border-white/10 pt-2' : 'pt-2 mt-2 border-t border-white/10'}>
              <p className={`px-3 pb-1 text-[10px] uppercase tracking-[0.18em] text-text-on-dark/50 font-bold ${collapsed ? 'sr-only' : ''}`}>
                Administração
              </p>

              <div className="space-y-0.5">
                {ADMIN_ITEMS.map((item) => (
                  <NavButton
                    key={item.id}
                    item={item}
                    currentScreen={currentScreen}
                    setCurrentScreen={setCurrentScreen}
                    badge={item.id === 'admin' && notifications.admin ? notifications.admin : ''}
                    collapsed={collapsed}
                  />
                ))}
              </div>
            </div>
          )}
        </nav>

        <div className={`shrink-0 border-t border-white/5 ${collapsed ? 'px-2 py-2 space-y-1' : 'px-3 py-2.5 space-y-1'}`}>
          <AssistantWidget currentScreen={currentScreen} setCurrentScreen={setCurrentScreen} compact={collapsed} dense />

          {displayUser && (
            <div className="relative">
              <button
                ref={buttonRef}
                type="button"
                onClick={() => { setAccountSwitchError(''); setShowProfilePopup((value) => !value) }}
                title={collapsed ? `${displayUser.name} - abrir perfil` : undefined}
                aria-label={collapsed ? `${displayUser.name} - abrir perfil` : undefined}
                className={collapsed
                  ? 'mx-auto flex h-11 w-11 items-center justify-center rounded-2xl p-0 transition-all hover:bg-text-main/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main'
                  : 'w-full flex items-center gap-3 rounded-lg px-3 py-1.5 hover:bg-white/5 transition-all'
                }
              >
                <UserAvatar user={displayUser} size={collapsed ? 'collapsed' : 'sm'} />

                <div className={collapsed ? 'sr-only' : 'min-w-0 text-left'}>
                  <p className="text-text-on-dark text-xs font-semibold truncate">
                    {displayUser.name}
                  </p>
                  <p className="text-text-on-dark text-[10px] opacity-60 truncate">
                    {displayUser.roleLabel || displayUser.role}
                  </p>
                </div>
              </button>

              {showProfilePopup && (
                <div
                  ref={popupRef}
                  className={`fixed bottom-14 w-72 bg-bg-surface rounded-2xl shadow-2xl p-5 pt-6 z-[99999] border border-border-soft ${collapsed ? 'left-[70px]' : 'left-[210px]'}`}
                >
                  <div className="absolute left-4 top-4">
                    <SettingsPanel variant="icon" panelClassName="bottom-20" />
                  </div>

                  <button
                    type="button"
                    onClick={() => {
                      setShowProfilePopup(false)
                      setShowLogoutConfirm(true)
                    }}
                    className="absolute right-4 top-4 inline-flex h-9 w-9 items-center justify-center rounded-xl border border-border-soft bg-bg-surface text-slate-500 hover:bg-red-50 hover:text-red-600 transition-all"
                    title="Sair"
                    aria-label="Sair da conta"
                  >
                    <FeatherIcon name="log-out" size={18} />
                  </button>

                  <div className="flex flex-col items-center">
                    <UserAvatar user={displayUser} size="lg" />

                    <div className="mt-3 w-full px-10 text-center">
                      <h3 className="font-bold text-slate-800 truncate">
                        {displayUser.name}
                      </h3>

                      <p className="text-sm text-slate-500 truncate">
                        {displayUser.roleLabel || displayUser.role}
                      </p>
                    </div>

                    <div className="w-full border-t mt-3 pt-3 text-sm text-slate-600 space-y-2 text-center">
                      <p>{displayUser.institution || displayUser.instituicao?.ins_numero || 'PREVER'}</p>
                    </div>

                    <button
                      onClick={() => {
                        setCurrentScreen('perfil')
                        setShowProfilePopup(false)
                      }}
                      className="btn-primary w-full mt-4"
                    >
                      Abrir Perfil
                    </button>

                    <div className="mt-4 w-full border-t border-border-soft pt-3">
                      <div className="mb-2 flex items-center justify-between gap-2">
                        <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-slate-400">Contas</p>
                        <button
                          type="button"
                          onClick={handleAddAccount}
                          className="rounded-lg border border-border-soft px-2 py-1 text-[11px] font-bold text-text-main hover:bg-text-main/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
                        >
                          + Adicionar
                        </button>
                      </div>

                      {accountSwitchError && (
                        <p className="mb-2 rounded-lg border border-yellow-200 bg-yellow-50 px-2 py-1.5 text-left text-[11px] font-semibold text-yellow-800">
                          {accountSwitchError}
                        </p>
                      )}

                      <div className="flex flex-wrap items-center gap-2">
                        {(savedAccounts || []).map((account) => {
                          const activeAccount = account.id === displayUser?.id
                          return (
                            <button
                              key={account.id}
                              type="button"
                              disabled={activeAccount}
                              onClick={() => handleSwitchAccount(account.id)}
                              className={`group relative rounded-full border p-0.5 transition-all ${activeAccount ? 'border-text-main bg-text-main/10' : 'border-border-soft bg-bg-surface hover:border-text-main hover:bg-text-main/10'}`}
                              title={`${account.name} ${activeAccount ? '(conta atual)' : account.email}`}
                              aria-label={`Alternar para ${account.name}`}
                            >
                              <UserAvatar user={account} />
                              {activeAccount && (
                                <span className="absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-bg-surface bg-status-success" aria-hidden="true" />
                              )}
                            </button>
                          )
                        })}
                      </div>

                      <p className="mt-2 text-left text-[10px] leading-snug text-slate-400">
                        48h sem acesso pede login novamente.
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </aside>

      {showLogoutConfirm && (
        <div className="fixed inset-0 z-[100000] flex items-center justify-center">
          <div className="absolute inset-0 bg-black/40" onClick={() => setShowLogoutConfirm(false)} />

          <div className="relative bg-bg-surface rounded-2xl shadow-modal px-8 py-7 flex flex-col items-center gap-4 max-w-xs w-full mx-4 animate-slide-up border border-border-soft">
            <div className="w-12 h-12 rounded-full bg-text-main/10 text-text-main flex items-center justify-center">
              <FeatherIcon name="log-out" size={22} />
            </div>

            <div className="text-center">
              <h3 className="text-lg font-bold text-slate-800">Deseja fazer logout?</h3>
              <p className="text-sm text-slate-500 mt-1">Você será redirecionado para a tela de login.</p>
            </div>

            <div className="flex gap-3 w-full mt-1">
              <button
                onClick={() => setShowLogoutConfirm(false)}
                className="flex-1 py-2.5 rounded-lg border border-border-soft text-sm font-semibold text-slate-600 hover:bg-slate-50 transition-all"
              >
                Não
              </button>

              <button
                onClick={() => {
                  setShowLogoutConfirm(false)
                  onLogout()
                }}
                className="flex-1 py-2.5 rounded-lg bg-text-main text-white text-sm font-semibold hover:bg-action-hover transition-all disabled:opacity-60"
              >
                Sim, sair
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
