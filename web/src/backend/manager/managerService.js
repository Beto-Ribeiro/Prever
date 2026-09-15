import { supabase } from '../supabase/client.js'

async function result(query) {
  const { data, error } = await query
  if (error) throw error
  return data
}
async function allRows(table, shelterId, columns = '*') {
  const rows = []
  for (let start = 0; ; start += 500) {
    const page = await result(supabase.from(table).select(columns).eq('shelter_id', shelterId).order('created_at').order('id').range(start, start + 499))
    rows.push(...page)
    if (page.length < 500) return rows
  }
}
export async function loadManagerData(userId) {
  const binding = await result(supabase.from('shelter_managers').select('shelter_id').eq('user_id', userId).maybeSingle())
  if (!binding) return null
  const s = binding.shelter_id
  const [shelter, residents, inventory, requests, donations, activity] = await Promise.all([
    result(supabase.from('Abrigo').select('*').eq('abr_id', s).single()),
    allRows('shelter_residents', s), allRows('shelter_inventory', s), allRows('shelter_requests', s),
    allRows('shelter_donations', s), allRows('shelter_activity', s),
  ])
  return { shelter, residents, inventory, requests, donations, activity }
}
const fields = {
  shelter_residents: ['name', 'age', 'category', 'responsible_name', 'responsible_contact', 'entered_on', 'active'],
  shelter_inventory: ['name', 'category', 'quantity', 'target', 'unit'],
  shelter_requests: ['inventory_id', 'target', 'priority'],
  shelter_donations: ['request_id', 'donor', 'donor_contact', 'quantity'],
}
export async function saveManagerRecord(table, shelterId, values, id) {
  if (!fields[table]) throw new Error('Ação inválida.')
  const payload = Object.fromEntries(fields[table].filter(k => values[k] !== undefined).map(k => [k, values[k]]))
  const query = id
    ? supabase.from(table).update(payload).eq('id', id).eq('shelter_id', shelterId)
    : supabase.from(table).insert({ ...payload, shelter_id: shelterId })
  return result(query.select('*').single())
}
export async function saveShelter(shelterId, form) {
  return result(supabase.rpc('manager_update_shelter_contacts', { s: shelterId, n: form.name, address: form.address, phone: form.phone, capacity: Number(form.capacity), coordinator_name: form.coordinator || '', coordinator_contact: form.coordinatorContact || '' }))
}

// Same authorized records as the portal, including the displayed personal details.
export async function loadManagerAssistantData(userId) {
  return loadManagerData(userId)
}
