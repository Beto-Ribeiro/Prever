import { useEffect, useMemo, useState } from 'react'
import Card from '../components/Card.jsx'
import Modal from '../components/Modal.jsx'
import MapView from '../components/MapView.jsx'
import {
  createShelter,
  listShelters,
  subscribeShelterChanges,
  updateShelterOccupancy,
} from '../backend/abrigos/shelterService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'

const INSTALLATION_TYPES = ['Escola pública', 'Ginásio', 'Centro comunitário', 'Igreja', 'Posto de apoio']
const ACCESSIBILITY_OPTIONS = ['Sim', 'Parcial', 'Não informado']
const PET_OPTIONS = ['Sim', 'Não', 'Sob avaliação']
const STATUS_OPTIONS = [
  { value: 'disponivel', label: 'Disponível' },
  { value: 'quase_lotado', label: 'Quase lotado' },
  { value: 'lotado', label: 'Lotado' },
]

const INITIAL_FORM = {
  name: '',
  type: '',
  capacity: '',
  accessibility: '',
  acceptsPets: '',
  coordinator: '',
  phone: '',
  phone2: '',
  city: '',
  location: '',
  lat: null,
  lng: null,
  status: 'disponivel',
}

function getOccupancyLabel(shelter) {
  return `${shelter.occupied || 0}/${shelter.capacity || 0}`
}

function getStatusFromOccupancy(occupied, capacity) {
  const total = Number(capacity) || 0
  const current = Number(occupied) || 0

  if (total > 0 && current >= total) return 'lotado'
  if (total > 0 && current >= total * 0.85) return 'quase_lotado'
  return 'disponivel'
}

function getStatusMeta(status) {
  if (status === 'lotado') return { label: 'Lotado', className: 'badge-critical inline-flex w-max min-w-[92px] justify-center whitespace-nowrap px-2.5' }
  if (status === 'quase_lotado') return { label: 'Quase lotado', className: 'badge-severe inline-flex w-max min-w-[108px] justify-center whitespace-nowrap px-2.5' }
  return { label: 'Disponível', className: 'badge-success inline-flex w-max min-w-[92px] justify-center whitespace-nowrap px-2.5' }
}

function isValidShelterCoord(shelter) {
  return Number.isFinite(shelter.lat) && Number.isFinite(shelter.lng)
}

