export interface AlertaPublico {
  alerta_id: string;
  tipo: string;
  cidade: string;
  bairro?: string;
  severidade?: string;
  descricao: string;
}

// Mesma normalização de lib/models/cidade_alertas.dart.
export function normalizarCidade(cidade: string): string {
  const slug = cidade.trim().toLowerCase().normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  if (slug.length < 2 || slug.length > 120) throw new Error('Cidade inválida');
  return `prever_cidade_${slug}`;
}

function limitarBytes(value: unknown, max: number): string {
  let text = '';
  let bytes = 0;
  for (const char of String(value ?? '').trim()) {
    bytes += new TextEncoder().encode(char).length;
    if (bytes > max) break;
    text += char;
  }
  return text;
}

export function mensagemFCM(alerta: AlertaPublico, validadeSegundos: number) {
  if (!alerta.alerta_id || !alerta.descricao?.trim() || !alerta.tipo?.trim()) {
    throw new Error('Alerta sem identificação, tipo ou descrição');
  }
  const titulo = limitarBytes(`Prever: ${alerta.tipo}`, 160);
  const descricao = limitarBytes(alerta.descricao, 800);
  const data = {
    kind: 'alerta_web', alerta_id: limitarBytes(alerta.alerta_id, 100), titulo,
    descricao, cidade: limitarBytes(alerta.cidade, 240),
    bairro: limitarBytes(alerta.bairro, 120), severidade: limitarBytes(alerta.severidade, 60),
  };
  return {
    topic: normalizarCidade(alerta.cidade),
    notification: { title: titulo, body: descricao },
    data,
    android: {
      priority: 'HIGH', ttl: `${Math.max(0, Math.floor(validadeSegundos))}s`,
      notification: {
        channel_id: 'prever_alertas_urgentes_v1', icon: 'ic_stat_alerta',
        sound: 'default', tag: `alerta_${data.alerta_id}`,
        notification_priority: 'PRIORITY_HIGH', visibility: 'PUBLIC',
        default_vibrate_timings: true,
      },
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert',
        'apns-expiration': String(Math.floor(Date.now() / 1000) + Math.floor(validadeSegundos)) },
      payload: { aps: { sound: 'default' } },
    },
  };
}
