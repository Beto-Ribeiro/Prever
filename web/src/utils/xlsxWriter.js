// Gerador enxuto e seguro de arquivos OpenXML (.xlsx) sem dependências externas.
// Elimina a dependência vulnerável `xlsx` (GHSA-4r6h-8v6p-xvw6 / GHSA-5pgg-2g8v-p4x9)
// e grava todas as strings como células inlineStr com proteção contra CSV/Formula Injection.

const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let i = 0; i < 256; i += 1) {
    let c = i
    for (let k = 0; k < 8; k += 1) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    }
    table[i] = c >>> 0
  }
  return table
})()

function crc32(bytes) {
  let crc = 0xffffffff
  for (let i = 0; i < bytes.length; i += 1) {
    crc = CRC_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8)
  }
  return (crc ^ 0xffffffff) >>> 0
}

function stripXmlControlChars(input) {
  let clean = ''
  for (let i = 0; i < input.length; i += 1) {
    const code = input.charCodeAt(i)
    if (code === 0x09 || code === 0x0a || code === 0x0d || code >= 0x20) {
      clean += input[i]
    }
  }
  return clean
}

function escapeXml(value) {
  return stripXmlControlChars(String(value ?? ''))
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
}

export function sanitizeSpreadsheetText(value) {
  const text = String(value ?? '')
  // Neutraliza payloads de Formula Injection (=, +, -, @, Tab, CR) em células de texto.
  if (/^[=+\-@\t\r]/.test(text)) {
    return `'${text}`
  }
  return text
}

function columnName(index) {
  let n = index + 1
  let result = ''
  while (n > 0) {
    const rem = (n - 1) % 26
    result = String.fromCharCode(65 + rem) + result
    n = Math.floor((n - 1) / 26)
  }
  return result
}

function sanitizeSheetTitle(rawName, index) {
  const cleaned = String(rawName || `Aba${index + 1}`)
    .replace(/[\\/?*:[\]]/g, ' ')
    .trim()
    .slice(0, 31)
  return cleaned || `Aba${index + 1}`
}

function buildWorksheetXml(rows) {
  const safeRows = Array.isArray(rows) && rows.length > 0
    ? rows
    : [{ Informação: 'Nenhum registro no período.' }]

  const headers = Array.from(
    safeRows.reduce((set, row) => {
      Object.keys(row || {}).forEach((k) => set.add(k))
      return set
    }, new Set())
  )

  const xmlRows = []

  // Linha 1: Cabeçalho
  const headerCells = headers
    .map((header, colIdx) => {
      const ref = `${columnName(colIdx)}1`
      const text = escapeXml(sanitizeSpreadsheetText(header))
      return `<c r="${ref}" s="1" t="inlineStr"><is><t xml:space="preserve">${text}</t></is></c>`
    })
    .join('')
  xmlRows.push(`<row r="1">${headerCells}</row>`)

  // Linhas de dados
  safeRows.forEach((row, rowIdx) => {
    const excelRow = rowIdx + 2
    const cells = headers
      .map((header, colIdx) => {
        const ref = `${columnName(colIdx)}${excelRow}`
        const val = row?.[header]
        if (typeof val === 'number' && Number.isFinite(val)) {
          return `<c r="${ref}"><v>${val}</v></c>`
        }
        const text = escapeXml(sanitizeSpreadsheetText(val ?? ''))
        return `<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${text}</t></is></c>`
      })
      .join('')
    xmlRows.push(`<row r="${excelRow}">${cells}</row>`)
  })

  return (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    `<sheetData>${xmlRows.join('')}</sheetData>` +
    '</worksheet>'
  )
}

