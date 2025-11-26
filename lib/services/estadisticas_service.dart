import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerStats {
  final String equipoId;
  final int dorsal;

  // ATAQUE
  int lanzamientos = 0;
  int goles = 0;
  int lanzamientos7m = 0;
  int goles7m = 0;
  int lanzamientosFallados = 0;
  int lanzamientosDetenidosPorPortero = 0;
  int lanzamientosBloqueadosSufridos = 0;

  // PORTERO / DEFENSA
  int lanzamientosRecibidos = 0;
  int golesEncajados = 0;
  int paradas = 0;
  int bloqueosHechos = 0;
  int perdidas = 0;
  int recuperaciones = 0;

  // FALTAS / SANCIONES (estadísticas, no el SancionEstado de partido_en_juego)
  int faltasCometidas = 0;
  int faltasRecibidas = 0;

  int suspensiones2Min = 0;
  int tarjetasAmarillas = 0;
  int tarjetasRojas = 0;
  int tarjetasAzules = 0;

  PlayerStats({
    required this.equipoId,
    required this.dorsal,
  });

  double get porcentajeAcierto {
    if (lanzamientos == 0) return 0;
    return goles / lanzamientos;
  }
}

class PartidoStats {
  /// clave: '$equipoId#$dorsal'
  final Map<String, PlayerStats> porJugador;

  PartidoStats(this.porJugador);

  PlayerStats getOrCreatePlayer(String equipoId, int dorsal) {
    final key = _playerKey(equipoId, dorsal);
    return porJugador.putIfAbsent(key, () => PlayerStats(equipoId: equipoId, dorsal: dorsal));
  }

  static String _playerKey(String equipoId, int dorsal) => '$equipoId#$dorsal';

  /// Devuelve todos los jugadores de un equipo concreto.
  Iterable<PlayerStats> jugadoresDeEquipo(String equipoId) {
    return porJugador.values.where((p) => p.equipoId == equipoId);
  }

  /// Suma simple de estadísticas por equipo (para resúmenes).
  PlayerStats resumenEquipo(String equipoId) {
    final resumen = PlayerStats(equipoId: equipoId, dorsal: -1);
    for (final p in jugadoresDeEquipo(equipoId)) {
      resumen.lanzamientos += p.lanzamientos;
      resumen.goles += p.goles;
      resumen.lanzamientos7m += p.lanzamientos7m;
      resumen.goles7m += p.goles7m;
      resumen.lanzamientosFallados += p.lanzamientosFallados;
      resumen.lanzamientosDetenidosPorPortero += p.lanzamientosDetenidosPorPortero;
      resumen.lanzamientosBloqueadosSufridos += p.lanzamientosBloqueadosSufridos;
      resumen.lanzamientosRecibidos += p.lanzamientosRecibidos;
      resumen.golesEncajados += p.golesEncajados;
      resumen.paradas += p.paradas;
      resumen.bloqueosHechos += p.bloqueosHechos;
      resumen.perdidas += p.perdidas;
      resumen.recuperaciones += p.recuperaciones;
      resumen.faltasCometidas += p.faltasCometidas;
      resumen.faltasRecibidas += p.faltasRecibidas;
      resumen.suspensiones2Min += p.suspensiones2Min;
      resumen.tarjetasAmarillas += p.tarjetasAmarillas;
      resumen.tarjetasRojas += p.tarjetasRojas;
      resumen.tarjetasAzules += p.tarjetasAzules;
    }
    return resumen;
  }
}

