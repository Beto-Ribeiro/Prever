/**
 * Relatorios.jsx
 *
 * Exportação PDF  → html2canvas + jsPDF (captura só o div#relatorio-content)
 * Exportação Excel → SheetJS (xlsx) com múltiplas abas
 *
 * Dados reais do painel
 * Exportação PDF e Excel continuam usando o layout atual, sem mudar o design.
 *
 * Dependências necessárias:
 *   html2canvas, jspdf, xlsx
 */

import { useState, useRef, useCallback, useEffect } from 'react'
import Card from '../components/Card'
import externalIcon from '../assets/relatorios/external-link.svg'
import { getRelatoriosData, subscribeRelatoriosChanges } from '../backend/relatorios/relatoriosService.js'
import { toFriendlyMessage } from '../utils/friendlyMessages.js'
import { useSmdnSettings } from '../hooks/useSmdnSettings.js'

// ─── Dependências de exportação ──────────────────────────────────────────────
// Se ainda não instalou: npm install html2canvas jspdf xlsx
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'

// ─────────────────────────────────────────────────────────────────────────────
// HOOK DE DADOS REAIS
// Centraliza a chamada aos dados sem alterar o desenho visual da tela.
// ─────────────────────────────────────────────────────────────────────────────
const EMPTY_REPORT_DATA = {
  kpis: {
    total: 0,
    totalDelta: '0%',
    totalPositive: true,
    resolutionRate: '0%',
    resolutionDelta: '0%',
    resolutionPositive: true,
  },
  monthly: [
    { month: 'Jan', total: 0, critical: 0 },
    { month: 'Fev', total: 0, critical: 0 },
    { month: 'Mar', total: 0, critical: 0 },
    { month: 'Abr', total: 0, critical: 0 },
    { month: 'Mai', total: 0, critical: 0 },
    { month: 'Jun', total: 0, critical: 0 },
    { month: 'Jul', total: 0, critical: 0 },
  ],
  byType: [],
  byCity: [],
  bySeverity: [
    { label: 'Crítico', count: 0, pct: 0, color: 'bg-status-critical', text: 'text-status-critical' },
    { label: 'Grave', count: 0, pct: 0, color: 'bg-status-severe', text: 'text-status-severe' },
    { label: 'Moderado', count: 0, pct: 0, color: 'bg-status-regular', text: 'text-status-regular' },
    { label: 'Normal', count: 0, pct: 0, color: 'bg-status-success', text: 'text-status-success' },
  ],
  byStatus: [
    { label: 'Resolvidas', count: 0, pct: 0, color: '#02c602' },
    { label: 'Em andamento', count: 0, pct: 0, color: '#ff6a00' },
    { label: 'Pendentes', count: 0, pct: 0, color: '#c60202' },
  ],
  occurrences: [],
}