function encodeZipStore(entries) {
  const encoder = new TextEncoder()
  const prepared = entries.map((entry) => {
    const nameBytes = encoder.encode(entry.name)
    const dataBytes = entry.content instanceof Uint8Array ? entry.content : encoder.encode(entry.content)
    return {
      nameBytes,
      dataBytes,
      crc: crc32(dataBytes),
    }
  })

  let localSize = 0
  let centralSize = 0
  for (const item of prepared) {
    localSize += 30 + item.nameBytes.length + item.dataBytes.length
    centralSize += 46 + item.nameBytes.length
  }

  const out = new Uint8Array(localSize + centralSize + 22)
  const view = new DataView(out.buffer)
  let offset = 0
  const offsets = []

  for (const item of prepared) {
    offsets.push(offset)
    view.setUint32(offset, 0x04034b50, true); offset += 4 // Local file header signature
    view.setUint16(offset, 20, true); offset += 2         // Version needed (2.0)
    view.setUint16(offset, 0x0800, true); offset += 2     // UTF-8 flag
    view.setUint16(offset, 0, true); offset += 2          // Store (no compression)
    view.setUint16(offset, 0, true); offset += 2          // Mod time
    view.setUint16(offset, 0x21, true); offset += 2       // Mod date
    view.setUint32(offset, item.crc, true); offset += 4   // CRC-32
    view.setUint32(offset, item.dataBytes.length, true); offset += 4
    view.setUint32(offset, item.dataBytes.length, true); offset += 4
    view.setUint16(offset, item.nameBytes.length, true); offset += 2
    view.setUint16(offset, 0, true); offset += 2          // Extra length
    out.set(item.nameBytes, offset); offset += item.nameBytes.length
    out.set(item.dataBytes, offset); offset += item.dataBytes.length
  }

  const centralStart = offset
  for (let i = 0; i < prepared.length; i += 1) {
    const item = prepared[i]
    view.setUint32(offset, 0x02014b50, true); offset += 4 // Central directory signature
    view.setUint16(offset, 20, true); offset += 2         // Version made by
    view.setUint16(offset, 20, true); offset += 2         // Version needed
    view.setUint16(offset, 0x0800, true); offset += 2     // UTF-8 flag
    view.setUint16(offset, 0, true); offset += 2          // Store
    view.setUint16(offset, 0, true); offset += 2          // Mod time
    view.setUint16(offset, 0x21, true); offset += 2       // Mod date
    view.setUint32(offset, item.crc, true); offset += 4   // CRC-32
    view.setUint32(offset, item.dataBytes.length, true); offset += 4
    view.setUint32(offset, item.dataBytes.length, true); offset += 4
    view.setUint16(offset, item.nameBytes.length, true); offset += 2
    view.setUint16(offset, 0, true); offset += 2          // Extra length
    view.setUint16(offset, 0, true); offset += 2          // Comment length
    view.setUint16(offset, 0, true); offset += 2          // Disk number
    view.setUint16(offset, 0, true); offset += 2          // Internal attrs
    view.setUint32(offset, 0, true); offset += 4          // External attrs
    view.setUint32(offset, offsets[i], true); offset += 4 // Local header offset
    out.set(item.nameBytes, offset); offset += item.nameBytes.length
  }

  const centralLength = offset - centralStart
  view.setUint32(offset, 0x06054b50, true); offset += 4   // End of central directory
  view.setUint16(offset, 0, true); offset += 2
  view.setUint16(offset, 0, true); offset += 2
  view.setUint16(offset, prepared.length, true); offset += 2
  view.setUint16(offset, prepared.length, true); offset += 2
  view.setUint32(offset, centralLength, true); offset += 4
  view.setUint32(offset, centralStart, true); offset += 4
  view.setUint16(offset, 0, true)

  return out
}

export function buildXlsxBytes(sheetsMap) {
  const entries = Object.entries(sheetsMap || {})
  const sheetList = entries.length > 0 ? entries : [['Relatório', []]]

  const usedNames = new Set()
  const normalizedSheets = sheetList.map(([rawName, rows], idx) => {
    let title = sanitizeSheetTitle(rawName, idx)
    if (usedNames.has(title.toLowerCase())) {
      title = `${title.slice(0, 28)}_${idx + 1}`
    }
    usedNames.add(title.toLowerCase())
    return { title, xml: buildWorksheetXml(rows), index: idx + 1 }
  })

  const contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    normalizedSheets
      .map(
        (s) =>
          `<Override PartName="/xl/worksheets/sheet${s.index}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`
      )
      .join('') +
    '</Types>'

  const rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    '</Relationships>'

  const workbookXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    '<sheets>' +
    normalizedSheets
      .map(
        (s) =>
          `<sheet name="${escapeXml(s.title)}" sheetId="${s.index}" r:id="rId${s.index}"/>`
      )
      .join('') +
    '</sheets>' +
    '</workbook>'

  const workbookRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    normalizedSheets
      .map(
        (s) =>
          `<Relationship Id="rId${s.index}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${s.index}.xml"/>`
      )
      .join('') +
    `<Relationship Id="rId${normalizedSheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>` +
    '</Relationships>'

  const stylesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<fonts count="2">' +
    '<font><sz val="11"/><name val="Calibri"/></font>' +
    '<font><b/><sz val="11"/><name val="Calibri"/></font>' +
    '</fonts>' +
    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
    '<cellXfs count="2">' +
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' +
    '</cellXfs>' +
    '</styleSheet>'

  const zipFiles = [
    { name: '[Content_Types].xml', content: contentTypes },
    { name: '_rels/.rels', content: rootRels },
    { name: 'xl/workbook.xml', content: workbookXml },
    { name: 'xl/_rels/workbook.xml.rels', content: workbookRels },
    { name: 'xl/styles.xml', content: stylesXml },
    ...normalizedSheets.map((s) => ({
      name: `xl/worksheets/sheet${s.index}.xml`,
      content: s.xml,
    })),
  ]

  return encodeZipStore(zipFiles)
}

export function downloadXlsx(sheetsMap, filename) {
  const bytes = buildXlsxBytes(sheetsMap)
  const blob = new Blob([bytes], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename.endsWith('.xlsx') ? filename : `${filename}.xlsx`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}
