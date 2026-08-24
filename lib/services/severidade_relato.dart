enum SeveridadeRelato { leve, moderada, severa, desconhecida }

/// Aceita os rótulos atuais do cadastro e as variações de relatos antigos.
SeveridadeRelato identificarSeveridade(String? descricao) {
  final texto = (descricao ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('í', 'i')
      .replaceAll('\u0301', '');
  if (RegExp(r'\b(sever[ao]|critic[ao]|extrem[ao])\b').hasMatch(texto)) {
    return SeveridadeRelato.severa;
  }
  if (RegExp(r'\bmoderad[ao]\b').hasMatch(texto)) {
    return SeveridadeRelato.moderada;
  }
  if (RegExp(r'\bleve\b').hasMatch(texto)) {
    return SeveridadeRelato.leve;
  }
  return SeveridadeRelato.desconhecida;
}
