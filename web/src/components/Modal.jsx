import { useDialogFocus } from '../hooks/useDialogFocus.js'
import { useEffect, useId, useRef } from 'react'
import { createPortal } from 'react-dom'

const Modal = ({ isOpen, onClose, title, children, size = 'md' }) => {
  const panelRef = useRef(null)
  const titleId = useId()
  useDialogFocus(isOpen, panelRef, onClose)
  useEffect(() => {

    if (isOpen) {


      const previousBodyOverflow = document.body.style.overflow
      const previousHtmlOverflow = document.documentElement.style.overflow

      document.body.style.overflow = 'hidden'
      document.documentElement.style.overflow = 'hidden'

      return () => {

        document.body.style.overflow = previousBodyOverflow
        document.documentElement.style.overflow = previousHtmlOverflow
      }
    }

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
        tabIndex={-1}
        onClick={onClose}
      />

      <div
        ref={panelRef} role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1}
        className={`modal-panel relative z-10 w-full ${sizes[size]} max-h-[calc(100dvh-2rem)] bg-bg-surface rounded-[16px] shadow-modal animate-slide-up overflow-hidden flex flex-col`}
      >
        <div className="flex items-center justify-between px-6 py-5 border-b border-border-soft flex-shrink-0">
          <h2 id={titleId} className="text-card-title font-bold text-slate-800">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Fechar janela"
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
