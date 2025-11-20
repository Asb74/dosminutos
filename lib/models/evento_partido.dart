enum TipoAccion {
  gol,
  lanzamiento,
  parada,
  falta,
  faltaSancionada,
  exclusion2min,
  amarilla,
  roja,
  azul,
  perdida,
  robo,
  bloqueo,
  asistencia,
  tiempoMuerto,
  cambio,
}

enum FaseJuego {
  ataque,
  defensa,
}

enum ZonaJuego {
  // 6 metros
  seisED, // 6ED - extremo derecho
  seisLD, // 6LD - lateral derecho
  seisC, // 6C  - central
  seisLE, // 6LE - lateral izquierdo
  seisEE, // 6EE - extremo izquierdo

  // 8 metros (segunda línea)
  ochoD, // 8D
  ochoC, // 8C
  ochoE, // 8E

  // 9 metros
  nueveD, // 9D
  nueveC, // 9C
  nueveE, // 9E
}

extension ZonaJuegoExt on ZonaJuego {
  String get label {
    switch (this) {
      case ZonaJuego.seisED:
        return '6ED';
      case ZonaJuego.seisLD:
        return '6LD';
      case ZonaJuego.seisC:
        return '6C';
      case ZonaJuego.seisLE:
        return '6LE';
      case ZonaJuego.seisEE:
        return '6EE';
      case ZonaJuego.ochoD:
        return '8D';
      case ZonaJuego.ochoC:
        return '8C';
      case ZonaJuego.ochoE:
        return '8E';
      case ZonaJuego.nueveD:
        return '9D';
      case ZonaJuego.nueveC:
        return '9C';
      case ZonaJuego.nueveE:
        return '9E';
    }
  }
}

class EventoPartido {
  final String id; // ID del evento
  final DateTime timestamp; // Momento real
  final int periodo; // 1, 2, prórroga
  final int segundoPartido; // segundo exacto del reloj interno

  final String equipoId; // local o visitante (idEquipo)
  final String? jugadorId; // null si es evento de equipo

  final TipoAccion tipoAccion;
  final FaseJuego fase;
  final ZonaJuego? zona;

  final String? resultado; // texto opcional (gol/poste/parada/etc.)
  final bool esPenalty;
  final String? nota;

  EventoPartido({
    required this.id,
    required this.timestamp,
    required this.periodo,
    required this.segundoPartido,
    required this.equipoId,
    required this.jugadorId,
    required this.tipoAccion,
    required this.fase,
    required this.zona,
    required this.resultado,
    required this.esPenalty,
    required this.nota,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'periodo': periodo,
      'segundoPartido': segundoPartido,
      'equipoId': equipoId,
      'jugadorId': jugadorId,
      'tipoAccion': tipoAccion.name,
      'fase': fase.name,
      'zona': zona?.name,
      'resultado': resultado,
      'esPenalty': esPenalty,
      'nota': nota,
    };
  }

  factory EventoPartido.fromMap(Map<String, dynamic> map) {
    return EventoPartido(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      periodo: map['periodo'],
      segundoPartido: map['segundoPartido'],
      equipoId: map['equipoId'],
      jugadorId: map['jugadorId'],
      tipoAccion: TipoAccion.values.byName(map['tipoAccion']),
      fase: FaseJuego.values.byName(map['fase']),
      zona: map['zona'] != null ? ZonaJuego.values.byName(map['zona']) : null,
      resultado: map['resultado'],
      esPenalty: map['esPenalty'] ?? false,
      nota: map['nota'],
    );
  }
}
