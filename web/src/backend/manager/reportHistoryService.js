import { supabase } from '../supabase/client.js'

export async function listReportHistory(shelterId) {
  const { data, error } = await supabase.from('shelter_report_history').select('id,report_type,format,start_date,end_date,created_at').eq('shelter_id', shelterId).order('created_at', { ascending: false }).limit(20)
  if (error) throw error
  return data || []
}
export async function recordReportExport(shelterId, actorId, period, format) {
  const { error } = await supabase.from('shelter_report_history').insert({ shelter_id: shelterId, actor_id: actorId, report_type: period.type, format, start_date: period.start, end_date: period.end })
  if (error) throw error
}
