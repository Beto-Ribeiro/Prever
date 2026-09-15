import { useEffect, useRef, useId } from 'react'
import { createPortal } from 'react-dom'

const Modal = ({ isOpen, onClose, title, children, size = 'md' }) => {
  const panelRef = useRef(null)
  const closeRef = useRef(onClose)
  const titleId = useId()
  useEffect(() => { closeRef.current = onClose }, [onClose])
  useEffect(() => {
    if (!isOpen) return
    const previous = document.activeElement
    const oldOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const focusable = () => Array.from(panelRef.current?.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), a[href], [tabindex="0"]') || [])
    focusable()[0]?.focus()
    function keydown(e) {
      if (e.key === 'Escape') closeRef.current?.()
      if (e.key !== 'Tab') return
      const nodes = focusable()
      if (!nodes.length) { e.preventDefault(); return }
      if (e.shiftKey && document.activeElement === nodes[0]) { e.preventDefault(); nodes.at(-1).focus() }
      else if (!e.shiftKey && document.activeElement === nodes.at(-1)) { e.preventDefault(); nodes[0].focus() }
    }
    document.addEventListener('keydown', keydown)
    return () => { document.removeEventListener('keydown', keydown); document.body.style.overflow = oldOverflow; previous?.focus() }
  }, [isOpen])

  if (!isOpen) return null

  const sizes = {
    sm: 'max-w-md',
    md: 'max-w-xl',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl',
  }

  return createPortal(
    <div className="fixed top-0 right-0 bottom-0 left-0 z-[99999] m-0 flex h-[100dvh] w-[100dvw] items-center justify-center overflow-hidden bg-bg-sidebar/60 p-4 backdrop-blur-sm animate-fade-in overscroll-none">
      <button
        type="button"
        className="absolute inset-0 h-full w-full cursor-default"
        aria-label="Fechar modal"
        onClick={onClose}
      />

      <div
        ref={panelRef} role="dialog" aria-modal="true" aria-labelledby={titleId}
        className={`modal-panel relative z-10 w-full ${sizes[size]} max-h-[calc(100dvh-2rem)] bg-bg-surface rounded-[16px] shadow-modal animate-slide-up overflow-hidden flex flex-col`}
      >
        <div className="flex items-center justify-between px-6 py-5 border-b border-border-soft flex-shrink-0">
          <h2 id={titleId} className="text-card-title font-bold text-slate-800">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Fechar"
            className="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M12 4L4 12M4 4l8 8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        <div className="px-6 py-5 overflow-y-auto overscroll-contain">
          {children}
        </div>
      </div>
    </div>,
    document.body
  )
}

export default Modal
