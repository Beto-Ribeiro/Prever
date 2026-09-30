import { supabase } from '../supabase/client.js'

const PHOTO_BUCKET = 'Fotos_Storage'

async function getPhotoUrl(photoPath) {
  if (!photoPath) return ''
  if (/^https?:\/\//i.test(photoPath)) return photoPath

  const { data, error } = await supabase.storage
    .from(PHOTO_BUCKET)
    .createSignedUrl(photoPath, 60 * 60)

  if (error) {
    console.warn('[PREVER Validação] Não foi possível assinar foto:', error.message)
    return ''
  }

  return data?.signedUrl || ''
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

  const parsedData = await Promise.all((data || []).map(async (item) => {
    let photoUrl = ''
    if (item.Foto && item.Foto.length > 0) {
      photoUrl = await getPhotoUrl(item.Foto[0].fto_url)
    }

    return {
      id: item.rel_id,
      type: item.rel_tipo_desastre,
      description: item.rel_descricao,
      level: item.rel_gravidade,
      date: item.rel_data_hora,
      score: item.rel_fraud_score,
      reason: item.rel_fraud_reason,
      photoUrl,
    }
  }))

  return parsedData
}

export async function validarRelatoStatus({ relatoId, isValid }) {
  const status = isValid ? 'legitimo' : 'fraude'
  const { data, error } = await supabase
    .from('Relato')
    .update({ rel_fraud_status: status })
    .eq('rel_id', relatoId)

  if (error) throw new Error('Não foi possível atualizar o relato.')
  return data
}
