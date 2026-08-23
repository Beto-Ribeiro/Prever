import 'package:flutter/material.dart';

// Mapeia a condição climática para um ícone adequado.
//
// Prioridade:
// 1) Se tiver o código numérico da condição (campo "id" da API OpenWeatherMap,
//    ex: 200-232 tempestade, 500-531 chuva, 800 céu limpo, etc.) usa ele,
//    que é muito mais confiável do que tentar interpretar texto.
// 2) Se tiver o código do ícone da API (ex: "01d", "10n") usa o sufixo
//    "d"/"n" para diferenciar dia/noite no caso de céu limpo.
// 3) Se nada disso estiver disponível (ex: dados de exemplo/mock), cai no
//    fallback por palavras-chave na descrição em português.
IconData iconeParaClima({String? icone, String? id, String? descricao}) {
  final bool isNoite = icone != null && icone.endsWith('n');
  final int? codigo = id != null && id.isNotEmpty ? int.tryParse(id) : null;

  String familia;

  if (codigo != null) {
    if (codigo >= 200 && codigo <= 232) {
      familia = 'tempestade';
    } else if (codigo >= 300 && codigo <= 321) {
      familia = 'garoa';
    } else if (codigo >= 500 && codigo <= 531) {
      familia = 'chuva';
    } else if (codigo >= 600 && codigo <= 622) {
      familia = 'neve';
    } else if (codigo >= 701 && codigo <= 781) {
      familia = 'atmosfera'; // névoa, neblina, fumaça, poeira, etc.
    } else if (codigo == 800) {
      familia = 'limpo';
    } else if (codigo >= 801 && codigo <= 804) {
      familia = 'nublado';
    } else {
      familia = 'nublado';
    }
  } else {
    // Fallback por texto (usado, por exemplo, na previsão de exemplo/mock).
    final texto = (descricao ?? '').toLowerCase();
    if (texto.contains('trovoada') || texto.contains('tempestade')) {
      familia = 'tempestade';
    } else if (texto.contains('garoa')) {
      familia = 'garoa';
    } else if (texto.contains('chuva')) {
      familia = 'chuva';
    } else if (texto.contains('neve')) {
      familia = 'neve';
    } else if (texto.contains('neblina') ||
        texto.contains('névoa') ||
        texto.contains('nevoa') ||
        texto.contains('bruma') ||
        texto.contains('fumaça') ||
        texto.contains('fumaca') ||
        texto.contains('poeira')) {
      familia = 'atmosfera';
    } else if (texto.contains('limpo') ||
        texto.contains('sol') ||
        texto.contains('ensolarado')) {
      familia = 'limpo';
    } else {
      familia = 'nublado';
    }
  }

  switch (familia) {
    case 'tempestade':
      return Icons.flash_on;
    case 'garoa':
      return Icons.grain;
    case 'chuva':
      return Icons.water_drop;
    case 'neve':
      return Icons.ac_unit;
    case 'atmosfera':
      return Icons.cloud;
    case 'limpo':
      return isNoite ? Icons.nights_stay : Icons.wb_sunny_outlined;
    case 'nublado':
    default:
      return Icons.cloud_outlined;
  }
}
