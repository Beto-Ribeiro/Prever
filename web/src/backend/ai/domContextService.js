const INTERACTIVE_SELECTOR = [
  'button',
  'input',
  'textarea',
  'select',
  'a[href]',
  '[role="button"]',
  '[contenteditable="true"]',
].join(',')

const FIELD_SELECTOR = [
  'input',
  'textarea',
  'select',
  '[contenteditable="true"]',
].join(',')

const DANGEROUS_WORDS = [
  'confirmar disparo',
  'disparar',
  'excluir',
  'deletar',
  'apagar',
  'remover',
  'aprovar',
  'rejeitar',
  'bloquear',
  'resetar',
  'salvar',
]

let aiElementId = 0

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function isVisible(element) {
  if (!element || !(element instanceof Element)) return false

  const style = window.getComputedStyle(element)
  const rect = element.getBoundingClientRect()

  return (
    style.display !== 'none' &&
    style.visibility !== 'hidden' &&
    style.opacity !== '0' &&
    rect.width > 0 &&
    rect.height > 0
  )
}

function getElementText(element) {
  if (!element) return ''

  const ariaLabel = element.getAttribute('aria-label')
  const title = element.getAttribute('title')
  const placeholder = element.getAttribute('placeholder')
  const value = element.value
  const text = element.innerText || element.textContent

  return String(ariaLabel || title || placeholder || value || text || '').trim()
}

function getAssociatedLabel(element) {
  if (!element) return ''

  const ariaLabel = element.getAttribute('aria-label')
  if (ariaLabel) return ariaLabel

  const id = element.getAttribute('id')
  if (id) {
    const label = document.querySelector(`label[for="${CSS.escape(id)}"]`)
    if (label?.innerText) return label.innerText.trim()
  }

  const parentLabel = element.closest('label')
  if (parentLabel?.innerText) return parentLabel.innerText.trim()

  const container = element.closest('div, section, article, form')
  if (container) {
    const possibleLabel = Array.from(container.querySelectorAll('label, .label, [data-label]'))
      .map((item) => item.innerText || item.getAttribute('data-label'))
      .find(Boolean)

    if (possibleLabel) return String(possibleLabel).trim()
  }

  return (
    element.getAttribute('placeholder') ||
    element.getAttribute('name') ||
    element.getAttribute('id') ||
    ''
  )
}

function ensureAiId(element) {
  if (!element.dataset.smdnAiId) {
    aiElementId += 1
    element.dataset.smdnAiId = `smdn-ai-${aiElementId}`
  }

  return element.dataset.smdnAiId
}

function getFieldValue(element) {
  if (!element) return ''

  if (element.tagName === 'SELECT') {
    const option = element.options[element.selectedIndex]
    return option?.text || element.value || ''
  }

  if (element.type === 'password') return '[campo protegido]'

  if (element.isContentEditable) return element.innerText || ''

  return element.value || ''
}

function getFieldOptions(element) {
  if (element.tagName !== 'SELECT') return []

  return Array.from(element.options)
    .map((option) => option.text || option.value)
    .filter(Boolean)
}

function collectDialogs() {
  return Array.from(document.querySelectorAll('[role="dialog"], [aria-modal="true"], .modal, .dialog'))
    .filter(isVisible)
    .slice(0, 8)
    .map((dialog) => ({
      aiId: ensureAiId(dialog),
      text: String(dialog.innerText || dialog.textContent || '').trim().slice(0, 3500),
    }))
}

function collectFields() {
  return Array.from(document.querySelectorAll(FIELD_SELECTOR))
    .filter(isVisible)
    .slice(0, 120)
    .map((field) => ({
      aiId: ensureAiId(field),
      tag: field.tagName.toLowerCase(),
      type: field.getAttribute('type') || '',
      label: getAssociatedLabel(field),
      placeholder: field.getAttribute('placeholder') || '',
      name: field.getAttribute('name') || '',
      id: field.getAttribute('id') || '',
      value: getFieldValue(field),
      options: getFieldOptions(field),
    }))
}

function collectButtons() {
  return Array.from(document.querySelectorAll(INTERACTIVE_SELECTOR))
    .filter(isVisible)
    .filter((element) => !element.matches(FIELD_SELECTOR))
    .slice(0, 160)
    .map((button) => ({
      aiId: ensureAiId(button),
      tag: button.tagName.toLowerCase(),
      role: button.getAttribute('role') || '',
      label: getElementText(button),
      disabled: Boolean(button.disabled || button.getAttribute('aria-disabled') === 'true'),
    }))
    .filter((button) => button.label)
}

function collectPageText() {
  const main =
    document.querySelector('main') ||
    document.querySelector('[role="main"]') ||
    document.body

  return String(main?.innerText || document.body.innerText || '')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .slice(0, 14000)
}

export function collectCurrentUiContext({ currentScreen, screenTitle } = {}) {
  const activeElement = document.activeElement

  return {
    currentScreen,
    screenTitle,
    url: window.location.href,
    title: document.title,
    viewport: {
      width: window.innerWidth,
      height: window.innerHeight,
    },
    activeElement: activeElement
      ? {
          aiId: activeElement.dataset?.smdnAiId || '',
          tag: activeElement.tagName?.toLowerCase?.() || '',
          label: getAssociatedLabel(activeElement),
          text: getElementText(activeElement),
        }
      : null,
    visibleText: collectPageText(),
    dialogs: collectDialogs(),
    fields: collectFields(),
    buttons: collectButtons(),
  }
}

