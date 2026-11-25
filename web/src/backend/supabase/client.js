import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim()
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Não foi possível iniciar o sistema. Avise o responsável pelo painel para conferir a configuração de acesso.'
  )
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})

// Apenas em desenvolvimento local: facilita testar o Auth no console do navegador.
// Exemplo no DevTools:
// await window.preverSupabase.auth.getSession()
if (import.meta.env.DEV && typeof window !== 'undefined') {
  window.preverSupabase = supabase
}