export default function Abrigos() {
  const [shelters, setShelters] = useState([])
  const [query, setQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [isMapOpen, setIsMapOpen] = useState(false)
  const [form, setForm] = useState(INITIAL_FORM)
  const [error, setError] = useState('')
  const [formError, setFormError] = useState('')
  const [success, setSuccess] = useState('')
  const [selectedShelter, setSelectedShelter] = useState(null)
  const [loading, setLoading] = useState(true)
  const [savingId, setSavingId] = useState('')
  const [savingCreate, setSavingCreate] = useState(false)

  async function loadShelters({ silent = false } = {}) {
    if (!silent) setLoading(true)

    try {
      setError('')
      const data = await listShelters()
      setShelters(data)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível carregar os abrigos.'))
    } finally {
      if (!silent) setLoading(false)
    }
  }

  useEffect(() => {
    loadShelters()
    return subscribeShelterChanges(() => loadShelters({ silent: true }))
  }, [])

  const filteredShelters = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase()
    return shelters.filter((shelter) => {
      const matchesQuery = !normalizedQuery || [shelter.name, shelter.city, shelter.location]
        .filter(Boolean)
        .some((value) => value.toLowerCase().includes(normalizedQuery))
      const matchesStatus = !statusFilter || shelter.status === statusFilter
      return matchesQuery && matchesStatus
    })
  }, [query, shelters, statusFilter])

  const availableCount = shelters.filter((shelter) => shelter.status !== 'lotado').length
  const fullCount = shelters.filter((shelter) => shelter.status === 'lotado').length
  const mapShelters = useMemo(
    () => filteredShelters.filter(isValidShelterCoord),
    [filteredShelters]
  )

  function resetForm() {
    setForm(INITIAL_FORM)
    setFormError('')
  }

  function openCreateModal() {
    resetForm()
    setIsCreateOpen(true)
  }

  async function handleMapClick(lat, lng) {
    setForm((current) => ({ ...current, lat, lng }))

    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`,
        { headers: { 'Accept-Language': 'pt-BR' } }
      )
      const data = await response.json()
      const city = data.address?.city || data.address?.town || data.address?.municipality || data.address?.village || ''
      const neighborhood = data.address?.suburb || data.address?.neighbourhood || data.address?.quarter || data.address?.road || ''
      setForm((current) => ({ ...current, city, location: neighborhood, lat, lng }))
    } catch {
      setForm((current) => ({ ...current, lat, lng }))
    }
  }

  async function handleCreateShelter(event) {
    event.preventDefault()
    setFormError('')
    setSavingCreate(true)

    try {
      const shelter = await createShelter(form)
      setShelters((current) => [shelter, ...current])
      setSuccess('Abrigo cadastrado com sucesso.')
      setIsCreateOpen(false)
      resetForm()
      window.setTimeout(() => setSuccess(''), 3500)
    } catch (err) {
      setFormError(toFriendlyMessage(err, 'Não foi possível cadastrar o abrigo.'))
    } finally {
      setSavingCreate(false)
    }
  }

  async function handleOccupancyChange(shelter, value) {
    const nextOccupied = Math.max(0, Math.min(Number(value) || 0, shelter.capacity || 0))
    const optimistic = {
      ...shelter,
      occupied: nextOccupied,
      status: getStatusFromOccupancy(nextOccupied, shelter.capacity),
    }

    setSavingId(shelter.id)
    setShelters((current) => current.map((item) => item.id === shelter.id ? optimistic : item))

    try {
      const updated = await updateShelterOccupancy(shelter.id, nextOccupied, shelter.capacity)
      setShelters((current) => current.map((item) => item.id === shelter.id ? updated : item))
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível atualizar a lotação do abrigo.'))
      loadShelters({ silent: true })
    } finally {
      setSavingId('')
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden p-4 animate-fade-in">
      <div className="grid flex-1 min-h-0 grid-cols-1 gap-4 xl:grid-cols-[minmax(620px,1fr)_minmax(300px,0.46fr)] 2xl:grid-cols-[minmax(700px,1fr)_minmax(340px,0.42fr)]">
        <section className="flex min-w-0 min-h-0 flex-col gap-3" aria-label="Gestão de abrigos">
          <div className="flex flex-shrink-0 flex-col gap-3 xl:flex-row xl:items-stretch xl:justify-between">
            <div className="flex shrink-0 flex-wrap items-stretch gap-3">
              <button
                type="button"
                onClick={openCreateModal}
                className="flex h-[88px] w-[88px] shrink-0 flex-col items-center justify-center gap-1 rounded-2xl bg-red-500 text-white shadow-lg transition-all hover:bg-red-600 active:scale-95 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-700"
                aria-label="Cadastrar novo abrigo"
              >
                <svg width="31" height="31" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path d="M3 11.5 12 4l9 7.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M5.5 10.5V20h13v-9.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M9.5 20v-6h5v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <span className="text-center text-[11px] font-bold leading-tight">Cadastrar<br />abrigo</span>
              </button>

              <Card className="flex min-w-[142px] flex-col justify-center px-4 py-3 text-center">
                <p className="mb-1 text-label text-slate-500">ABRIGOS DISPONÍVEIS</p>
                <p className="text-3xl font-bold text-status-success">{availableCount}</p>
              </Card>

              <Card className="flex min-w-[142px] flex-col justify-center px-4 py-3 text-center">
                <p className="mb-1 text-label text-slate-500">ABRIGOS LOTADOS</p>
                <p className="text-3xl font-bold text-status-critical">{fullCount}</p>
              </Card>
            </div>

            <div className="flex w-full min-w-0 flex-col gap-3 sm:flex-row sm:items-center xl:max-w-[460px] xl:flex-1 xl:self-center">
              <label className="sr-only" htmlFor="shelter-search">Pesquisar por nome ou local</label>
              <input
                id="shelter-search"
                className="input-field h-10 min-w-0 flex-1"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Pesquisar por nome ou local"
              />

              <label className="sr-only" htmlFor="shelter-status">Filtrar status</label>
              <select
                id="shelter-status"
                className="select-field h-10 w-full shrink-0 sm:w-[150px]"
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value)}
              >
                <option value="">Todos os status</option>
                {STATUS_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>{option.label}</option>
                ))}
              </select>
            </div>
          </div>

          {success && (
            <div className="rounded-lg border border-status-success/30 bg-status-success-bg px-4 py-3 text-sm font-semibold text-status-success">
              {success}
            </div>
          )}

          {error && (
            <div className="rounded-lg border border-red-100 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
              {error}
            </div>
          )}

          <Card className="flex min-h-0 flex-1 flex-col overflow-hidden p-0">
            <div className="flex items-center justify-between border-b border-border-soft px-6 py-4">
              <h1 className="text-card-title font-bold text-slate-800">Abrigos cadastrados</h1>
              <span className="text-xs font-semibold text-slate-500">{filteredShelters.length} registro(s)</span>
            </div>

            <div className="min-h-0 flex-1 overflow-auto">
              <table className="w-full min-w-[620px] text-left text-sm">
                <thead className="sticky top-0 z-10 bg-bg-surface text-xs uppercase tracking-wide text-slate-500">
                  <tr className="border-b border-border-soft">
                    <th className="px-6 py-3 font-bold">Nome</th>
                    <th className="px-4 py-3 font-bold">Local</th>
                    <th className="px-4 py-3 font-bold">Lotação</th>
                    <th className="px-4 py-3 font-bold">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border-soft">
                  {loading ? (
                    <tr>
                      <td colSpan="4" className="px-6 py-10 text-center text-sm font-semibold text-slate-500">Carregando abrigos...</td>
                    </tr>
                  ) : filteredShelters.length === 0 ? (
                    <tr>
                      <td colSpan="4" className="px-6 py-10 text-center text-sm font-semibold text-slate-500">Nenhum abrigo encontrado.</td>
                    </tr>
                  ) : filteredShelters.map((shelter) => {
                    const status = getStatusMeta(shelter.status)
                    return (
                      <tr key={shelter.id} className="transition-colors hover:bg-slate-50">
                        <td className="px-6 py-4 align-middle">
                          <button
                            type="button"
                            onClick={() => setSelectedShelter(shelter)}
                            className="font-bold text-slate-800 underline-offset-4 hover:text-text-main hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
                          >
                            {shelter.name}
                          </button>
                          <p className="mt-1 text-xs text-slate-500">{shelter.type || 'Tipo não informado'}</p>
                        </td>
                        <td className="px-4 py-4 align-middle text-slate-600">
                          <p className="font-semibold text-slate-700">{shelter.city || '—'}</p>
                          <p className="text-xs text-slate-500">{shelter.location || 'Local não informado'}</p>
                        </td>
                        <td className="px-4 py-4 align-middle">
                          <div className="flex items-center gap-1 whitespace-nowrap">
                            <input
                              type="number"
                              min="0"
                              max={shelter.capacity || 0}
                              disabled={savingId === shelter.id}
                              className="w-20 rounded-lg border border-border-soft bg-bg-surface px-2 py-1.5 text-sm font-bold text-slate-800 focus:border-text-main focus:outline-none focus:ring-2 focus:ring-text-main/20 disabled:opacity-60"
                              value={shelter.occupied || 0}
                              onChange={(event) => handleOccupancyChange(shelter, event.target.value)}
                              aria-label={`Lotação atual de ${shelter.name}`}
                            />
                            <span className="font-bold text-slate-800">/{shelter.capacity || 0}</span>
                          </div>
                        </td>
                        <td className="min-w-[136px] px-4 py-4 align-middle">
                          <span className={status.className}>{status.label}</span>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </section>

        <aside className="min-h-0" aria-label="Mapa de abrigos cadastrados">
          <Card className="h-full min-h-[420px] overflow-hidden p-0">
            <MapView abrigos={mapShelters} mapMode="points" />
          </Card>
        </aside>
      </div>

      <Modal isOpen={isCreateOpen} onClose={() => setIsCreateOpen(false)} title="Cadastro de abrigos" size="lg">
        <form onSubmit={handleCreateShelter} className="space-y-4">
          {formError && (
            <div className="rounded-lg border border-red-100 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
              {formError}
            </div>
          )}

          <div>
            <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-name">NOME DO ABRIGO</label>
            <input
              id="shelter-name"
              className="input-field"
              value={form.name}
              onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
              required
            />
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-type">TIPO DE INSTALAÇÃO</label>
              <select
                id="shelter-type"
                className="select-field"
                value={form.type}
                onChange={(event) => setForm((current) => ({ ...current, type: event.target.value }))}
                required
              >
                <option value="">Selecione...</option>
                {INSTALLATION_TYPES.map((type) => <option key={type}>{type}</option>)}
              </select>
            </div>

            <div>
              <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-capacity">CAPACIDADE MÁXIMA</label>
              <input
                id="shelter-capacity"
                className="input-field"
                type="number"
                min="1"
                value={form.capacity}
                onChange={(event) => setForm((current) => ({ ...current, capacity: event.target.value }))}
                required
              />
            </div>

            <div>
              <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-accessibility">ACESSIBILIDADE</label>
              <select
                id="shelter-accessibility"
                className="select-field"
                value={form.accessibility}
                onChange={(event) => setForm((current) => ({ ...current, accessibility: event.target.value }))}
              >
                <option value="">Selecione...</option>
                {ACCESSIBILITY_OPTIONS.map((value) => <option key={value}>{value}</option>)}
              </select>
            </div>

            <div>
              <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-pets">ACEITA PETS</label>
              <select
                id="shelter-pets"
                className="select-field"
                value={form.acceptsPets}
                onChange={(event) => setForm((current) => ({ ...current, acceptsPets: event.target.value }))}
              >
                <option value="">Selecione...</option>
                {PET_OPTIONS.map((value) => <option key={value}>{value}</option>)}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-coordinator">NOME DO COORDENADOR DO ABRIGO</label>
            <input
              id="shelter-coordinator"
              className="input-field"
              value={form.coordinator}
              onChange={(event) => setForm((current) => ({ ...current, coordinator: event.target.value }))}
            />
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-phone">TELEFONE PRINCIPAL</label>
              <input
                id="shelter-phone"
                className="input-field"
                value={form.phone}
                onChange={(event) => setForm((current) => ({ ...current, phone: event.target.value }))}
              />
            </div>
            <div>
              <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-phone2">TELEFONE SECUNDÁRIO</label>
              <input
                id="shelter-phone2"
                className="input-field"
                value={form.phone2}
                onChange={(event) => setForm((current) => ({ ...current, phone2: event.target.value }))}
              />
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-center justify-between gap-3">
              <label className="block text-label text-slate-600" htmlFor="shelter-map">SELECIONE SUA LOCALIDADE</label>
              <button
                type="button"
                onClick={() => setIsMapOpen(true)}
                className="text-xs font-bold text-text-main underline-offset-4 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
              >
                Abrir mapa ampliado
              </button>
            </div>
            <div id="shelter-map" className="h-48 overflow-hidden rounded-xl border border-border-soft" aria-label="Mapa para selecionar localidade do abrigo">
              <MapView onMapClick={handleMapClick} targetLocation={form.lat && form.lng ? { lat: form.lat, lon: form.lng } : null} showSelectionRadius={false} />
            </div>
            <p className="mt-2 text-xs text-slate-500">
              {form.lat && form.lng
                ? `Local selecionado: ${form.city || 'cidade não identificada'}${form.location ? ` · ${form.location}` : ''}`
                : 'Clique no mapa para marcar a posição do abrigo.'}
            </p>
          </div>

          <div>
            <label className="block text-label text-slate-600 mb-1.5" htmlFor="shelter-status-field">STATUS INICIAL</label>
            <select
              id="shelter-status-field"
              className="select-field"
              value={form.status}
              onChange={(event) => setForm((current) => ({ ...current, status: event.target.value }))}
            >
              {STATUS_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <button type="button" className="btn-ghost" onClick={() => setIsCreateOpen(false)}>Cancelar</button>
            <button type="submit" disabled={savingCreate} className="rounded-full bg-red-600 px-6 py-2.5 text-sm font-bold text-white transition-colors hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-red-700 disabled:cursor-wait disabled:opacity-70">
              {savingCreate ? 'Cadastrando...' : 'Cadastrar'}
            </button>
          </div>
        </form>
      </Modal>

      <Modal isOpen={isMapOpen} onClose={() => setIsMapOpen(false)} title="Selecionar localidade do abrigo" size="xl">
        <div className="h-[65vh] overflow-hidden rounded-xl border border-border-soft">
          <MapView onMapClick={handleMapClick} targetLocation={form.lat && form.lng ? { lat: form.lat, lon: form.lng } : null} showSelectionRadius={false} />
        </div>
        <p className="mt-3 text-xs text-slate-500">Clique no ponto exato do abrigo. O município e o bairro serão preenchidos quando possível.</p>
      </Modal>

      <Modal isOpen={Boolean(selectedShelter)} onClose={() => setSelectedShelter(null)} title="Detalhes do abrigo" size="md">
        {selectedShelter && (
          <div className="space-y-4">
            <div className="rounded-2xl border border-border-soft bg-slate-50 p-4">
              <h3 className="text-lg font-bold text-slate-800">{selectedShelter.name}</h3>
              <p className="mt-1 text-sm text-slate-500">{selectedShelter.city}{selectedShelter.location ? ` · ${selectedShelter.location}` : ''}</p>
            </div>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="rounded-xl border border-border-soft bg-slate-50 p-3"><p className="text-label text-slate-500">LOTAÇÃO</p><p className="mt-1 font-bold text-slate-800">{getOccupancyLabel(selectedShelter)}</p></div>
              <div className="rounded-xl border border-border-soft bg-slate-50 p-3"><p className="text-label text-slate-500">STATUS</p><p className="mt-1"><span className={getStatusMeta(selectedShelter.status).className}>{getStatusMeta(selectedShelter.status).label}</span></p></div>
              <div className="rounded-xl border border-border-soft bg-slate-50 p-3"><p className="text-label text-slate-500">ACESSIBILIDADE</p><p className="mt-1 font-semibold text-slate-700">{selectedShelter.accessibility || '—'}</p></div>
              <div className="rounded-xl border border-border-soft bg-slate-50 p-3"><p className="text-label text-slate-500">ACEITA PETS</p><p className="mt-1 font-semibold text-slate-700">{selectedShelter.acceptsPets || '—'}</p></div>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
