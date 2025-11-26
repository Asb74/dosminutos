import 'package:cloud_firestore/cloud_firestore.dart';

enum ZonaTiro { seis, ocho, nueve, siete, otra }

ZonaTiro clasificarZona(String? zonaCampo) {
  switch (zonaCampo) {
    case '7M':
      return ZonaTiro.siete;
    case 'E6D':
    case 'L6D':
    case 'C6C':
    case 'L6I':
    case 'E6I':
      return ZonaTiro.seis;
    case 'L8D':
    case 'C8C':
    case 'L8I':
      return ZonaTiro.ocho;
    case 'L9D':
    case 'C9C':
    case 'L9I':
      return ZonaTiro.nueve;
    default:
      return ZonaTiro.otra;
  }
}

class StatsJugador {
  final String equipoId;
  final int dorsal;
  String? nombre;
  bool esPortero;

  int segsJugados = 0;

  // Tiro general
  int lanzamientosTotales = 0;
  int golesTotales = 0;

  // Por zona
  int lanzamientos6m = 0;
  int goles6m = 0;
  int lanzamientos8m = 0;
  int goles8m = 0;
  int lanzamientos9m = 0;
  int goles9m = 0;
  int lanzamientos7m = 0;
  int goles7m = 0;

  // Pérdidas / recuperaciones
  int perdidas = 0;
  int recuperaciones = 0;

  // Faltas y disciplina
  int golpesCometidos = 0;
  int golpesProvocados = 0;
  int exclusiones2m = 0;
  int amarillas = 0;
  int rojas = 0;
  int azules = 0;

  // Porteros
  int paradas = 0;
  int golesEncajados = 0;
  int lanzamientosRecibidos = 0;

  StatsJugador({
    required this.equipoId,
    required this.dorsal,
    this.nombre,
    this.esPortero = false,
  });
}

class ResumenEquipo {
  int lanzamientosTotales = 0;
  int golesTotales = 0;
  int lanzamientos7m = 0;
  int goles7m = 0;
  int perdidas = 0;
  int recuperaciones = 0;
  int exclusiones2m = 0;
  int amarillas = 0;
  int rojas = 0;
  int azules = 0;

  double get porcentajeAcierto =>
      lanzamientosTotales == 0 ? 0 : golesTotales / lanzamientosTotales;
}

class PartidoStats {
  final Map<String, StatsJugador> porJugador;

  PartidoStats(this.porJugador);

  StatsJugador obtenerStatsJugador(String equipoId, int dorsal) {
    final key = _playerKey(equipoId, dorsal);
    return porJugador.putIfAbsent(
      key,
      () => StatsJugador(
        equipoId: equipoId,
        dorsal: dorsal,
      ),
    );
  }

  static String _playerKey(String equipoId, int dorsal) => '$equipoId#$dorsal';

  Iterable<StatsJugador> jugadoresDeEquipo(String equipoId) {
    return porJugador.values.where((p) => p.equipoId == equipoId);
  }

  ResumenEquipo resumenEquipo(String equipoId) {
    final resumen = ResumenEquipo();
    for (final p in jugadoresDeEquipo(equipoId)) {
      resumen.lanzamientosTotales += p.lanzamientosTotales;
      resumen.golesTotales += p.golesTotales;
      resumen.lanzamientos7m += p.lanzamientos7m;
      resumen.goles7m += p.goles7m;
      resumen.perdidas += p.perdidas;
      resumen.recuperaciones += p.recuperaciones;
      resumen.exclusiones2m += p.exclusiones2m;
      resumen.amarillas += p.amarillas;
      resumen.rojas += p.rojas;
      resumen.azules += p.azules;
    }
    return resumen;
  }
}

