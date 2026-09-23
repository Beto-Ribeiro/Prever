export function activityIcon(detail) {
  const text = String(detail || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  if (/critic|urgente|alerta/.test(text)) return 'alert-triangle'
  if (/doacao|doou|doacoes/.test(text)) return 'gift'
  if (/ocupante/.test(text)) return 'user-plus'
  if (/pedido/.test(text)) return 'file-plus'
  if (/estoque|recurso/.test(text)) return 'package'
  if (/abrigo|atualiz/.test(text)) return 'edit-2'
  return 'activity'
}
export function activityTime(value, now = Date.now()) {
  const date = new Date(value)
  if (!Number.isFinite(date.getTime())) return 'Data não informada'
  const minutes = Math.floor((now - date.getTime()) / 60000)
  if (minutes >= 0 && minutes < 1) return 'Agora'
  if (minutes >= 1 && minutes < 60) return `Há ${minutes} min`
  if (minutes >= 60 && minutes < 1440) return `Há ${Math.floor(minutes / 60)} h${minutes % 60 ? ` ${minutes % 60} min` : ''}`
  return date.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
}
