import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ======================
/// Helpers de conversión
/// ======================
Color colorFromHex(String hex) {
  var sanitized = hex.trim();
  if (sanitized.startsWith('#')) {
    sanitized = sanitized.substring(1);
  }

  if (sanitized.length == 6) {
    sanitized = 'FF$sanitized';
  } else if (sanitized.length == 3) {
    final r = sanitized[0];
    final g = sanitized[1];
    final b = sanitized[2];
    sanitized = 'FF$r$r$g$g$b$b';
  }

  return Color(int.parse(sanitized, radix: 16));
}

String colorToHex(Color color) {
  final value = color.value.toRadixString(16).padLeft(8, '0');
  return '#${value.substring(2).toUpperCase()}';
}

String normalizarPuesto(String? puesto) {
  return puesto?.trim().toLowerCase() ?? '';
}

/// ======================
/// Cache en memoria
/// ======================
Future<Map<String, Color>>? _mapaColoresFuture;
Map<String, Color>? _mapaColoresCache;

/// Llama a esta función UNA VEZ al iniciar la app
/// (por ejemplo en main() o en el initState de la primera pantalla)
Future<void> inicializarColoresPuesto({bool forceRefresh = false}) async {
  await cargarMapaColoresPuesto(forceRefresh: forceRefresh);
}

/// Carga PlantillaPuesto y construye:
///   puesto (lowercase) -> Color
Future<Map<String, Color>> cargarMapaColoresPuesto({
  bool forceRefresh = false,
}) {
  if (!forceRefresh && _mapaColoresCache != null) {
    debugPrint('[ColoresPuesto] Usando cache existente');
    return Future.value(_mapaColoresCache);
  }

  if (!forceRefresh && _mapaColoresFuture != null) {
    debugPrint('[ColoresPuesto] Esperando future en curso');
    return _mapaColoresFuture!;
  }

  debugPrint('[ColoresPuesto] Cargando de Firestore...');

  _mapaColoresFuture = FirebaseFirestore.instance
      .collection('PlantillaPuesto') // 👈 nombre correcto
      .get()
      .then((snapshot) {
    final mapa = <String, Color>{};
    debugPrint(
        '[ColoresPuesto] Documentos obtenidos: ${snapshot.docs.length}');

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final puestoRaw = data['puesto'] as String?;
      final colorHex = data['colorHex'] as String?;

      final puestoNormalizado = normalizarPuesto(puestoRaw);

      debugPrint(
          '[ColoresPuesto] Doc ${doc.id} -> puestoRaw="$puestoRaw", normalizado="$puestoNormalizado", colorHex="$colorHex"');

      if (puestoNormalizado.isEmpty) {
        debugPrint(
            '[ColoresPuesto]   -> Saltado (puesto nulo o vacío)');
        continue;
      }

      try {
        final color = (colorHex == null || colorHex.trim().isEmpty)
            ? Colors.grey
            : colorFromHex(colorHex.trim());

        mapa[puestoNormalizado] = color;
        debugPrint(
            '[ColoresPuesto]   -> Guardado "$puestoNormalizado" = ${colorToHex(color)}');
      } catch (e, st) {
        debugPrint(
            '[ColoresPuesto]   -> ERROR parseando color "$colorHex": $e\n$st');
        mapa[puestoNormalizado] = Colors.grey;
      }
    }

    _mapaColoresCache = mapa;
    _mapaColoresFuture = null;

    debugPrint('[ColoresPuesto] Mapa final: '
        '${_mapaColoresCache!.map((k, v) => MapEntry(k, colorToHex(v)))}');

    return mapa;
  }).catchError((e, st) {
    debugPrint('[ColoresPuesto] ERROR leyendo PlantillaPuesto: $e\n$st');
    _mapaColoresFuture = null;
    _mapaColoresCache ??= {};
    return _mapaColoresCache!;
  });

  return _mapaColoresFuture!;
}

/// Limpia cache (por si editas colores en tiempo real)
void limpiarCacheColoresPuesto() {
  _mapaColoresCache = null;
  _mapaColoresFuture = null;
  debugPrint('[ColoresPuesto] Cache limpiada');
}

/// Devuelve el color para un puesto (ej: "Portero")
Color obtenerColorParaPuestoSync(String? puesto) {
  final puestoNormalizado = normalizarPuesto(puesto);
  if (puestoNormalizado.isEmpty) {
    return Colors.grey;
  }

  final color = _mapaColoresCache?[puestoNormalizado];
  if (color == null) {
    debugPrint(
        '[ColoresPuesto] Color NO encontrado para "$puestoNormalizado" -> gris');
    return Colors.grey;
  }
  debugPrint(
      '[ColoresPuesto] Color encontrado para "$puestoNormalizado" -> ${colorToHex(color)}');
  return color;
}

/// Devuelve el color para un jugador usando jugadorData['posicionAtaque']
Color obtenerColorParaJugadorSync(Map<String, dynamic> jugadorData) {
  final puesto =
      (jugadorData['posicionAtaque'] as String?) ??
      (jugadorData['posicion'] as String?);
  debugPrint(
      '[ColoresPuesto] obtenerColorParaJugadorSync -> posicionAtaque="$puesto"');
  return obtenerColorParaPuestoSync(puesto);
}

Future<Color> obtenerColorParaJugador(Map<String, dynamic> jugadorData) async {
  final mapa = await cargarMapaColoresPuesto();
  final puesto =
      (jugadorData['posicionAtaque'] as String?) ??
      (jugadorData['posicion'] as String?);
  final puestoNormalizado = normalizarPuesto(puesto);
  final color = mapa[puestoNormalizado] ?? Colors.grey;
  debugPrint(
      '[ColoresPuesto] obtenerColorParaJugador -> posicionAtaque="$puesto" (normalizado="$puestoNormalizado") => ${colorToHex(color)}');
  return color;
}
