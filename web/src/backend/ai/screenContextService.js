// Read-only snapshot of the authorized application view. Never captures the chat,
// browser URL, storage, scripts, password/secret controls or hidden fields.
const EXCLUDED = '[data-nimbo-widget], [data-nimbo-private], script, style, noscript, [hidden], [aria-hidden="true"]'
export function isProtectedField(field) {
  const signature = [field.type, field.name, field.id, field.getAttribute('autocomplete'), field.getAttribute('aria-label'), ...(Array.from(field.labels || []).map(label => label.textContent))].join(' ')
  return field.type === 'hidden' || field.type === 'file' || /password|senha|token|secret|api.?key|credencial|credential|one-time-code/i.test(signature)
}
export function captureScreenContext({ currentScreen, accountId, document: doc = globalThis.document } = {}) {
  if (!doc || !accountId) return null
  const main = doc.querySelector('main[data-nimbo-account]')
  if (!main || main.dataset.nimboAccount !== accountId || main.dataset.nimboScreen !== currentScreen) return null
  const win = doc.defaultView
  const visible = el => {
    if (el.closest(EXCLUDED)) return false
    for (let node = el; node && node.nodeType === 1; node = node.parentElement) {
      const style = win.getComputedStyle(node)
      if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false
    }
    return true
  }
  function readText(root) {
    const lines = []
    function walk(node) {
      if (node.nodeType === 3) { const value = node.textContent.trim(); if (value) lines.push(value); return }
      if (node.nodeType !== 1 || !visible(node)) return
      if (node.matches('input,textarea,select,[contenteditable="true"]')) return
      Array.from(node.childNodes).forEach(walk)
    }
    walk(root)
    const full = lines.join('\n')
    return { text: full.slice(0, 16000), truncated: full.length > 16000 }
  }
  function snapshot(root) {
    const allFields = Array.from(root.querySelectorAll('input,textarea,select')).filter(field => visible(field) && !isProtectedField(field))
    const fields = allFields.slice(0, 80).map(field => ({
      label: String(field.getAttribute('aria-label') || Array.from(field.labels || []).map(label => label.textContent.trim()).join(' ') || field.placeholder || field.name || field.id || '').slice(0, 200),
      value: field.type === 'checkbox' || field.type === 'radio' ? field.checked : field.tagName === 'SELECT' ? field.options[field.selectedIndex]?.text || '' : String(field.value || '').slice(0, 800),
      note: 'Valor exibido no formulário; pode ainda não estar salvo.',
    }))
    return { ...readText(root), fields, fieldsTruncated: allFields.length > 80 }
  }
  const dialogs = Array.from(doc.querySelectorAll('.modal-panel,[role="dialog"]')).filter(el => !main.contains(el) && visible(el))
  const unique = dialogs.filter(el => !dialogs.some(other => other !== el && other.contains(el)))
  return { accountId, currentScreen, capturedAt: new Date().toISOString(), page: snapshot(main), dialogs: unique.slice(-4).map(snapshot), note: 'Conteúdo da tela e formulários no envio da pergunta. Dialogs são janelas abertas; campos podem conter alterações não salvas. Não é uma captura de imagem.' }
}
