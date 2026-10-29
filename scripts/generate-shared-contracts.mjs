#!/usr/bin/env node
/**
 * Gerador automatizado de DTOs e contratos de domínio (TypeScript/ESM + Flutter/Dart)
 * a partir de `shared/schema/domain.schema.json`.
 *
 * Uso:
 *   node scripts/generate-shared-contracts.mjs          # Gera/atualiza os arquivos
 *   node scripts/generate-shared-contracts.mjs --check  # Verifica se os arquivos estão sincronizados (CI)
 */

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const ROOT_DIR = path.resolve(__dirname, '..')

const SCHEMA_PATH = path.join(ROOT_DIR, 'shared', 'schema', 'domain.schema.json')
const schema = JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf8'))

function mapTsType(field) {
  if (field.tsType) return field.tsType
  switch (field.type) {
    case 'string':
      return 'string'
    case 'int':
    case 'double':
      return 'number'
    case 'boolean':
      return 'boolean'
    default:
      return 'unknown'
  }
}

function mapDartType(field) {
  switch (field.type) {
    case 'string':
      return field.required ? 'String' : 'String?'
    case 'int':
      return field.required ? 'int' : 'int?'
    case 'double':
      return field.required ? 'double' : 'double?'
    case 'boolean':
      return field.required ? 'bool' : 'bool?'
    default:
      return 'dynamic'
  }
}

function generateTypeScriptDefinitions(schemaObj) {
  const lines = [
    '// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.',
    '// Source: shared/schema/domain.schema.json',
    '// Generator: scripts/generate-shared-contracts.mjs',
    '',
  ]

  for (const [enumName, entries] of Object.entries(schemaObj.enums)) {
    const union = entries.map((e) => `'${e.value}'`).join(' | ')
    lines.push(`export type ${enumName} = ${union};`)
    lines.push('')
  }

  lines.push('export interface WebPermissions {')
  for (const key of Object.keys(schemaObj.constants.defaultWebPermissions)) {
    lines.push(`  ${key}: boolean;`)
  }
  lines.push('  usuarios?: boolean;')
  lines.push('  admin?: boolean;')
  lines.push('}')
  lines.push('')

  for (const [dtoName, dtoDef] of Object.entries(schemaObj.dtos)) {
    lines.push(`/** ${dtoDef.description} */`)
    lines.push(`export interface ${dtoName} {`)
    for (const field of dtoDef.fields) {
      const tsType = mapTsType(field)
      if (field.required) {
        lines.push(`  ${field.name}: ${tsType};`)
      } else {
        lines.push(`  ${field.name}?: ${tsType} | null;`)
      }
    }
    lines.push('}')
    lines.push('')
  }

  lines.push('export type PerfilUsuario = PerfilUsuarioDto;')
  lines.push('export type OcorrenciaRelato = OcorrenciaRelatoDto;')
  lines.push('export type AbrigoEmergencia = AbrigoEmergenciaDto;')
  lines.push('export type AlertaDefesaCivil = AlertaDefesaCivilDto;')
  lines.push('')

  return lines.join('\n')
}