PartidoStats calcularEstadisticasPartidoDesdeSnapshots({
  required Map<String, dynamic> partidoData,
  required QuerySnapshot<Map<String, dynamic>> datosSnapshot,
  required QuerySnapshot<Map<String, dynamic>> sancionesSnapshot,
}) {
  final mapa = <String, StatsJugador>{};
  final stats = PartidoStats(mapa);

  final equipoLocalId = partidoData['equipoLocalId'] as String?;
  final equipoVisitanteId = partidoData['equipoVisitanteId'] as String?;

  Map<int, Map<String, dynamic>> _mapearConvocados(List<dynamic>? lista) {
    final mapaConvocados = <int, Map<String, dynamic>>{};
    for (final raw in lista ?? []) {
      if (raw is Map<String, dynamic>) {
        final dorsal = (raw['dorsal'] as num?)?.toInt();
        if (dorsal != null) {
          mapaConvocados[dorsal] = raw;
        }
      }
    }
    return mapaConvocados;
  }

  final convocadosPorEquipo = <String, Map<int, Map<String, dynamic>>>{};
  if (equipoLocalId != null) {
    convocadosPorEquipo[equipoLocalId] =
        _mapearConvocados(partidoData['convocadosLocal'] as List<dynamic>?);
  }
  if (equipoVisitanteId != null) {
    convocadosPorEquipo[equipoVisitanteId] =
        _mapearConvocados(partidoData['convocadosVisitante'] as List<dynamic>?);
  }

  StatsJugador obtenerStatsJugador(String equipoId, int dorsal) {
    final statsJugador = stats.obtenerStatsJugador(equipoId, dorsal);
    final infoEquipo = convocadosPorEquipo[equipoId];
    final infoJugador = infoEquipo?[dorsal];
    if (infoJugador != null) {
      statsJugador.nombre ??= infoJugador['nombre'] as String?;
      final posicion = (infoJugador['posicion'] as String?)?.toLowerCase() ?? '';
      if (posicion.contains('portero')) {
        statsJugador.esPortero = true;
      }
    }
    return statsJugador;
  }

  for (final doc in datosSnapshot.docs) {
    final data = doc.data();
    final String? equipoPrincipalId = data['equipoPrincipal'] as String?;
    final int? dorsalPrincipal = (data['dorsalPrincipal'] as num?)?.toInt();
    final String? equipoSecundarioId = data['equipoSecundario'] as String?;
    final int? dorsalSecundario = (data['dorsalSecundario'] as num?)?.toInt();
    final String? accion = data['accion'] as String?;
    final String? zonaCampo = data['zonaCampo'] as String?;
    final zona = clasificarZona(zonaCampo);

    StatsJugador? pj;
    StatsJugador? sj;

    if (equipoPrincipalId != null && dorsalPrincipal != null) {
      pj = obtenerStatsJugador(equipoPrincipalId, dorsalPrincipal);
    }
    if (equipoSecundarioId != null && dorsalSecundario != null) {
      sj = obtenerStatsJugador(equipoSecundarioId, dorsalSecundario);
    }

    if (pj == null || accion == null) continue;

    final bool esLanzamiento =
        accion == 'Gol' || accion == 'Gol Contra' || accion == 'Fallo' ||
            accion == 'Parada' || accion == 'Bloqueo';

    if (esLanzamiento) {
      pj.lanzamientosTotales++;

      void cuentaZona(bool esGol) {
        switch (zona) {
          case ZonaTiro.seis:
            pj!.lanzamientos6m++;
            if (esGol) pj.goles6m++;
            break;
          case ZonaTiro.ocho:
            pj!.lanzamientos8m++;
            if (esGol) pj.goles8m++;
            break;
          case ZonaTiro.nueve:
            pj!.lanzamientos9m++;
            if (esGol) pj.goles9m++;
            break;
          case ZonaTiro.siete:
            pj!.lanzamientos7m++;
            if (esGol) pj.goles7m++;
            break;
          default:
            break;
        }
      }

      if (accion == 'Gol' || accion == 'Gol Contra') {
        pj.golesTotales++;
        cuentaZona(true);
      } else {
        cuentaZona(false);
      }
    }

    if (sj != null &&
        (accion == 'Gol' || accion == 'Gol Contra' || accion == 'Parada')) {
      sj.lanzamientosRecibidos++;
      if (accion == 'Parada') {
        sj.paradas++;
      } else {
        sj.golesEncajados++;
      }
    }

    if (accion == 'Perdida') {
      pj.perdidas++;
    } else if (accion == 'Recuperación') {
      pj.recuperaciones++;
    }

    if (accion == 'Golpe') {
      pj.golpesCometidos++;
      if (sj != null) sj.golpesProvocados++;
    }

    if (accion == '2 minutos') {
      pj.exclusiones2m++;
    }
    if (accion == 'Tarjeta Amarilla') {
      pj.amarillas++;
    }
    if (accion == 'Tarjeta Roja') {
      pj.rojas++;
    }
    if (accion == 'Tarjeta Azul') {
      pj.azules++;
    }
  }

  for (final doc in sancionesSnapshot.docs) {
    final data = doc.data();
    final String? equipoId = data['equipoId'] as String?;
    final int? dorsal = (data['dorsal'] as num?)?.toInt();
    final String? tipo = data['tipo'] as String?;

    if (equipoId == null || dorsal == null || tipo == null) continue;

    final p = obtenerStatsJugador(equipoId, dorsal);

    switch (tipo) {
      case '2min':
        p.exclusiones2m++;
        break;
      case 'amarilla':
        p.amarillas++;
        break;
      case 'roja':
        p.rojas++;
        break;
      case 'azul':
        p.azules++;
        break;
    }
  }

  final tiemposJugados = (partidoData['tiemposJugados'] as Map<String, dynamic>?);
  if (tiemposJugados != null) {
    tiemposJugados.forEach((key, value) {
      final statsJugador = mapa[key];
      if (statsJugador != null) {
        statsJugador.segsJugados = (value as num).toInt();
      }
    });
  }

  return stats;
}
