import FeatherIcon from '../../components/FeatherIcon.jsx'
import { activityIcon, activityTime } from './activityPresentation.js'
import { listReportHistory, recordReportExport } from '../../backend/manager/reportHistoryService.js'
import { useCallback, useEffect, useState } from 'react'
import { useAuth } from '../../hooks/useAuth.js'
import { loadManagerData, saveManagerRecord, saveShelter } from '../../backend/manager/managerService.js'
import { toFriendlyMessage } from '../../utils/friendlyMessages.js'
import { exportReport } from './reportExport.js'
import Modal from '../../components/Modal.jsx'
import Perfil from '../Perfil.jsx'
import './manager.css'

const today = () => new Date().toLocaleDateString('en-CA')
const number = value => Number(value).toLocaleString('pt-BR', { maximumFractionDigits: 2 })
const categories = ['Suprimentos básicos', 'Higiene e saúde', 'Estrutura']
function Meter({ value, max, label }) {
  const pct = Math.min(100, Math.max(0, Number(value) / Number(max || 1) * 100))
  return <div><div className="manager-meter" role="progressbar" aria-label={label} aria-valuenow={Number(value)} aria-valuemin={0} aria-valuemax={Math.max(Number(max), Number(value))}><span style={{ width: `${pct}%`, backgroundColor: `rgb(var(--meter-${pct < 25 ? 'low' : pct < 60 ? 'medium' : 'good'}))` }} /></div></div>
}
function Field({ label, name, form, setForm, options, ...props }) {
  return <label className="manager-field">{label}{options ? <select value={form[name] ?? ''} onChange={e => setForm({ ...form, [name]: e.target.value })} {...props}>{options.map(o => <option key={o.value ?? o} value={o.value ?? o}>{o.label ?? o}</option>)}</select> : <input value={form[name] ?? ''} onChange={e => setForm({ ...form, [name]: e.target.value })} {...props} />}</label>
}
export default function ManagerPortal({ screen }) {
  const { user } = useAuth()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [reportHistory, setReportHistory] = useState([])
  const [historyError, setHistoryError] = useState('')
  const [historyLoading, setHistoryLoading] = useState(false)
  const [filter, setFilter] = useState('Todos')
  const [search, setSearch] = useState('')
  const [dialog, setDialog] = useState(null)
  const [form, setForm] = useState({})
  const [busy, setBusy] = useState(false)
  const [period, setPeriod] = useState({ start: today().slice(0, 8) + '01', end: today(), type: 'Completo' })
  const load = useCallback(async () => {
    setLoading(true); setError('')
    try { setData(await loadManagerData(user.id)) } catch (e) { setError(toFriendlyMessage(e)) }
    finally { setLoading(false) }
  }, [user.id])
  useEffect(() => { load() }, [load])
  useEffect(() => { setFilter('Todos'); setSearch(''); setDialog(null) }, [screen])
  function open(kind, record = {}) {
    setError(''); setNotice(''); setDialog({ kind, id: record.id })
    const defaults = kind === 'resident' ? { name: '', age: '', category: 'Adulto', responsible_name: '', responsible_contact: '', entered_on: today(), active: true }
      : kind === 'inventory' ? { name: '', category: categories[0], quantity: 0, target: 1, unit: 'un.' }
      : kind === 'request' ? { inventory_id: data.inventory[0]?.id || '', target: 1, priority: 'Moderado' }
      : kind === 'donation' ? { request_id: record.id, donor: '', donor_contact: '', quantity: '', remaining: Number(record.target) - Number(record.received) }
      : { name: data.shelter.abr_nome, address: data.shelter.abr_bairro || '', phone: data.shelter.abr_telefone_principal || '', coordinator: data.shelter.abr_coordenador || '', coordinatorContact: data.shelter.abr_coordenador_contato || '', capacity: data.shelter.abr_capacidade }
    setForm(kind === 'donation' ? defaults : { ...defaults, ...record })
  }
  async function submit(event) {
    event.preventDefault(); if (busy) return
    setBusy(true); setError('')
    try {
      const table = { resident: 'shelter_residents', inventory: 'shelter_inventory', request: 'shelter_requests', donation: 'shelter_donations' }[dialog.kind]
      if (dialog.kind === 'shelter') await saveShelter(data.shelter.abr_id, form)
      else await saveManagerRecord(table, data.shelter.abr_id, form, dialog.kind === 'donation' ? null : dialog.id)
      setDialog(null); setNotice('Alterações salvas com sucesso.'); await load()
    } catch (e) { setError(toFriendlyMessage(e)) } finally { setBusy(false) }
  }
  const shelterId = data?.shelter?.abr_id
  const loadHistory = useCallback(async () => {
    if (!shelterId) return
    setHistoryLoading(true); setHistoryError('')
    try { setReportHistory(await listReportHistory(shelterId)) }
    catch (e) { setHistoryError(toFriendlyMessage(e)) }
    finally { setHistoryLoading(false) }
  }, [shelterId])
  useEffect(() => { if (screen === 'relatorios') loadHistory() }, [screen, loadHistory])
  async function download(format) {
    setBusy(true); setError('')
    try {
      await exportReport(data, period.start, period.end, period.type, format)
      setNotice('Relatório gerado. Confira os downloads do navegador.')
      try { await recordReportExport(shelterId, user.id, period, format); await loadHistory() }
      catch { setHistoryError('O relatório foi gerado, mas não foi possível registrar a exportação no histórico.') }
    }
    catch (e) { setError(toFriendlyMessage(e)) } finally { setBusy(false) }
  }
  if (screen === 'perfil') return <Perfil />
  if (loading && !data) return <div className="manager-page" role="status">Carregando os dados do abrigo…</div>
  if (!data) return <div className="manager-page"><h1>Gerência do abrigo</h1><p role={error ? 'alert' : 'status'}>{error || 'Seu perfil ainda não tem um abrigo vinculado. Solicite o vínculo ao administrador.'}</p><button onClick={load}>Tentar novamente</button></div>
  const s = data.shelter
  const stock = id => data.inventory.find(i => i.id === id)
  const outstanding = data.requests.filter(r => Number(r.received) < Number(r.target))
  const titles = { dashboard: 'Visão geral', ocupantes: 'Ocupantes', estoque: 'Estoque', pedidos: 'Pedidos de ajuda', relatorios: 'Relatórios' }
  const filters = screen === 'ocupantes' ? ['Todos', 'Criança', 'Idoso', 'PCD', 'Saídas'] : screen === 'estoque' ? ['Todos', ...categories] : ['Todos', 'Urgentes', 'Em andamento', 'Concluídos']
  const residents = data.residents.filter(r => (filter === 'Saídas' ? !r.active : r.active && (filter === 'Todos' || r.category === filter)) && `${r.name} ${r.responsible_name} ${r.responsible_contact} ${r.contact}`.toLocaleLowerCase('pt-BR').includes(search.toLocaleLowerCase('pt-BR')))
  return <section className={`manager-page ${screen === 'relatorios' ? 'manager-page--reports' : ''}`}>
    <header className="manager-heading"><div><p className="manager-eyebrow">GERENTE DE ABRIGO · {s.abr_nome}</p><h1>{titles[screen]}</h1></div><button onClick={() => { load(); if (screen === 'relatorios') loadHistory() }} disabled={loading || busy || historyLoading}>{loading ? 'Atualizando…' : 'Atualizar'}</button></header>
    {error && !dialog && <p className="manager-error" role="alert">{error}</p>}
    {notice && <p className="manager-notice" role="status">{notice}</p>}
    {screen === 'dashboard' && <>
      <div className="manager-stats">{[
        ['Ocupação atual', `${s.abr_ocupacao} / ${s.abr_capacidade}`, `${Math.round(s.abr_ocupacao / s.abr_capacidade * 100)}% da capacidade total`],
        ['Pedidos em aberto', outstanding.length, `${outstanding.filter(r => r.priority === 'Urgente').length} urgentes`],
        ['Doações recebidas', data.donations.length, 'Entregas registradas'],
        ['Itens em nível crítico', data.inventory.filter(i => i.quantity < i.target * .25).length, 'Abaixo de 25% da meta'],
      ].map(([label, value, detail]) => <article className="manager-card" key={label}><h2>{label}</h2><strong className="manager-stat">{value}</strong><p>{detail}</p></article>)}</div>
      <div className="manager-columns"><article className="manager-card"><div className="manager-toolbar"><h2>Dados do abrigo</h2><button onClick={() => open('shelter')}>Editar</button></div><div className="manager-shelter-mark" aria-hidden="true">⌂</div><dl>{[['Endereço', s.abr_bairro], ['Cidade', s.abr_cidade], ['Responsável', s.abr_coordenador], ['Contato do responsável', s.abr_coordenador_contato], ['Telefone do abrigo', s.abr_telefone_principal], ['Aberto desde', new Date(s.abr_created_at).toLocaleDateString('pt-BR')]].map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v || 'Não informado'}</dd></div>)}</dl></article>
      <article className="manager-card"><h2>Registro de atividades recentes</h2>{!data.activity.length && <p>Nenhuma atividade registrada.</p>}<ul className="manager-activity">{data.activity.slice(-10).reverse().map(a => <li key={a.id}><span className="manager-activity-icon"><FeatherIcon name={activityIcon(a.detail)} /></span><div><span className="manager-activity-detail">{a.detail}</span><time dateTime={a.created_at} title={new Date(a.created_at).toLocaleString('pt-BR')}>{activityTime(a.created_at)}</time></div></li>)}</ul></article></div>
    </>}
    {['ocupantes', 'estoque', 'pedidos'].includes(screen) && <div className="manager-toolbar">
      {screen === 'ocupantes' && <input aria-label="Buscar ocupante" placeholder="Buscar ocupante" value={search} onChange={e => setSearch(e.target.value)} />}
      <div className="manager-filters">{filters.map(f => <button key={f} aria-pressed={filter === f} onClick={() => setFilter(f)}>{f === 'Criança' ? 'Crianças' : f === 'Idoso' ? 'Idosos' : f}</button>)}</div>
      <button className="manager-primary" disabled={busy || (screen === 'pedidos' && !data.inventory.length)} onClick={() => open({ ocupantes: 'resident', estoque: 'inventory', pedidos: 'request' }[screen])}>+ {screen === 'ocupantes' ? 'Cadastrar ocupante' : screen === 'estoque' ? 'Adicionar recurso' : 'Novo pedido'}</button>
    </div>}
    {screen === 'ocupantes' && <><div className="manager-table-wrap"><table><thead><tr>{['Nome', 'Idade', 'Categoria', 'Responsável', 'Contato do responsável', 'Data de entrada', 'Ações'].map(h => <th key={h}>{h}</th>)}</tr></thead><tbody>{residents.map(r => <tr key={r.id}><td><span className="manager-avatar">{r.name.split(' ').map(n => n[0]).slice(0, 2).join('')}</span>{r.name}</td><td>{r.age}</td><td><span className="manager-tag">{r.category}</span></td><td>{r.responsible_name || (r.contact ? <span>Registro anterior: {r.contact}</span> : '—')}</td><td>{r.responsible_contact || '—'}</td><td>{r.entered_on.split('-').reverse().join('/')}</td><td><button aria-label={`Editar ${r.name}`} onClick={() => open('resident', r)}>Editar</button></td></tr>)}</tbody></table></div><p>{residents.length ? `Mostrando ${residents.length} ocupantes.` : 'Nenhum ocupante encontrado.'}</p></>}
    {screen === 'estoque' && <div className="manager-grid">{categories.filter(c => filter === 'Todos' || filter === c).map(c => <article className="manager-card" key={c}><h2>{c}</h2>{!data.inventory.some(i => i.category === c) && <p>Nenhum recurso cadastrado.</p>}{data.inventory.filter(i => i.category === c).map(i => <div className="manager-stock-item" key={i.id}><div><strong>{i.name}</strong><button aria-label={`Editar ${i.name}`} onClick={() => open('inventory', i)}>Editar</button></div><p>{number(i.quantity)} / {number(i.target)} {i.unit} {i.quantity < i.target * .25 && <b> · Crítico</b>}</p><Meter value={i.quantity} max={i.target} label={i.name} /></div>)}</article>)}</div>}
    {screen === 'pedidos' && <>{!data.inventory.length && <p>Cadastre um recurso em Estoque antes de criar um pedido.</p>}<div className="manager-grid">{data.requests.filter(r => filter === 'Todos' || (filter === 'Urgentes' ? r.priority === 'Urgente' && r.received < r.target : filter === 'Concluídos' ? r.received >= r.target : r.received < r.target)).map(r => <article className="manager-card" key={r.id}><div className="manager-toolbar"><h2>{stock(r.inventory_id)?.name || 'Recurso'}</h2><span className={`manager-tag ${r.received >= r.target ? 'done' : r.priority === 'Urgente' ? 'urgent' : ''}`}>{r.received >= r.target ? 'Concluído' : r.priority}</span></div><p>{stock(r.inventory_id)?.category}</p><p>{number(r.received)} de {number(r.target)} {stock(r.inventory_id)?.unit}</p><Meter value={r.received} max={r.target} label={stock(r.inventory_id)?.name || 'Pedido'} /><div className="manager-toolbar manager-actions"><button onClick={() => { setDialog({ kind: 'history', id: r.id }); setError('') }}>Histórico</button><button disabled={r.received >= r.target} onClick={() => open('donation', r)}>Registrar doação</button></div></article>)}</div>{!data.requests.length && <p>Nenhum pedido de ajuda cadastrado.</p>}</>}
    {screen === 'relatorios' && <div className="manager-reports-layout"><article className="manager-report" tabIndex={0} role="region" aria-label="Gerar relatório do abrigo"><h2>Gerar relatório do abrigo</h2><p>Selecione o período e os dados que deseja incluir.</p><div className="manager-columns"><Field label="Data inicial" name="start" form={period} setForm={setPeriod} type="date" required /><Field label="Data final" name="end" form={period} setForm={setPeriod} type="date" min={period.start} required /></div><Field label="Tipo de relatório" name="type" form={period} setForm={setPeriod} options={['Completo', 'Ocupantes', 'Estoque', 'Pedidos', 'Doações', 'Atividades']} /><p>O estoque mostra a posição atual. Os outros dados são filtrados pela data de entrada ou registro.</p><div className="manager-toolbar"><button disabled={busy} onClick={() => download('pdf')}>Exportar em PDF</button><button disabled={busy} onClick={() => download('xlsx')}>Exportar em Excel</button></div></article><aside className="manager-card manager-report-history" tabIndex={0} role="region" aria-labelledby="report-history-title">
      <h2 id="report-history-title"><FeatherIcon name="clock" /> Histórico de relatórios</h2>
      <p>Últimas 20 exportações do abrigo. Os arquivos ficam nos downloads de quem os gerou.</p>
      {historyError && <p role="alert" className="manager-error">{historyError}</p>}
      {historyLoading ? <p role="status">Carregando histórico…</p> : !reportHistory.length && !historyError ? <div className="manager-history-empty"><FeatherIcon name="file-plus" size={30} /><p>Nenhum relatório exportado ainda.</p><span>Gere um PDF ou Excel para começar o histórico.</span></div> : <ul className="manager-activity">{reportHistory.map(r => <li key={r.id}><span className="manager-activity-icon"><FeatherIcon name="file-plus" /></span><div><strong>{r.report_type}</strong><span className="manager-history-format">{r.format === 'xlsx' ? 'Excel' : 'PDF'}</span><p>{r.start_date.split('-').reverse().join('/')} a {r.end_date.split('-').reverse().join('/')}</p><time dateTime={r.created_at}>{new Date(r.created_at).toLocaleString('pt-BR')}</time></div></li>)}</ul>}
    </aside></div>}
    <Modal isOpen={Boolean(dialog)} onClose={() => !busy && setDialog(null)} title={{ resident: 'Cadastro de ocupante', inventory: 'Recurso do estoque', request: 'Novo pedido', donation: 'Registrar doação', shelter: 'Dados do abrigo', history: 'Histórico de doações' }[dialog?.kind]}>
      <div className="manager-form">{error && <p className="manager-error" role="alert">{error}</p>}{dialog?.kind === 'history' ? <>{data.donations.filter(d => d.request_id === dialog.id).length ? data.donations.filter(d => d.request_id === dialog.id).map(d => <p key={d.id}>{d.donor} · Contato: {d.donor_contact || 'Não informado'} · {number(d.quantity)} · {new Date(d.created_at).toLocaleString('pt-BR')}</p>) : <p>Nenhuma doação registrada para este pedido.</p>}</> : <form onSubmit={submit}>
      {['resident', 'inventory', 'shelter'].includes(dialog?.kind) && <Field label="Nome" name="name" form={form} setForm={setForm} required minLength={2} maxLength={160} />}
      {dialog?.kind === 'resident' && <><div className="manager-columns"><Field label="Idade" name="age" form={form} setForm={setForm} type="number" min="0" max="130" required /><Field label="Categoria" name="category" form={form} setForm={setForm} options={['Adulto', 'Criança', 'Idoso', 'PCD']} /></div><Field label="Nome do responsável" name="responsible_name" form={form} setForm={setForm} maxLength={160} /><Field label="Contato do responsável" name="responsible_contact" form={form} setForm={setForm} placeholder="Telefone ou e-mail" maxLength={120} />{form.contact && <p>Registro anterior de responsável/contato: {form.contact}. Confira e preencha os campos separados acima.</p>}<Field label="Data de entrada" name="entered_on" form={form} setForm={setForm} type="date" max={today()} required />{dialog.id && <label><input type="checkbox" checked={form.active} onChange={e => setForm({ ...form, active: e.target.checked })} /> Permanece no abrigo</label>}</>}
      {dialog?.kind === 'inventory' && <><Field label="Categoria" name="category" form={form} setForm={setForm} options={categories} /><div className="manager-columns"><Field label="Quantidade atual" name="quantity" form={form} setForm={setForm} type="number" min="0" step="0.01" required /><Field label="Meta de estoque" name="target" form={form} setForm={setForm} type="number" min="0.01" step="0.01" required /></div><Field label="Unidade (kg, L, un.)" name="unit" form={form} setForm={setForm} required maxLength={20} /></>}
      {dialog?.kind === 'request' && <><Field label="Recurso" name="inventory_id" form={form} setForm={setForm} required options={data.inventory.map(i => ({ value: i.id, label: `${i.name} (${i.unit})` }))} /><Field label="Quantidade solicitada" name="target" form={form} setForm={setForm} type="number" min="0.01" step="0.01" required /><Field label="Prioridade" name="priority" form={form} setForm={setForm} options={['Urgente', 'Moderado', 'Leve']} /></>}
      {dialog?.kind === 'donation' && <><Field label="Nome do doador" name="donor" form={form} setForm={setForm} required minLength={2} maxLength={160} /><Field label="Contato do doador" name="donor_contact" form={form} setForm={setForm} placeholder="Telefone ou e-mail" maxLength={120} /><Field label={`Quantidade recebida (faltam ${number(form.remaining)})`} name="quantity" form={form} setForm={setForm} type="number" min="0.01" max={form.remaining} step="0.01" required /><p>A entrega será adicionada ao estoque e ao progresso do pedido.</p></>}
      {dialog?.kind === 'shelter' && <><Field label="Endereço" name="address" form={form} setForm={setForm} /><Field label="Nome do responsável pelo abrigo" name="coordinator" form={form} setForm={setForm} maxLength={160} /><Field label="Contato do responsável pelo abrigo" name="coordinatorContact" form={form} setForm={setForm} placeholder="Telefone ou e-mail" maxLength={120} /><Field label="Telefone do abrigo" name="phone" form={form} setForm={setForm} type="tel" /><Field label="Capacidade" name="capacity" form={form} setForm={setForm} type="number" min={Math.max(1, s.abr_ocupacao)} required /></>}
      <div className="manager-toolbar manager-actions"><button type="button" onClick={() => setDialog(null)} disabled={busy}>Cancelar</button><button className="manager-primary" disabled={busy}>{busy ? 'Salvando…' : 'Salvar'}</button></div>
      </form>}</div>
    </Modal>
  </section>
}
