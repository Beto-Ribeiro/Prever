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
    console.warn('[PREVER Ocorrências] Geocodificação reversa indisponível:', error.message)
    geocodeCache.set(cacheKey, null)
    return null
  }
}

async function enrichOccurrenceAddress(item) {
  const hasCoords = Number.isFinite(item.lat) && Number.isFinite(item.lng)
  if (!hasCoords) return item

  const shouldLookupCity = isGenericLocation(item.city)
  const shouldLookupNeighborhood = isGenericLocation(item.neighborhood)
  if (!shouldLookupCity && !shouldLookupNeighborhood) return item

  const geocode = await reverseGeocode(item.lat, item.lng)

  return {
    ...item,
    city: geocode?.city || nearestKnownCity(item.lat, item.lng) || item.city || 'Município não identificado',
    neighborhood: geocode?.neighborhood || (shouldLookupNeighborhood ? 'Bairro não identificado' : item.neighborhood),
  }
}

export function formatOccurrenceDate(value) {
  if (!value) return 'Data não informada'

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Data não informada'

  return date.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

async function getPhotoUrl(photoPath) {
  if (!photoPath) return ''
  if (/^https?:\/\//i.test(photoPath)) return photoPath

  const { data, error } = await supabase.storage
    .from(PHOTO_BUCKET)
    .createSignedUrl(photoPath, 60 * 60)

  if (error) {
    console.warn('[PREVER Ocorrências] Não foi possível assinar foto:', error.message)
    return ''
  }

  return data?.signedUrl || ''
}

async function attachPhotos(items) {
  return Promise.all(
    (items || []).map(async (item) => {
      const normalized = {
        ...item,
        lat: typeof item.lat === 'number' ? item.lat : item.lat ? Number(item.lat) : null,
        lng: typeof item.lng === 'number' ? item.lng : item.lng ? Number(item.lng) : null,
        photoUrl: await getPhotoUrl(item.photoPath),
      }

      return enrichOccurrenceAddress(normalized)
    })
  )
}

export async function getOcorrenciasData() {
  const { data, error } = await supabase.rpc('get_ocorrencias_data')

  if (error) {
    throw new Error('Não foi possível carregar ocorrências. Tente novamente.')
  }

  return {
    stats: {
      active: Number(data?.stats?.active || 0),
      monitoring: Number(data?.stats?.monitoring || 0),
      resolved: Number(data?.stats?.resolved || 0),
    },
    items: await attachPhotos(data?.items || []),
  }
}

export async function updateOcorrenciaStatus({ relatoId, status }) {
  const { data, error } = await supabase.rpc('update_ocorrencia_status', {
    p_rel_id: relatoId,
    p_status: status,
  })

  if (error) {
    throw new Error('Não foi possível atualizar o status da ocorrência. Tente novamente.')
  }

  return data
}

export function subscribeOcorrenciasChanges(onChange) {
  const channel = supabase
    .channel('ocorrencias-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Relato' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Foto' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Ocorrencia_Status' }, onChange)
    .subscribe()

  const intervalId = window.setInterval(onChange, 30000)

  return () => {
    window.clearInterval(intervalId)
    supabase.removeChannel(channel)
  }
}
