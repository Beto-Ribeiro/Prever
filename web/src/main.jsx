import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import { applySmdnSettings, readSmdnSettings } from './hooks/useSmdnSettings.js'

const root = ReactDOM.createRoot(document.getElementById('root'))
applySmdnSettings(readSmdnSettings())
Promise.all([import('./App.jsx'), import('./context/AuthContext.jsx')]).then(([{ default: App }, { AuthProvider }]) => {
  root.render(<React.StrictMode><AuthProvider><App /></AuthProvider></React.StrictMode>)
}).catch(error => {
  console.error('Application startup failed', error)
  root.render(<main className="min-h-screen flex flex-col items-center justify-center p-8 bg-bg-main"><h1 className="text-xl font-bold">Não foi possível iniciar o sistema</h1><p role="alert" className="my-4">Erro interno no banco de dados.</p><button className="btn-primary" onClick={() => window.location.reload()}>Tentar novamente</button></main>)
})
