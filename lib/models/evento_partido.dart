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
  seisIzquierda,
  seisCentro,
  seisDerecha,
  nueveIzquierda,
  nueveCentro,
  nueveDerecha,
  sieteMetros,
  contraataque,
  contraataque2,
  lanzamientoLargo,
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
