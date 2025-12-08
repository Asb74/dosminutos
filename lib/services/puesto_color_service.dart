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
///  puesto (lowercase, sin espacios) -> Color
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
      .collection('PlantillaPuesto')
      .get()
      .then((snapshot) {
    final mapa = <String, Color>{};
    debugPrint(
        '[ColoresPuesto] Documentos obtenidos: ${snapshot.docs.length}');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final puestoRaw = data['puesto'] as String?;
      final colorHex = data['colorHex'] as String?;

      final puestoNormalizado = puestoRaw?.trim().toLowerCase();

      debugPrint(
          '[ColoresPuesto] Doc ${doc.id} -> puestoRaw="$puestoRaw", normalizado="$puestoNormalizado", colorHex="$colorHex"');

      if (puestoNormalizado == null || puestoNormalizado.isEmpty) {
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
  final puestoNormalizado = puesto?.trim().toLowerCase();
  if (puestoNormalizado == null || puestoNormalizado.isEmpty) {
    return Colors.grey;
  }

  final color = _mapaColoresCache?[puestoNormalizado];
  if (color == null) {
    debugPrint(
        '[ColoresPuesto] Color NO encontrado para "$puestoNormalizado" -> gris');
  }
  return color ?? Colors.grey;
}

/// Devuelve el color para un jugador usando jugadorData['posicionAtaque']
Color obtenerColorParaJugadorSync(Map<String, dynamic> jugadorData) {
  final puesto = jugadorData['posicionAtaque'] as String?;
  debugPrint(
      '[ColoresPuesto] obtenerColorParaJugadorSync -> posicionAtaque="$puesto"');
  return obtenerColorParaPuestoSync(puesto);
}
