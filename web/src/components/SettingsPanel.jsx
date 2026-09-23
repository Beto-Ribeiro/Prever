import { useDialogFocus } from '../hooks/useDialogFocus.js'
import { useEffect, useRef, useState } from 'react'
import { useSmdnSettings } from '../hooks/useSmdnSettings.js'

function GearIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4Z" stroke="currentColor" strokeWidth="1.8" />
      <path d="M19.4 13.5c.1-.5.1-1 .1-1.5s0-1-.1-1.5l2-1.5-2-3.4-2.4 1a7.9 7.9 0 0 0-2.6-1.5L14 2.5h-4l-.4 2.6A7.9 7.9 0 0 0 7 6.6l-2.4-1-2 3.4 2 1.5c-.1.5-.1 1-.1 1.5s0 1 .1 1.5l-2 1.5 2 3.4 2.4-1c.8.7 1.6 1.1 2.6 1.5l.4 2.6h4l.4-2.6c1-.4 1.9-.8 2.6-1.5l2.4 1 2-3.4-2-1.5Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </svg>
  )
}

function Toggle({ checked, onChange, label, description }) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className="w-full flex items-center justify-between gap-4 rounded-xl border border-border-soft bg-bg-surface px-3 py-2 text-left hover:bg-slate-50 transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
      aria-pressed={checked}
    >
      <span>
        <span className="block text-sm font-bold text-slate-800">{label}</span>
        {description && <span className="block text-xs text-slate-500 mt-0.5">{description}</span>}
      </span>
      <span className={`relative h-6 w-11 rounded-full transition-colors ${checked ? 'bg-text-main' : 'bg-slate-300'}`}>
        <span className={`absolute top-1 h-4 w-4 rounded-full bg-white shadow transition-transform ${checked ? 'translate-x-6 left-0' : 'translate-x-1 left-0'}`} />
      </span>
    </button>
  )
}

function OptionGroup({ label, value, options, onChange }) {
  return (
    <div>
      <p className="text-[0.6875rem] uppercase tracking-[0.18em] font-black text-slate-400 mb-2">{label}</p>
      <div className="grid gap-2">
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => onChange(option.value)}
            className={`rounded-xl border px-3 py-2 text-left transition-all focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main ${
              value === option.value
                ? 'border-text-main bg-text-main/10 text-slate-900 shadow-sm'
                : 'border-border-soft bg-bg-surface text-slate-600 hover:bg-slate-50'
            }`}
            aria-pressed={value === option.value}
          >
            <span className="block text-sm font-bold">{option.label}</span>
            {option.description && <span className="block text-xs opacity-70 mt-0.5">{option.description}</span>}
          </button>
        ))}
      </div>
    </div>
  )
}

