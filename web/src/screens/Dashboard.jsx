import { useEffect, useMemo, useRef, useState } from 'react'
import Card from '../components/Card'
import Modal from '../components/Modal'
import MapView from '../components/MapView'
import Alert_triangle from '../assets/menu/inativo/alert-triangle.svg'
import Alert_triangleLight from '../assets/menu/light/alert-triangle.svg'
import Flag from '../assets/menu/inativo/flag.svg'
import FlagLight from '../assets/menu/light/flag.svg'
import Map_pin from '../assets/menu/inativo/map-pin.svg'
import Map_pinLight from '../assets/menu/light/map-pin.svg'
import CheckCircle from '../assets/dashboard/check-circle.svg'
import CheckCircleLight from '../assets/dashboard/check-circle-light.svg'
import {
  getDashboardData,
  subscribeDashboardChanges,
  updateVictimAssistance,
} from '../backend/dashboard/dashboardService.js'
import { useSmdnSettings } from '../hooks/useSmdnSettings.js'
import {
  formatOccurrenceDate,
  updateOcorrenciaStatus,
} from '../backend/ocorrencias/ocorrenciasService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import { listShelters, subscribeShelterChanges } from '../backend/abrigos/shelterService.js'

const SEVERITY_CONFIG = {
  critical: { label: 'Crítico', cls: 'badge-critical', dotColor: '#c60202', shape: 'critical', symbol: '◆' },
  severe: { label: 'Grave', cls: 'badge-severe', dotColor: '#ff6a00', shape: 'severe', symbol: '▲' },
  regular: { label: 'Moderado', cls: 'badge-regular', dotColor: '#cab900', shape: 'regular', symbol: '●' },
}

function getSeverityColor(cfg, colorBlind = false) {
  if (!colorBlind) return cfg.dotColor
  const safe = {
    critical: '#005cab',
    severe: '#d95f02',
    regular: '#7570b3',
  }
  return safe[cfg.shape] || cfg.dotColor
}

function SeverityShape({ severity, colorBlind = false, className = '' }) {
  const cfg = SEVERITY_CONFIG[severity] || SEVERITY_CONFIG.regular
  return (
    <span
      className={`severity-shape severity-shape-${cfg.shape} ${className}`}
      style={{ '--severity-color': getSeverityColor(cfg, colorBlind) }}
      aria-hidden="true"
    />
  )
}

const STATUS_MAP = {
  active: { label: 'Ativa', dot: 'bg-status-critical', cls: 'text-status-critical bg-status-critical-bg border-status-critical/20' },
  monitoring: { label: 'Monitorando', dot: 'bg-status-regular', cls: 'text-status-regular bg-status-regular-bg border-status-regular/20' },
  resolved: { label: 'Resolvida', dot: 'bg-status-success', cls: 'text-status-success bg-status-success-bg border-status-success/20' },
}

const STATUS_OPTIONS = [
  { value: 'active', label: 'Ativa' },
  { value: 'monitoring', label: 'Monitorando' },
  { value: 'resolved', label: 'Resolvida' },
]

const MAP_MODES = [
  { id: 'heat', label: 'Mapa de calor', aria: 'Exibir mapa de calor com ocorrências e vítimas' },
  { id: 'points', label: 'Pontos', aria: 'Exibir pontos de ocorrências e vítimas' },
  { id: 'victims', label: 'Vítimas', aria: 'Exibir somente pontos de vítimas' },
]

function normalizeMapMode(value) {
  return MAP_MODES.some((mode) => mode.id === value) ? value : 'heat'
}

function toMapOcorrencias(ocorrencias) {
  return ocorrencias
    .filter((item) => Number.isFinite(item.lat) && Number.isFinite(item.lng))
    .map((item) => ({
      lat: item.lat,
      lng: item.lng,
      id: item.relatoId || item.id,
      titulo: item.title,
      severidade: SEVERITY_CONFIG[item.severity]?.label || 'Moderado',
      original: item,
    }))
}

