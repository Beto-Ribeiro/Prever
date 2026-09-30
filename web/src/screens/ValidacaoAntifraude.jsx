import { useEffect, useState } from 'react'
import Card from '../components/Card'
import Modal from '../components/Modal'
import { getRelatosPendentes, validarRelatoStatus } from '../backend/validacao/validacaoService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'

export default function ValidacaoAntifraude() {
  const [items, setItems] = useState([])
  const [selected, setSelected] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  async function loadData() {
    try {
      setError('')
      const data = await getRelatosPendentes()
      setItems(data)
    } catch (err) {
      setError(toFriendlyMessage(err, 'Erro ao carregar relatos para validação.'))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [])

  async function handleValidation(isValid) {
    if (!selected) return

    setSaving(true)
    setError('')
    setNotice('')

    try {
      await validarRelatoStatus({ relatoId: selected.id, isValid })
      setNotice(isValid ? 'Relato aprovado com sucesso.' : 'Relato marcado como fraude e rejeitado.')
      setTimeout(() => setNotice(''), 3500)
      setSelected(null)
      loadData()
    } catch (err) {
      setError(toFriendlyMessage(err, 'Não foi possível validar este relato.'))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="p-8 space-y-6 animate-fade-in h-full overflow-hidden flex flex-col">
      <div className="flex items-center justify-between flex-shrink-0">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Validação Antifraude</h1>
          <p className="text-sm text-slate-500 mt-1">
            Revise relatos marcados como suspeitos pela Inteligência Artificial.
          </p>
        </div>
      </div>

      {notice && (
        <div className="rounded-lg border border-green-100 bg-green-50 px-4 py-3 text-sm font-semibold text-green-700 flex-shrink-0">
          {notice}
        </div>
      )}

      {error && (
        <div className="rounded-lg border border-red-100 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700 flex-shrink-0">
          {error}
        </div>
      )}

      <Card className="p-0 overflow-hidden flex-1 min-h-0 flex flex-col">
        <div className="overflow-auto flex-1 min-h-0">
          <table className="w-full text-sm">
            <thead className="sticky top-0 z-10">
              <tr className="border-b border-border-soft bg-slate-50">
                {['ID', 'Tipo', 'Score', 'Motivo da Suspeita', 'Data', ''].map((heading) => (
                  <th key={heading} className="px-5 py-3 text-left text-label text-slate-500 font-bold whitespace-nowrap">
                    {heading}
                  </th>
                ))}
              </tr>
            </thead>

            <tbody>
              {items.length === 0 && !loading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-10 text-center text-slate-400 text-sm">
                    Nenhum relato pendente de validação.
                  </td>
                </tr>
              ) : (
                items.map((item) => (
                  <tr key={item.id} className="border-b border-border-soft hover:bg-slate-50 transition-colors">
                    <td className="px-5 py-3 font-mono text-xs text-slate-500">{item.id}</td>
                    <td className="px-5 py-3 font-semibold text-slate-800">{item.type}</td>
                    <td className="px-5 py-3">
                      <span className="text-status-critical font-bold">{Math.round(item.score * 100)}%</span>
                    </td>
                    <td className="px-5 py-3 max-w-[300px] truncate text-slate-600">
                      {item.reason}
                    </td>
                    <td className="px-5 py-3 text-slate-500 text-xs whitespace-nowrap">
                      {new Date(item.date).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="px-5 py-3">
                      <button
                        onClick={() => setSelected(item)}
                        className="text-text-main text-xs font-semibold hover:underline"
                      >
                        Revisar
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal isOpen={!!selected} onClose={() => setSelected(null)} title="Revisar Relato" size="md">
        {selected && (
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              <span className="font-bold text-lg text-slate-800">{selected.type}</span>
              <span className="badge-critical text-xs">Atenção Necessária</span>
            </div>

            {selected.photoUrl && (
              <img
                src={selected.photoUrl}
                alt="Foto suspeita"
                className="w-full max-h-64 object-cover rounded-xl border border-border-soft"
              />
            )}

            <div>
              <p className="text-label text-slate-400 mb-1">DESCRIÇÃO FORNECIDA</p>
              <p className="text-sm text-slate-700 bg-slate-50 rounded-lg p-3 border border-border-soft">
                {selected.description || 'Nenhuma descrição fornecida.'}
              </p>
            </div>

            <div>
              <div className="flex items-center gap-2 mb-1">
                <span className="w-5 h-5 flex items-center justify-center bg-status-critical-bg text-status-critical rounded-full">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z" />
                    <line x1="12" y1="9" x2="12" y2="13" />
                    <line x1="12" y1="17" x2="12.01" y2="17" />
                  </svg>
                </span>
                <p className="text-label text-status-critical">ANÁLISE DO NIMBO (SCORE: {Math.round(selected.score * 100)}%)</p>
              </div>
              <p className="text-sm text-status-critical font-medium bg-status-critical-bg/50 rounded-lg p-3 border border-status-critical/20">
                {selected.reason}
              </p>
            </div>

            <div className="rounded-xl border border-border-soft bg-slate-50 p-4 mt-2">
              <p className="text-sm font-semibold text-slate-700 mb-3 text-center">Decisão de Validação</p>
              <div className="flex gap-3">
                <button
                  className="flex-1 py-2.5 rounded-lg border border-status-critical text-status-critical font-bold text-sm hover:bg-status-critical hover:text-white transition-all disabled:opacity-50"
                  disabled={saving}
                  onClick={() => handleValidation(false)}
                >
                  Confirmar Fraude
                </button>
                <button
                  className="flex-1 py-2.5 rounded-lg border border-status-success text-status-success font-bold text-sm hover:bg-status-success hover:text-white transition-all disabled:opacity-50"
                  disabled={saving}
                  onClick={() => handleValidation(true)}
                >
                  Aprovar Relato
                </button>
              </div>
            </div>

            <div className="flex justify-end pt-2 border-t border-border-soft">
              <button className="btn-ghost text-sm" onClick={() => setSelected(null)}>Cancelar</button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
