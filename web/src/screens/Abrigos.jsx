import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import Card from '../components/Card.jsx'
import Modal from '../components/Modal.jsx'
import MapView from '../components/MapView.jsx'
import {
  createShelter,
  deleteShelter,
  listShelters,
  subscribeShelterChanges,
  updateShelter,
  updateShelterOccupancy,
} from '../backend/abrigos/shelterService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import { formatBrazilPhone } from '../utils/phone.js'

const INSTALLATION_TYPES = ['Escola pública', 'Ginásio', 'Centro comunitário', 'Igreja', 'Posto de apoio']
const ACCESSIBILITY_OPTIONS = ['Sim', 'Parcial', 'Não informado']
const PET_OPTIONS = ['Sim', 'Não', 'Sob avaliação']
const STATUS_OPTIONS = [
  { value: 'disponivel', label: 'Disponível' },
  { value: 'quase_lotado', label: 'Quase lotado' },
  { value: 'lotado', label: 'Lotado' },
  { value: 'inativo', label: 'Inativo' },
]

const INITIAL_FORM = {
  name: '',
  type: '',
  capacity: '',
  accessibility: '',
  acceptsPets: '',
  coordinator: '',
  coordinatorContact: '',
  phone: '',
  phone2: '',
  details: '',
  city: '',
  location: '',
  lat: null,
  lng: null,
  status: 'disponivel',
}

function getOccupancyLabel(shelter) {
  return `${shelter.occupied || 0}/${shelter.capacity || 0}`
}

function getStatusFromOccupancy(occupied, capacity, currentStatus = 'disponivel') {
  if (currentStatus === 'inativo') return 'inativo'

  const total = Number(capacity) || 0
  const current = Number(occupied) || 0

  if (total > 0 && current >= total) return 'lotado'
  if (total > 0 && current >= total * 0.85) return 'quase_lotado'
  return 'disponivel'
}

function getStatusMeta(status) {
  if (status === 'lotado') return { label: 'Lotado', className: 'badge-critical inline-flex w-max min-w-[92px] justify-center whitespace-nowrap px-2.5' }
  if (status === 'quase_lotado') return { label: 'Quase lotado', className: 'badge-severe inline-flex w-max min-w-[108px] justify-center whitespace-nowrap px-2.5' }
  if (status === 'inativo') return { label: 'Inativo', className: 'inline-flex w-max min-w-[92px] justify-center whitespace-nowrap rounded-full bg-slate-200 px-2.5 py-1 text-xs font-bold text-slate-600' }
  return { label: 'Disponível', className: 'badge-success inline-flex w-max min-w-[92px] justify-center whitespace-nowrap px-2.5' }
}

function isValidShelterCoord(shelter) {
  return Number.isFinite(shelter?.lat) && Number.isFinite(shelter?.lng)
}

function formFromShelter(shelter) {
  return {
    name: shelter.name || '',
    type: shelter.type || '',
    capacity: String(shelter.capacity || ''),
    accessibility: shelter.accessibility || '',
    acceptsPets: shelter.acceptsPets || '',
    coordinator: shelter.coordinator || '',
    coordinatorContact: shelter.coordinatorContact || '',
    phone: shelter.phone || '',
    phone2: shelter.phone2 || '',
    details: shelter.details || '',
    city: shelter.city || '',
    location: shelter.location || '',
    lat: shelter.lat,
    lng: shelter.lng,
    status: shelter.status || 'disponivel',
  }
}

function EditIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="m4 16-.8 4.8L8 20l10.7-10.7a2.1 2.1 0 0 0 0-3L17.7 5.3a2.1 2.1 0 0 0-3 0L4 16Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <path d="m13.5 6.5 4 4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  )
}

function DeleteIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M4 7h16M9 7V4h6v3m-8 0 1 13h8l1-13M10 11v5m4-5v5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