PartidoStats calcularEstadisticasPartidoDesdeSnapshots({
  required QuerySnapshot<Map<String, dynamic>> datosSnapshot,
  required QuerySnapshot<Map<String, dynamic>> sancionesSnapshot,
}) {
  final mapa = <String, PlayerStats>{};
  final stats = PartidoStats(mapa);

  // 1) Procesar DATOS (acciones)
  for (final doc in datosSnapshot.docs) {
    final data = doc.data();
    final String? equipoPrincipalId = data['equipoPrincipal'] as String?;
    final int? dorsalPrincipal = (data['dorsalPrincipal'] as num?)?.toInt();
    final String? equipoSecundarioId = data['equipoSecundario'] as String?;
    final int? dorsalSecundario = (data['dorsalSecundario'] as num?)?.toInt();
    final String? accion = data['accion'] as String?;
    final String? zonaCampo = data['zonaCampo'] as String?;
    // final String? zonaPorteria = data['zonaPorteria'] as String?; // se puede usar en el futuro

    if (equipoPrincipalId == null || dorsalPrincipal == null || accion == null) {
      continue;
    }

    final p = stats.getOrCreatePlayer(equipoPrincipalId, dorsalPrincipal);
    PlayerStats? s;
    if (equipoSecundarioId != null && dorsalSecundario != null) {
      s = stats.getOrCreatePlayer(equipoSecundarioId, dorsalSecundario);
    }

    // MATRIZ DE ACCIONES (principal / secundario)

    switch (accion) {
      /// ATAQUE
      case 'Gol':
        // Principal (atacante)
        p.lanzamientos++;
        p.goles++;
        if (zonaCampo == '7M') {
          p.lanzamientos7m++;
          p.goles7m++;
        }
        // Secundario (portero rival)
        if (s != null) {
          s.lanzamientosRecibidos++;
          s.golesEncajados++;
        }
        break;

      case 'Gol Contra':
        // Lo tratamos como gol del principal y gol encajado del portero rival
        p.lanzamientos++;
        p.goles++;
        if (zonaCampo == '7M') {
          p.lanzamientos7m++;
          p.goles7m++;
        }
        if (s != null) {
          s.lanzamientosRecibidos++;
          s.golesEncajados++;
        }
        break;

      case 'Fallo':
        // Principal
        p.lanzamientos++;
        p.lanzamientosFallados++;
        if (zonaCampo == '7M') {
          p.lanzamientos7m++;
        }
        // Por ahora no tocamos al portero secundario en fallo
        break;

      case 'Parada':
        // Principal (atacante)
        p.lanzamientos++;
        p.lanzamientosDetenidosPorPortero++;
        if (zonaCampo == '7M') {
          p.lanzamientos7m++;
        }
        // Secundario (portero)
        if (s != null) {
          s.lanzamientosRecibidos++;
          s.paradas++;
        }
        break;

      case 'Bloqueo':
        // Principal (atacante que sufre el bloqueo)
        p.lanzamientos++;
        p.lanzamientosBloqueadosSufridos++;
        // Secundario (defensor que bloquea)
        if (s != null) {
          s.bloqueosHechos++;
        }
        break;

      case 'Perdida':
        // Principal (atacante que pierde el balón)
        p.perdidas++;
        // Secundario (defensor que recupera)
        if (s != null) {
          s.recuperaciones++;
        }
        break;

      case 'Pasivo':
        // Lo contamos como pérdida de equipo para el principal
        p.perdidas++;
        break;

      case 'Línea':
        // Pisar área: también lo contamos como pérdida
        p.perdidas++;
        break;

      /// DEFENSA (principal = defensor, secundario = atacante que la sufre)
      case 'Golpe':
        p.faltasCometidas++;
        if (s != null) {
          s.faltasRecibidas++;
        }
        break;

      case '2 minutos':
        p.faltasCometidas++;
        p.suspensiones2Min++;
        if (s != null) {
          s.faltasRecibidas++;
        }
        break;

      case 'Tarjeta Amarilla':
        p.tarjetasAmarillas++;
        // opcional: s?.faltasRecibidas++;
        break;

      case 'Tarjeta Roja':
        p.tarjetasRojas++;
        break;

      case 'Tarjeta Azul':
        p.tarjetasAzules++;
        break;

      default:
        // Otras acciones que puedan aparecer en el futuro
        break;
    }
  }

  // 2) Procesar SANCIONES para asegurarnos de que stats y sanciones van alineados
  for (final doc in sancionesSnapshot.docs) {
    final data = doc.data();
    final String? equipoId = data['equipoId'] as String?;
    final int? dorsal = (data['dorsal'] as num?)?.toInt();
    final String? tipo = data['tipo'] as String?;

    if (equipoId == null || dorsal == null || tipo == null) continue;

    final p = stats.getOrCreatePlayer(equipoId, dorsal);

    switch (tipo) {
      case '2min':
        p.suspensiones2Min++;
        break;
      case 'amarilla':
        p.tarjetasAmarillas++;
        break;
      case 'roja':
        p.tarjetasRojas++;
        break;
      case 'azul':
        p.tarjetasAzules++;
        break;
    }
  }

  return stats;
}
