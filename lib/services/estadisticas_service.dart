import 'package:cloud_firestore/cloud_firestore.dart';

enum ZonaTiro { seis, ocho, nueve, siete, otra }

const List<String> ordenStatsJugador = [
  'Gol',
  'Gol 6m',
  'Gol 8m',
  'Gol 9m',
  'Gol 7m',
  'Linea',
  'Perdida Posesión',
  'Recuperación Posesión',
  'Golpe cometido',
  'Golpe provocado',
  'Asistencia',
  '2 minutos',
  'Tarjeta Amarilla',
  'Tarjeta Roja',
  'Tarjeta Azul',
  'Parada',
  'Gol Encajado',
];

class MapeoAccionEstadistica {
  final String estadisticaPrincipal;
  final String estadisticaSecundaria;

  const MapeoAccionEstadistica(
    this.estadisticaPrincipal,
    this.estadisticaSecundaria,
  );
}

Future<Map<String, MapeoAccionEstadistica>>? _mapaAccionesFuture;

Future<Map<String, MapeoAccionEstadistica>> cargarMapaAccionesEstadistica() {
  _mapaAccionesFuture ??=
      FirebaseFirestore.instance.collection('AccionEstadistica').get().then(
    (snapshot) {
      final mapa = <String, MapeoAccionEstadistica>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final principal = (data['EstadisticaDorsalPrincipal'] as String?) ??
            doc.id;
        final secundaria = (data['EstadisticaDorsalSecundario'] as String?) ??
            doc.id;
        mapa[doc.id] = MapeoAccionEstadistica(principal, secundaria);
      }
      return mapa;
    },
  );

  return _mapaAccionesFuture!;
}

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

  Map<String, int> contadores = {};

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
  int lanzamientos6m = 0;
  int goles6m = 0;
  int lanzamientos8m = 0;
  int goles8m = 0;
  int lanzamientos9m = 0;
  int goles9m = 0;
  int lanzamientos7m = 0;
  int goles7m = 0;
  int perdidas = 0;
  int recuperaciones = 0;
  int exclusiones2m = 0;
  int amarillas = 0;
  int rojas = 0;
  int azules = 0;
  Map<String, int> contadores = {};

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
      resumen.lanzamientos6m += p.lanzamientos6m;
      resumen.goles6m += p.goles6m;
      resumen.lanzamientos8m += p.lanzamientos8m;
      resumen.goles8m += p.goles8m;
      resumen.lanzamientos9m += p.lanzamientos9m;
      resumen.goles9m += p.goles9m;
      resumen.lanzamientos7m += p.lanzamientos7m;
      resumen.goles7m += p.goles7m;
      resumen.perdidas += p.perdidas;
      resumen.recuperaciones += p.recuperaciones;
      resumen.exclusiones2m += p.exclusiones2m;
      resumen.amarillas += p.amarillas;
      resumen.rojas += p.rojas;
      resumen.azules += p.azules;
      p.contadores.forEach((key, value) {
        resumen.contadores[key] = (resumen.contadores[key] ?? 0) + value;
      });
    }
    return resumen;
  }
}

