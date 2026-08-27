import { useEffect, useMemo, useState } from 'react'

export const SETTINGS_STORAGE_KEY = 'smdn:settings:v1'

export const DEFAULT_SETTINGS = {
  theme: 'system',
  fontScale: 'normal',
  highContrast: false,
  reducedMotion: false,
  colorBlind: false,
  density: 'comfortable',
  defaultMapMode: 'points',
  promptRecommendationsDisabled: false,
}


function normalizeSettings(settings) {
  const next = {
    ...DEFAULT_SETTINGS,
    ...(settings || {}),
  }

  if (!['small', 'normal', 'large', 'xlarge'].includes(next.fontScale)) {
    next.fontScale = DEFAULT_SETTINGS.fontScale
  }

  if (next.defaultMapMode === 'heat') {
    next.defaultMapMode = 'points'
  }

  if (!['points', 'victims'].includes(next.defaultMapMode)) {
    next.defaultMapMode = DEFAULT_SETTINGS.defaultMapMode
  }

  next.highContrast = Boolean(next.highContrast)
  next.reducedMotion = Boolean(next.reducedMotion)
  next.colorBlind = Boolean(next.colorBlind)
  next.promptRecommendationsDisabled = Boolean(next.promptRecommendationsDisabled)

  return next
}

function safeJsonParse(value) {
  try {
    return value ? JSON.parse(value) : null
  } catch {
    return null
  }
}

export function readSmdnSettings() {
  if (typeof window === 'undefined') return DEFAULT_SETTINGS

  const stored = safeJsonParse(window.localStorage.getItem(SETTINGS_STORAGE_KEY))
  return normalizeSettings(stored)
}

export function getEffectiveTheme(theme) {
  if (theme === 'system') {
    if (typeof window === 'undefined') return 'dark'
    return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
  }

  return theme === 'light' ? 'light' : 'dark'
}

export function applySmdnSettings(settings) {
  if (typeof document === 'undefined') return

  const next = normalizeSettings(settings)

  const root = document.documentElement
  const effectiveTheme = getEffectiveTheme(next.theme)

  root.dataset.theme = effectiveTheme
  root.dataset.themeMode = next.theme
  root.dataset.fontScale = next.fontScale
  root.dataset.contrast = next.highContrast ? 'high' : 'normal'
  root.dataset.motion = next.reducedMotion ? 'reduced' : 'normal'
  root.dataset.colorblind = next.colorBlind ? 'true' : 'false'
  root.dataset.density = next.density
  root.dataset.promptRecommendations = next.promptRecommendationsDisabled ? 'off' : 'on'
}

export function saveSmdnSettings(settings) {
  const next = normalizeSettings(settings)

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(next))
    window.dispatchEvent(new CustomEvent('smdn-settings-change', { detail: next }))
  }

  applySmdnSettings(next)
  return next
}

export function useSmdnSettings() {
  const [settings, setSettings] = useState(() => readSmdnSettings())

  useEffect(() => {
    applySmdnSettings(settings)
  }, [settings])

  useEffect(() => {
    function handleExternalChange(event) {
      setSettings(normalizeSettings(event.detail || readSmdnSettings()))
    }

    function handleStorage(event) {
      if (event.key === SETTINGS_STORAGE_KEY) {
        setSettings(readSmdnSettings())
      }
    }

    const media = window.matchMedia?.('(prefers-color-scheme: light)')
    const handleMediaChange = () => applySmdnSettings(readSmdnSettings())

    window.addEventListener('smdn-settings-change', handleExternalChange)
    window.addEventListener('storage', handleStorage)
    media?.addEventListener?.('change', handleMediaChange)

    return () => {
      window.removeEventListener('smdn-settings-change', handleExternalChange)
      window.removeEventListener('storage', handleStorage)
      media?.removeEventListener?.('change', handleMediaChange)
    }
  }, [])

  const effectiveTheme = useMemo(() => getEffectiveTheme(settings.theme), [settings.theme])

  function updateSetting(key, value) {
    setSettings((current) => saveSmdnSettings({ ...current, [key]: value }))
  }

  function resetSettings() {
    setSettings(saveSmdnSettings(DEFAULT_SETTINGS))
  }

  return {
    settings,
    effectiveTheme,
    updateSetting,
    resetSettings,
  }
}