function toMapVictims(victims) {
  return (victims || [])
    .filter((item) => Number.isFinite(item.lat) && Number.isFinite(item.lng))
    .map((item) => ({
      id: item.id,
      name: item.name || 'Vítima localizada',
      lat: item.lat,
      lng: item.lng,
      source: item.source,
      updatedAt: item.updatedAt,
      assistanceStatus: item.assistanceStatus || 'pendente',
      assistedAt: item.assistedAt,
      assistedBy: item.assistedBy,
    }))
}

function toMapShelters(shelters) {
  return (shelters || [])
    .filter((item) => Number.isFinite(item.lat) && Number.isFinite(item.lng))
    .map((item) => ({ ...item }))
}


function normalizeAiSearch(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
}

function occurrenceToAiContext(occurrence) {
  return {
    id: occurrence?.id,
    relatoId: occurrence?.relatoId,
    title: occurrence?.title,
    type: occurrence?.type,
    severity: occurrence?.severity,
    riskLabel: occurrence?.riskLabel,
    status: occurrence?.status,
    city: occurrence?.city,
    neighborhood: occurrence?.neighborhood,
    citizenName: occurrence?.citizenName,
    reportedAt: occurrence?.reportedAt,
    time: occurrence?.time,
    description: occurrence?.description,
    lat: occurrence?.lat,
    lng: occurrence?.lng,
  }
}

function findOccurrenceByAiQuery(occurrences, detail = {}) {
  const id = normalizeAiSearch(detail.id || detail.relatoId)
  const query = normalizeAiSearch(detail.query || detail.title || detail.description)

  if (id) {
    const exact = occurrences.find((occurrence) => {
      return [occurrence.id, occurrence.relatoId]
        .filter(Boolean)
        .some((value) => normalizeAiSearch(value) === id)
    })
    if (exact) return exact
  }

  if (!query) return occurrences[0] || null

  return occurrences.find((occurrence) => {
    const content = normalizeAiSearch([
      occurrence.id,
      occurrence.relatoId,
      occurrence.title,
      occurrence.type,
      occurrence.city,
      occurrence.neighborhood,
      occurrence.citizenName,
      occurrence.riskLabel,
      occurrence.description,
    ].filter(Boolean).join(' '))

    return content.includes(query) || query.split(/\s+/).filter((part) => part.length >= 3).every((part) => content.includes(part))
  }) || occurrences[0] || null
}

