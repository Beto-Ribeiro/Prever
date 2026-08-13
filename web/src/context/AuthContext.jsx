import { createContext, useEffect, useMemo, useState } from 'react'
import { supabase } from '../backend/supabase/client.js'
import { signInWithEmailAndPassword, signOutFromSupabase } from '../backend/auth/authService.js'
import { getWebAccessForUser } from '../backend/auth/webAccessService.js'
import { recordLoginActivity } from '../backend/perfil/profileActivityService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'

export const AuthContext = createContext()

const SAVED_ACCOUNTS_KEY = 'smdn_saved_accounts_v1'
const ACCOUNT_TTL_MS = 48 * 60 * 60 * 1000

function readSavedAccounts() {
  try {
    return JSON.parse(localStorage.getItem(SAVED_ACCOUNTS_KEY) || '[]')
  } catch {
    return []
  }
}

function writeSavedAccounts(accounts) {
  localStorage.setItem(SAVED_ACCOUNTS_KEY, JSON.stringify(accounts))
}

function publicAccountData(session, accessUser) {
  if (!session?.user?.id || !session?.access_token || !session?.refresh_token) return null

  return {
    id: session.user.id,
    email: session.user.email || accessUser?.email || '',
    name: accessUser?.name || session.user.email?.split('@')[0] || 'Usuário PREVER',
    roleLabel: accessUser?.roleLabel || accessUser?.role || 'Usuário',
    avatar: accessUser?.avatar || accessUser?.perfil?.prf_avatar_url || null,
    lastAccess: Date.now(),
    session: {
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_at: session.expires_at,
      expires_in: session.expires_in,
      token_type: session.token_type,
      user: session.user,
    },
  }
}

function upsertSavedAccount(account) {
  if (!account?.id) return readSavedAccounts()
  const next = [account, ...readSavedAccounts().filter((item) => item.id !== account.id)]
  writeSavedAccounts(next)
  return next
}

function removeSavedAccount(accountId) {
  const next = readSavedAccounts().filter((item) => item.id !== accountId)
  writeSavedAccounts(next)
  return next
}

function isSavedAccountExpired(account) {
  return !account?.lastAccess || Date.now() - account.lastAccess > ACCOUNT_TTL_MS
}

export const AuthProvider = ({ children }) => {
  const [session, setSession] = useState(null)
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [accessError, setAccessError] = useState('')
  const [recoveryMode, setRecoveryMode] = useState(false)
  const [savedAccounts, setSavedAccounts] = useState(() => readSavedAccounts())

  async function applySession(nextSession, { signOutWhenUnauthorized = true } = {}) {
    if (!nextSession?.user) {
      setSession(null)
      setUser(null)
      setAccessError('')
      return null
    }

    const access = await getWebAccessForUser(nextSession.user)

    console.info('[PREVER Acesso] Resultado da autorização web:', {
      allowed: access?.allowed,
      role: access?.role,
      isAdmin: access?.isAdmin,
      reason: access?.reason,
    })

    if (!access.allowed) {
      setSession(null)
      setUser(null)
      setAccessError(access.reason)

      if (signOutWhenUnauthorized) {
        await supabase.auth.signOut()
      }

      return access
    }

    setSession(nextSession)
    setUser(access.user)
    setAccessError('')

    const savedAccount = publicAccountData(nextSession, access.user)
    if (savedAccount) {
      setSavedAccounts(upsertSavedAccount(savedAccount))
    }

    return access
  }

  useEffect(() => {
    let mounted = true

    async function loadSession() {
      try {
        const { data, error } = await supabase.auth.getSession()

        if (error) throw error
        if (!mounted) return

        await applySession(data?.session ?? null)
      } catch (error) {
        console.error('[PREVER Acesso] Erro ao carregar sessão:', error)
        if (mounted) {
          setAccessError(toFriendlyMessage(error, 'Não foi possível carregar sua sessão. Entre novamente.'))
          setSession(null)
          setUser(null)
        }
      } finally {
        if (mounted) setLoading(false)
      }
    }

    loadSession()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (event === 'PASSWORD_RECOVERY') {
        setRecoveryMode(true)
      }
      // Evita consultas diretas dentro do retorno síncrono da autenticação.
      setTimeout(() => {
        if (!mounted) return

        applySession(nextSession)
          .catch((error) => {
            console.error('[PREVER Acesso] Erro ao aplicar sessão:', error)
            if (mounted) {
              setAccessError(toFriendlyMessage(error, 'Não foi possível confirmar seu acesso. Entre novamente.'))
              setSession(null)
              setUser(null)
            }
          })
          .finally(() => {
            if (mounted) setLoading(false)
          })
      }, 0)
    })

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [])

  async function signIn({ email, password }) {
    setAccessError('')

    const data = await signInWithEmailAndPassword({ email, password })
    const access = await applySession(data.session)

    if (!access?.allowed) {
      throw new Error(access?.reason || 'Usuário sem permissão para acessar o painel web.')
    }

    await recordLoginActivity(access.user?.id).catch((error) => {
      console.warn('[PREVER Acesso] Login confirmado, mas a atividade não foi registrada:', error.message)
    })

    return data
  }

  async function signOut() {
    const currentUserId = session?.user?.id || user?.id
    await signOutFromSupabase()
    if (currentUserId) {
      setSavedAccounts(removeSavedAccount(currentUserId))
    }
    setSession(null)
    setUser(null)
    setAccessError('')
    setRecoveryMode(false)
  }

  async function startAddAccount() {
    if (session?.user && user) {
      const savedAccount = publicAccountData(session, user)
      if (savedAccount) setSavedAccounts(upsertSavedAccount(savedAccount))
    }

    await supabase.auth.signOut({ scope: 'local' }).catch(() => null)
    setSession(null)
    setUser(null)
    setAccessError('')
    setRecoveryMode(false)
  }

  async function switchAccount(accountId) {
    const account = readSavedAccounts().find((item) => item.id === accountId)

    if (!account) {
      throw new Error('Conta salva não encontrada.')
    }

    if (isSavedAccountExpired(account)) {
      setSavedAccounts(removeSavedAccount(account.id))
      throw new Error('Essa conta ficou mais de 48h sem acesso. Faça login novamente.')
    }

    const { data, error } = await supabase.auth.setSession({
      access_token: account.session.access_token,
      refresh_token: account.session.refresh_token,
    })

    if (error || !data?.session) {
      setSavedAccounts(removeSavedAccount(account.id))
      throw new Error(toFriendlyMessage(error, 'Não foi possível alternar para essa conta. Faça login novamente.'))
    }

    return applySession(data.session, { signOutWhenUnauthorized: false })
  }

  async function refreshUser() {
    const { data, error } = await supabase.auth.getSession()
    if (error) throw error

    return applySession(data?.session ?? session, {
      signOutWhenUnauthorized: false,
    })
  }

  const value = useMemo(
    () => ({
      session,
      user,
      setUser,
      loading,
      accessError,
      recoveryMode,
      clearRecoveryMode: () => setRecoveryMode(false),
      savedAccounts,
      switchAccount,
      startAddAccount,
      isAuthenticated: Boolean(session?.user && user),
      isAdmin: Boolean(user?.isAdmin || user?.role === 'admin'),
      signIn,
      signOut,
      refreshUser,
    }),
    [session, user, loading, accessError, recoveryMode, savedAccounts]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
