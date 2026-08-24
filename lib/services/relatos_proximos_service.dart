import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatoProximo {
  final String tipo;
  final String descricao;
  final double distanciaMetros;
  final String? id;
  final double? latitude;
  final double? longitude;

  const RelatoProximo(
    this.tipo,
    this.descricao,
    this.distanciaMetros, {
    this.id,
    this.latitude,
    this.longitude,
  });
}

/// Usa as coordenadas da mesma view utilizada pelo mapa de alertas.
List<RelatoProximo> filtrarRelatosProximos(
  List<Map<String, dynamic>> dados,
  double latitude,
  double longitude, {
  double raioMetros = 3000,
}) {
  final relatos = <RelatoProximo>[];
  for (final item in dados) {
    final lat = double.tryParse('${item['latitude']}');
    final lon = double.tryParse('${item['longitude']}');
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        item['rel_tipo_desastre'] == 'SOS') {
      continue;
    }
    final distancia = Geolocator.distanceBetween(latitude, longitude, lat, lon);
    if (distancia <= raioMetros) {
      relatos.add(
        RelatoProximo(
          item['rel_tipo_desastre']?.toString() ?? 'Relato',
          item['rel_descricao']?.toString() ?? '',
          distancia,
          id: item['rel_id']?.toString(),
          latitude: lat,
          longitude: lon,
        ),
      );
    }
  }
  relatos.sort((a, b) => a.distanciaMetros.compareTo(b.distanciaMetros));
  return relatos;
}

class LocalizacaoIndisponivel implements Exception {
  final String mensagem;
  const LocalizacaoIndisponivel(this.mensagem);
}

Future<String?> carregarFotoRelato(String id) async {
  final storage = Supabase.instance.client.storage.from('Fotos_Storage');
  final pasta = 'relatos/$id';
  final arquivos = await storage
      .list(path: pasta)
      .timeout(const Duration(seconds: 15));
  if (arquivos.isEmpty) return null;
  return storage
      .createSignedUrl('$pasta/${arquivos.first.name}', 3600)
      .timeout(const Duration(seconds: 15));
}

Future<List<RelatoProximo>> carregarRelatosProximos() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocalizacaoIndisponivel(
      'Ative a localização do dispositivo e toque em atualizar.',
    );
  }
  // A tela principal já solicita permissão. Evita dois pedidos simultâneos.
  final permissao = await Geolocator.checkPermission();
  if (permissao != LocationPermission.always &&
      permissao != LocationPermission.whileInUse) {
    throw const LocalizacaoIndisponivel(
      'Permita o acesso à localização nas configurações e toque em atualizar.',
    );
  }
  final posicao = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  final dados = <Map<String, dynamic>>[];
  // Pagina para não omitir relatos próximos após o limite padrão do servidor.
  const tamanhoPagina = 500;
  for (var inicio = 0; ; inicio += tamanhoPagina) {
    final pagina = await Supabase.instance.client
        .from('relatos_mapa')
        .select('rel_id, rel_tipo_desastre, rel_descricao, latitude, longitude')
        .neq('rel_tipo_desastre', 'SOS')
        .order('rel_id')
        .range(inicio, inicio + tamanhoPagina - 1)
        .timeout(const Duration(seconds: 15));
    dados.addAll(pagina);
    if (pagina.length < tamanhoPagina) break;
  }
  return filtrarRelatosProximos(dados, posicao.latitude, posicao.longitude);
}