function setNativeValue(element, value) {
  const tagName = element.tagName.toLowerCase()
  const property = tagName === 'textarea' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype
  const descriptor = Object.getOwnPropertyDescriptor(property, 'value')

  if (descriptor?.set) {
    descriptor.set.call(element, value)
  } else {
    element.value = value
  }

  element.dispatchEvent(new Event('input', { bubbles: true }))
  element.dispatchEvent(new Event('change', { bubbles: true }))
}

function setFieldValue(element, value) {
  if (!element) return false

  element.focus()

  if (element.tagName === 'SELECT') {
    const normalizedValue = normalizeText(value)
    const option = Array.from(element.options).find((item) => {
      return (
        normalizeText(item.text) === normalizedValue ||
        normalizeText(item.value) === normalizedValue ||
        normalizeText(item.text).includes(normalizedValue) ||
        normalizedValue.includes(normalizeText(item.text))
      )
    })

    if (!option) return false

    element.value = option.value
    element.dispatchEvent(new Event('input', { bubbles: true }))
    element.dispatchEvent(new Event('change', { bubbles: true }))
    return true
  }

  if (element.isContentEditable) {
    element.innerText = value
    element.dispatchEvent(new Event('input', { bubbles: true }))
    return true
  }

  if ('value' in element) {
    setNativeValue(element, value)
    return true
  }

  return false
}

function scoreElement(element, target) {
  const normalizedTarget = normalizeText(target)
  if (!normalizedTarget) return 0

  const aiId = normalizeText(element.dataset?.smdnAiId)
  const label = normalizeText(getAssociatedLabel(element))
  const text = normalizeText(getElementText(element))
  const placeholder = normalizeText(element.getAttribute('placeholder'))
  const name = normalizeText(element.getAttribute('name'))
  const id = normalizeText(element.getAttribute('id'))

  const candidates = [aiId, label, text, placeholder, name, id].filter(Boolean)

  let score = 0

  for (const candidate of candidates) {
    if (candidate === normalizedTarget) score = Math.max(score, 100)
    if (candidate.includes(normalizedTarget)) score = Math.max(score, 80)
    if (normalizedTarget.includes(candidate) && candidate.length > 2) score = Math.max(score, 60)
  }

  return score
}

function findBestElement(target, selector = INTERACTIVE_SELECTOR) {
  const elements = Array.from(document.querySelectorAll(selector)).filter(isVisible)

  const direct = elements.find((element) => element.dataset?.smdnAiId === target)
  if (direct) return direct

  const ranked = elements
    .map((element) => ({
      element,
      score: scoreElement(element, target),
    }))
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score)

  return ranked[0]?.element || null
}

function isDangerousClick(label) {
  const normalized = normalizeText(label)
  return DANGEROUS_WORDS.some((word) => normalized.includes(normalizeText(word)))
}

function highlightElement(element) {
  if (!element) return

  const previousOutline = element.style.outline
  const previousBoxShadow = element.style.boxShadow

  element.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' })
  element.style.outline = '3px solid #7ec8ff'
  element.style.boxShadow = '0 0 0 6px rgba(126, 200, 255, 0.25)'

  window.setTimeout(() => {
    element.style.outline = previousOutline
    element.style.boxShadow = previousBoxShadow
  }, 2400)
}

function delay(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms))
}

export async function executeAssistantUiActions(actions = [], { setCurrentScreen } = {}) {
  const results = []

  for (const rawAction of actions) {
    const action = {
      ...rawAction,
      type: String(rawAction?.type || '').toLowerCase(),
    }

    if (!action.type) continue

    try {
      if (action.type === 'navigate' && action.screen) {
        setCurrentScreen?.(action.screen)
        results.push({ ok: true, action })
        await delay(250)
        continue
      }

      if (action.type === 'fill') {
        const element = findBestElement(action.target || action.field || action.aiId, FIELD_SELECTOR)
        const ok = setFieldValue(element, String(action.value ?? ''))
        if (ok) highlightElement(element)
        results.push({ ok, action, reason: ok ? undefined : 'Campo não encontrado' })
        await delay(80)
        continue
      }

      if (action.type === 'select') {
        const element = findBestElement(action.target || action.field || action.aiId, 'select')
        const ok = setFieldValue(element, String(action.value ?? ''))
        if (ok) highlightElement(element)
        results.push({ ok, action, reason: ok ? undefined : 'Select não encontrado/opção inválida' })
        await delay(80)
        continue
      }

      if (action.type === 'focus' || action.type === 'highlight' || action.type === 'scroll_to') {
        const element = findBestElement(action.target || action.aiId, INTERACTIVE_SELECTOR)
        if (element) {
          element.focus?.()
          highlightElement(element)
        }
        results.push({ ok: Boolean(element), action, reason: element ? undefined : 'Elemento não encontrado' })
        await delay(80)
        continue
      }

      if (action.type === 'click' || action.type === 'open_modal') {
        const element = findBestElement(action.target || action.button || action.aiId, INTERACTIVE_SELECTOR)
        const label = getElementText(element)

        if (!element) {
          results.push({ ok: false, action, reason: 'Botão/elemento não encontrado' })
          continue
        }

        if (isDangerousClick(label) && action.confirm !== true) {
          highlightElement(element)
          results.push({
            ok: false,
            action,
            reason: `Ação sensível bloqueada: ${label}. Peça confirmação explícita antes de executar.`,
          })
          continue
        }

        element.click()
        highlightElement(element)
        results.push({ ok: true, action })
        await delay(220)
        continue
      }

      results.push({ ok: false, action, reason: `Tipo de ação desconhecido: ${action.type}` })
    } catch (error) {
      results.push({ ok: false, action, reason: error?.message || 'Erro ao executar ação' })
    }
  }

  return results
}
