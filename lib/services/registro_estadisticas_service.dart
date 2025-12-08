import 'package:cloud_firestore/cloud_firestore.dart';

/// Acciones que consideramos "sanciones" y que deben ir a la subcolección
/// `Sanciones` en lugar de `Estadisticas`.
const _accionesSancion = {
  '2 minutos',
  '2 minutos Provocado',
  'Tarjeta Amarilla',
  'Tarjeta Amarilla Provocado',
  'Tarjeta Roja',
  'Tarjeta Roja Provocado',
  'Tarjeta Azul',
  'Tarjeta Azul Provocado',
  'Amarilla',
  'Roja',
  'Azul',
};

/// Registra una acción de partido en Firestore.
///
/// - Si la acción es sanción (2', amarilla, roja, azul…) se guarda en
///   `ActaPartido/{actaPartidoId}/Sanciones`.
/// - El resto se guarda en `ActaPartido/{actaPartidoId}/Estadisticas`.
///
/// Parámetros obligatorios:
///   [actaPartidoId]  -> id del documento en `ActaPartido`
///   [equipoId]       -> id del equipo que realiza la acción
///   [dorsal]         -> dorsal del jugador principal
///   [categoria]      -> id de la categoría (Gol, Perdida, Gol Contra, …)
///   [accion]         -> nombre de la acción concreta (Gol, Gol Encajado, …)
///   [periodoActual]  -> "1º Tiempo", "2º Tiempo", "Prórroga", …
///   [segundoPartido] -> segundo exacto del partido (cuenta global)
///
/// Parámetros opcionales:
///   [zonaJuego]        -> zona del campo (L6D, C6C, 7M, …)
///   [zonaPorteria]     -> zona de portería (1A, 1B, …) sólo si aplica
///   [equipoIdSecundario], [dorsalSecundario] -> para asistencias, golpes prov.
Future<void> registrarAccionPartido({
  required String actaPartidoId,
  required String equipoId,
  required int dorsal,
  required String categoria,
  required String accion,
  required String periodoActual,
  required int segundoPartido,
  String? zonaJuego,
  String? zonaPorteria,
  String? equipoIdSecundario,
  int? dorsalSecundario,
}) async {
  final now = DateTime.now();
  final firestore = FirebaseFirestore.instance;

  // Construimos el payload común a todas las acciones
  final Map<String, dynamic> data = {
    'equipoId': equipoId,
    'dorsal': dorsal,
    'categoria': categoria,
    'accion': accion,
    'periodo': periodoActual,
    'segundoPartido': segundoPartido,
    'timestamp': Timestamp.fromDate(now),
  };

  // Zona de juego / portería (solo se añaden si tienen valor)
  if (zonaJuego != null && zonaJuego.isNotEmpty) {
    data['zona'] = zonaJuego;
    data['zonaJuego'] = zonaJuego;
  }
  if (zonaPorteria != null && zonaPorteria.isNotEmpty) {
    data['zonaPorteria'] = zonaPorteria;
  }

  // Dorsal secundario (asistencias, golpes provocados, etc.)
  if (equipoIdSecundario != null && equipoIdSecundario.isNotEmpty) {
    data['equipoIdSecundario'] = equipoIdSecundario;
  }
  if (dorsalSecundario != null) {
    data['dorsalSecundario'] = dorsalSecundario;
  }

  // Elegimos colección según sea sanción o acción de juego
  final String subcoleccion =
      _accionesSancion.contains(accion) || _accionesSancion.contains(categoria)
          ? 'Sanciones'
          : 'Estadisticas';

  await firestore
      .collection('ActaPartido')
      .doc(actaPartidoId)
      .collection(subcoleccion)
      .add(data);
}