Future<PartidoStats> calcularEstadisticasPartidoDesdeSnapshots({
  required Map<String, dynamic> partidoData,
  required QuerySnapshot<Map<String, dynamic>> datosSnapshot,
  required QuerySnapshot<Map<String, dynamic>> sancionesSnapshot,
}) async {
  final mapa = <String, StatsJugador>{};
  final stats = PartidoStats(mapa);
  final mapaAcciones = await cargarMapaAccionesEstadistica();

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

  void incrementarContador(StatsJugador jugador, String? clave) {
    if (clave == null || clave.isEmpty) return;
    jugador.contadores[clave] = (jugador.contadores[clave] ?? 0) + 1;
  }

  const accionesSancion = {
    '2 minutos',
    'Tarjeta Amarilla',
    'Tarjeta Roja',
    'Tarjeta Azul',
    'Amarilla',
    'Roja',
    'Azul',
  };

  // ============================
  // 1) ESTADÍSTICAS DE JUEGO
  // ============================
  for (final doc in datosSnapshot.docs) {
    final data = doc.data();
    final String? equipoId = data['equipoId'] as String?;
    final int? dorsal = (data['dorsal'] as num?)?.toInt();
    final String? categoria = data['categoria'] as String?;
    final String? accionRaw = data['accion'] as String?;
    final String? zonaCampo = data['zona'] as String?;
    final zona = clasificarZona(zonaCampo);

    if (equipoId == null || dorsal == null || categoria == null) continue;

    if ((accionRaw ?? '').toLowerCase().contains('provoc')) continue;

    // Resolvemos la ACCIÓN REAL de la jugada
    String nombreAccion = accionRaw?.trim() ?? '';
    if (nombreAccion.isEmpty) {
      final mapeo = mapaAcciones[categoria];
      nombreAccion = mapeo?.estadisticaPrincipal ?? categoria;
    }

    // Si la acción es una sanción, la tratamos sólo en sancionesSnapshot
    if (accionesSancion.contains(categoria) ||
        accionesSancion.contains(nombreAccion)) {
      continue;
    }

    final jugador = obtenerStatsJugador(equipoId, dorsal);

    // Guardamos el contador genérico por nombreAccion para la UI
    incrementarContador(jugador, nombreAccion);

    // Helper interno para tiros por zona
    void cuentaZona(bool esGol) {
      switch (zona) {
        case ZonaTiro.seis:
          jugador.lanzamientos6m++;
          if (esGol) jugador.goles6m++;
          jugador.contadores['Lanzamiento 6m'] =
              (jugador.contadores['Lanzamiento 6m'] ?? 0) + 1;
          if (esGol) {
            jugador.contadores['Gol 6m'] =
                (jugador.contadores['Gol 6m'] ?? 0) + 1;
          }
          break;
        case ZonaTiro.ocho:
          jugador.lanzamientos8m++;
          if (esGol) jugador.goles8m++;
          jugador.contadores['Lanzamiento 8m'] =
              (jugador.contadores['Lanzamiento 8m'] ?? 0) + 1;
          if (esGol) {
            jugador.contadores['Gol 8m'] =
                (jugador.contadores['Gol 8m'] ?? 0) + 1;
          }
          break;
        case ZonaTiro.nueve:
          jugador.lanzamientos9m++;
          if (esGol) jugador.goles9m++;
          jugador.contadores['Lanzamiento 9m'] =
              (jugador.contadores['Lanzamiento 9m'] ?? 0) + 1;
          if (esGol) {
            jugador.contadores['Gol 9m'] =
                (jugador.contadores['Gol 9m'] ?? 0) + 1;
          }
          break;
        case ZonaTiro.siete:
          jugador.lanzamientos7m++;
          if (esGol) jugador.goles7m++;
          jugador.contadores['Lanzamiento 7m'] =
              (jugador.contadores['Lanzamiento 7m'] ?? 0) + 1;
          if (esGol) {
            jugador.contadores['Gol 7m'] =
                (jugador.contadores['Gol 7m'] ?? 0) + 1;
          }
          break;
        default:
          break;
      }
    }

    // --- Clasificación según la ACCIÓN real ---
    switch (nombreAccion) {
      // Lanzamientos del jugador de campo
      case 'Gol':
        jugador.lanzamientosTotales++;
        jugador.golesTotales++;
        cuentaZona(true);
        break;

      case 'Error Lanzamiento':
      case 'Lanzamiento Bloqueado':
        jugador.lanzamientosTotales++;
        cuentaZona(false);
        break;

      // Porteros
      case 'Gol Encajado':
        jugador.lanzamientosRecibidos++;
        jugador.golesEncajados++;
        break;

      case 'Parada':
        jugador.lanzamientosRecibidos++;
        jugador.paradas++;
        break;

      case 'Lanzamiento Recibido':
        jugador.lanzamientosRecibidos++;
        break;

      // Gestión de posesión
      case 'Perdida Posesión':
        jugador.perdidas++;
        break;

      case 'Recuperación Posesión':
        jugador.recuperaciones++;
        break;

      // Faltas
      case 'Golpe cometido':
        jugador.golpesCometidos++;
        break;

      case 'Golpe provocado':
        jugador.golpesProvocados++;
        break;

      // Asistencia: sólo contador genérico (ya sumado)
      case 'Asistencia':
        break;

      default:
        // Otras acciones: "Linea", "Pasivo", etc.
        // Si desde el maestro "Linea" mapea a "Recuperación Posesión"
        // ya queda recogido por el case anterior.
        break;
    }
  }

  // ============================
  // 2) SANCIONES
  // ============================
  for (final doc in sancionesSnapshot.docs) {
    final data = doc.data();
    final String? equipoId = data['equipoId'] as String?;
    final int? dorsal = (data['dorsal'] as num?)?.toInt();
    final String? accion =
        (data['accion'] as String?) ?? (data['tipo'] as String?);

    if (equipoId == null || dorsal == null || accion == null) continue;

    if (accion.toLowerCase().contains('provoc')) continue;

    final jugador = obtenerStatsJugador(equipoId, dorsal);

    switch (accion) {
      case '2 minutos':
        jugador.exclusiones2m++;
        incrementarContador(jugador, '2 minutos');
        break;
      case 'Tarjeta Amarilla':
      case 'Amarilla':
        jugador.amarillas++;
        incrementarContador(jugador, 'Tarjeta Amarilla');
        break;
      case 'Tarjeta Roja':
      case 'Roja':
        jugador.rojas++;
        incrementarContador(jugador, 'Tarjeta Roja');
        break;
      case 'Tarjeta Azul':
      case 'Azul':
        jugador.azules++;
        incrementarContador(jugador, 'Tarjeta Azul');
        break;
    }
  }

  // ============================
  // 3) TIEMPOS JUGADOS
  // ============================
  final tiemposJugados =
      (partidoData['tiemposJugados'] as Map<String, dynamic>?);
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
