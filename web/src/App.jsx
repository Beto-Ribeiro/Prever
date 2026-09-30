import { useEffect, useState } from 'react'
import ManagerPortal from './screens/manager/ManagerPortal.jsx'
import Login from './screens/Login.jsx'
import Dashboard from './screens/Dashboard.jsx'
import Reportar from './screens/Reportar.jsx'
import Abrigos from './screens/Abrigos.jsx'
import Ocorrencias from './screens/Ocorrencias.jsx'
import Relatorios from './screens/Relatorios.jsx'
import Auditoria from './screens/Auditoria.jsx'
import Perfil from './screens/Perfil.jsx'
import AdminPanel from './screens/AdminPanel.jsx'
import UserList from './screens/UserList.jsx'
import ValidacaoAntifraude from './screens/ValidacaoAntifraude.jsx'
import Sidebar from './components/Sidebar.jsx'
import { APIProvider } from '@vis.gl/react-google-maps'
import { useAuth } from './hooks/useAuth.js'
import { createWebAccessRequest } from './backend/auth/webAccessService.js'

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
  const { isAuthenticated, loading, isAdmin, user, recoveryMode, signIn, signOut } = useAuth()
  const [currentScreen, setCurrentScreen] = useState('dashboard')
  const [loginView, setLoginView] = useState('login')

  const { devBypassAuth, devBypassAdmin } = getDevBypassFlags()
  const canRenderApp = isAuthenticated || devBypassAuth
  const canOpenAdmin = isAdmin || devBypassAdmin
  const isManager = user?.role === 'shelter_manager'
  const permissions = user?.permissions || {}

  function canOpenScreen(screenId) {
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
  }

  useEffect(() => {
    if (recoveryMode) {
      setCurrentScreen('perfil')
      return
    }

    if (!canOpenScreen(currentScreen)) {
      setCurrentScreen(canOpenScreen('dashboard') ? 'dashboard' : 'perfil')
    }
  }, [currentScreen, isManager, canOpenAdmin, devBypassAuth, recoveryMode, permissions.dashboard, permissions.reportar, permissions.ocorrencias, permissions.relatorios, permissions.validacao, permissions.auditoria, user?.role])

  const handleLogin = async ({ email, password }) => {
    await signIn({ email, password })
  }

  const handleRegister = async ({ institution, name, email, role, documentNumber }) => {
    await createWebAccessRequest({ institution, name, email, role, documentNumber })
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
      />
    )
  }

  const ActiveScreen = SCREENS[currentScreen] || Dashboard

  return (
    <APIProvider apiKey={import.meta.env.VITE_GOOGLE_MAPS_API_KEY} version="beta">
      <div className="flex h-screen bg-bg-main overflow-hidden">
        <a href="#main-content" className="skip-link">Ir para o conteúdo</a>
        <Sidebar currentScreen={currentScreen} setCurrentScreen={setCurrentScreen} onLogout={handleLogout} />
        <main id="main-content" tabIndex={-1} data-nimbo-account={user?.id} data-nimbo-screen={currentScreen} className="flex-1 min-w-0 h-full overflow-y-auto">
          {isManager ? <ManagerPortal key={user.id} screen={canOpenScreen(currentScreen) ? currentScreen : 'dashboard'} /> : <ActiveScreen />}
        </main>
      </div>
    </APIProvider>
  )
}
