import { supabase } from '../supabase/client.js'

const PHOTO_BUCKET = 'Fotos_Storage'

const geocodeCache = new Map()

const KNOWN_CITIES = [
  { name: 'Pindamonhangaba', lat: -22.9239, lng: -45.4617 },
  { name: 'Roseira', lat: -22.8988, lng: -45.3070 },
  { name: 'Taubaté', lat: -23.0264, lng: -45.5553 },
  { name: 'São José dos Campos', lat: -23.2237, lng: -45.9009 },
  { name: 'Jacareí', lat: -23.3053, lng: -45.9658 },
  { name: 'Guaratinguetá', lat: -22.8164, lng: -45.1927 },
  { name: 'Caraguatatuba', lat: -23.6203, lng: -45.4131 },
]

function nearestKnownCity(lat, lng) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return ''

  return KNOWN_CITIES
    .map((city) => ({
      ...city,
      distance: ((city.lat - lat) * (city.lat - lat)) + ((city.lng - lng) * (city.lng - lng)),
    }))
    .sort((a, b) => a.distance - b.distance)[0]?.name || ''
}

function isGenericLocation(value) {
  return !value || ['local informado', 'coordenadas disponíveis', 'local não informado'].includes(String(value).toLowerCase())
}

async function reverseGeocode(lat, lng) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null

  const cacheKey = `${lat.toFixed(5)},${lng.toFixed(5)}`
  if (geocodeCache.has(cacheKey)) return geocodeCache.get(cacheKey)

  try {
    const url = new URL('https://nominatim.openstreetmap.org/reverse')
    url.searchParams.set('format', 'jsonv2')
    url.searchParams.set('lat', String(lat))
    url.searchParams.set('lon', String(lng))
    url.searchParams.set('zoom', '18')
    url.searchParams.set('addressdetails', '1')
    url.searchParams.set('accept-language', 'pt-BR')

    const response = await fetch(url.toString())
    if (!response.ok) throw new Error('Reverse geocode indisponível')

    const data = await response.json()
    const address = data?.address || {}
    const city =
      address.city ||
      address.town ||
      address.village ||
      address.municipality ||
      address.county ||
      address.state_district ||
      ''

    const neighborhood =
      address.neighbourhood ||
      address.suburb ||
      address.quarter ||
      address.city_district ||
      address.district ||
      address.hamlet ||
      address.road ||
      ''

    const result = { city, neighborhood }
    geocodeCache.set(cacheKey, result)
    return result
  } catch (error) {
    console.warn('[PREVER Dashboard] Geocodificação reversa indisponível:', error.message)
    geocodeCache.set(cacheKey, null)
    return null
  }
}

async function enrichOccurrenceAddress(occurrence) {
  const hasCoords = Number.isFinite(occurrence.lat) && Number.isFinite(occurrence.lng)
  if (!hasCoords) return occurrence

  const shouldLookupCity = isGenericLocation(occurrence.city)
  const shouldLookupNeighborhood = isGenericLocation(occurrence.neighborhood)

  if (!shouldLookupCity && !shouldLookupNeighborhood) return occurrence

  const geocode = await reverseGeocode(occurrence.lat, occurrence.lng)
  const city = geocode?.city || nearestKnownCity(occurrence.lat, occurrence.lng) || occurrence.city
  const neighborhood = geocode?.neighborhood || (shouldLookupNeighborhood ? 'Bairro não identificado' : occurrence.neighborhood)

  return {
    ...occurrence,
    city,
    neighborhood,
  }
}

