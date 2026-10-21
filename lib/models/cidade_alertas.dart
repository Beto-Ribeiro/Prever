/// Deve permanecer idêntica a normalizarCidade em supabase/functions/alerta-web-push/payload.ts.
String topicoDaCidade(String cidade) {
  var normalizada = cidade.trim().toLowerCase();
  const grupos = {
    'a': 'áàâãä',
    'e': 'éèêë',
    'i': 'íìîï',
    'o': 'óòôõö',
    'u': 'úùûü',
    'c': 'ç',
    'n': 'ñ',
  };
  for (final grupo in grupos.entries) {
    for (final letra in grupo.value.split('')) {
      normalizada = normalizada.replaceAll(letra, grupo.key);
    }
  }
  normalizada = normalizada
      .replaceAll(RegExp('[\u0300-\u036f]'), '')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalizada.length < 2 || normalizada.length > 120) {
    throw const FormatException('Informe um nome de cidade válido.');
  }
  return 'prever_cidade_$normalizada';
}
