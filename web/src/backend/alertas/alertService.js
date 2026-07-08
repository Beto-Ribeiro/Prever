import { supabase } from '../supabase/client.js'

function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
}

function startOfDay(date = new Date()) {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  return d.toISOString()
}

function endOfDay(date = new Date()) {
  const d = new Date(date)
  d.setHours(23, 59, 59, 999)
  return d.toISOString()
}

export function mapAlertRow(row) {
  return {
    id: row.alw_id,
    type: row.alw_tipo,
    city: row.alw_cidade,
    neighborhood: row.alw_bairro,
    severity: row.alw_severidade,
    description: row.alw_descricao,
    recipients: row.alw_destinatarios || 0,
    operatorId: row.alw_operador_id,
    operator: row.alw_operador_nome || 'Usuário SMDN',
    status: row.alw_status,
    lat: row.alw_lat,
    lng: row.alw_lng,
    metadata: row.alw_metadata || {},
    radiusKm: row.alw_metadata?.raio_km || row.alw_metadata?.radiusKm || null,
    sentAt: row.alw_created_at,
  }
}

export async function listAlerts(filters = {}) {
  let query = supabase
    .from('Alerta_Web')
    .select('*')
    .order('alw_created_at', { ascending: false })
    .limit(100)

  if (filters.severity) query = query.eq('alw_severidade', filters.severity)
  if (filters.city) query = query.ilike('alw_cidade', `%${filters.city}%`)
  if (filters.operator) query = query.ilike('alw_operador_nome', `%${filters.operator}%`)
  if (filters.date) {
    const selectedDate = new Date(`${filters.date}T00:00:00`)
    query = query.gte('alw_created_at', startOfDay(selectedDate)).lte('alw_created_at', endOfDay(selectedDate))
  }

  const { data, error } = await query

  if (error) {
    if (isMissingRelationError(error)) {
      throw new Error('O envio de alertas ainda não está disponível. Avise o responsável pelo painel.')
    }
    throw error
  }

  return (data || []).map(mapAlertRow)
}

export async function countRecipientsInArea({ lat, lng, radiusKm }) {
  if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng))) return 0

  const { data, error } = await supabase.rpc('usuarios_no_raio', {
    p_lat: Number(lat),
    p_lng: Number(lng),
    p_raio_km: Math.max(0.5, Number(radiusKm) || 3),
  })

  if (error) {
    console.warn('Não foi possível contar destinatários por área:', error.message)
    return 0
  }

  return Array.isArray(data) ? data.length : 0
}

export async function countRecipients() {
  const { count, error } = await supabase
    .from('Cidadao')
    .select('cid_id', { count: 'exact', head: true })

  if (error) {
    console.warn('Não foi possível contar cidadãos destinatários:', error.message)
    return 0
  }

  return count || 0
}

export async function countAlertsToday() {
  const { count, error } = await supabase
    .from('Alerta_Web')
    .select('alw_id', { count: 'exact', head: true })
    .gte('alw_created_at', startOfDay())
    .lte('alw_created_at', endOfDay())

  if (error) {
    if (isMissingRelationError(error)) return 0
    throw error
  }

  return count || 0
}

export async function dispatchAlert({ form, currentUser, recipients, radiusKm }) {
  if (!currentUser?.id) throw new Error('Usuário inválido para disparar alerta.')

  const payload = {
    alw_tipo: form.type,
    alw_cidade: form.city,
    alw_bairro: form.neighborhood || null,
    alw_severidade: form.severity,
    alw_descricao: form.description,
    alw_destinatarios: recipients || 0,
    alw_operador_id: currentUser.id,
    alw_operador_nome: currentUser.name || currentUser.email || 'Usuário SMDN',
    alw_lat: form.lat || null,
    alw_lng: form.lng || null,
    alw_metadata: {
      origem: 'web-reportar',
      criado_por_email: currentUser.email || null,
      segmentacao: 'raio_geografico',
      raio_km: Math.max(0.5, Number(radiusKm) || 3),
      centro: { lat: Number(form.lat), lng: Number(form.lng) },
      push_scope: 'usuarios_no_raio',
    },
  }

  const { data, error } = await supabase
    .from('Alerta_Web')
    .insert(payload)
    .select('*')
    .single()

  if (error) {
    if (isMissingRelationError(error)) {
      throw new Error('O envio de alertas ainda não está disponível. Avise o responsável pelo painel.')
    }
    throw error
  }

  return mapAlertRow(data)
}

export function subscribeReportarData(onChange) {
  const channel = supabase
    .channel('reportar-alertas-tempo-real')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Alerta_Web' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'Cidadao' }, onChange)
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}