function useReportData(period) {
  const [state, setState] = useState({
    loading: true,
    error: '',
    data: EMPTY_REPORT_DATA,
  })

  const load = useCallback(async ({ silent = false } = {}) => {
    setState((prev) => ({ ...prev, loading: silent ? prev.loading : true, error: '' }))

    try {
      const data = await getRelatoriosData(period)
      setState({ loading: false, error: '', data })
    } catch (err) {
      console.error('[PREVER Relatórios] Erro ao carregar dados reais:', err)
      setState((prev) => ({
        loading: false,
        error: toFriendlyMessage(err, 'Não foi possível carregar os relatórios. Tente novamente.'),
        data: prev.data || EMPTY_REPORT_DATA,
      }))
    }
  }, [period])

  useEffect(() => {
    let active = true

    async function safeLoad() {
      if (!active) return
      await load()
    }

    safeLoad()

    const unsubscribe = subscribeRelatoriosChanges(() => {
      if (active) load({ silent: true })
    })

    return () => {
      active = false
      unsubscribe?.()
    }
  }, [load])

  return state
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITÁRIOS DE EXPORTAÇÃO
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Gera e baixa um PDF bonito a partir do elemento DOM passado.
 * Usa html2canvas para renderizar o conteúdo e jsPDF para empacotar.
 */
async function exportToPDF(element, period) {
  // Esconde temporariamente os botões de exportação dentro da área capturada
  const exportBar = element.querySelector('[data-export-bar]')
  if (exportBar) exportBar.style.visibility = 'hidden'

  const canvas = await html2canvas(element, {
    scale: 2,          // alta resolução
    useCORS: true,
    backgroundColor: '#f8fafc',
    logging: false,
  })

  if (exportBar) exportBar.style.visibility = ''

  const pdf     = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })

  const pageW  = pdf.internal.pageSize.getWidth()
  const pageH  = pdf.internal.pageSize.getHeight()
  const margin = 10
  const usableW = pageW - margin * 2
  const imgH    = (canvas.height * usableW) / canvas.width

  // Cabeçalho
  pdf.setFillColor(15, 23, 42)        // slate-900
  pdf.rect(0, 0, pageW, 14, 'F')
  pdf.setTextColor(255, 255, 255)
  pdf.setFontSize(9)
  pdf.setFont('helvetica', 'bold')
  pdf.text('PREVER – Plataforma de Resiliência e Vigilância de Eventos de Risco', margin, 9)
  pdf.setFont('helvetica', 'normal')
  pdf.text(`Relatório · ${period} · Gerado em ${new Date().toLocaleDateString('pt-BR')}`, pageW - margin, 9, { align: 'right' })

  // Conteúdo (com paginação automática)
  const startY = 16
  let remaining = imgH
  let srcY = 0

  while (remaining > 0) {
    const sliceH = Math.min(pageH - startY - margin, remaining)
    const sliceCanvas = document.createElement('canvas')
    sliceCanvas.width  = canvas.width
    sliceCanvas.height = (sliceH / usableW) * canvas.width

    const ctx = sliceCanvas.getContext('2d')
    ctx.drawImage(canvas, 0, srcY * (canvas.width / usableW), canvas.width, sliceCanvas.height, 0, 0, sliceCanvas.width, sliceCanvas.height)

    pdf.addImage(sliceCanvas.toDataURL('image/png'), 'PNG', margin, startY, usableW, sliceH)

    remaining -= sliceH
    srcY      += sliceH

    if (remaining > 0) {
      pdf.addPage()
    }
  }

  // Rodapé
  const totalPages = pdf.internal.getNumberOfPages()
  for (let i = 1; i <= totalPages; i++) {
    pdf.setPage(i)
    pdf.setFontSize(7)
    pdf.setTextColor(148, 163, 184) // slate-400
    pdf.text(`Página ${i} de ${totalPages}`, pageW / 2, pageH - 4, { align: 'center' })
  }

  pdf.save(`PREVER_Relatorio_${period.replace(/\s+/g, '_')}.pdf`)
}

/**
 * Gera e baixa um arquivo Excel (.xlsx) com abas separadas por seção.
 * Estruturado para receber dados reais sem alteração.
 */
function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

function periodSlug(period) {
  const normalized = String(period || '').toLowerCase()
  if (normalized.includes('7')) return '7dias'
  if (normalized.includes('30')) return '30dias'
  if (normalized.includes('ano')) return '1ano'
  return '6meses'
}

function reportFileName(period, extension = 'xls') {
  const now = new Date()
  const pad = (value) => String(value).padStart(2, '0')
  const date = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
  const time = `${pad(now.getHours())}h${pad(now.getMinutes())}`
  return `${date}_${periodSlug(period)}_${time}.${extension}`
}

function tableHtml(headers, rows, options = {}) {
  const caption = options.caption ? `<tr><td class="section-title" colspan="${headers.length}">${escapeHtml(options.caption)}</td></tr>` : ''
  return `
    <table class="report-table">
      ${caption}
      <thead><tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join('')}</tr></thead>
      <tbody>
        ${rows.map((row) => `<tr>${row.map((cell, index) => `<td class="${options.cellClass?.(cell, index, row) || ''}">${cell}</td>`).join('')}</tr>`).join('')}
      </tbody>
    </table>
  `
}

