import { lazy, Suspense, useCallback, useEffect, useState } from 'react'
import Login from './screens/Login.jsx'
import Sidebar from './components/Sidebar.jsx'
import { APIProvider } from '@vis.gl/react-google-maps'
import { useAuth } from './hooks/useAuth.js'
import { createWebAccessRequest } from './backend/auth/webAccessService.js'

const Dashboard = lazy(() => import('./screens/Dashboard.jsx'))
const Reportar = lazy(() => import('./screens/Reportar.jsx'))
const Abrigos = lazy(() => import('./screens/Abrigos.jsx'))
const Ocorrencias = lazy(() => import('./screens/Ocorrencias.jsx'))
const Relatorios = lazy(() => import('./screens/Relatorios.jsx'))
const ValidacaoAntifraude = lazy(() => import('./screens/ValidacaoAntifraude.jsx'))
const Auditoria = lazy(() => import('./screens/Auditoria.jsx'))
const Perfil = lazy(() => import('./screens/Perfil.jsx'))
const AdminPanel = lazy(() => import('./screens/AdminPanel.jsx'))
const UserList = lazy(() => import('./screens/UserList.jsx'))
const ManagerPortal = lazy(() => import('./screens/manager/ManagerPortal.jsx'))

function AdminHomeScreen() {
  return <AdminPanel initialTab="all" />
}

const SCREENS = {
  dashboard: Dashboard,
  reportar: Reportar,
  abrigos: Abrigos,
  ocorrencias: Ocorrencias,
  relatorios: Relatorios,
  validacao: ValidacaoAntifraude,
  auditoria: Auditoria,
  perfil: Perfil,
  admin: AdminHomeScreen,
  users: UserList,
}

function ScreenFallback() {
  return (
    <div className="flex h-full w-full items-center justify-center p-8" role="status" aria-live="polite">
      <div className="rounded-2xl bg-bg-surface px-6 py-4 shadow-sm border border-border-soft text-center">
        <p className="text-sm font-semibold text-slate-700">Carregando módulo…</p>
      </div>
    </div>
  )
}

function getDevBypassFlags() {
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

export default function App() {
  const { isAuthenticated, loading, isAdmin, user, recoveryMode, accessError, signIn, signOut } = useAuth()
  const [currentScreen, setCurrentScreen] = useState('dashboard')
  const [loginView, setLoginView] = useState('login')

  const { devBypassAuth, devBypassAdmin } = getDevBypassFlags()
  const canRenderApp = isAuthenticated || devBypassAuth
  const canOpenAdmin = isAdmin || devBypassAdmin
  const isManager = user?.role === 'shelter_manager'

  const canOpenScreen = useCallback((screenId) => {
    const permissions = user?.permissions || {}
    if (isManager) return ['dashboard', 'ocupantes', 'estoque', 'pedidos', 'relatorios', 'perfil'].includes(screenId)
    if (screenId === 'perfil') return true
    if (['admin', 'users'].includes(screenId)) return canOpenAdmin
    if (screenId === 'validacao') return ['admin', 'defesa_civil', 'bombeiros'].includes(user?.role) || devBypassAuth || canOpenAdmin
    if (devBypassAuth) return true

    const permissionKeyByScreen = {
      dashboard: 'dashboard',
      reportar: 'reportar',
      abrigos: 'ocorrencias',
      ocorrencias: 'ocorrencias',
      relatorios: 'relatorios',
      validacao: 'validacao',
      auditoria: 'auditoria',
    }

    const permissionKey = permissionKeyByScreen[screenId]
    return permissionKey ? Boolean(permissions[permissionKey]) : false
  }, [isManager, canOpenAdmin, devBypassAuth, user?.permissions, user?.role])

  useEffect(() => {
    if (recoveryMode) {
      setCurrentScreen('perfil')
      return
    }

    if (!canOpenScreen(currentScreen)) {
      setCurrentScreen(canOpenScreen('dashboard') ? 'dashboard' : 'perfil')
    }
  }, [currentScreen, recoveryMode, canOpenScreen])

  const handleLogin = async ({ email, password, rememberMe }) => {
    await signIn({ email, password, rememberMe })
  }

  const handleRegister = async ({ institution, name, email, role, documentNumber, password }) => {
    await createWebAccessRequest({ institution, name, email, role, documentNumber, password })
  }

  const handleLogout = async () => {
    if (isAuthenticated) {
      await signOut()
    }

    setCurrentScreen('dashboard')
    setLoginView('login')
  }

  if (loading && !devBypassAuth) {
    return (
      <div className="flex h-screen w-full items-center justify-center bg-bg-main">
        <div className="rounded-2xl bg-white px-8 py-6 shadow-modal text-center">
          <p className="text-sm font-semibold text-slate-700">Carregando sessão...</p>
          <p className="text-xs text-slate-400 mt-1">Preparando seu acesso ao painel</p>
        </div>
      </div>
    )
  }

  if (!canRenderApp) {
    return (
      <Login
        view={loginView}
        setView={setLoginView}
        onLogin={handleLogin}
        onRegister={handleRegister}
        initialError={accessError}
      />
    )
  }

  const ActiveScreen = SCREENS[currentScreen] || Dashboard

  return (
    <APIProvider apiKey={import.meta.env.VITE_GOOGLE_MAPS_API_KEY} version="alpha">
      <div className="flex h-screen bg-bg-main overflow-hidden">
        <a href="#main-content" className="skip-link">Ir para o conteúdo</a>
        <Sidebar currentScreen={currentScreen} setCurrentScreen={setCurrentScreen} onLogout={handleLogout} />
        <main id="main-content" tabIndex={-1} data-nimbo-account={user?.id} data-nimbo-screen={currentScreen} className="flex-1 min-w-0 h-full overflow-y-auto">
          <Suspense fallback={<ScreenFallback />}>
            {isManager ? <ManagerPortal key={user.id} screen={canOpenScreen(currentScreen) ? currentScreen : 'dashboard'} /> : <ActiveScreen />}
          </Suspense>
        </main>
      </div>
    </APIProvider>
  )
}