export default function SettingsPanel({ variant = 'row', className = '', panelClassName = '', label }) {
  const { settings, effectiveTheme, updateSetting, resetSettings } = useSmdnSettings()
  const [open, setOpen] = useState(false)
  const panelRef = useRef(null)
  const buttonRef = useRef(null)

  useEffect(() => {
    function handleClickOutside(event) {
      if (!open) return
      if (
        panelRef.current &&
        !panelRef.current.contains(event.target) &&
        buttonRef.current &&
        !buttonRef.current.contains(event.target)
      ) {
        setOpen(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  useDialogFocus(open, panelRef, () => setOpen(false), false)

  const isIcon = variant === 'icon'
  const isAction = variant === 'action'
  const buttonLabel = label || (isAction ? 'Config.' : 'Configurações')

  const buttonClassName = isIcon
    ? `inline-flex h-9 w-9 items-center justify-center rounded-xl border border-border-soft bg-bg-surface text-slate-500 hover:bg-slate-50 hover:text-text-main transition-all ${className}`
    : isAction
      ? `w-full flex items-center justify-center gap-2 rounded-xl border border-border-soft bg-bg-surface px-3 py-3 text-sm font-bold text-slate-600 hover:bg-slate-50 hover:text-text-main transition-all ${className}`
      : `w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-text-on-dark hover:bg-white/5 hover:text-white transition-all focus-visible:outline focus-visible:outline-2 focus-visible:outline-white ${className}`

  return (
    <div className="relative">
      <button
        ref={buttonRef}
        type="button"
        onClick={() => setOpen((value) => !value)}
        className={buttonClassName}
        aria-expanded={open}
        aria-label={`Abrir ${buttonLabel.toLowerCase()}`}
        title="Configurações"
      >
        <GearIcon />
        {!isIcon && <span>{buttonLabel}</span>}
      </button>

      {open && (
        <div
          ref={panelRef}
          className={`settings-panel fixed bottom-16 left-[210px] z-[99999] w-[360px] max-h-[calc(100vh-5rem)] overflow-y-auto rounded-3xl border border-border-soft bg-bg-surface p-5 shadow-2xl animate-slide-up ${panelClassName}`}
          role="dialog"
          aria-label="Configurações do PREVER"
        >
          <div className="flex items-center justify-end border-b border-border-soft pb-3 mb-4">
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded-lg p-2 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
              aria-label="Fechar configurações"
            >
              ×
            </button>
          </div>

          <div className="space-y-5">
            <OptionGroup
              label="Tema"
              value={settings.theme}
              onChange={(value) => updateSetting('theme', value)}
              options={[
                { value: 'system', label: 'Sistema', description: `Seguindo o dispositivo: ${effectiveTheme === 'light' ? 'claro' : 'escuro'}` },
                { value: 'light', label: 'Claro', description: 'Sidebar clara e logo escura.' },
                { value: 'dark', label: 'Escuro', description: 'Interface com menos brilho.' },
              ]}
            />

            <OptionGroup
              label="Fonte"
              value={settings.fontScale}
              onChange={(value) => updateSetting('fontScale', value)}
              options={[
                { value: 'small', label: 'Pequena', description: 'Mais conteúdo sem dar zoom no navegador.' },
                { value: 'normal', label: 'Normal' },
                { value: 'large', label: 'Grande' },
                { value: 'xlarge', label: 'Muito grande' },
              ]}
            />

            <OptionGroup
              label="Densidade"
              value={settings.density}
              onChange={(value) => updateSetting('density', value)}
              options={[
                { value: 'comfortable', label: 'Confortável', description: 'Mais espaço entre blocos.' },
                { value: 'compact', label: 'Compacta', description: 'Mais conteúdo na tela.' },
              ]}
            />


            <div className="space-y-2">
              <Toggle
                checked={settings.highContrast}
                onChange={(value) => updateSetting('highContrast', value)}
                label="Alto contraste"
                description="Melhora leitura em projetor e tela clara."
              />
              <Toggle
                checked={settings.reducedMotion}
                onChange={(value) => updateSetting('reducedMotion', value)}
                label="Reduzir animações"
                description="Remove transições e pulsos visuais."
              />
              <Toggle
                checked={settings.colorBlind}
                onChange={(value) => updateSetting('colorBlind', value)}
                label="Modo daltônico"
                description="Ajusta cores de severidade para maior distinção."
              />
              <button
                type="button"
                onClick={() => updateSetting('promptRecommendationsDisabled', !settings.promptRecommendationsDisabled)}
                className={`w-full rounded-xl border px-3 py-2 text-left transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main ${
                  settings.promptRecommendationsDisabled
                    ? 'border-sky-200 bg-sky-50 text-slate-800 hover:bg-sky-100'
                    : 'border-border-soft bg-bg-surface text-slate-800 hover:bg-slate-50'
                }`}
                aria-pressed={settings.promptRecommendationsDisabled}
              >
                <span className="block text-sm font-bold">
                  {settings.promptRecommendationsDisabled
                    ? 'Ligar recomendação de prompt'
                    : 'Desligar recomendação de prompt'}
                </span>
                <span className="block text-xs text-slate-500 mt-0.5">
                  {settings.promptRecommendationsDisabled
                    ? 'As sugestões rápidas do Nimbo estão ocultas.'
                    : 'Oculta sugestões prontas do Nimbo, como botões de perguntas rápidas.'}
                </span>
              </button>
            </div>

            <button
              type="button"
              onClick={resetSettings}
              className="w-full rounded-xl border border-border-soft px-3 py-2 text-sm font-bold text-slate-600 hover:bg-slate-50"
            >
              Restaurar padrão
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
