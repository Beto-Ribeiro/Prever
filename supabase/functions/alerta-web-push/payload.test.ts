import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mensagemFCM, normalizarCidade } from './payload.ts';

test('Destino é somente a cidade do alerta, independentemente dos acentos', () => {
  assert.equal(normalizarCidade(' São José dos Campos '), 'prever_cidade_sao-jose-dos-campos');
  assert.equal(normalizarCidade('SAO JOSE DOS CAMPOS'), normalizarCidade('Sa\u0303o Jose\u0301 dos Campos'));
  assert.notEqual(normalizarCidade('Jacareí'), normalizarCidade('Taubaté'));
  assert.throws(() => normalizarCidade(''));
});

test('Payload usa alta prioridade e não expõe campos privados', () => {
  const result = mensagemFCM({ alerta_id: '17', cidade: 'Jacareí',
    tipo: 'Alagamento', descricao: 'Evite a área.', severidade: 'Extrema' }, 3600);
  assert.equal(result.topic, 'prever_cidade_jacarei');
  assert.equal(result.android.notification.channel_id, 'prever_alertas_urgentes_v1');
  assert.equal(result.android.priority, 'HIGH');
  assert.equal(result.data.alerta_id, '17');
  assert.equal(result.apns.headers['apns-push-type'], 'alert');
  assert.equal(result.android.ttl, '3600s');
  assert.equal('alw_operador_id' in result.data, false);
});

test('Texto longo mantém tamanho compatível com FCM e Unicode válido', () => {
  const result = mensagemFCM({ alerta_id: '17', cidade: 'Jacareí',
    tipo: '🌧️'.repeat(200), descricao: 'Água 🌊 '.repeat(2000),
    bairro: 'a'.repeat(200), severidade: 'a'.repeat(200) }, 300);
  assert.ok(new TextEncoder().encode(JSON.stringify({ message: result })).length < 4096);
  assert.equal(result.data.descricao.includes('\uFFFD'), false);
  assert.throws(() => mensagemFCM({ alerta_id: '1', cidade: '', tipo: 'Chuva', descricao: 'Risco' }, 100));
});