export default function Abrigos() {
  const mapRef = useRef(null)
  const [shelters, setShelters] = useState([])
  const [query, setQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [isMapOpen, setIsMapOpen] = useState(false)
  const [editingShelterId, setEditingShelterId] = useState('')
  const [deleteTarget, setDeleteTarget] = useState(null)
  const [form, setForm] = useState(INITIAL_FORM)
  const [error, setError] = useState('')
  const [formError, setFormError] = useState('')
  const [success, setSuccess] = useState('')
  const [selectedShelterId, setSelectedShelterId] = useState('')
  const [loading, setLoading] = useState(true)
  const [savingId, setSavingId] = useState('')
  const [savingForm, setSavingForm] = useState(false)
  const [deletingId, setDeletingId] = useState('')

  const selectedShelter = useMemo(
    () => shelters.find((shelter) => shelter.id === selectedShelterId) || null,
    [selectedShelterId, shelters]
  )

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

  useEffect(() => {
    if (!loading && selectedShelterId && !shelters.some((item) => item.id === selectedShelterId)) {
      setSelectedShelterId('')
    }
  }, [loading, selectedShelterId, shelters])

  const filteredShelters = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase()
    return shelters.filter((shelter) => {
      const matchesQuery = !normalizedQuery || [shelter.name, shelter.city, shelter.location, shelter.type]
        .filter(Boolean)
        .some((value) => value.toLowerCase().includes(normalizedQuery))
      const matchesStatus = !statusFilter || shelter.status === statusFilter
      return matchesQuery && matchesStatus
    })
  }, [query, shelters, statusFilter])

  const availableCount = shelters.filter((shelter) => !['lotado', 'inativo'].includes(shelter.status)).length
  const fullCount = shelters.filter((shelter) => shelter.status === 'lotado').length
  const mapShelters = useMemo(
    () => filteredShelters.filter(isValidShelterCoord),
    [filteredShelters]
  )

  const hasFormCoordinates = Number.isFinite(form.lat) && Number.isFinite(form.lng)

  const selectShelter = useCallback((shelter) => {
    if (!shelter) return
    setSelectedShelterId(shelter.id)

    if (isValidShelterCoord(shelter)) {
      mapRef.current?.flyTo(shelter.lat, shelter.lng, 16)
    }
  }, [])

  function showSuccess(message) {
    setSuccess(message)
    window.setTimeout(() => setSuccess(''), 3500)
  }

  function resetForm() {
    setForm(INITIAL_FORM)
    setFormError('')
    setEditingShelterId('')
  }

  function closeFormModal() {
    setIsFormOpen(false)
    setIsMapOpen(false)
    resetForm()
  }

  function openCreateModal() {
    resetForm()
    setIsFormOpen(true)
  }

  function openEditModal(shelter) {
    setSelectedShelterId(shelter.id)
    setEditingShelterId(shelter.id)
    setForm(formFromShelter(shelter))
    setFormError('')
    setIsFormOpen(true)
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

  async function handleSaveShelter(event) {
    event.preventDefault()
    setFormError('')
    setSavingForm(true)

    try {
      if (editingShelterId) {
        const currentShelter = shelters.find((item) => item.id === editingShelterId)
        const updated = await updateShelter(editingShelterId, {
          ...form,
          occupied: currentShelter?.occupied || 0,
        })
        setShelters((current) => current.map((item) => item.id === updated.id ? updated : item))
        setSelectedShelterId(updated.id)
        showSuccess('Abrigo atualizado com sucesso.')
        closeFormModal()
        window.setTimeout(() => selectShelter(updated), 80)
      } else {
        const shelter = await createShelter(form)
        setShelters((current) => [shelter, ...current])
        setSelectedShelterId(shelter.id)
        showSuccess('Abrigo cadastrado com sucesso.')
        closeFormModal()
        window.setTimeout(() => selectShelter(shelter), 80)
      }
    } catch (err) {
      setFormError(toFriendlyMessage(err, editingShelterId
        ? 'Não foi possível atualizar o abrigo.'
        : 'Não foi possível cadastrar o abrigo.'))
    } finally {
      setSavingForm(false)
    }
  }

  async function handleOccupancyChange(shelter, value) {
    const nextOccupied = Math.max(0, Math.min(Number(value) || 0, shelter.capacity || 0))
    const optimistic = {
      ...shelter,
      occupied: nextOccupied,
      status: getStatusFromOccupancy(nextOccupied, shelter.capacity, shelter.status),
    }

    setSavingId(shelter.id)
    setShelters((current) => current.map((item) => item.id === shelter.id ? optimistic : item))

    try {
      const updated = await updateShelterOccupancy(shelter.id, nextOccupied, shelter.capacity, shelter.status)
      setShelters((current) => current.map((item) => item.id === shelter.id ? updated : item))
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível atualizar a lotação do abrigo.'))
      loadShelters({ silent: true })
    } finally {
      setSavingId('')
    }
  }

  async function handleDeleteShelter() {
    if (!deleteTarget) return

    setDeletingId(deleteTarget.id)
    setError('')

    try {
      await deleteShelter(deleteTarget.id)
      setShelters((current) => current.filter((item) => item.id !== deleteTarget.id))
      if (selectedShelterId === deleteTarget.id) setSelectedShelterId('')
      setDeleteTarget(null)
      showSuccess('Abrigo excluído com sucesso.')
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível excluir o abrigo.'))
    } finally {
      setDeletingId('')
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden p-4 animate-fade-in">
      <div className="grid flex-1 min-h-0 grid-cols-1 gap-4 xl:grid-cols-[minmax(620px,1fr)_minmax(330px,0.48fr)] 2xl:grid-cols-[minmax(700px,1fr)_minmax(370px,0.44fr)]">
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
                <span className="text-center text-[0.6875rem] font-bold leading-tight">Cadastrar<br />abrigo</span>
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
                placeholder="Pesquisar abrigo..."
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
              <div>
                <h1 className="text-card-title font-bold text-slate-800">Abrigos cadastrados</h1>
                <p className="mt-0.5 text-xs text-slate-500">Selecione um abrigo para destacá-lo no mapa.</p>
              </div>
              <span className="text-xs font-semibold text-slate-500">{filteredShelters.length} registro(s)</span>
            </div>

            <div className="min-h-0 flex-1 overflow-auto">
              <table className="w-full min-w-[760px] text-left text-sm">
                <thead className="sticky top-0 z-10 bg-bg-surface text-xs uppercase tracking-wide text-slate-500">
                  <tr className="border-b border-border-soft">
                    <th className="px-6 py-3 font-bold">Nome</th>
                    <th className="px-4 py-3 font-bold">Local</th>
                    <th className="px-4 py-3 font-bold">Lotação</th>
                    <th className="px-4 py-3 font-bold">Status</th>
                    <th className="px-4 py-3 text-right font-bold">Ações</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border-soft">
                  {loading ? (
                    <tr>
                      <td colSpan="5" className="px-6 py-10 text-center text-sm font-semibold text-slate-500">Carregando abrigos...</td>
                    </tr>
                  ) : filteredShelters.length === 0 ? (
                    <tr>
                      <td colSpan="5" className="px-6 py-10 text-center text-sm font-semibold text-slate-500">Nenhum abrigo encontrado.</td>
                    </tr>
                  ) : filteredShelters.map((shelter) => {
                    const status = getStatusMeta(shelter.status)
                    const isSelected = shelter.id === selectedShelterId
                    return (
                      <tr
                        key={shelter.id}
                        onClick={() => selectShelter(shelter)}
                        aria-selected={isSelected}
                        className={`cursor-pointer transition-all ${isSelected
                          ? 'bg-sky-50 shadow-[inset_4px_0_0_rgb(var(--text-main))]'
                          : 'hover:bg-slate-50'}`}
                      >
                        <td className="px-6 py-4 align-middle">
                          <button
                            type="button"
                            onClick={(event) => {
                              event.stopPropagation()
                              selectShelter(shelter)
                            }}
                            className="text-left font-bold text-slate-800 underline-offset-4 hover:text-text-main hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
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
                          <div className="flex items-center gap-1 whitespace-nowrap" onClick={(event) => event.stopPropagation()}>
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
                        <td className="px-4 py-4 align-middle">
                          <div className="flex justify-end gap-2" onClick={(event) => event.stopPropagation()}>
                            <button
                              type="button"
                              onClick={() => openEditModal(shelter)}
                              className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-border-soft bg-bg-surface text-slate-600 transition-colors hover:border-sky-300 hover:bg-sky-50 hover:text-sky-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
                              aria-label={`Editar ${shelter.name}`}
                              title="Editar abrigo"
                            >
                              <EditIcon />
                            </button>
                            <button
                              type="button"
                              onClick={() => setDeleteTarget(shelter)}
                              className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-red-100 bg-red-50 text-red-600 transition-colors hover:border-red-300 hover:bg-red-100 hover:text-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-red-600"
                              aria-label={`Excluir ${shelter.name}`}
                              title="Excluir abrigo"
                            >
                              <DeleteIcon />
                            </button>
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </section>

        <aside className="flex min-h-0 flex-col gap-3" aria-label="Mapa e detalhes dos abrigos">
          <Card className="min-h-[330px] flex-1 overflow-hidden p-0">
            <MapView
              ref={mapRef}
              abrigos={mapShelters}
              mapMode="points"
              selectedShelterId={selectedShelterId}
              onShelterSelect={selectShelter}
            />
          </Card>

          <Card className="max-h-[46%] min-h-[210px] flex-shrink-0 overflow-y-auto p-5">
            {selectedShelter ? (
              <div className="space-y-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-label text-slate-500">ABRIGO SELECIONADO</p>
                    <h2 className="mt-1 truncate text-xl font-bold text-slate-800">{selectedShelter.name}</h2>
                    <p className="mt-1 text-sm text-slate-500">
                      {[selectedShelter.city, selectedShelter.location].filter(Boolean).join(' · ') || 'Local não informado'}
                    </p>
                  </div>
                  <span className={getStatusMeta(selectedShelter.status).className}>{getStatusMeta(selectedShelter.status).label}</span>
                </div>

                <div className="grid grid-cols-2 gap-2.5">
                  <div className="rounded-xl border border-border-soft bg-slate-50 p-3">
                    <p className="text-label text-slate-500">INSTALAÇÃO</p>
                    <p className="mt-1 text-sm font-semibold text-slate-700">{selectedShelter.type || 'Não informada'}</p>
                  </div>
                  <div className="rounded-xl border border-border-soft bg-slate-50 p-3">
                    <p className="text-label text-slate-500">LOTAÇÃO</p>
                    <p className="mt-1 text-sm font-bold text-slate-800">{getOccupancyLabel(selectedShelter)}</p>
                  </div>
                  <div className="rounded-xl border border-border-soft bg-slate-50 p-3">
                    <p className="text-label text-slate-500">ACESSIBILIDADE</p>
                    <p className="mt-1 text-sm font-semibold text-slate-700">{selectedShelter.accessibility || 'Não informada'}</p>
                  </div>
                  <div className="rounded-xl border border-border-soft bg-slate-50 p-3">
                    <p className="text-label text-slate-500">ACEITA PETS</p>
                    <p className="mt-1 text-sm font-semibold text-slate-700">{selectedShelter.acceptsPets || 'Não informado'}</p>
                  </div>
                </div>

                <div className="space-y-2 rounded-xl border border-border-soft p-3">
                  <div>
                    <p className="text-label text-slate-500">COORDENAÇÃO</p>
                    <p className="mt-1 text-sm font-semibold text-slate-700">{selectedShelter.coordinator || 'Não informada'}</p><p className="mt-2 text-label text-slate-500">CONTATO DO RESPONSÁVEL</p><p className="mt-1 text-sm text-slate-700">{selectedShelter.coordinatorContact || 'Não informado'}</p>
                  </div>
                  <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2">
                    <div>
                      <p className="text-label text-slate-500">TELEFONE PRINCIPAL</p>
                      {selectedShelter.phone ? (
                        <a className="mt-1 inline-block text-sm font-bold text-text-main hover:underline" href={`tel:${selectedShelter.phone}`}>{selectedShelter.phone}</a>
                      ) : <p className="mt-1 text-sm text-slate-500">Não informado</p>}
                    </div>
                    <div>
                      <p className="text-label text-slate-500">TELEFONE SECUNDÁRIO</p>
                      {selectedShelter.phone2 ? (
                        <a className="mt-1 inline-block text-sm font-bold text-text-main hover:underline" href={`tel:${selectedShelter.phone2}`}>{selectedShelter.phone2}</a>
                      ) : <p className="mt-1 text-sm text-slate-500">Não informado</p>}
                    </div>
                  </div>
                </div>

                <div className="rounded-xl border border-border-soft bg-slate-50 p-3">
                  <p className="text-label text-slate-500">DETALHES DO ABRIGO</p>
                  <p className="mt-1 whitespace-pre-line text-sm leading-6 text-slate-700">
                    {selectedShelter.details || 'Nenhum detalhe adicional informado.'}
                  </p>
                </div>

                <div className="flex gap-2 border-t border-border-soft pt-4">
                  <button
                    type="button"
                    onClick={() => openEditModal(selectedShelter)}
                    className="inline-flex flex-1 items-center justify-center gap-2 rounded-full bg-text-main px-4 py-2.5 text-sm font-bold text-white transition-colors hover:bg-sky-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-text-main"
                  >
                    <EditIcon />
                    Editar abrigo
                  </button>
                  <button
                    type="button"
                    onClick={() => setDeleteTarget(selectedShelter)}
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-red-200 bg-red-50 px-4 py-2.5 text-sm font-bold text-red-700 transition-colors hover:bg-red-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
                  >
                    <DeleteIcon />
                    Excluir
                  </button>
                </div>
              </div>
            ) : (
              <div className="flex min-h-[168px] flex-col items-center justify-center px-4 text-center">
                <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-sky-50 text-text-main">
                  <svg width="25" height="25" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M3 11.5 12 4l9 7.5M5.5 10.5V20h13v-9.5M9.5 20v-6h5v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </span>
                <h2 className="mt-3 text-base font-bold text-slate-700">Selecione um abrigo</h2>
                <p className="mt-1 max-w-[280px] text-sm text-slate-500">Clique em um registro da lista ou em um marcador do mapa para ver todos os detalhes.</p>
              </div>
            )}
          </Card>
        </aside>
      </div>

      <Modal
        isOpen={isFormOpen}
        onClose={closeFormModal}
        title={editingShelterId ? 'Editar abrigo' : 'Cadastro de abrigos'}
        size="lg"
      >
        <form onSubmit={handleSaveShelter} className="space-y-4">
          {formError && (
            <div className="rounded-lg border border-red-100 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
              {formError}
            </div>
          )}

          <div>
            <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-name">NOME DO ABRIGO</label>
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
              <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-type">TIPO DE INSTALAÇÃO</label>
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
              <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-capacity">CAPACIDADE MÁXIMA</label>
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
              <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-accessibility">ACESSIBILIDADE</label>
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
              <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-pets">ACEITA PETS</label>
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
            <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-coordinator">NOME DO COORDENADOR DO ABRIGO</label>
            <input
              id="shelter-coordinator"
              className="input-field"
              value={form.coordinator}
              onChange={(event) => setForm((current) => ({ ...current, coordinator: event.target.value }))}
            />
          </div>

          <div><label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-coordinator-contact">CONTATO DO RESPONSÁVEL</label><input id="shelter-coordinator-contact" className="input-field" value={form.coordinatorContact} onChange={event => setForm(current => ({ ...current, coordinatorContact: event.target.value }))} placeholder="Telefone ou e-mail" maxLength={120} /></div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-phone">TELEFONE PRINCIPAL</label>
              <input
                id="shelter-phone"
                className="input-field"
                inputMode="numeric"
                placeholder="(99) 99999-9999"
                value={form.phone}
                onChange={(event) => setForm((current) => ({ ...current, phone: formatBrazilPhone(event.target.value) }))}
              />
            </div>
            <div>
              <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-phone2">TELEFONE SECUNDÁRIO</label>
              <input
                id="shelter-phone2"
                className="input-field"
                inputMode="numeric"
                placeholder="(99) 99999-9999"
                value={form.phone2}
                onChange={(event) => setForm((current) => ({ ...current, phone2: formatBrazilPhone(event.target.value) }))}
              />
            </div>
          </div>

          <div>
            <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-details">DETALHES DO ABRIGO</label>
            <textarea
              id="shelter-details"
              className="input-field min-h-[110px] resize-y"
              maxLength="1200"
              placeholder="Informe estrutura disponível, horários, orientações de acesso e outras informações úteis."
              value={form.details}
              onChange={(event) => setForm((current) => ({ ...current, details: event.target.value }))}
            />
            <p className="mt-1 text-right text-xs text-slate-400">{form.details.length}/1200</p>
          </div>

          <div>
            <div className="mb-2 flex items-center justify-between gap-3">
              <label className="block text-label text-slate-600" htmlFor="shelter-map">SELECIONE A LOCALIDADE</label>
              <button
                type="button"
                onClick={() => setIsMapOpen(true)}
                className="text-xs font-bold text-text-main underline-offset-4 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
              >
                Abrir mapa ampliado
              </button>
            </div>
            <div id="shelter-map" className="h-48 overflow-hidden rounded-xl border border-border-soft" aria-label="Mapa para selecionar localidade do abrigo">
              <MapView onMapClick={handleMapClick} targetLocation={hasFormCoordinates ? { lat: form.lat, lon: form.lng } : null} showSelectionRadius={false} />
            </div>
            <p className="mt-2 text-xs text-slate-500">
              {hasFormCoordinates
                ? `Local selecionado: ${form.city || 'cidade não identificada'}${form.location ? ` · ${form.location}` : ''}`
                : 'Clique no mapa para marcar a posição do abrigo.'}
            </p>
          </div>

          <div>
            <label className="mb-1.5 block text-label text-slate-600" htmlFor="shelter-status-field">STATUS</label>
            <select
              id="shelter-status-field"
              className="select-field"
              value={form.status}
              onChange={(event) => setForm((current) => ({ ...current, status: event.target.value }))}
            >
              {STATUS_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
            {editingShelterId && form.status !== 'inativo' && (
              <p className="mt-1 text-xs text-slate-500">Ao salvar, o status será ajustado automaticamente conforme a lotação.</p>
            )}
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <button type="button" className="btn-ghost" onClick={closeFormModal}>Cancelar</button>
            <button type="submit" disabled={savingForm} className="rounded-full bg-red-600 px-6 py-2.5 text-sm font-bold text-white transition-colors hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-red-700 disabled:cursor-wait disabled:opacity-70">
              {savingForm
                ? (editingShelterId ? 'Salvando...' : 'Cadastrando...')
                : (editingShelterId ? 'Salvar alterações' : 'Cadastrar')}
            </button>
          </div>
        </form>
      </Modal>

      <Modal isOpen={isMapOpen} onClose={() => setIsMapOpen(false)} title="Selecionar localidade do abrigo" size="xl">
        <div className="h-[65vh] overflow-hidden rounded-xl border border-border-soft">
          <MapView onMapClick={handleMapClick} targetLocation={hasFormCoordinates ? { lat: form.lat, lon: form.lng } : null} showSelectionRadius={false} />
        </div>
        <p className="mt-3 text-xs text-slate-500">Clique no ponto exato do abrigo. O município e o bairro serão preenchidos quando possível.</p>
      </Modal>

      <Modal isOpen={Boolean(deleteTarget)} onClose={() => !deletingId && setDeleteTarget(null)} title="Excluir abrigo" size="sm">
        {deleteTarget && (
          <div>
            <div className="rounded-xl border border-red-100 bg-red-50 p-4">
              <p className="font-bold text-red-800">Tem certeza que deseja excluir “{deleteTarget.name}”?</p>
              <p className="mt-2 text-sm leading-6 text-red-700">O abrigo será removido da lista e do mapa. Esta ação não pode ser desfeita.</p>
            </div>
            <div className="mt-5 flex justify-end gap-3">
              <button type="button" className="btn-ghost" disabled={Boolean(deletingId)} onClick={() => setDeleteTarget(null)}>Cancelar</button>
              <button
                type="button"
                disabled={Boolean(deletingId)}
                onClick={handleDeleteShelter}
                className="rounded-full bg-red-600 px-6 py-2.5 text-sm font-bold text-white transition-colors hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-red-700 disabled:cursor-wait disabled:opacity-70"
              >
                {deletingId ? 'Excluindo...' : 'Excluir abrigo'}
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