export function formatRelativeTime(value) {
  if (!value) return 'Data não informada'

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Data não informada'

  const diffMs = Date.now() - date.getTime()
  const diffMinutes = Math.floor(diffMs / 60000)

  if (diffMinutes < 1) return 'Agora'
  if (diffMinutes < 60) return `${diffMinutes} min atrás`

  const diffHours = Math.floor(diffMinutes / 60)
  if (diffHours < 24) return `${diffHours}h atrás`

  return date.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

async function getPhotoUrl(photoPath) {
  if (!photoPath) return ''

  if (/^https?:\/\//i.test(photoPath)) {
    return photoPath
  }

  const { data, error } = await supabase.storage
    .from(PHOTO_BUCKET)
    .createSignedUrl(photoPath, 60 * 60)

  if (error) {
    console.warn('[PREVER Dashboard] Não foi possível assinar foto do relato:', error.message)
    return ''
  }

  return data?.signedUrl || ''
}

function normalizeVictims(victims) {
  return (victims || [])
    .map((item) => ({
      id: item.id || item.victimId || item.victim_id || `${item.lat}-${item.lng}`,
      name: item.name || item.victimName || 'Vítima localizada',
      lat: typeof item.lat === 'number' ? item.lat : item.lat ? Number(item.lat) : null,
      lng: typeof item.lng === 'number' ? item.lng : item.lng ? Number(item.lng) : null,
      source: item.source || 'relato',
      updatedAt: item.updatedAt || item.updated_at || null,
      assistanceStatus: item.assistanceStatus || item.assistance_status || 'pendente',
      assistedAt: item.assistedAt || item.assisted_at || null,
      assistedBy: item.assistedBy || item.assisted_by || null,
    }))
    .filter((item) => Number.isFinite(item.lat) && Number.isFinite(item.lng))
}

function formatOccurrenceCode(id) {
  if (!id) return 'OC-PREVER'
  return `OC-${String(id).slice(0, 6).toUpperCase()}`
}

function normalizeOccurrence(item, photoUrl) {
  const lat = typeof item.lat === 'number' ? item.lat : item.lat ? Number(item.lat) : null
  const lng = typeof item.lng === 'number' ? item.lng : item.lng ? Number(item.lng) : null
  const hasCoords = Number.isFinite(lat) && Number.isFinite(lng)
  const riskLabel = item.riskLabel || item.rel_descricao || 'Não informado'

  return {
    ...item,
    relatoId: item.id,
    id: formatOccurrenceCode(item.id),
    title: item.title || `${item.type || 'Relato'} reportado`,
    type: item.type || 'Relato',
    city: item.city || (hasCoords ? 'Local informado' : 'Local não informado'),
    neighborhood: item.neighborhood || (hasCoords ? 'Coordenadas disponíveis' : 'Local não informado'),
    status: item.status || 'active',
    riskLabel,
    description: item.description || `Nível reportado pelo cidadão: ${riskLabel}`,
    time: formatRelativeTime(item.reportedAt),
    lat,
    lng,
    photoUrl,
  }
}

async function withSignedPhotos(occurrences) {
  return Promise.all(
    (occurrences || []).map(async (item) => {
      const photoUrl = await getPhotoUrl(item.photoPath)
      const occurrence = normalizeOccurrence(item, photoUrl)
      return enrichOccurrenceAddress(occurrence)
    })
  )
}

export async function getDashboardData() {
  const { data, error } = await supabase.rpc('get_dashboard_data')

  if (error) {
    throw new Error('Não foi possível carregar o painel. Tente novamente.')
  }

  const recentOccurrences = await withSignedPhotos(data?.recentOccurrences || [])

  return {
    stats: {
      activeOccurrences: Number(data?.stats?.activeOccurrences || 0),
      activeAlerts: Number(data?.stats?.activeAlerts || 0),
      criticalSeverity: Number(data?.stats?.criticalSeverity || 0),
      resolvedToday: Number(data?.stats?.resolvedToday || 0),
      locatedVictims: Number(data?.stats?.locatedVictims || 0),
      assistedVictims: Number(data?.stats?.assistedVictims || 0),
    },
    recentOccurrences,
    victims: normalizeVictims(data?.victims || []),
  }
}


export async function updateVictimAssistance({ victim, status = 'atendida' }) {
  const { data, error } = await supabase.rpc('update_victim_assistance', {
    p_victim_id: victim.id,
    p_status: status,
    p_name: victim.name || 'Vítima localizada',
    p_lat: victim.lat,
    p_lng: victim.lng,
    p_source: victim.source || 'relato',
  })

  if (error) {
    throw new Error('Não foi possível atualizar o atendimento da vítima. Tente novamente.')
  }

  return data
}

export function subscribeDashboardChanges(onChange) {
  const channel = supabase
    .channel('dashboard-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Relato' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Foto' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Ocorrencia_Status' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Alerta_Web' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'user_tokens' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Vitima_Atendimento' }, onChange)
    .subscribe()

  const intervalId = window.setInterval(onChange, 30000)

  return () => {
    window.clearInterval(intervalId)
    supabase.removeChannel(channel)
  }
}
