import { useEffect, useState } from 'react'
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
import Sidebar from './components/Sidebar.jsx'
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
  const permissions = user?.permissions || {}

  function canOpenScreen(screenId) {
    if (screenId === 'perfil') return true
    if (['admin', 'users'].includes(screenId)) return canOpenAdmin
    if (devBypassAuth) return true

    const permissionKeyByScreen = {
      dashboard: 'dashboard',
      reportar: 'reportar',
      abrigos: 'ocorrencias',
      ocorrencias: 'ocorrencias',
      relatorios: 'relatorios',
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
  }, [currentScreen, canOpenAdmin, devBypassAuth, recoveryMode, permissions.dashboard, permissions.reportar, permissions.ocorrencias, permissions.relatorios, permissions.auditoria])

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
    <div className="flex h-screen bg-bg-main overflow-hidden">
      <Sidebar currentScreen={currentScreen} setCurrentScreen={setCurrentScreen} onLogout={handleLogout} />
      <main className="flex-1 overflow-y-auto">
        <ActiveScreen />
      </main>
    </div>
  )
}
