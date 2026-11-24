import { supabase } from '../supabase/client.js'

const PHOTO_BUCKET = 'Fotos_Storage'

async function resolveSignedPhotoUrls(paths) {
  const result = new Map()
  const storagePaths = []

  for (const raw of paths) {
    if (!raw) continue
    if (/^https?:\/\//i.test(raw)) {
      result.set(raw, raw)
    } else if (!result.has(raw)) {
      result.set(raw, '')
      storagePaths.push(raw)
    }
  }

  if (storagePaths.length === 0) return result

  const storageBucket = supabase.storage.from(PHOTO_BUCKET)

  if (typeof storageBucket.createSignedUrls === 'function') {
    const { data, error } = await storageBucket.createSignedUrls(storagePaths, 60 * 60)
    if (!error && Array.isArray(data)) {
      for (const entry of data) {
        if (entry?.path && entry?.signedUrl) {
          result.set(entry.path, entry.signedUrl)
        }
      }
      return result
    }
  }

  await Promise.all(storagePaths.map(async (path) => {
    const { data, error } = await storageBucket.createSignedUrl(path, 60 * 60)
    if (error) {
      console.warn('[PREVER Validação] Não foi possível assinar foto:', error.message)
      return
    }
    result.set(path, data?.signedUrl || '')
  }))

  return result
}

export async function getRelatosPendentes() {
  const { data, error } = await supabase
    .from('Relato')
    .select(`
      rel_id,
      rel_tipo_desastre,
      rel_descricao,
      rel_gravidade,
      rel_data_hora,
      rel_fraud_score,
      rel_fraud_reason,
      Foto ( fto_url )
    `)
    .eq('rel_fraud_status', 'pendente_revisao')
    .order('rel_data_hora', { ascending: false })

  if (error) throw new Error('Erro ao carregar relatos pendentes')

  const rows = data || []
  const photoPaths = rows.map((item) => item?.Foto?.[0]?.fto_url || '').filter(Boolean)
  const signedMap = await resolveSignedPhotoUrls(photoPaths)

  return rows.map((item) => {
    const rawPhoto = item?.Foto?.[0]?.fto_url || ''
    return {
      id: item.rel_id,
      type: item.rel_tipo_desastre,
      description: item.rel_descricao,
      level: item.rel_gravidade,
      date: item.rel_data_hora,
      score: item.rel_fraud_score,
      reason: item.rel_fraud_reason,
      photoUrl: rawPhoto ? (signedMap.get(rawPhoto) || '') : '',
    }
  })
}

export async function validarRelatoStatus({ relatoId, isValid, reason }) {
  if (!relatoId) throw new Error('Identificador do relato é obrigatório.')

  const { data: authData } = await supabase.auth.getUser()
  const adminId = authData?.user?.id || null

  const rpcName = isValid ? 'aprovar_relato' : 'rejeitar_relato'
  const rpcArgs = isValid
    ? { p_rel_id: relatoId, p_admin_id: adminId }
    : {
        p_rel_id: relatoId,
        p_admin_id: adminId,
        ...(reason ? { p_motivo: reason } : {}),
      }

  const { error: rpcError } = await supabase.rpc(rpcName, rpcArgs)
  if (!rpcError) {
    return { status: isValid ? 'aprovado' : 'rejeitado', viaRpc: true }
  }

  // Fallback compatível com o CHECK constraint relato_fraud_status_check caso a RPC
  // ainda não tenha sido aplicada no ambiente de banco.
  const isMissingRpc = /function .* does not exist|could not find the function/i.test(
    rpcError.message || ''
  )
  if (!isMissingRpc) {
    throw new Error(rpcError.message || 'Não foi possível validar o relato.')
  }

  const status = isValid ? 'aprovado' : 'rejeitado'
  const updatePayload = {
    rel_fraud_status: status,
    rel_needs_admin_review: false,
    rel_prioridade: isValid ? 'normal' : 'baixa',
    ...(reason && !isValid ? { rel_fraud_reason: reason } : {}),
  }

  const { data, error } = await supabase
    .from('Relato')
    .update(updatePayload)
    .eq('rel_id', relatoId)

  if (error) throw new Error('Não foi possível atualizar o relato.')
  return data
}
