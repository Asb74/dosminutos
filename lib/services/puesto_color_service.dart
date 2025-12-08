import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

Future<Map<String, Color>>? _mapaColoresFuture;
Map<String, Color>? _mapaColoresCache;

Future<Map<String, Color>> cargarMapaColoresPuesto({bool forceRefresh = false}) {
  if (!forceRefresh && _mapaColoresCache != null) {
    return Future.value(_mapaColoresCache);
  }

  if (!forceRefresh && _mapaColoresFuture != null) {
    return _mapaColoresFuture!;
  }

  _mapaColoresFuture = FirebaseFirestore.instance
      .collection('PlantillaPuesto')
      .get()
      .then((snapshot) {
    final mapa = <String, Color>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final puestoRaw = data['puesto'] as String?;
      final colorHex = data['colorHex'] as String?;
      final puesto = puestoRaw?.trim().toLowerCase();

      if (puesto == null || puesto.isEmpty) continue;
      try {
        final color = colorHex == null
            ? Colors.grey
            : colorFromHex(colorHex.trim());
        mapa[puesto] = color;
      } catch (_) {
        mapa[puesto] = Colors.grey;
      }
    }
    _mapaColoresCache = mapa;
    _mapaColoresFuture = null;
    return mapa;
  });

  return _mapaColoresFuture!;
}

void limpiarCacheColoresPuesto() {
  _mapaColoresCache = null;
  _mapaColoresFuture = null;
}

Color obtenerColorParaPuestoSync(String? puesto) {
  final puestoNormalizado = puesto?.trim().toLowerCase();
  if (puestoNormalizado == null || puestoNormalizado.isEmpty) {
    return Colors.grey;
  }

  return _mapaColoresCache?[puestoNormalizado] ?? Colors.grey;
}

Color obtenerColorParaJugadorSync(Map<String, dynamic> jugadorData) {
  final puesto = jugadorData['posicionAtaque'] as String?;
  return obtenerColorParaPuestoSync(puesto);
}

// Ejemplo de uso:
// CircleAvatar(
//   backgroundColor: obtenerColorParaJugadorSync(jugadorData),
//   child: Text(jugadorData['dorsal'].toString()),
// )
