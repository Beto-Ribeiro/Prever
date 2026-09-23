import { useEffect, useRef } from 'react'

export function useDialogFocus(open, panelRef, onClose, modal = true) {
  const closeRef = useRef(onClose)
  useEffect(() => { closeRef.current = onClose }, [onClose])
  useEffect(() => {
    if (!open) return
    const panel = panelRef.current
    const previous = document.activeElement
    const focusable = () => Array.from(panel?.querySelectorAll('button:not(:disabled),a[href],input:not(:disabled):not([type="hidden"]),select:not(:disabled),textarea:not(:disabled),[tabindex="0"]') || []).filter(el => el.getClientRects().length > 0)
    const first = panel?.querySelector('input:not([type="hidden"]):not(:disabled),select:not(:disabled),textarea:not(:disabled)') || focusable()[0] || panel
    first?.focus({ preventScroll: true })
    function key(event) {
      if (!panel?.contains(document.activeElement)) return
      if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); closeRef.current?.() }
      if (event.key !== 'Tab' || !modal) return
      const items = focusable()
      if (!items.length) { event.preventDefault(); panel?.focus(); return }
      const firstItem = items[0], lastItem = items[items.length - 1]
      if (event.shiftKey && document.activeElement === firstItem) { event.preventDefault(); lastItem.focus() }
      else if (!event.shiftKey && document.activeElement === lastItem) { event.preventDefault(); firstItem.focus() }
    }
    panel?.addEventListener('keydown', key)
    return () => { panel?.removeEventListener('keydown', key); if (previous?.isConnected) previous.focus({ preventScroll: true }) }
  }, [open, panelRef, modal])
}