function MapSettingsButton({ mapType, setMapType, showMapSettings, setShowMapSettings }) {
  return (
    <div className="relative z-[500]">
      <button type="button" onClick={() => setShowMapSettings(!showMapSettings)} className="w-10 h-10 bg-bg-surface/95 rounded-xl shadow-md flex items-center justify-center text-slate-700 hover:bg-slate-50 border border-border-soft backdrop-blur-sm" title="Configurações do Mapa">
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
      </button>
      {showMapSettings && (
        <div className="absolute top-12 right-0 bg-bg-surface/95 backdrop-blur-sm rounded-xl shadow-xl border border-border-soft p-2 w-48 flex flex-col gap-1">
          <div className="px-3 py-2 text-xs font-bold text-slate-400 uppercase tracking-wider">Tipo de Mapa</div>
          {[
            { id: 'roadmap', label: 'Ruas (Padrão)' },
            { id: 'satellite', label: 'Satélite (2D)' },
            { id: 'hybrid', label: 'Híbrido' },
            { id: 'terrain', label: 'Relevo' },
            { id: '3d', label: 'Satélite 3D' }
          ].map(t => (
            <button key={t.id} type="button" onClick={() => { setMapType(t.id); setShowMapSettings(false); }} className={`text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors ${mapType === t.id ? 'bg-action-hover/20 text-slate-800 font-bold' : 'text-slate-600 hover:bg-action-hover/10'}`}>
              {t.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

export default function Dashboard() {
  const [selectedOcc, setSelectedOcc] = useState(null)
  const [statusDraft, setStatusDraft] = useState('active')
  const [savingStatus, setSavingStatus] = useState(false)
  const [savingVictimId, setSavingVictimId] = useState('')
  const [recentMinimized, setRecentMinimized] = useState(false)
  const [statsMinimized, setStatsMinimized] = useState(false)
  const [dashboard, setDashboard] = useState({
    stats: {
      activeOccurrences: 0,
      activeAlerts: 0,
      criticalSeverity: 0,
      resolvedToday: 0,
      locatedVictims: 0,
      assistedVictims: 0,
    },
    recentOccurrences: [],
    victims: [],
  })
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const { settings, effectiveTheme } = useSmdnSettings()
  const [mapMode, setMapMode] = useState(normalizeMapMode(settings.defaultMapMode))
  const [mapType, setMapType] = useState('roadmap')
  const [showMapSettings, setShowMapSettings] = useState(false)
  const [showShelters, setShowShelters] = useState(false)
  const [shelters, setShelters] = useState([])
  const mapRef = useRef(null)

  const mapOccurrences = useMemo(
    () => toMapOcorrencias(dashboard.recentOccurrences),
    [dashboard.recentOccurrences]
  )

  const mapVictims = useMemo(
    () => toMapVictims(dashboard.victims),
    [dashboard.victims]
  )

  const mapShelters = useMemo(
    () => toMapShelters(shelters),
    [shelters]
  )

  const dashboardSummary = [
    { label: 'No mapa', value: mapOccurrences.length },
    { label: 'Críticos', value: dashboard.stats.criticalSeverity },
  ]


  async function loadShelters({ silent = true } = {}) {
    try {
      const data = await listShelters()
      setShelters(data)
    } catch (err) {
      if (!silent) setError(toFriendlyMessage(err, 'Não foi possível carregar os abrigos.'))
    }
  }

  async function loadDashboard({ silent = false } = {}) {
    if (!silent) setLoading(true)

    try {
      setError('')
      const data = await getDashboardData()
      setDashboard(data)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível carregar o painel. Tente novamente.'))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadDashboard()
    return subscribeDashboardChanges(() => loadDashboard({ silent: true }))
  }, [])

  useEffect(() => {
    loadShelters()
    return subscribeShelterChanges(() => loadShelters())
  }, [])
  useEffect(() => {
    setMapMode(normalizeMapMode(settings.defaultMapMode))
  }, [settings.defaultMapMode])

  useEffect(() => {
    if (selectedOcc) {
      setStatusDraft(selectedOcc.status || 'active')
    }
  }, [selectedOcc])

  function handleOccClick(occ) {
    if (Number.isFinite(occ.lat) && Number.isFinite(occ.lng)) {
      mapRef.current?.flyTo(occ.lat, occ.lng, 15)
    }

    setSelectedOcc(occ)
  }

  function handleMapOccurrenceDetails(mapItem) {
    const occurrence = mapItem?.original || dashboard.recentOccurrences.find((item) => {
      return item.relatoId === mapItem?.id || item.id === mapItem?.id
    })

    if (occurrence) {
      handleOccClick(occurrence)
    }
  }

  useEffect(() => {
    window.__SMDN_AI_DASHBOARD = {
      stats: dashboard.stats,
      recentOccurrences: dashboard.recentOccurrences.map(occurrenceToAiContext),
      victims: dashboard.victims,
    }
    window.dispatchEvent(new CustomEvent('smdn-ai-dashboard-context-updated', {
      detail: window.__SMDN_AI_DASHBOARD,
    }))
  }, [dashboard])

  useEffect(() => {
    function handleAiOpenOccurrence(event) {
      const detail = event?.detail || window.__SMDN_AI_PENDING_DASHBOARD_ACTION
      if (!detail || dashboard.recentOccurrences.length === 0) return

      const occurrence = findOccurrenceByAiQuery(dashboard.recentOccurrences, detail)
      if (occurrence) {
        setRecentMinimized(false)
        handleOccClick(occurrence)
      }

      window.__SMDN_AI_PENDING_DASHBOARD_ACTION = null
    }

    window.addEventListener('smdn-ai-dashboard-open-occurrence', handleAiOpenOccurrence)
    handleAiOpenOccurrence({ detail: window.__SMDN_AI_PENDING_DASHBOARD_ACTION })

    return () => {
      window.removeEventListener('smdn-ai-dashboard-open-occurrence', handleAiOpenOccurrence)
    }
  }, [dashboard.recentOccurrences])

  async function handleStatusUpdate() {
    if (!selectedOcc) return

    setSavingStatus(true)
    setError('')

    try {
      await updateOcorrenciaStatus({ relatoId: selectedOcc.relatoId, status: statusDraft })
      await loadDashboard()
      setSelectedOcc((current) => current ? { ...current, status: statusDraft } : current)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível atualizar o status. Tente novamente.'))
    } finally {
      setSavingStatus(false)
    }
  }


  async function handleVictimAssistance(victim) {
    if (!victim?.id || victim.assistanceStatus === 'atendida') return

    setSavingVictimId(victim.id)
    setError('')

    try {
      await updateVictimAssistance({ victim, status: 'atendida' })
      await loadDashboard()
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível marcar a vítima como atendida.'))
    } finally {
      setSavingVictimId('')
    }
  }

  const useLightIcons = effectiveTheme === 'dark'

  const statCards = [
    {
      label: 'OCORRÊNCIAS ATIVAS',
      value: dashboard.stats.activeOccurrences,
      color: 'text-status-critical',
      icon: useLightIcons ? Alert_triangleLight : Alert_triangle,
    },
    {
      label: 'ALERTAS ATIVOS',
      value: dashboard.stats.activeAlerts,
      color: 'text-status-severe',
      icon: useLightIcons ? FlagLight : Flag,
    },
    {
      label: 'SEVERIDADE CRÍTICA',
      value: dashboard.stats.criticalSeverity,
      color: 'text-status-critical',
      icon: useLightIcons ? Map_pinLight : Map_pin,
    },
    {
      label: 'RESOLVIDAS HOJE',
      value: dashboard.stats.resolvedToday,
      color: 'text-status-success',
      icon: useLightIcons ? CheckCircleLight : CheckCircle,
    },
  ]

  return (
    <div className="relative w-full h-full overflow-hidden bg-bg-main p-4 animate-fade-in">
      <Card
        className="absolute inset-4 !p-0 overflow-hidden !border-0 !shadow-none !rounded-[22px] z-0 bg-transparent"
        role="region"
        aria-label="Mapa de monitoramento com ocorrências e vítimas localizadas"
      >
        <p className="sr-only" aria-live="polite">
          Dashboard com {mapOccurrences.length} ocorrência(s), {mapVictims.length} vítima(s) e {showShelters ? mapShelters.length : 0} abrigo(s) visível(is).
          Filtro atual do mapa: {MAP_MODES.find((mode) => mode.id === mapMode)?.label}.
        </p>

        <MapView
          ref={mapRef}
          ocorrencias={mapOccurrences}
          vitimas={mapVictims}
          abrigos={showShelters ? mapShelters : []}
          mapMode={mapMode}
          mapType={mapType}
          heatmap={mapMode === 'heat'}
          onOccurrenceDetails={handleMapOccurrenceDetails}
          onVictimAssistance={handleVictimAssistance}
          savingVictimId={savingVictimId}
          colorBlind={settings.colorBlind}
          theme={effectiveTheme}
        />

        <div className="absolute top-4 left-4 z-[500] flex items-center gap-3">
          <div
            className="flex rounded-xl bg-bg-surface/95 backdrop-blur-sm border border-border-soft shadow-sm overflow-hidden"
            role="group"
            aria-label="Filtro de visualização do mapa"
          >
            {MAP_MODES.map((mode) => (
              <button
                key={mode.id}
                type="button"
                className={`px-3 py-2 text-xs font-bold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-500 ${mapMode === mode.id ? 'bg-text-main text-white' : 'text-slate-600 hover:bg-action-hover/20'}`}
                onClick={() => setMapMode(mode.id)}
                aria-pressed={mapMode === mode.id}
                aria-label={mode.aria}
              >
                {mode.label}
              </button>
            ))}
          </div>

          <button
            type="button"
            onClick={() => setShowShelters((value) => !value)}
            className={`rounded-xl border px-3 py-2 text-xs font-bold shadow-sm backdrop-blur-sm transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-500 ${showShelters ? 'border-text-main bg-text-main text-white' : 'border-border-soft bg-bg-surface/95 text-slate-600 hover:bg-action-hover/20'}`}
            aria-pressed={showShelters}
            aria-label="Mostrar ou ocultar abrigos no mapa do dashboard"
          >
            Abrigos {mapShelters.length > 0 ? `(${mapShelters.length})` : ''}
          </button>
        </div>
      </Card>

      <div
        className="absolute top-8 right-8 z-[500] flex flex-col items-end gap-3 pointer-events-none"
        style={{ width: recentMinimized ? 'auto' : 'clamp(19rem, 25vw, 24rem)' }}
      >
        <div className="flex items-start gap-3 w-full justify-end pointer-events-auto">
          <MapSettingsButton mapType={mapType} setMapType={setMapType} showMapSettings={showMapSettings} setShowMapSettings={setShowMapSettings} />
          
          {recentMinimized ? (
            <div className="flex items-center gap-2">
              {mapVictims.length > 0 && (
                <Card className="!rounded-xl border border-border-soft bg-bg-surface/95 px-3 py-2 shadow-lg backdrop-blur-sm">
                  <span className="mr-2 inline-block h-2.5 w-2.5 rounded-full bg-black align-middle ring-2 ring-white" />
                  <span className="text-[0.6875rem] font-bold text-slate-700">
                    {mapMode === 'victims' ? `${mapVictims.length} vítima(s)` : `${mapVictims.length} vítima(s) · ${dashboard.stats.assistedVictims || 0} atendida(s)`}
                  </span>
                </Card>
              )}

              <Card
                className="h-12 w-12 shadow-xl border border-border-soft bg-bg-surface/95 backdrop-blur-sm !p-0 overflow-hidden flex items-center justify-center transition-all duration-200"
                role="region"
                aria-label="Ocorrências recentes minimizadas"
              >
                <button
                  type="button"
                  onClick={() => setRecentMinimized(false)}
                  className="flex h-full w-full items-center justify-center text-lg font-black text-slate-700 hover:bg-action-hover/20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-500"
                  aria-label="Expandir ocorrências recentes"
                  title="Expandir ocorrências recentes"
                >
                  +
                </button>
              </Card>
            </div>
          ) : (
            <Card
              className="w-full max-h-[360px] shadow-xl border border-border-soft bg-bg-surface/95 backdrop-blur-sm p-0 overflow-hidden flex flex-col transition-all duration-200"
              role="region"
              aria-label="Ocorrências recentes"
            >
              <div className="px-3 pt-4 pb-3 border-b border-slate-100">
                <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="text-sm font-bold leading-tight text-slate-800">Ocorrências Recentes</h3>
                  <div className="mt-2 flex flex-wrap gap-1.5" aria-label="Resumo rápido do dashboard">
                    {dashboardSummary.map((item) => (
                      <span
                        key={item.label}
                        className="rounded-full border border-border-soft bg-action-hover/10 px-2 py-0.5 text-[0.625rem] font-bold text-slate-600"
                      >
                        {item.label}: {item.value}
                      </span>
                    ))}
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  {loading && <span className="text-[0.6875rem] text-slate-400">Carregando...</span>}
                  <button
                    type="button"
                    onClick={() => loadDashboard()}
                    className="hidden sm:inline-flex h-8 items-center justify-center rounded-lg border border-border-soft bg-bg-surface px-2.5 text-[0.6875rem] font-bold text-slate-600 hover:bg-action-hover/20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-500"
                    aria-label="Atualizar ocorrências recentes"
                    title="Atualizar ocorrências"
                  >
                    Atualizar
                  </button>
                  <button
                    type="button"
                    onClick={() => setRecentMinimized(true)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-lg border border-border-soft bg-bg-surface text-sm font-black text-slate-600 hover:bg-action-hover/20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-500"
                    aria-label="Minimizar ocorrências recentes"
                    title="Minimizar"
                  >
                    −
                  </button>
                </div>
              </div>
            </div>

            {error && (
              <div className="mx-3 mt-3 rounded-lg border border-red-100 bg-red-50 px-3 py-2 text-xs text-red-700">
                {error}
              </div>
            )}

            <div className="flex-1 overflow-y-auto divide-y divide-slate-100 max-h-[360px]">
              {dashboard.recentOccurrences.length === 0 && !loading ? (
                <div className="px-4 py-8 text-center text-xs text-slate-400">
                  Nenhum relato encontrado ainda.
                </div>
              ) : (
                dashboard.recentOccurrences.map((occ) => {
                  const cfg = SEVERITY_CONFIG[occ.severity] || SEVERITY_CONFIG.regular
                  return (
                    <button
                      key={occ.id}
                      type="button"
                      onClick={() => handleOccClick(occ)}
                      aria-label={`Abrir detalhes de ${occ.title}, severidade ${cfg.label}, ${occ.city}`}
                      className="w-full flex items-start gap-2.5 px-3 py-3 hover:bg-slate-50/80 transition-colors text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-sky-500"
                    >
                      <SeverityShape severity={occ.severity} colorBlind={settings.colorBlind} className="mt-1 flex-shrink-0" />
                      <div className="min-w-0 flex-1">
                        <p className="font-semibold text-xs text-slate-800 truncate">{occ.title}</p>
                        <p className="text-[0.6875rem] text-slate-500 mt-0.5">
                          {occ.city} · {occ.time}
                        </p>
                        <p className="text-[0.625rem] text-slate-400 mt-0.5 truncate">
                          por {occ.citizenName}
                        </p>
                      </div>
                      <span className={`${cfg.cls} text-[0.625rem] px-1.5 py-0.5 rounded`}>
                        {cfg.label}
                      </span>
                    </button>
                  )
                })
              )}
            </div>
          </Card>
          )}
        </div>

        {!recentMinimized && mapVictims.length > 0 && (
          <Card className="self-end !rounded-xl border border-border-soft bg-bg-surface/95 px-3 py-2 shadow-lg backdrop-blur-sm pointer-events-auto">
            <span className="mr-2 inline-block h-2.5 w-2.5 rounded-full bg-black align-middle ring-2 ring-white" />
            <span className="text-[0.6875rem] font-bold text-slate-700">
              {mapMode === 'victims' ? `${mapVictims.length} vítima(s) no mapa` : `${mapVictims.length} vítima(s) · ${dashboard.stats.assistedVictims || 0} atendida(s)`}
            </span>
          </Card>
        )}
      </div>

      {statsMinimized ? (
        <button
          type="button"
          onClick={() => setStatsMinimized(false)}
          className="absolute bottom-6 left-1/2 z-10 -translate-x-1/2 rounded-2xl border border-border-soft bg-bg-surface/95 px-4 py-3 text-xs font-bold text-slate-700 shadow-lg backdrop-blur-sm hover:bg-action-hover/20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-500"
          aria-label="Expandir indicadores do dashboard"
        >
          Mostrar indicadores · {dashboard.stats.activeOccurrences} ativas · {dashboard.stats.activeAlerts} alertas · {dashboard.stats.criticalSeverity} críticas
        </button>
      ) : (
        <div
          className="absolute bottom-6 left-16 right-16 z-10 grid pointer-events-none"
          style={{
            gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
            gap: 'clamp(0.7rem, 1.1vw, 1.25rem)',
          }}
          role="list"
          aria-label="Indicadores do dashboard"
        >
          <button
            type="button"
            onClick={() => setStatsMinimized(true)}
            className="absolute -top-10 right-0 pointer-events-auto rounded-xl border border-border-soft bg-bg-surface/95 px-3 py-2 text-[0.6875rem] font-bold text-slate-600 shadow-sm backdrop-blur-sm hover:bg-action-hover/20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-500"
            aria-label="Minimizar indicadores do dashboard"
          >
            Minimizar cards
          </button>

          {statCards.map((card) => (
            <Card
              key={card.label}
              role="listitem"
              aria-label={`${card.label}: ${card.value}`}
              className="pointer-events-auto flex min-h-[64px] items-center gap-3 px-3 py-2.5 bg-bg-surface/95 backdrop-blur-sm shadow-lg border border-border-soft w-full max-w-full"
            >
              <div className="w-8 h-8 rounded-xl bg-action-hover/15 flex items-center justify-center flex-shrink-0">
                <img src={card.icon} alt={card.label} className="w-[80%] h-[80%] object-contain" />
              </div>
              <div className="min-w-0">
                <p className="text-[clamp(8px,0.72vw,10px)] font-bold text-slate-700 tracking-wider truncate">{card.label}</p>
                <p className={`text-[clamp(17px,1.7vw,23px)] font-black mt-0.5 leading-none ${card.color}`}>{card.value}</p>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal isOpen={!!selectedOcc} onClose={() => setSelectedOcc(null)} title={`Ocorrência ${selectedOcc?.id || ''}`} size="md">
        {selectedOcc && (
          <div className="space-y-4">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-bold text-lg text-slate-800">{selectedOcc.type}</span>
              <span className={SEVERITY_CONFIG[selectedOcc.severity]?.cls || SEVERITY_CONFIG.regular.cls}>
                {SEVERITY_CONFIG[selectedOcc.severity]?.label || 'Moderado'}
              </span>
              <span className={`inline-flex items-center gap-1.5 border text-xs font-bold px-2.5 py-0.5 rounded-badge ${(STATUS_MAP[selectedOcc.status] || STATUS_MAP.active).cls}`}>
                <span className={`w-1.5 h-1.5 rounded-full ${(STATUS_MAP[selectedOcc.status] || STATUS_MAP.active).dot}`} />
                {(STATUS_MAP[selectedOcc.status] || STATUS_MAP.active).label}
              </span>
            </div>

            {selectedOcc.photoUrl && (
              <img
                src={selectedOcc.photoUrl}
                alt="Foto da ocorrência"
                className="w-full max-h-64 object-cover rounded-xl border border-border-soft"
              />
            )}

            <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
              <div><dt className="text-label text-slate-400">MUNICÍPIO</dt><dd className="text-slate-700 font-medium mt-0.5">{selectedOcc.city}</dd></div>
              <div><dt className="text-label text-slate-400">BAIRRO</dt><dd className="text-slate-700 font-medium mt-0.5">{selectedOcc.neighborhood}</dd></div>
              <div><dt className="text-label text-slate-400">DATA DE REGISTRO</dt><dd className="text-slate-700 font-medium mt-0.5">{formatOccurrenceDate(selectedOcc.reportedAt)}</dd></div>
              <div><dt className="text-label text-slate-400">CIDADÃO</dt><dd className="text-slate-700 font-medium mt-0.5">{selectedOcc.citizenName}</dd></div>
              <div><dt className="text-label text-slate-400">NÍVEL INFORMADO</dt><dd className="text-slate-700 font-medium mt-0.5">{selectedOcc.riskLabel}</dd></div>
              <div><dt className="text-label text-slate-400">LOCALIZAÇÃO</dt><dd className="text-slate-700 font-medium mt-0.5">{Number.isFinite(selectedOcc.lat) && Number.isFinite(selectedOcc.lng) ? `${selectedOcc.lat.toFixed(5)}, ${selectedOcc.lng.toFixed(5)}` : 'Não informada'}</dd></div>
            </dl>

            <div>
              <p className="text-label text-slate-400 mb-1">DESCRIÇÃO</p>
              <p className="text-sm text-slate-700 bg-slate-50 rounded-lg p-3 border border-border-soft">{selectedOcc.description}</p>
            </div>

            <div className="rounded-xl border border-border-soft bg-slate-50 p-3">
              <label className="block text-label text-slate-500 mb-1.5">ATUALIZAR STATUS</label>
              <div className="flex gap-3">
                <select
                  className="select-field flex-1"
                  value={statusDraft}
                  onChange={(event) => setStatusDraft(event.target.value)}
                >
                  {STATUS_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>{option.label}</option>
                  ))}
                </select>
                <button
                  className="btn-primary"
                  disabled={savingStatus}
                  onClick={handleStatusUpdate}
                >
                  {savingStatus ? 'Salvando...' : 'Salvar Status'}
                </button>
              </div>
            </div>

            <div className="flex justify-between gap-3 pt-4 mt-2 border-t border-border-soft">
              <button 
                type="button"
                className="btn-ghost flex items-center gap-2 !px-3 !text-slate-600 hover:!text-text-main"
                onClick={() => {
                  if (Number.isFinite(selectedOcc?.lat) && Number.isFinite(selectedOcc?.lng)) {
                    mapRef.current?.flyTo(selectedOcc.lat, selectedOcc.lng, 17);
                  }
                  setSelectedOcc(null);
                  setRecentMinimized(true);
                }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                Ver localização no mapa
              </button>
              <button className="btn-ghost bg-action-hover/10" onClick={() => setSelectedOcc(null)}>Fechar</button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