function kpiCardHtml(label, value, detail, tone = 'blue') {
  return `
    <td class="kpi kpi-${tone}">
      <div class="kpi-label">${escapeHtml(label)}</div>
      <div class="kpi-value">${escapeHtml(value)}</div>
      <div class="kpi-detail">${escapeHtml(detail)}</div>
    </td>
  `
}

function downloadHtmlExcel(html, filename) {
  const blob = new Blob(['\ufeff', html], { type: 'application/vnd.ms-excel;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

/**
 * Gera e baixa um Excel em HTML formatado.
 * O Excel abre como .xls com cores, títulos grandes, tabelas e layout horizontal.
 */
function exportToExcel(data, period) {
  const generatedAt = new Date().toLocaleString('pt-BR')

  const severityRows = data.bySeverity.map((item) => [
    escapeHtml(SEVERITY_META[item.label]?.symbol || '•'),
    escapeHtml(item.label),
    escapeHtml(item.count),
    escapeHtml(`${item.pct}%`),
  ])

  const statusRows = data.byStatus.map((item) => [
    escapeHtml(STATUS_META[item.label]?.label || item.label),
    escapeHtml(item.label),
    escapeHtml(item.count),
    escapeHtml(`${item.pct}%`),
  ])

  const monthlyRows = data.monthly.map((item) => [
    escapeHtml(item.month),
    escapeHtml(item.total),
    escapeHtml(item.critical),
    escapeHtml(item.total > 0 ? `${((item.critical / item.total) * 100).toFixed(1)}%` : '0%'),
    escapeHtml(item.critical > 0 ? 'Atenção a ocorrências críticas' : 'Sem críticas no período'),
  ])

  const cityRows = data.byCity.map((item, index) => [
    escapeHtml(index + 1),
    escapeHtml(item.city),
    escapeHtml(item.count),
    escapeHtml(index < 3 ? 'Alta prioridade' : 'Monitorar'),
  ])

  const typeRows = data.byType.map((item) => [
    escapeHtml(item.type),
    escapeHtml(item.count),
    escapeHtml(`${item.pct}%`),
    escapeHtml(item.pct >= 25 ? 'Tipo recorrente' : 'Acompanhar tendência'),
  ])

  const occurrenceRows = (data.occurrences || []).map((item) => [
    escapeHtml(item.id),
    escapeHtml(item.tipo),
    escapeHtml(item.descricao),
    escapeHtml(item.severidade),
    escapeHtml(item.status),
    escapeHtml(item.municipio),
    escapeHtml(item.cidadaoNome),
    escapeHtml(item.data ? new Date(item.data).toLocaleString('pt-BR') : 'Data não informada'),
    escapeHtml(item.lat ?? '—'),
    escapeHtml(item.lng ?? '—'),
  ])

  const html = `
    <!doctype html>
    <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
      <head>
        <meta charset="utf-8" />
        <!--[if gte mso 9]>
        <xml>
          <x:ExcelWorkbook>
            <x:ExcelWorksheets>
              <x:ExcelWorksheet>
                <x:Name>PREVER Relatório</x:Name>
                <x:WorksheetOptions>
                  <x:PageSetup><x:Layout x:Orientation="Landscape"/></x:PageSetup>
                  <x:FitToPage/>
                  <x:Print><x:FitWidth>1</x:FitWidth><x:FitHeight>0</x:FitHeight></x:Print>
                </x:WorksheetOptions>
              </x:ExcelWorksheet>
            </x:ExcelWorksheets>
          </x:ExcelWorkbook>
        </xml>
        <![endif]-->
        <style>
          body { margin: 0; font-family: Segoe UI, Arial, sans-serif; background: #eef5fa; color: #0f172a; }
          .sheet { width: 1280px; padding: 22px; background: #eef5fa; }
          .hero { width: 100%; border-collapse: collapse; margin-bottom: 18px; }
          .hero-title { background: #0b1f35; color: #ffffff; font-size: 28px; font-weight: 800; padding: 18px 22px; border: 1px solid #0b1f35; }
          .hero-meta { background: #dfeaf3; color: #1e3a55; font-size: 13px; font-weight: 700; padding: 10px 22px; border: 1px solid #b8c8d8; }
          .kpi-grid { width: 100%; border-collapse: separate; border-spacing: 12px; margin-bottom: 20px; }
          .kpi { border-radius: 16px; border: 1px solid #9fb5c9; padding: 16px 18px; width: 25%; vertical-align: top; }
          .kpi-blue { background: #dbeafe; }
          .kpi-green { background: #dcfce7; }
          .kpi-red { background: #fee2e2; }
          .kpi-orange { background: #ffedd5; }
          .kpi-label { color: #334155; font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; }
          .kpi-value { color: #0f172a; font-size: 30px; font-weight: 900; margin-top: 5px; }
          .kpi-detail { color: #475569; font-size: 13px; font-weight: 700; margin-top: 4px; }
          .two-col { width: 100%; border-collapse: separate; border-spacing: 14px; margin-bottom: 18px; }
          .two-col > tbody > tr > td { width: 50%; vertical-align: top; }
          .report-table { width: 100%; border-collapse: collapse; background: #ffffff; margin-bottom: 18px; border: 1px solid #9fb5c9; }
          .report-table th { background: #123a5c; color: #ffffff; font-size: 13px; font-weight: 800; padding: 10px; border: 1px solid #0b1f35; text-align: left; }
          .report-table td { font-size: 12px; padding: 9px 10px; border: 1px solid #c7d6e3; color: #1e293b; }
          .report-table tr:nth-child(even) td { background: #f6f9fc; }
          .section-title { background: #82b9df !important; color: #0b1f35 !important; font-size: 17px !important; font-weight: 900 !important; padding: 12px !important; border: 1px solid #5a93bd !important; }
          .critical { color: #b91c1c; font-weight: 900; }
          .severe { color: #c2410c; font-weight: 900; }
          .regular { color: #a16207; font-weight: 900; }
          .success { color: #047857; font-weight: 900; }
          .muted { color: #64748b; }
          .wide { width: 100%; }
        </style>
      </head>
      <body>
        <div class="sheet">
          <table class="hero">
            <tr><td class="hero-title" colspan="4">PREVER — Relatório de Ocorrências</td></tr>
            <tr>
              <td class="hero-meta">Período: ${escapeHtml(period)}</td>
              <td class="hero-meta">Gerado em: ${escapeHtml(generatedAt)}</td>
              <td class="hero-meta">Fonte: Painel PREVER</td>
              <td class="hero-meta">Formato: Executivo</td>
            </tr>
          </table>

          <table class="kpi-grid">
            <tr>
              ${kpiCardHtml('Total de Ocorrências', data.kpis.total, data.kpis.totalDelta, 'blue')}
              ${kpiCardHtml('Taxa de Resolução', data.kpis.resolutionRate, data.kpis.resolutionDelta, 'green')}
              ${kpiCardHtml('Ocorrências Críticas', data.bySeverity.find((item) => item.label === 'Crítico')?.count || 0, 'prioridade máxima', 'red')}
              ${kpiCardHtml('Municípios Monitorados', data.byCity.length, 'com ocorrências no período', 'orange')}
            </tr>
          </table>

          <table class="two-col"><tr>
            <td>${tableHtml(['Símbolo', 'Nível', 'Qtd.', '%'], severityRows, { caption: 'Distribuição de Severidade' })}</td>
            <td>${tableHtml(['Ícone', 'Status', 'Qtd.', '%'], statusRows, { caption: 'Status das Ocorrências' })}</td>
          </tr></table>

          ${tableHtml(['Mês', 'Total', 'Críticas', '% Críticas', 'Leitura rápida'], monthlyRows, { caption: 'Ocorrências por Mês' })}

          <table class="two-col"><tr>
            <td>${tableHtml(['Ranking', 'Município', 'Qtd.', 'Prioridade'], cityRows, { caption: 'Ocorrências por Município' })}</td>
            <td>${tableHtml(['Tipo', 'Qtd.', '%', 'Observação'], typeRows, { caption: 'Ocorrências por Tipo' })}</td>
          </tr></table>

          ${tableHtml(['ID', 'Tipo', 'Descrição/Risco', 'Severidade', 'Status', 'Município', 'Cidadão', 'Data', 'Latitude', 'Longitude'], occurrenceRows, { caption: 'Ocorrências Detalhadas' })}
        </div>
      </body>
    </html>
  `

  downloadHtmlExcel(html, reportFileName(period, 'xls'))
}

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES VISUAIS (independentes dos dados)
// ─────────────────────────────────────────────────────────────────────────────

const SEVERITY_META = {
  'Crítico': { shape: 'critical', color: '#c60202', symbol: '◆' },
  'Grave': { shape: 'severe', color: '#ff6a00', symbol: '▲' },
  'Moderado': { shape: 'regular', color: '#cab900', symbol: '●' },
  'Normal': { shape: 'regular', color: '#02c602', symbol: '✓' },
}

const STATUS_META = {
  'Resolvidas': { icon: 'check', label: 'Resolvida' },
  'Em andamento': { icon: 'clock', label: 'Em andamento' },
  'Pendentes': { icon: 'alert', label: 'Pendente' },
}

function MiniFeatherIcon({ type = 'circle', color = 'currentColor', className = '' }) {
  if (type === 'check') {
    return (
      <svg className={className} width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle cx="12" cy="12" r="9" stroke={color} strokeWidth="2" />
        <path d="M8 12.5l2.5 2.5L16 9" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    )
  }
  if (type === 'clock') {
    return (
      <svg className={className} width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle cx="12" cy="12" r="9" stroke={color} strokeWidth="2" />
        <path d="M12 7v5l3 2" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    )
  }
  if (type === 'alert') {
    return (
      <svg className={className} width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M12 3l9 16H3L12 3Z" stroke={color} strokeWidth="2" strokeLinejoin="round" />
        <path d="M12 9v4M12 17h.01" stroke={color} strokeWidth="2" strokeLinecap="round" />
      </svg>
    )
  }
  return (
    <svg className={className} width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="8" stroke={color} strokeWidth="2" />
    </svg>
  )
}

function SeverityLegendLabel({ item }) {
  const meta = SEVERITY_META[item.label] || SEVERITY_META.Moderado
  return (
    <span className={`inline-flex items-center gap-1.5 font-bold ${item.text}`}>
      <span className="inline-flex w-4 justify-center text-base leading-none" style={{ color: meta.color }} aria-hidden="true">
        {meta.symbol}
      </span>
      {item.label}
    </span>
  )
}

function StatusLegendLabel({ item }) {
  const meta = STATUS_META[item.label] || { icon: 'circle' }
  return (
    <span className="inline-flex items-center gap-1.5 text-slate-600 font-medium">
      <MiniFeatherIcon type={meta.icon} color={item.color} />
      {item.label}
    </span>
  )
}

const TYPE_COLORS = [
  'bg-text-main',
  'bg-status-severe',
  'bg-status-regular',
  'bg-action-inactive',
  'bg-status-critical',
  'bg-slate-400',
]

const PERIODS = ['Últimos 7 dias', 'Últimos 30 dias', 'Últimos 6 meses', 'Último ano']

const DONUT_R          = 54
const DONUT_CX         = 70
const DONUT_CY         = 70
const CIRCUMFERENCE    = 2 * Math.PI * DONUT_R

function buildDonutSegments(items) {
  let offset = 0
  return items.map((item) => {
    const dash = (item.pct / 100) * CIRCUMFERENCE
    const gap  = CIRCUMFERENCE - dash
    const seg  = { ...item, dash, gap, offset }
    offset += dash
    return seg
  })
}


function getAccessibleStatusRows(rows, colorBlind = false) {
  if (!colorBlind) return rows

  const safe = {
    Resolvidas: '#1b9e77',
    'Em andamento': '#d95f02',
    Pendentes: '#005cab',
  }

  return rows.map((row) => ({ ...row, color: safe[row.label] || row.color }))
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTE PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
export default function Relatorios() {
  const [period, setPeriod]       = useState('Últimos 6 meses')
  const [exporting, setExporting] = useState(null) // 'pdf' | 'excel' | null
  const reportRef                 = useRef(null)

  const { loading, error, data } = useReportData(period)
  const { settings } = useSmdnSettings()
  const accessibleStatus = getAccessibleStatusRows(data.byStatus, settings.colorBlind)

  const maxTotal = Math.max(1, ...data.monthly.map((m) => m.total))
  const maxCity  = Math.max(1, ...data.byCity.map((c) => c.count))
  const donutSegments = buildDonutSegments(accessibleStatus)

  // ── Handlers de exportação ─────────────────────────────────────────────────
  const handleExportPDF = useCallback(async () => {
    if (!reportRef.current || exporting || loading) return
    setExporting('pdf')
    try {
      await exportToPDF(reportRef.current, period)
    } catch (err) {
      console.error('Erro ao gerar PDF:', err)
      alert('Não foi possível gerar o PDF. Tente novamente.')
    } finally {
      setExporting(null)
    }
  }, [period, exporting, loading])

  const handleExportExcel = useCallback(() => {
    if (exporting || loading) return
    setExporting('excel')
    try {
      exportToExcel(data, period)
    } catch (err) {
      console.error('Erro ao gerar Excel:', err)
      alert('Não foi possível gerar o Excel. Tente novamente.')
    } finally {
      setExporting(null)
    }
  }, [data, period, exporting, loading])

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="p-8 space-y-6 animate-fade-in">

      {/* ── Barra de controles (período + exportação) ── */}
      <div className="flex items-center justify-between flex-wrap gap-4" data-export-bar>
        {/* KPIs */}
        <div className="flex gap-4 flex-wrap">
          {[
            {
              label:    'TOTAL DE OCORRÊNCIAS',
              value:    String(data.kpis.total),
              delta:    data.kpis.totalDelta,
              positive: data.kpis.totalPositive,
              color:    'text-text-main',
            },
            {
              label:    'TAXA DE RESOLUÇÃO',
              value:    data.kpis.resolutionRate,
              delta:    data.kpis.resolutionDelta,
              positive: data.kpis.resolutionPositive,
              color:    'text-status-success',
            },
          ].map((kpi) => (
            <Card key={kpi.label} className="py-4 min-w-[200px]">
              <p className="text-label text-slate-500 mb-1.5">{kpi.label}</p>
              <p className={`text-3xl font-bold ${kpi.color}`}>{kpi.value}</p>
              <p className={`text-xs font-semibold mt-1 ${kpi.positive ? 'text-status-success' : 'text-status-critical'}`}>
                {kpi.delta} em comparação ao período anterior
              </p>
            </Card>
          ))}
        </div>

        {/* Seletor de período + botões */}
        <div className="flex flex-col items-end gap-2">
          <div className="flex items-center gap-2 bg-bg-surface border border-border-soft rounded-lg p-1">
            {PERIODS.map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`px-3 py-1.5 rounded text-xs font-semibold transition-all ${
                  period === p
                    ? 'bg-text-main text-white shadow-sm'
                    : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                {p}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleExportPDF}
              disabled={!!exporting || loading}
              className="flex items-center gap-2 px-4 py-2 text-xs font-semibold text-slate-600 border border-border-soft rounded-lg bg-bg-surface hover:bg-slate-50 hover:border-slate-300 transition-all disabled:opacity-50 disabled:cursor-wait"
            >
              <img src={externalIcon} width="13" height="13" alt="" />
              {exporting === 'pdf' ? 'Gerando…' : 'Exportar PDF'}
            </button>
            <button
              onClick={handleExportExcel}
              disabled={!!exporting || loading}
              className="flex items-center gap-2 px-4 py-2 text-xs font-semibold text-slate-600 border border-border-soft rounded-lg bg-bg-surface hover:bg-slate-50 hover:border-slate-300 transition-all disabled:opacity-50 disabled:cursor-wait"
            >
              <img src={externalIcon} width="13" height="13" alt="" />
              {exporting === 'excel' ? 'Gerando…' : 'Exportar Excel'}
            </button>
          </div>
        </div>
      </div>

      {loading && (
        <Card className="border border-blue-100 bg-blue-50/80">
          <p className="text-sm font-semibold text-blue-900">Carregando dados do relatório...</p>
          <p className="text-xs text-blue-700 mt-1">A tela continua com o mesmo design, mas agora calcula tudo com Relato e Ocorrencia_Status.</p>
        </Card>
      )}

      {error && (
        <Card className="border border-red-100 bg-red-50/80">
          <p className="text-sm font-semibold text-red-800">Não foi possível carregar os relatórios.</p>
          <p className="text-xs text-red-700 mt-1">{error}</p>
        </Card>
      )}

      {/* ═══════════════════════════════════════════════════════════════════
          ÁREA CAPTURADA PELO PDF
          id="relatorio-content" + ref={reportRef}
          Tudo abaixo daqui vai para o PDF; os controles acima ficam de fora.
          ═══════════════════════════════════════════════════════════════════ */}
      <div id="relatorio-content" ref={reportRef} className="space-y-6 bg-bg-base rounded-xl">

        {/* Gráfico de barras mensal + Por Tipo */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <Card className="lg:col-span-2">
            <h3 className="text-card-title font-bold text-slate-800 mb-6">Ocorrências por Mês</h3>
            <div className="flex items-end gap-3 h-48">
              {data.monthly.map((m) => (
                <div key={m.month} className="flex-1 flex flex-col items-center gap-1.5">
                  <span className="text-[10px] text-slate-400 font-bold">{m.total}</span>
                  <div className="w-full flex flex-col justify-end" style={{ height: '160px' }}>
                    <div
                      className="w-full rounded-t bg-text-main/20 relative overflow-hidden flex flex-col justify-end"
                      style={{ height: `${(m.total / maxTotal) * 100}%` }}
                    >
                      <div
                        className="w-full bg-status-critical rounded-t report-pattern-critical"
                        style={{ height: `${m.total > 0 ? (m.critical / m.total) * 100 : 0}%` }}
                      />
                    </div>
                  </div>
                  <span className="text-[11px] text-slate-500 font-medium">{m.month}</span>
                </div>
              ))}
            </div>
            <div className="flex items-center gap-5 mt-4">
              <div className="flex items-center gap-1.5">
                <span className="w-3 h-3 rounded-sm bg-text-main/20 report-pattern-main block" />
                <span className="text-xs text-slate-500">Total</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="w-3 h-3 rounded-sm bg-status-critical report-pattern-critical block" />
                <span className="text-xs text-slate-500">◆ Críticos</span>
              </div>
            </div>
          </Card>

          <Card>
            <h3 className="text-card-title font-bold text-slate-800 mb-5">Por Tipo</h3>
            <div className="space-y-3">
              {data.byType.length === 0 && (
                <p className="text-sm text-slate-400">Nenhuma ocorrência no período.</p>
              )}
              {data.byType.map((t, i) => (
                <div key={t.type}>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-slate-600 font-medium">{t.type}</span>
                    <span className="text-slate-400 font-bold">{t.count}</span>
                  </div>
                  <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full ${TYPE_COLORS[i]} report-pattern-main`}
                      style={{ width: `${t.pct}%`, transition: 'width 0.6s ease' }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </Card>
        </div>

        {/* Severidade + Status */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <h3 className="text-card-title font-bold text-slate-800 mb-5">Distribuição de Severidade</h3>
            <div className="space-y-4">
              {data.bySeverity.map((s) => (
                <div key={s.label}>
                  <div className="flex justify-between text-xs mb-1.5">
                    <SeverityLegendLabel item={s} />
                    <span className="text-slate-400 font-bold">
                      {s.count} <span className="text-slate-300">({s.pct}%)</span>
                    </span>
                  </div>
                  <div className="h-3 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full ${s.color} report-pattern-main`}
                      style={{ width: `${s.pct}%`, transition: 'width 0.7s ease' }}
                    />
                  </div>
                </div>
              ))}
            </div>
            <div className="grid grid-cols-4 gap-2 mt-5 pt-4 border-t border-border-soft">
              {data.bySeverity.map((s) => (
                <div key={s.label} className="text-center">
                  <p className={`text-lg font-bold ${s.text}`}>{s.pct}%</p>
                  <p className="text-[10px] text-slate-400 font-semibold">{s.label}</p>
                </div>
              ))}
            </div>
          </Card>

          <Card>
            <h3 className="text-card-title font-bold text-slate-800 mb-5">Status das Ocorrências</h3>
            <div className="flex items-center gap-8">
              <div className="relative flex-shrink-0">
                <svg width="140" height="140" viewBox="0 0 140 140">
                  <circle cx={DONUT_CX} cy={DONUT_CY} r={DONUT_R} fill="none" stroke="#f1f5f9" strokeWidth="16" />
                  {donutSegments.map((seg) => (
                    <circle
                      key={seg.label}
                      cx={DONUT_CX}
                      cy={DONUT_CY}
                      r={DONUT_R}
                      fill="none"
                      stroke={seg.color}
                      strokeWidth="16"
                      strokeDasharray={`${seg.dash} ${seg.gap}`}
                      strokeDashoffset={-seg.offset}
                      transform={`rotate(-90 ${DONUT_CX} ${DONUT_CY})`}
                      style={{ transition: 'stroke-dasharray 0.7s ease' }}
                    />
                  ))}
                </svg>
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-2xl font-bold text-slate-800">{data.kpis.total}</span>
                  <span className="text-[10px] text-slate-400 font-semibold">total</span>
                </div>
              </div>
              <div className="flex-1 space-y-4">
                {accessibleStatus.map((s) => (
                  <div key={s.label}>
                    <div className="flex justify-between text-xs mb-1">
                      <StatusLegendLabel item={s} />
                      <span className="font-bold text-slate-700">{s.count}</span>
                    </div>
                    <div className="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full report-pattern-main"
                        style={{
                          width:           `${s.pct}%`,
                          backgroundColor: s.color,
                          transition:      'width 0.7s ease',
                        }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </Card>
        </div>

        {/* Por Município */}
        <Card>
          <h3 className="text-card-title font-bold text-slate-800 mb-5">Ocorrências por Município</h3>
          <div className="space-y-3">
            {data.byCity.length === 0 && (
              <p className="text-sm text-slate-400">Nenhuma ocorrência com município no período.</p>
            )}
            {data.byCity.map((c) => (
              <div key={c.city} className="flex items-center gap-4">
                <span className="text-sm text-slate-600 w-40 font-medium truncate">{c.city}</span>
                <div className="flex-1 h-6 bg-slate-100 rounded overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-text-main to-action-hover flex items-center justify-end pr-2 rounded transition-all duration-700"
                    style={{ width: `${(c.count / maxCity) * 100}%` }}
                  >
                    <span className="text-white text-[11px] font-bold">{c.count}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </Card>

      </div>{/* fim #relatorio-content */}
    </div>
  )
}
