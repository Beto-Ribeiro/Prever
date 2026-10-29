import test from 'node:test'
import assert from 'node:assert/strict'
import {
  SEVERITY_LEVELS,
  SEVERITY_VISUAL_TOKENS,
  SHELTER_STATUSES,
  ANTIFRAUD_CONFIG,
  createPerfilUsuarioDto,
  createOcorrenciaRelatoDto,
  createAbrigoEmergenciaDto,
  createAlertaDefesaCivilDto,
} from '../../shared/constants/domain.js'
import {
  SUPABASE_TABLES,
  SUPABASE_STORAGE_BUCKETS,
  SUPABASE_EDGE_FUNCTIONS,
  SUPABASE_RPCS,
} from '../../shared/services/supabaseContracts.js'
import {
  onlyDigits,
  isValidEmail,
  isValidCoordinate,
  matchesSosCpfConfirmation,
  calculateHaversineDistanceKm,
} from '../../shared/utils/validators.js'

test('contratos compartilhados: constantes de severidade, antifraude e Supabase estão íntegras', () => {
  assert.equal(SEVERITY_LEVELS.CRITICO, 'Crítico')
  assert.equal(SEVERITY_VISUAL_TOKENS['Crítico'].radiusMeters, 3000)
  assert.equal(SHELTER_STATUSES.LOTADO, 'lotado')
  assert.equal(ANTIFRAUD_CONFIG.MIN_LEGITIMATE_SCORE, 0.8)
  assert.equal(SUPABASE_TABLES.RELATOS, 'relatos')
  assert.equal(SUPABASE_STORAGE_BUCKETS.FOTOS_RELATOS, 'fotos_relatos')
  assert.equal(SUPABASE_EDGE_FUNCTIONS.SMDN_AI, 'smdn-ai')
  assert.equal(SUPABASE_RPCS.ADMIN_UPDATE_USER_PROFILE, 'admin_update_user_profile')
})

test('contratos compartilhados: factories de DTO normalizam campos obrigatórios e opcionais', () => {
  const perfil = createPerfilUsuarioDto({
    prf_id: 123,
    prf_nome: 'Operador Defesa Civil',
    prf_tipo: 'defesa_civil',
    prf_acesso_web: 1,
  })
  assert.equal(perfil.prf_id, '123')
  assert.equal(perfil.prf_nome, 'Operador Defesa Civil')
  assert.equal(perfil.prf_acesso_web, true)
  assert.equal(perfil.prf_admin_web, false)
  assert.equal(perfil.prf_cpf, null)

  const relato = createOcorrenciaRelatoDto({
    rel_id: 42,
    prf_id: 'u-1',
    rel_tipo: 'Alagamento',
    rel_latitude: '-23.5505',
    rel_longitude: '-46.6333',
    rel_score_antifraude: '0.92',
  })
  assert.equal(relato.rel_id, '42')
  assert.equal(relato.rel_gravidade, 'Moderado')
  assert.equal(relato.rel_latitude, -23.5505)
  assert.equal(relato.rel_score_antifraude, 0.92)

  const abrigo = createAbrigoEmergenciaDto({
    abr_id: 'abr-1',
    abr_nome: 'Ginásio Municipal',
    abr_capacidade: '120',
    abr_ocupacao: '45',
  })
  assert.equal(abrigo.abr_capacidade, 120)
  assert.equal(abrigo.abr_ocupacao, 45)
  assert.equal(abrigo.abr_status, 'disponivel')

  const alerta = createAlertaDefesaCivilDto({
    ale_id: 'ale-1',
    ale_titulo: 'Chuva Forte',
    ale_mensagem: 'Evite áreas alagadas',
  })
  assert.equal(alerta.ale_severidade, 'Moderado')
  assert.equal(alerta.ale_ativo, true)
})

test('contratos compartilhados: validadores geodésicos e de confirmação SOS', () => {
  assert.equal(onlyDigits('123.456.789-00'), '12345678900')
  assert.equal(isValidEmail('agente@defesacivil.gov.br'), true)
  assert.equal(isValidCoordinate(-23.5505, -46.6333), true)
  assert.equal(isValidCoordinate(0, 0), false)
  assert.equal(matchesSosCpfConfirmation('123.456.789-00', '123'), true)
  assert.equal(matchesSosCpfConfirmation('123.456.789-00', '12345678900'), true)
  assert.equal(matchesSosCpfConfirmation('123.456.789-00', '999'), false)

  const dist = calculateHaversineDistanceKm(-23.5505, -46.6333, -23.5614, -46.6559)
  assert.ok(dist > 2 && dist < 3)
})
