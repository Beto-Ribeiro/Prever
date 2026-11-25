import { useEffect, useState } from 'react'

export const SETTINGS_STORAGE_KEY = 'prever:settings:v1'

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

  if (!['system', 'light', 'dark'].includes(next.theme)) next.theme = DEFAULT_SETTINGS.theme
  if (!['comfortable', 'compact'].includes(next.density)) next.density = DEFAULT_SETTINGS.density

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

export function readPreverSettings() {
  if (typeof window === 'undefined') return DEFAULT_SETTINGS

  try { return normalizeSettings(safeJsonParse(window.localStorage.getItem(SETTINGS_STORAGE_KEY))) }
  catch { return { ...DEFAULT_SETTINGS } }
}

export function getEffectiveTheme(theme) {
  if (theme === 'system') {
    if (typeof window === 'undefined') return 'dark'
    return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
  }

  return theme === 'light' ? 'light' : 'dark'
}

export function applyPreverSettings(settings) {
  if (typeof document === 'undefined') return

  const next = normalizeSettings(settings)

  const root = document.documentElement
  const effectiveTheme = getEffectiveTheme(next.theme)

  root.dataset.theme = effectiveTheme
  root.dataset.themeMode = next.theme
  root.dataset.fontScale = next.fontScale
  root.dataset.contrast = next.highContrast ? 'high' : 'normal'
  root.dataset.motion = (next.reducedMotion || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) ? 'reduced' : 'normal'
  root.dataset.colorblind = next.colorBlind ? 'true' : 'false'
  root.dataset.density = next.density
  root.dataset.promptRecommendations = next.promptRecommendationsDisabled ? 'off' : 'on'
}

export function savePreverSettings(settings) {
  const next = normalizeSettings(settings)

  if (typeof window !== 'undefined') {
    try { window.localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(next)) } catch { /* Still apply settings for this session. */ }
    window.dispatchEvent(new CustomEvent('prever-settings-change', { detail: next }))
  }

  applyPreverSettings(next)
  return next
}

export function usePreverSettings() {
  const [, setSystemRevision] = useState(0)
  const [settings, setSettings] = useState(() => readPreverSettings())

  useEffect(() => {
    applyPreverSettings(settings)
  }, [settings])

  useEffect(() => {
    function handleExternalChange(event) {
      setSettings(normalizeSettings(event.detail || readPreverSettings()))
    }

    function handleStorage(event) {
      if (event.key === SETTINGS_STORAGE_KEY) {
        setSettings(readPreverSettings())
      }
    }

    const media = window.matchMedia?.('(prefers-color-scheme: light)')
    const motionMedia = window.matchMedia?.('(prefers-reduced-motion: reduce)')
    const handleMediaChange = () => { applyPreverSettings(readPreverSettings()); setSystemRevision(value => value + 1) }

    window.addEventListener('prever-settings-change', handleExternalChange)
    window.addEventListener('storage', handleStorage)
    media?.addEventListener?.('change', handleMediaChange)
    motionMedia?.addEventListener?.('change', handleMediaChange)

    return () => {
      window.removeEventListener('prever-settings-change', handleExternalChange)
      window.removeEventListener('storage', handleStorage)
      media?.removeEventListener?.('change', handleMediaChange)
      motionMedia?.removeEventListener?.('change', handleMediaChange)
    }
  }, [])

  const effectiveTheme = getEffectiveTheme(settings.theme)

  function updateSetting(key, value) {
    const next = { ...settings, [key]: value }
    setSettings(savePreverSettings(next))
  }

  function resetSettings() {
    setSettings(savePreverSettings(DEFAULT_SETTINGS))
  }

  return {
    settings,
    effectiveTheme,
    updateSetting,
    resetSettings,
  }
}
