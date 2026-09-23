export function buildReport(data, start, end, type) {
  if (!start || !end || start > end) throw new Error('Informe um período válido: a data final deve ser igual ou posterior à inicial.')
  const within = value => String(value || '').slice(0, 10) >= start && String(value || '').slice(0, 10) <= end
  const stockName = id => data.inventory.find(i => i.id === id)?.name || 'Recurso'
  const sheets = {
    Ocupantes: data.residents.filter(r => within(r.entered_on)).map(r => ({ Nome: r.name, Idade: r.age, Categoria: r.category, Responsável: r.responsible_name || '', 'Contato do responsável': r.responsible_contact || '', 'Registro anterior de responsável/contato': r.contact || '', Entrada: r.entered_on, Situação: r.active ? 'No abrigo' : 'Saída registrada' })),
    Estoque: data.inventory.map(i => ({ Recurso: i.name, Categoria: i.category, Quantidade: i.quantity, Meta: i.target, Unidade: i.unit })),
    Pedidos: data.requests.filter(r => within(r.created_at)).map(r => ({ Recurso: stockName(r.inventory_id), Prioridade: r.priority, Meta: r.target, Recebido: r.received, Criação: r.created_at.slice(0, 10) })),
    Doações: data.donations.filter(r => within(r.created_at)).map(r => ({ Doador: r.donor, Contato: r.donor_contact || '', Quantidade: r.quantity, Recurso: stockName(data.requests.find(q => q.id === r.request_id)?.inventory_id), Data: r.created_at.slice(0, 10) })),
    Atividades: data.activity.filter(r => within(r.created_at)).map(r => ({ Atividade: r.detail, Data: new Date(r.created_at).toLocaleString('pt-BR') })),
  }
  return type === 'Completo' ? sheets : { [type]: sheets[type] || [] }
}
export async function exportReport(data, start, end, type, format) {
  const sheets = buildReport(data, start, end, type)
  const filename = `abrigo-${start}-${end}`
  if (format === 'xlsx') {
    const XLSX = await import('xlsx')
    const book = XLSX.utils.book_new()
    for (const [name, rows] of Object.entries(sheets)) {
      // Force strings into text cells; user input is never an Excel formula.
      const sheet = XLSX.utils.json_to_sheet(rows.length ? rows : [{ Informação: 'Nenhum registro no período.' }])
      XLSX.utils.book_append_sheet(book, sheet, name)
    }
    XLSX.writeFile(book, `${filename}.xlsx`)
    return
  }
  const { jsPDF } = await import('jspdf')
  const doc = new jsPDF()
  let y = 18
  function line(text, bold = false) {
    doc.setFont('helvetica', bold ? 'bold' : 'normal')
    for (const fragment of doc.splitTextToSize(String(text), 178)) {
      if (y > 280) { doc.addPage(); y = 18 }
      doc.text(fragment, 16, y); y += 6
    }
  }
  doc.setFontSize(11)
  line(data.shelter.abr_nome, true)
  line(`Período: ${start} a ${end}`)
  line('Estoque: posição atual na data de emissão. Demais seções: registros do período.')
  for (const [name, rows] of Object.entries(sheets)) {
    y += 5; line(name, true)
    if (!rows.length) line('Nenhum registro no período.')
    for (const row of rows) { line(Object.entries(row).map(([k, v]) => `${k}: ${v}`).join(' | ')); y += 3 }
  }
  doc.save(`${filename}.pdf`)
}