function generateJsDomainConstants(schemaObj) {
  const lines = [
    '// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.',
    '// Source: shared/schema/domain.schema.json',
    '// Generator: scripts/generate-shared-contracts.mjs',
    '',
  ]

  const enumMap = {
    SEVERITY_LEVELS: 'SeverityLevel',
    SHELTER_STATUSES: 'ShelterStatus',
    USER_ROLES: 'UserRole',
    OCCURRENCE_VALIDATION_STATUSES: 'OccurrenceValidationStatus',
  }

  for (const [constName, enumKey] of Object.entries(enumMap)) {
    lines.push(`export const ${constName} = Object.freeze({`)
    for (const item of schemaObj.enums[enumKey]) {
      lines.push(`  ${item.key}: '${item.value}',`)
    }
    lines.push('})')
    lines.push('')
  }

  lines.push('export const SEVERITY_VISUAL_TOKENS = Object.freeze({')
  for (const [sevKey, token] of Object.entries(schemaObj.constants.severityVisualTokens)) {
    lines.push(`  ${JSON.stringify(sevKey)}: Object.freeze({`)
    lines.push(`    color: '${token.color}',`)
    lines.push(`    colorBlindSafe: '${token.colorBlindSafe}',`)
    lines.push(`    radiusMeters: ${token.radiusMeters},`)
    lines.push(`    opacity: ${token.opacity},`)
    lines.push(`    shape: '${token.shape}',`)
    lines.push(`    label: '${token.label}',`)
    lines.push('  }),')
  }
  lines.push('})')
  lines.push('')

  lines.push('export const DEFAULT_WEB_PERMISSIONS = Object.freeze({')
  for (const [permKey, permVal] of Object.entries(schemaObj.constants.defaultWebPermissions)) {
    lines.push(`  ${permKey}: ${permVal},`)
  }
  lines.push('})')
  lines.push('')

  const af = schemaObj.constants.antifraudConfig
  lines.push('export const ANTIFRAUD_CONFIG = Object.freeze({')
  lines.push(`  MIN_LEGITIMATE_SCORE: ${af.minLegitimateScore},`)
  lines.push(`  MODEL_NAME: '${af.modelName}',`)
  lines.push(`  FALLBACK_STATUS: '${af.fallbackStatus}',`)
  lines.push('})')
  lines.push('')

  for (const [dtoName, dtoDef] of Object.entries(schemaObj.dtos)) {
    lines.push(`/** Normaliza um objeto bruto em ${dtoName}. */`)
    lines.push(`export function create${dtoName}(raw = {}) {`)
    lines.push('  return {')
    for (const field of dtoDef.fields) {
      if (field.required) {
        if (field.type === 'string') {
          lines.push(`    ${field.name}: raw.${field.name} != null ? String(raw.${field.name}) : ${field.default},`)
        } else if (field.type === 'double' || field.type === 'int') {
          lines.push(`    ${field.name}: raw.${field.name} != null && Number.isFinite(Number(raw.${field.name})) ? Number(raw.${field.name}) : ${field.default},`)
        } else if (field.type === 'boolean') {
          lines.push(`    ${field.name}: raw.${field.name} != null ? Boolean(raw.${field.name}) : ${field.default},`)
        }
      } else {
        if (field.type === 'string') {
          lines.push(`    ${field.name}: raw.${field.name} != null ? String(raw.${field.name}) : null,`)
        } else if (field.type === 'double' || field.type === 'int') {
          lines.push(`    ${field.name}: raw.${field.name} != null && Number.isFinite(Number(raw.${field.name})) ? Number(raw.${field.name}) : null,`)
        } else if (field.type === 'boolean') {
          lines.push(`    ${field.name}: raw.${field.name} != null ? Boolean(raw.${field.name}) : null,`)
        }
      }
    }
    lines.push('  }')
    lines.push('}')
    lines.push('')
  }

  return lines.join('\n')
}

function generateJsSupabaseContracts(schemaObj) {
  const lines = [
    '// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.',
    '// Source: shared/schema/domain.schema.json',
    '// Generator: scripts/generate-shared-contracts.mjs',
    '',
  ]

  const sections = [
    ['SUPABASE_TABLES', schemaObj.supabase.tables],
    ['SUPABASE_STORAGE_BUCKETS', schemaObj.supabase.storageBuckets],
    ['SUPABASE_EDGE_FUNCTIONS', schemaObj.supabase.edgeFunctions],
    ['SUPABASE_RPCS', schemaObj.supabase.rpcs],
  ]

  for (const [constName, entries] of sections) {
    lines.push(`export const ${constName} = Object.freeze({`)
    for (const [k, v] of Object.entries(entries)) {
      lines.push(`  ${k}: '${v}',`)
    }
    lines.push('})')
    lines.push('')
  }

  return lines.join('\n')
}

function toCamelCase(snake) {
  return snake.replace(/_([a-z])/g, (_, ch) => ch.toUpperCase())
}

