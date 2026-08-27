import axios from 'axios'

// TODO: Configurar base URL do Supabase
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// TODO: Adicionar interceptors para autenticação com Supabase

export default api