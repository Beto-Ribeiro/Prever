import { supabase } from '../supabase/client.js'

const SHELTER_COLUMNS = [
  'abr_id',
  'abr_nome',
  'abr_tipo',
  'abr_capacidade',
  'abr_ocupacao',
  'abr_acessibilidade',
  'abr_aceita_pets',
  'abr_coordenador',
  'abr_coordenador_contato',
  'abr_telefone_principal',
  'abr_telefone_secundario',
  'abr_detalhes',
  'abr_cidade',
  'abr_bairro',
  'abr_lat',
  'abr_lng',
  'abr_status',
  'abr_created_by',
  'abr_created_at',
  'abr_updated_at',
].join(',')

function getStatusFromOccupancy(occupied, capacity, fallback = 'disponivel') {
  const total = Number(capacity) || 0
  const current = Number(occupied) || 0

  if (fallback === 'inativo') return 'inativo'
  if (total <= 0) return fallback || 'disponivel'
  if (current >= total) return 'lotado'
  if (current >= total * 0.85) return 'quase_lotado'
  return 'disponivel'
}

function toNumberOrNull(value) {
  if (value === '' || value === null || value === undefined) return null
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

function mapShelterRow(row) {
  if (!row) return null

  const capacity = Number(row.abr_capacidade || 0)
  const occupied = Number(row.abr_ocupacao || 0)

  return {
    id: row.abr_id,
    name: row.abr_nome || '',
    type: row.abr_tipo || '',
    capacity,
    occupied,
    accessibility: row.abr_acessibilidade || '',
    acceptsPets: row.abr_aceita_pets || '',
    coordinator: row.abr_coordenador || '',
    coordinatorContact: row.abr_coordenador_contato || '',
    phone: row.abr_telefone_principal || '',
    phone2: row.abr_telefone_secundario || '',
    details: row.abr_detalhes || '',
    city: row.abr_cidade || '',
    location: row.abr_bairro || '',
    lat: toNumberOrNull(row.abr_lat),
    lng: toNumberOrNull(row.abr_lng),
    status: row.abr_status || getStatusFromOccupancy(occupied, capacity),
    createdBy: row.abr_created_by || null,
    createdAt: row.abr_created_at || '',
    updatedAt: row.abr_updated_at || '',
  }
}

function normalizeShelterPayload(payload, { forceStatusFromOccupancy = false } = {}) {
  const capacity = Number(payload.capacity || payload.maxCapacity || 0)
  const occupied = Math.max(0, Math.min(Number(payload.occupied || 0), capacity || 0))
  const requestedStatus = payload.status || getStatusFromOccupancy(occupied, capacity)
  const status = forceStatusFromOccupancy
    ? getStatusFromOccupancy(occupied, capacity, requestedStatus)
    : requestedStatus

  const lat = toNumberOrNull(payload.lat)
  const lng = toNumberOrNull(payload.lng)

  return {
    abr_nome: String(payload.name || '').trim(),
    abr_tipo: String(payload.type || '').trim(),
    abr_capacidade: capacity,
    abr_ocupacao: occupied,
    abr_acessibilidade: String(payload.accessibility || '').trim() || null,
    abr_aceita_pets: String(payload.acceptsPets || '').trim() || null,
    abr_coordenador: String(payload.coordinator || '').trim() || null,
    abr_coordenador_contato: String(payload.coordinatorContact || '').trim(),
    abr_telefone_principal: String(payload.phone || '').trim() || null,
    abr_telefone_secundario: String(payload.phone2 || '').trim() || null,
    abr_detalhes: String(payload.details || '').trim() || null,
    abr_cidade: String(payload.city || '').trim() || null,
    abr_bairro: String(payload.location || '').trim() || null,
    abr_lat: lat,
    abr_lng: lng,
    abr_status: status,
    abr_updated_at: new Date().toISOString(),
  }
}

function validateShelterPayload(row) {
  if (!row.abr_nome) throw new Error('Informe o nome do abrigo.')
  if (!row.abr_tipo) throw new Error('Informe o tipo de instalação.')
  if (!row.abr_capacidade || row.abr_capacidade < 1) throw new Error('Informe uma capacidade máxima válida.')
  if (!row.abr_cidade && (!Number.isFinite(row.abr_lat) || !Number.isFinite(row.abr_lng))) {
    throw new Error('Selecione a localidade do abrigo.')
  }
}

export async function listShelters() {
  const { data, error } = await supabase
    .from('Abrigo')
    .select(SHELTER_COLUMNS)
    .order('abr_created_at', { ascending: false })

  if (error) throw error
  return (data || []).map(mapShelterRow).filter(Boolean)
}

export async function createShelter(payload) {
  const row = normalizeShelterPayload({ ...payload, occupied: 0 })
  validateShelterPayload(row)

  const { data: userResult } = await supabase.auth.getUser()
  const createdBy = userResult?.user?.id || null

  const { data, error } = await supabase
    .from('Abrigo')
    .insert({
      ...row,
      abr_created_by: createdBy,
      abr_created_at: new Date().toISOString(),
    })
    .select(SHELTER_COLUMNS)
    .single()

  if (error) throw error
  return mapShelterRow(data)
}

export async function updateShelter(id, payload) {
  const row = normalizeShelterPayload(payload, { forceStatusFromOccupancy: true })
  validateShelterPayload(row)

  const { data, error } = await supabase
    .from('Abrigo')
    .update(row)
    .eq('abr_id', id)
    .select(SHELTER_COLUMNS)
    .single()

  if (error) throw error
  return mapShelterRow(data)
}

export async function updateShelterOccupancy(id, occupied, capacity, currentStatus = 'disponivel') {
  const nextOccupied = Math.max(0, Math.min(Number(occupied) || 0, Number(capacity) || 0))
  const nextStatus = getStatusFromOccupancy(nextOccupied, capacity, currentStatus)

  const { data, error } = await supabase
    .from('Abrigo')
    .update({
      abr_ocupacao: nextOccupied,
      abr_status: nextStatus,
      abr_updated_at: new Date().toISOString(),
    })
    .eq('abr_id', id)
    .select(SHELTER_COLUMNS)
    .single()

  if (error) throw error
  return mapShelterRow(data)
}

export async function deleteShelter(id) {
  const { error } = await supabase
    .from('Abrigo')
    .delete()
    .eq('abr_id', id)

  if (error) throw error
}

export function subscribeShelterChanges(callback) {
  const channel = supabase
    .channel('smdn-abrigos')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Abrigo' }, callback)
    .subscribe()

  return () => supabase.removeChannel(channel)
}
