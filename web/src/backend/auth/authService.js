import { supabase } from '../supabase/client.js'

function mapAuthError(error) {
  const message = String(error?.message || '')

  if (message.toLowerCase().includes('invalid login credentials')) {
    return 'E-mail ou senha incorretos. Confira os dados e tente novamente.'
  }

  if (message.toLowerCase().includes('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar no painel.'
  }

  return 'Não foi possível entrar no painel. Tente novamente.'
}

export async function signInWithEmailAndPassword({ email, password }) {
  const cleanEmail = email?.trim().toLowerCase()
  const cleanPassword = String(password ?? '')

  console.info('[PREVER Login] Tentando entrada:', { email: cleanEmail })

  const { data, error } = await supabase.auth.signInWithPassword({
    email: cleanEmail,
    password: cleanPassword,
  })

  if (error) {
    console.error('[PREVER Login] Erro ao entrar:', {
      name: error.name,
      message: error.message,
      status: error.status,
    })
    throw new Error(mapAuthError(error))
  }

  console.info('[PREVER Login] Entrada confirmada:', {
    userId: data?.user?.id,
    hasSession: Boolean(data?.session),
  })

  if (!data?.session?.user) {
    throw new Error('Não foi possível confirmar sua entrada. Tente fazer login novamente.')
  }

  return data
}

export async function signOutFromSupabase() {
  const { error } = await supabase.auth.signOut()

  if (error) throw new Error('Não foi possível sair agora. Tente novamente.')
}
