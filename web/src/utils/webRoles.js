const ROLE_LABELS = {
  admin: 'Administrador',
  employee: 'Funcionário',
  institution: 'Instituição',
  citizen: 'Cidadão',
  unknown: 'Sem perfil web',
}

export function normalizeRole(value) {
  const role = String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')

  if (!role) return 'unknown'

  if (['admin', 'adm', 'administrador', 'administradora', 'gestor', 'gestora'].includes(role)) {
    return 'admin'
  }

  if (
    [
      'funcionario',
      'funcionaria',
      'agente',
      'operador',
      'operadora',
      'bombeiro',
      'bombeiros',
      'samu',
      'saude',
      'seguranca',
      'defesa civil',
      'defesacivil',
    ].includes(role)
  ) {
    return 'employee'
  }

  if (['instituicao', 'instituicao publica', 'orgao', 'orgao publico'].includes(role)) {
    return 'institution'
  }

  if (['cidadao', 'cidada', 'usuario mobile', 'mobile'].includes(role)) {
    return 'citizen'
  }

  return 'unknown'
}

export function getRoleLabel(role) {
  return ROLE_LABELS[normalizeRole(role)] || ROLE_LABELS.unknown
}

// Regra do PREVER:
// - Sem perfil e Cidadão não acessam o painel web.
// - Funcionário, Instituição e Administrador acessam o sistema web.
export function canAccessWeb(role) {
  return ['admin', 'employee', 'institution'].includes(normalizeRole(role))
}

// Só Administrador abre Administração/Painel do Admin/Lista de Usuários.
// A permissão "admin" do JSON não deve liberar esse acesso sozinha.
export function canAccessAdmin(role) {
  return normalizeRole(role) === 'admin'
}
