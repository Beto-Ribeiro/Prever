import { useState } from 'react'
import monitoramentoIcon from '../assets/menu/ativo/map-pin.svg'
import disparoIcon from '../assets/menu/ativo/flag.svg'
import relatoriosIcon from '../assets/menu/ativo/pie-chart.svg'
import logoClaro from '../assets/logo-claro.svg'
import logoEscuro from '../assets/logo.svg'
import mapBg from '../assets/map-bg.png'
import SettingsPanel from '../components/SettingsPanel.jsx'
import { useSmdnSettings } from '../hooks/useSmdnSettings.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'

const Login = ({ view, setView, onLogin, onRegister }) => {
  const isRegister = view === 'cadastro'
  const { effectiveTheme } = useSmdnSettings()
  const logo = effectiveTheme === 'light' ? logoEscuro : logoClaro

  const [institution, setInstitution] = useState('')
  const [name, setName] = useState('')
  const [role, setRole] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [rememberMe, setRememberMe] = useState(false)
  const [showSuccess, setShowSuccess] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const normalizedEmail = email.trim().toLowerCase()
  const isValidEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)
  const isRegisterValid = Boolean(institution.trim() && name.trim() && role.trim() && isValidEmail)
  const isLoginValid = Boolean(normalizedEmail && password)

  const handleSubmit = async () => {
    setError('')
    setLoading(true)

    try {
      if (isRegister) {
        if (!isRegisterValid) return
        await onRegister?.({ institution: institution.trim(), name: name.trim(), email: normalizedEmail, role: role.trim() })
        setShowSuccess(true)
        setInstitution('')
        setName('')
        setRole('')
        setEmail('')
        return
      }

      if (!isLoginValid) return
      await onLogin({ email: normalizedEmail, password, rememberMe })
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível concluir a ação. Tente novamente.'))
    } finally {
      setLoading(false)
    }
  }

  const handleKeyDown = (event) => {
    if (event.key === 'Enter') {
      handleSubmit()
    }
  }

  return (
    <div className="relative flex h-screen w-full overflow-hidden">
      <div className="absolute right-6 top-6 z-30">
        <SettingsPanel
          variant="action"
          label="Acessibilidade"
          className="rounded-full bg-bg-surface/90 px-4 py-2.5 shadow-lg backdrop-blur-sm"
          panelClassName="!left-auto !right-6 !top-20 !bottom-auto"
        />
      </div>
      <div
        className="absolute inset-0 bg-cover bg-center"
        style={{ backgroundImage: `url(${mapBg})`, filter: 'blur(2px) brightness(0.7)' }}
      />
      <div className="absolute inset-0 bg-bg-sidebar/30" />

      <div className="relative z-10 flex w-full h-full items-center justify-center">
        <div className="flex flex-col md:flex-row w-full max-w-3xl shadow-modal overflow-hidden rounded-2xl" style={{ minHeight: '560px' }}>
          <div className="md:w-1/2 bg-bg-sidebar text-text-on-dark flex flex-col justify-center items-center p-8 space-y-8">
            <div className="flex flex-col items-center text-center">
              <img src={logo} alt="PREVER Logo" className="w-full max-w-[200px] mb-4" />
              <p className="text-sm font-medium opacity-80 leading-snug">
                Plataforma de Resiliência e Vigilância de Eventos de Risco
              </p>
            </div>
            <div className="space-y-5 w-full">
              <div className="flex items-start gap-3">
                <span className="flex-shrink-0 mt-0.5">
                  <img src={monitoramentoIcon} width="20" height="20" alt="map-pin" />
                </span>
                <p className="text-sm opacity-90">Monitoramento em Tempo Real</p>
              </div>
              <div className="flex items-start gap-3">
                <span className="flex-shrink-0 mt-0.5">
                  <img src={disparoIcon} width="20" height="20" alt="flag" />
                </span>
                <p className="text-sm opacity-90">Disparo de Alertas Segmentados</p>
              </div>
              <div className="flex items-start gap-3">
                <span className="flex-shrink-0 mt-0.5">
                  <img src={relatoriosIcon} width="20" height="20" alt="pie-chart" />
                </span>
                <p className="text-sm opacity-90">Relatórios e Auditoria Completa</p>
              </div>
            </div>
          </div>

          <div className="md:w-1/2 bg-bg-surface flex flex-col justify-center p-8 space-y-5 flex-1">
            <h2 className="text-2xl font-bold text-slate-800 text-center">
              {isRegister ? 'Solicitar acesso web' : 'Bem-vindo de volta!'}
            </h2>

            <p className="text-xs text-slate-500 text-center leading-relaxed">
              {isRegister
                ? 'O painel web é restrito a agentes, instituições e administradores autorizados.'
                : 'Acesso restrito a usuários autorizados para operação web.'}
            </p>

            {error && (
              <div className="rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700 leading-relaxed">
                {error}
              </div>
            )}

            {isRegister && (
              <>
                <select
                  aria-label="Instituição" value={institution}
                  onChange={(e) => setInstitution(e.target.value)}
                  onKeyDown={handleKeyDown}
                  className="w-full px-4 py-3 border border-border-soft rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-text-main/40 bg-bg-main/80"
                >
                  <option value="" disabled>Instituição</option>
                  <option value="Corpo de Bombeiros">Corpo de Bombeiros</option>
                  <option value="S.A.M.U">S.A.M.U</option>
                  <option value="Polícia Federal">Polícia Federal</option>
                  <option value="Defesa Civil">Defesa Civil</option>
                  <option value="Secretaria de Saúde">Secretaria de Saúde</option>
                  <option value="Segurança Pública">Segurança Pública</option>
                  <option value="Abrigo">Abrigo</option>
                </select>
                <input
                  type="text"
                  aria-label="Seu nome" placeholder="Seu nome"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  onKeyDown={handleKeyDown}
                  className="w-full px-4 py-3 border border-border-soft rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-text-main/40 bg-bg-main/80"
                />
              </>
            )}

            <input
              type="email"
              aria-label="E-mail" placeholder="Digite seu email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={handleKeyDown}
              className="w-full px-4 py-3 border border-border-soft rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-text-main/40 bg-bg-main/80"
            />

            {!isRegister && (
              <input
                type="password"
                aria-label="Senha" placeholder="Digite sua senha"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={handleKeyDown}
                className="w-full px-4 py-3 border border-border-soft rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-text-main/40 bg-bg-main/80"
              />
            )}

            {isRegister && (
              <input
                type="text"
                placeholder="Sua função. Ex: Gerente de Abrigo, bombeiro"
                aria-label="Função solicitada" value={role}
                onChange={(e) => setRole(e.target.value)}
                onKeyDown={handleKeyDown}
                className="w-full px-4 py-3 border border-border-soft rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-text-main/40 bg-bg-main/80"
              />
            )}

            {!isRegister && (
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="rememberMe"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="w-4 h-4 text-text-main focus:ring-text-main border-border-soft rounded"
                />
                <label htmlFor="rememberMe" className="text-sm text-gray-500">
                  Mantenha-me logado.
                </label>
              </div>
            )}

            <p className="text-sm text-gray-500 text-center">
              <span
                onClick={() => { setError(''); setView(isRegister ? 'login' : 'cadastro') }}
                className="text-text-main font-bold cursor-pointer hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main rounded"
              >
                {isRegister ? 'Já tenho acesso PREVER' : 'Solicitar acesso ao PREVER'}
              </span>
            </p>

            <button
              onClick={handleSubmit}
              disabled={loading || (isRegister ? !isRegisterValid : !isLoginValid)}
              className="w-full py-3 bg-text-main text-white rounded-full font-semibold text-sm hover:bg-action-hover transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Processando...' : isRegister ? 'Solicitar Acesso' : 'Acessar'}
            </button>
          </div>
        </div>
      </div>

      {showSuccess && (
        <div className="absolute inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/40" onClick={() => setShowSuccess(false)} />
          <div className="relative bg-white rounded-2xl shadow-modal px-10 py-8 flex flex-col items-center gap-4 max-w-sm w-full mx-4 animate-slide-up">
            <div className="w-14 h-14 rounded-full bg-status-success/10 flex items-center justify-center">
              <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
                <circle cx="14" cy="14" r="13" stroke="#02c602" strokeWidth="1.8" />
                <path d="M8 14l4 4 8-8" stroke="#02c602" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-slate-800">Acesso Solicitado</h3>
            <p className="text-sm text-slate-500 text-center leading-relaxed">
              Sua solicitação foi enviada. Aguarde um administrador verificar e aprovar o acesso web.
            </p>
            <button
              onClick={() => { setShowSuccess(false); setView('login') }}
              className="mt-1 w-full py-2.5 bg-text-main text-white rounded-full font-semibold text-sm hover:opacity-90 transition-all"
            >
              Entendido
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

export default Login
