import { useCallback, useEffect, useRef, useState } from 'react'
import Card from '../components/Card'
import Modal from '../components/Modal'
import MapView from '../components/MapView'
import { useAuth } from '../hooks/useAuth.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import {
  countAlertsToday,
  countRecipients,
  countRecipientsInArea,
  dispatchAlert,
  listAlerts,
  subscribeReportarData,
} from '../backend/alertas/alertService.js'

const ALERT_TYPES = ['Enchente', 'Deslizamento', 'Temporal', 'Tornado']
const SEVERITIES = ['critical', 'severe', 'regular']

const SEVERITY_MAP = {
  critical: { label: 'Crítico', cls: 'badge-critical' },
  severe: { label: 'Grave', cls: 'badge-severe' },
  regular: { label: 'Moderado', cls: 'badge-regular' },
}

function formatDate(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function useCityAutocomplete(query) {
  const [suggestions, setSuggestions] = useState([])
  const [loading, setLoading] = useState(false)
  const debounceRef = useRef(null)

  useEffect(() => {
    if (!query || query.length < 2) {
      setSuggestions([])
      return
    }

    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(async () => {
      setLoading(true)
      try {
        const url = `https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&limit=6&countrycodes=br&q=${encodeURIComponent(query)}`
        const res = await fetch(url, { headers: { 'Accept-Language': 'pt-BR' } })
        const data = await res.json()

        const seen = new Set()
        const cities = []
        for (const item of data) {
          const addr = item.address || {}
          const cityName = addr.city || addr.town || addr.municipality || addr.village || ''
          const state = addr.state || ''
          if (!cityName) continue
          const key = `${cityName.toLowerCase()}|${state.toLowerCase()}`
          if (seen.has(key)) continue
          seen.add(key)
          cities.push({
            displayName: `${cityName}${state ? `, ${state}` : ''}`,
            city: cityName,
            state,
            lat: parseFloat(item.lat),
            lon: parseFloat(item.lon),
          })
        }
        setSuggestions(cities)
      } catch {
        setSuggestions([])
      } finally {
        setLoading(false)
      }
    }, 300)

    return () => clearTimeout(debounceRef.current)
  }, [query])

  return { suggestions, loading, clear: () => setSuggestions([]) }
}

function useNeighborhoodAutocomplete(query, cityName) {
  const [suggestions, setSuggestions] = useState([])
  const debounceRef = useRef(null)

  useEffect(() => {
    if (!query || query.length < 2) {
      setSuggestions([])
      return
    }

    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(async () => {
      try {
        const searchQuery = cityName ? `${query}, ${cityName}, Brasil` : `${query}, Brasil`
        const url = `https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&limit=6&countrycodes=br&q=${encodeURIComponent(searchQuery)}`
        const res = await fetch(url, { headers: { 'Accept-Language': 'pt-BR' } })
        const data = await res.json()

        const seen = new Set()
        const results = []
        for (const item of data) {
          const addr = item.address || {}
          const neighborhood = addr.suburb || addr.neighbourhood || addr.quarter || addr.residential || ''
          if (!neighborhood) continue
          const key = neighborhood.toLowerCase()
          if (seen.has(key)) continue
          seen.add(key)
          results.push({
            displayName: neighborhood,
            neighborhood,
            lat: parseFloat(item.lat),
            lon: parseFloat(item.lon),
            boundingbox: item.boundingbox,
          })
        }
        setSuggestions(results)
      } catch {
        setSuggestions([])
      }
    }, 300)

    return () => clearTimeout(debounceRef.current)
  }, [query, cityName])

  return { suggestions, clear: () => setSuggestions([]) }
}

function AlertDetails({ alert }) {
  if (!alert) return null

  return (
    <div className="space-y-4">
      <div className="rounded-2xl border border-border-soft bg-slate-50 p-4">
        <div className="flex items-center gap-2 flex-wrap">
          <h3 className="text-lg font-bold text-slate-800">{alert.type}</h3>
          <span className={SEVERITY_MAP[alert.severity]?.cls}>{SEVERITY_MAP[alert.severity]?.label || alert.severity}</span>
        </div>
        <p className="text-sm text-slate-500 mt-1">
          {alert.city}{alert.neighborhood ? ` · ${alert.neighborhood}` : ''}
        </p>
      </div>

      <div>
        <p className="text-label text-slate-500 mb-1">DESCRIÇÃO</p>
        <p className="text-sm text-slate-700 leading-relaxed">{alert.description}</p>
      </div>

      <div className="grid grid-cols-2 gap-3 text-sm">
        <div className="rounded-xl bg-slate-50 border border-border-soft p-3">
          <p className="text-xs text-slate-400 font-bold uppercase">Operador</p>
          <p className="text-slate-700 font-semibold mt-1">{alert.operator}</p>
        </div>
        <div className="rounded-xl bg-slate-50 border border-border-soft p-3">
          <p className="text-xs text-slate-400 font-bold uppercase">Data e hora</p>
          <p className="text-slate-700 font-semibold mt-1">{formatDate(alert.sentAt)}</p>
        </div>
        <div className="rounded-xl bg-slate-50 border border-border-soft p-3">
          <p className="text-xs text-slate-400 font-bold uppercase">Destinatários</p>
          <p className="text-slate-700 font-semibold mt-1">{alert.recipients.toLocaleString('pt-BR')}</p>
        </div>
        <div className="rounded-xl bg-slate-50 border border-border-soft p-3">
          <p className="text-xs text-slate-400 font-bold uppercase">Status</p>
          <p className="text-slate-700 font-semibold mt-1">{alert.status || 'disparado'}</p>
        </div>
      </div>
    </div>
  )
}

export default function Reportar() {
  const { user } = useAuth()
  const [alerts, setAlerts] = useState([])
  const [alertsToday, setAlertsToday] = useState(0)
  const [recipients, setRecipients] = useState(0)
  const [filterSeverity, setFilterSeverity] = useState('')
  const [filterCity, setFilterCity] = useState('')
  const [filterDate, setFilterDate] = useState('')
  const [filterOperator, setFilterOperator] = useState('')
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [selectedAlert, setSelectedAlert] = useState(null)
  const [form, setForm] = useState({ type: '', city: '', severity: 'critical', description: '', neighborhood: '', lat: null, lng: null })
  const [successMsg, setSuccessMsg] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [dispatching, setDispatching] = useState(false)
  const [isMapOpen, setIsMapOpen] = useState(false)
  const [autoFilled, setAutoFilled] = useState(false)
  const [radiusKm, setRadiusKm] = useState(3)
  const [areaRecipients, setAreaRecipients] = useState(0)
  const [areaRecipientsLoading, setAreaRecipientsLoading] = useState(false)

  const [cityInputValue, setCityInputValue] = useState('')
  const [neighborhoodInputValue, setNeighborhoodInputValue] = useState('')
  const [showCitySuggestions, setShowCitySuggestions] = useState(false)
  const [showNeighborhoodSuggestions, setShowNeighborhoodSuggestions] = useState(false)
  const cityWrapperRef = useRef(null)
  const neighborhoodWrapperRef = useRef(null)
  const [targetLocation, setTargetLocation] = useState(null)

  const { suggestions: citySuggestions, loading: cityLoading, clear: clearCitySuggestions } = useCityAutocomplete(cityInputValue)
  const { suggestions: neighborhoodSuggestions, clear: clearNeighborhoodSuggestions } = useNeighborhoodAutocomplete(neighborhoodInputValue, form.city)

  const loadReportarData = useCallback(async () => {
    setError('')
    try {
      const [alertsResult, todayResult, recipientsResult] = await Promise.all([
        listAlerts({ severity: filterSeverity, city: filterCity, operator: filterOperator, date: filterDate }),
        countAlertsToday(),
        countRecipients(),
      ])
      setAlerts(alertsResult)
      setAlertsToday(todayResult)
      setRecipients(recipientsResult)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível carregar alertas. Tente novamente.'))
    } finally {
      setLoading(false)
    }
  }, [filterSeverity, filterCity, filterOperator, filterDate])

  useEffect(() => {
    loadReportarData()
  }, [loadReportarData])

  useEffect(() => {
    return subscribeReportarData(() => {
      loadReportarData()
    })
  }, [loadReportarData])


  useEffect(() => {
    let cancelled = false

    async function loadAreaRecipients() {
      if (!isModalOpen || !Number.isFinite(Number(form.lat)) || !Number.isFinite(Number(form.lng))) {
        setAreaRecipients(0)
        return
      }

      setAreaRecipientsLoading(true)
      try {
        const total = await countRecipientsInArea({ lat: form.lat, lng: form.lng, radiusKm })
        if (!cancelled) setAreaRecipients(total)
      } finally {
        if (!cancelled) setAreaRecipientsLoading(false)
      }
    }

    loadAreaRecipients()

    return () => {
      cancelled = true
    }
  }, [form.lat, form.lng, isModalOpen, radiusKm])

  useEffect(() => {
    function handleClickOutside(e) {
      if (cityWrapperRef.current && !cityWrapperRef.current.contains(e.target)) {
        setShowCitySuggestions(false)
      }
      if (neighborhoodWrapperRef.current && !neighborhoodWrapperRef.current.contains(e.target)) {
        setShowNeighborhoodSuggestions(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  function resetForm() {
    setForm({ type: '', city: '', severity: 'critical', description: '', neighborhood: '', lat: null, lng: null })
    setCityInputValue('')
    setNeighborhoodInputValue('')
    setTargetLocation(null)
    setRadiusKm(3)
    setAreaRecipients(0)
    setAutoFilled(false)
  }

  async function handleDispatch() {
    if (!form.type || !form.city || !form.description) {
      setError('Preencha tipo, município e descrição para disparar o alerta.')
      return
    }

    if (!Number.isFinite(Number(form.lat)) || !Number.isFinite(Number(form.lng))) {
      setError('Selecione a área no mapa para garantir o disparo georreferenciado.')
      return
    }

    setDispatching(true)
    setError('')

    try {
      await dispatchAlert({ form, currentUser: user, recipients: areaRecipients, radiusKm })
      setIsModalOpen(false)
      setSuccessMsg(`Alerta georreferenciado registrado para ${areaRecipients.toLocaleString('pt-BR')} destinatário(s) na área selecionada.`)
      resetForm()
      await loadReportarData()
      setTimeout(() => setSuccessMsg(''), 4000)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível disparar o alerta. Tente novamente.'))
    } finally {
      setDispatching(false)
    }
  }

  async function handleMapClick(lat, lng) {
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`,
        { headers: { 'Accept-Language': 'pt-BR' } }
      )
      const data = await response.json()
      const city = data.address?.city || data.address?.town || data.address?.municipality || data.address?.village || ''
      const neighborhood = data.address?.suburb || data.address?.neighbourhood || data.address?.quarter || ''

      setForm((prev) => ({ ...prev, city, neighborhood, lat, lng }))
      setTargetLocation({ city, neighborhood, lat, lon: lng })
      setCityInputValue(city)
      setNeighborhoodInputValue(neighborhood)
      setAutoFilled(true)
    } catch (err) {
      console.error('Erro ao localizar endereço:', err)
    }
  }

  function handleCitySelect(suggestion) {
    setForm((f) => ({ ...f, city: suggestion.city, lat: suggestion.lat, lng: suggestion.lon }))
    setCityInputValue(suggestion.displayName)
    setAutoFilled(false)
    clearCitySuggestions()
    setShowCitySuggestions(false)
    setTargetLocation({ city: suggestion.city, lat: suggestion.lat, lon: suggestion.lon })
  }

  function handleNeighborhoodSelect(suggestion) {
    setForm((f) => ({ ...f, neighborhood: suggestion.neighborhood, lat: suggestion.lat, lng: suggestion.lon }))
    setNeighborhoodInputValue(suggestion.displayName)
    setAutoFilled(false)
    clearNeighborhoodSuggestions()
    setShowNeighborhoodSuggestions(false)
    setTargetLocation({
      city: form.city,
      neighborhood: suggestion.neighborhood,
      lat: suggestion.lat,
      lon: suggestion.lon,
      boundingbox: suggestion.boundingbox,
    })
  }

  return (
    <div className="p-6 h-full min-h-0 overflow-hidden flex flex-col gap-4 animate-fade-in">
      <div className="flex flex-wrap items-center gap-3 flex-shrink-0">
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3 flex-1 min-w-[560px]">
          <select className="select-field min-w-0" value={filterSeverity} onChange={(e) => setFilterSeverity(e.target.value)}>
            <option value="">Todas as severidades</option>
            <option value="critical">Crítico</option>
            <option value="severe">Grave</option>
            <option value="regular">Moderado</option>
          </select>

          <input className="input-field min-w-0" placeholder="Pesquisar cidade..." value={filterCity} onChange={(e) => setFilterCity(e.target.value)} />
          <input className="input-field min-w-0" placeholder="Pesquisar operador..." value={filterOperator} onChange={(e) => setFilterOperator(e.target.value)} />
          <input className="input-field min-w-0" type="date" value={filterDate} onChange={(e) => setFilterDate(e.target.value)} />
        </div>

        <Card className="text-center py-3 px-5 min-w-[120px]">
          <p className="text-label text-slate-500 mb-1">ALERTAS HOJE</p>
          <p className="text-3xl font-bold text-text-main">{alertsToday}</p>
        </Card>

        <Card className="text-center py-3 px-5 min-w-[160px]">
          <p className="text-label text-slate-500 mb-1">TOTAL DESTINATÁRIOS</p>
          <p className="text-3xl font-bold text-status-severe">{recipients.toLocaleString('pt-BR')}</p>
        </Card>

        <button
          className="flex flex-col items-center justify-center gap-1 bg-red-500 hover:bg-red-600 active:scale-95 transition-all rounded-2xl w-24 h-24 shadow-lg text-white shrink-0"
          onClick={() => setIsModalOpen(true)}
        >
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M13.73 21a2 2 0 0 1-3.46 0" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span className="text-xs font-bold leading-tight text-center">Disparar<br />Alerta</span>
        </button>
      </div>

      {successMsg && (
        <div className="flex-shrink-0 flex items-center gap-3 bg-status-success-bg border border-status-success/30 text-status-success font-semibold text-sm px-4 py-3 rounded-lg animate-slide-up">
          {successMsg}
        </div>
      )}

      {error && (
        <div className="flex-shrink-0 rounded-lg border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <Card className="p-0 overflow-hidden flex-1 min-h-0 flex flex-col">
        <div className="px-6 py-4 border-b border-border-soft flex items-center justify-between flex-shrink-0">
          <h3 className="text-card-title font-bold text-slate-800">Histórico de Alertas</h3>
          {loading && <span className="text-xs text-slate-400">Carregando...</span>}
        </div>

        <div className="divide-y divide-border-soft overflow-y-auto flex-1 min-h-0">
          {!loading && alerts.length === 0 && (
            <div className="px-6 py-10 text-center text-sm text-slate-400">Nenhum alerta encontrado.</div>
          )}

          {alerts.map((alert) => (
            <button
              key={alert.id}
              onClick={() => setSelectedAlert(alert)}
              className="w-full text-left px-6 py-4 hover:bg-slate-50 transition-colors"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap mb-1">
                    <span className="font-bold text-slate-800">{alert.type}</span>
                    <span className={SEVERITY_MAP[alert.severity]?.cls}>{SEVERITY_MAP[alert.severity]?.label || alert.severity}</span>
                    <span className="text-xs text-slate-400">• {alert.city}{alert.neighborhood ? ` · ${alert.neighborhood}` : ''}</span>
                  </div>

                  <p className="text-sm text-slate-600 mb-2 line-clamp-2">{alert.description}</p>

                  <div className="flex items-center gap-4 text-xs text-slate-400 flex-wrap">
                    <span>{formatDate(alert.sentAt)}</span>
                    <span>{alert.operator}</span>
                    <span>{alert.recipients.toLocaleString('pt-BR')} destinatários</span>
                  </div>
                </div>
              </div>
            </button>
          ))}
        </div>
      </Card>

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Disparar Novo Alerta" size="md">
        <div className="space-y-4">
          <div>
            <label className="block text-label text-slate-600 mb-1.5">TIPO DE OCORRÊNCIA</label>
            <select className="select-field" value={form.type} onChange={(e) => setForm((f) => ({ ...f, type: e.target.value }))}>
              <option value="">Selecione o tipo...</option>
              {ALERT_TYPES.map((t) => <option key={t}>{t}</option>)}
            </select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div ref={cityWrapperRef} className="relative">
              <label className="block text-label text-slate-600 mb-1.5">MUNICÍPIO</label>
              <div className="relative">
                <input
                  className={`input-field w-full pr-7 ${autoFilled ? 'border border-[#597891] ring-1 ring-[#597891]/20' : ''}`}
                  placeholder="Digite o município..."
                  value={cityInputValue}
                  onChange={(e) => {
                    setCityInputValue(e.target.value)
                    setForm((f) => ({ ...f, city: e.target.value }))
                    setAutoFilled(false)
                    setShowCitySuggestions(true)
                  }}
                  onFocus={() => cityInputValue.length >= 2 && setShowCitySuggestions(true)}
                  autoComplete="off"
                />
                {cityLoading && <span className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400">...</span>}
              </div>
              {showCitySuggestions && citySuggestions.length > 0 && (
                <ul className="absolute z-50 left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg overflow-hidden max-h-48 overflow-y-auto">
                  {citySuggestions.map((s, i) => (
                    <li key={i} className="px-3 py-2 text-sm text-slate-700 hover:bg-[#597891]/10 cursor-pointer" onMouseDown={() => handleCitySelect(s)}>
                      {s.displayName}
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <div>
              <label className="block text-label text-slate-600 mb-1.5">SEVERIDADE</label>
              <select className="select-field" value={form.severity} onChange={(e) => setForm((f) => ({ ...f, severity: e.target.value }))}>
                {SEVERITIES.map((s) => <option key={s} value={s}>{SEVERITY_MAP[s].label}</option>)}
              </select>
            </div>
          </div>

          <div ref={neighborhoodWrapperRef} className="relative">
            <label className="block text-label text-slate-600 mb-1.5">BAIRRO / ÁREA (opcional)</label>
            <input
              className={`input-field w-full ${autoFilled ? 'border border-[#597891] ring-1 ring-[#597891]/20' : ''}`}
              placeholder="Ex: Centro, Vila Nova..."
              value={neighborhoodInputValue}
              onChange={(e) => {
                setNeighborhoodInputValue(e.target.value)
                setForm((f) => ({ ...f, neighborhood: e.target.value }))
                setAutoFilled(false)
                setShowNeighborhoodSuggestions(true)
              }}
              onFocus={() => neighborhoodInputValue.length >= 2 && setShowNeighborhoodSuggestions(true)}
              autoComplete="off"
            />
            {showNeighborhoodSuggestions && neighborhoodSuggestions.length > 0 && (
              <ul className="absolute z-50 left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg overflow-hidden max-h-48 overflow-y-auto">
                {neighborhoodSuggestions.map((s, i) => (
                  <li key={i} className="px-3 py-2 text-sm text-slate-700 hover:bg-[#597891]/10 cursor-pointer" onMouseDown={() => handleNeighborhoodSelect(s)}>
                    {s.displayName}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-[1fr_160px]">
            <button type="button" className="w-full py-3 bg-[#597891] hover:bg-[#2D5A87] text-white font-semibold rounded-lg transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main" onClick={() => setIsMapOpen(true)}>
              Localizar Área no Mapa
            </button>

            <label className="block">
              <span className="block text-label text-slate-600 mb-1.5">RAIO</span>
              <select className="select-field" value={radiusKm} onChange={(e) => setRadiusKm(Number(e.target.value))}>
                <option value={1}>1 km</option>
                <option value={3}>3 km</option>
                <option value={5}>5 km</option>
                <option value={10}>10 km</option>
                <option value={20}>20 km</option>
              </select>
            </label>
          </div>

          <Modal isOpen={isMapOpen} onClose={() => setIsMapOpen(false)} title="Selecionar Área no Mapa" size="xl">
            <div className="h-[65vh] rounded-xl overflow-hidden border border-border-soft">
              <MapView onMapClick={handleMapClick} targetLocation={targetLocation} selectionRadiusKm={radiusKm} />
            </div>
            <p className="text-xs text-slate-500 mt-3">Clique no mapa para preencher município e bairro aproximados. O raio selecionado define quem receberá o push.</p>
          </Modal>

          <div>
            <label className="block text-label text-slate-600 mb-1.5">DESCRIÇÃO</label>
            <textarea className="input-field min-h-[110px] resize-none" placeholder="Descreva a situação..." value={form.description} onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))} />
          </div>

          <div className="rounded-xl bg-slate-50 border border-border-soft px-4 py-3 text-sm text-slate-600">
            Este alerta será direcionado somente para usuários dentro de <strong>{radiusKm} km</strong> da área selecionada. Destinatários estimados: <strong>{areaRecipientsLoading ? 'calculando...' : areaRecipients.toLocaleString('pt-BR')}</strong> de {recipients.toLocaleString('pt-BR')} cadastrados.
          </div>

          <button type="button" className="w-full py-3 bg-red-500 hover:bg-red-600 text-white font-bold rounded-lg transition-all disabled:opacity-50" onClick={handleDispatch} disabled={dispatching}>
            {dispatching ? 'Disparando...' : 'Confirmar Disparo'}
          </button>
        </div>
      </Modal>

      <Modal isOpen={Boolean(selectedAlert)} onClose={() => setSelectedAlert(null)} title="Detalhes do Alerta" size="lg">
        <AlertDetails alert={selectedAlert} />
      </Modal>
    </div>
  )
}
