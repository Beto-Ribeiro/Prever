import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'
import './accessibility.css'
import { AuthProvider } from './context/AuthContext.jsx'
import { applyPreverSettings, readPreverSettings } from './hooks/usePreverSettings.js'

applyPreverSettings(readPreverSettings())

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <AuthProvider>
      <App />
    </AuthProvider>
  </React.StrictMode>
)