function generateDartContracts(schemaObj) {
  const lines = [
    '// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.',
    '// Source: shared/schema/domain.schema.json',
    '// Generator: scripts/generate-shared-contracts.mjs',
    '',
    'class PreverTables {',
    '  const PreverTables._();',
  ]

  for (const [k, v] of Object.entries(schemaObj.supabase.tables)) {
    lines.push(`  static const String ${toCamelCase(k.toLowerCase())} = '${v}';`)
  }
  lines.push('}')
  lines.push('')

  lines.push('class PreverStorageBuckets {')
  lines.push('  const PreverStorageBuckets._();')
  for (const [k, v] of Object.entries(schemaObj.supabase.storageBuckets)) {
    lines.push(`  static const String ${toCamelCase(k.toLowerCase())} = '${v}';`)
  }
  lines.push('}')
  lines.push('')

  lines.push('class PreverEdgeFunctions {')
  lines.push('  const PreverEdgeFunctions._();')
  for (const [k, v] of Object.entries(schemaObj.supabase.edgeFunctions)) {
    lines.push(`  static const String ${toCamelCase(k.toLowerCase())} = '${v}';`)
  }
  lines.push('}')
  lines.push('')

  const af = schemaObj.constants.antifraudConfig
  lines.push('class PreverAntifraudConfig {')
  lines.push('  const PreverAntifraudConfig._();')
  lines.push(`  static const double minLegitimateScore = ${af.minLegitimateScore};`)
  lines.push(`  static const String modelName = '${af.modelName}';`)
  lines.push(`  static const String fallbackStatus = '${af.fallbackStatus}';`)
  lines.push('}')
  lines.push('')

  for (const [dtoName, dtoDef] of Object.entries(schemaObj.dtos)) {
    lines.push(`/// ${dtoDef.description}`)
    lines.push(`class ${dtoName} {`)
    for (const field of dtoDef.fields) {
      const dartType = mapDartType(field)
      lines.push(`  final ${dartType} ${toCamelCase(field.name)};`)
    }
    lines.push('')
    lines.push(`  const ${dtoName}({`)
    for (const field of dtoDef.fields) {
      const prop = toCamelCase(field.name)
      if (field.required) {
        lines.push(`    required this.${prop},`)
      } else {
        lines.push(`    this.${prop},`)
      }
    }
    lines.push('  });')
    lines.push('')
    lines.push(`  factory ${dtoName}.fromJson(Map<String, dynamic> json) {`)
    lines.push(`    return ${dtoName}(`)
    for (const field of dtoDef.fields) {
      const prop = toCamelCase(field.name)
      const k = field.name
      if (field.type === 'string') {
        if (field.required) {
          lines.push(`      ${prop}: json['${k}']?.toString() ?? ${field.default},`)
        } else {
          lines.push(`      ${prop}: json['${k}']?.toString(),`)
        }
      } else if (field.type === 'double') {
        if (field.required) {
          lines.push(`      ${prop}: (json['${k}'] as num?)?.toDouble() ?? ${field.default},`)
        } else {
          lines.push(`      ${prop}: (json['${k}'] as num?)?.toDouble(),`)
        }
      } else if (field.type === 'int') {
        if (field.required) {
          lines.push(`      ${prop}: (json['${k}'] as num?)?.toInt() ?? ${field.default},`)
        } else {
          lines.push(`      ${prop}: (json['${k}'] as num?)?.toInt(),`)
        }
      } else if (field.type === 'boolean') {
        if (field.required) {
          lines.push(`      ${prop}: (json['${k}'] as bool?) ?? ${field.default},`)
        } else {
          lines.push(`      ${prop}: json['${k}'] as bool?,`)
        }
      }
    }
    lines.push('    );')
    lines.push('  }')
    lines.push('')
    lines.push('  Map<String, dynamic> toJson() {')
    lines.push('    return <String, dynamic>{')
    for (const field of dtoDef.fields) {
      const prop = toCamelCase(field.name)
      lines.push(`      '${field.name}': ${prop},`)
    }
    lines.push('    };')
    lines.push('  }')
    lines.push('}')
    lines.push('')
  }

  return lines.join('\n')
}

const outputs = [
  {
    filePath: path.join(ROOT_DIR, 'shared', 'types', 'domain.d.ts'),
    content: generateTypeScriptDefinitions(schema),
  },
  {
    filePath: path.join(ROOT_DIR, 'shared', 'constants', 'domain.js'),
    content: generateJsDomainConstants(schema),
  },
  {
    filePath: path.join(ROOT_DIR, 'shared', 'services', 'supabaseContracts.js'),
    content: generateJsSupabaseContracts(schema),
  },
  {
    filePath: path.join(ROOT_DIR, 'mobile', 'lib', 'shared', 'prever_contracts.dart'),
    content: generateDartContracts(schema),
  },
]

const isCheckMode = process.argv.includes('--check')
let hasDrift = false

for (const out of outputs) {
  const relPath = path.relative(ROOT_DIR, out.filePath)
  if (isCheckMode) {
    if (!fs.existsSync(out.filePath)) {
      console.error(`[ERRO] Arquivo gerado ausente: ${relPath}`)
      hasDrift = true
      continue
    }
    const existing = fs.readFileSync(out.filePath, 'utf8').replace(/\r\n/g, '\n')
    const expected = out.content.replace(/\r\n/g, '\n')
    if (existing !== expected) {
      console.error(`[ERRO] Arquivo desatualizado em relação ao schema: ${relPath}`)
      hasDrift = true
    } else {
      console.log(`[OK] Contrato sincronizado: ${relPath}`)
    }
  } else {
    fs.mkdirSync(path.dirname(out.filePath), { recursive: true })
    fs.writeFileSync(out.filePath, out.content, 'utf8')
    console.log(`[GERADO] ${relPath}`)
  }
}

if (isCheckMode && hasDrift) {
  console.error('Execute `node scripts/generate-shared-contracts.mjs` para atualizar os contratos.')
  process.exit(1)
}
