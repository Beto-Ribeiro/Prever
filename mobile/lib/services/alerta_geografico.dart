import 'dart:math' as math;

const raioNotificacaoMetros = 20000.0;
const raioTerraMetros = 6371008.8;

bool coordenadasValidas(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;

/// Distância de grande círculo; também funciona ao cruzar o antimeridiano.
double distanciaEntreCoordenadas(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  if (!coordenadasValidas(latitudeA, longitudeA) ||
      !coordenadasValidas(latitudeB, longitudeB)) {
    return double.infinity;
  }
  const radianos = math.pi / 180;
  final dLat = (latitudeB - latitudeA) * radianos;
  final dLon = (longitudeB - longitudeA) * radianos;
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(latitudeA * radianos) *
          math.cos(latitudeB * radianos) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * raioTerraMetros * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

bool estaNoRaioDoAlerta(
  double latitudeCelular,
  double longitudeCelular,
  double latitudeAlerta,
  double longitudeAlerta,
) =>
    distanciaEntreCoordenadas(
      latitudeCelular,
      longitudeCelular,
      latitudeAlerta,
      longitudeAlerta,
      // Um micrômetro absorve apenas o arredondamento do ponto flutuante na borda.
    ) <=
    raioNotificacaoMetros + 1e-6;

class AlertaGeografico {
  const AlertaGeografico({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.titulo,
    required this.descricao,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String titulo;
  final String descricao;

  static AlertaGeografico? deMensagem(Map<String, dynamic> dados) {
    if (dados['tipo'] != 'alerta_web') return null;
    final id = dados['alerta_id'];
    final latitude = double.tryParse('${dados['latitude']}');
    final longitude = double.tryParse('${dados['longitude']}');
    if (id is! String ||
        id.trim().isEmpty ||
        latitude == null ||
        longitude == null ||
        !coordenadasValidas(latitude, longitude)) {
      return null;
    }
    return AlertaGeografico(
      id: id,
      latitude: latitude,
      longitude: longitude,
      titulo: dados['titulo']?.toString() ?? 'Alerta próximo de você',
      descricao: dados['descricao']?.toString() ?? '',
    );
  }
}
