import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Cache global de colores por puesto, usando la clave en minúsculas y sin espacios.
final Map<String, Color> _mapaColoresCache = <String, Color>{};

/// Convierte un string HEX ("#RRGGBB" o "#AARRGGBB") en un [Color].
Color colorFromHex(String hexString) {
  final String buffer = hexString.trim().replaceFirst('#', '');
  final String normalized =
      buffer.length == 6 ? 'FF$buffer' : buffer.padLeft(8, 'F');
  return Color(int.parse(normalized, radix: 16));
}

/// Convierte un [Color] a string HEX en formato `#AARRGGBB`.
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

String _normalizarPuesto(String puesto) => puesto.trim().toLowerCase();

/// Carga la colección `PlantillaPuesto` y actualiza el cache global.
Future<void> cargarMapaColoresPuesto() async {
  final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
      .instance
      .collection('PlantillaPuesto')
      .get();

  _mapaColoresCache
    ..clear()
    ..addEntries(snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final String puesto = _normalizarPuesto(doc.data()['puesto'] as String? ?? '');
      final String colorHex = (doc.data()['colorHex'] as String? ?? '#FF808080');
      return MapEntry<String, Color>(puesto, colorFromHex(colorHex));
    }));
}

/// Obtiene el color para un puesto desde el cache. Si no existe, devuelve gris.
Color obtenerColorParaPuestoSync(String puesto) {
  if (puesto.trim().isEmpty) {
    return Colors.grey;
  }
  final String clave = _normalizarPuesto(puesto);
  return _mapaColoresCache[clave] ?? Colors.grey;
}

/// Obtiene el color para un jugador usando `jugadorData['posicionAtaque']`.
Color obtenerColorParaJugadorSync(Map<String, dynamic> jugadorData) {
  final String puesto = (jugadorData['posicionAtaque'] as String? ?? '').trim();
  return obtenerColorParaPuestoSync(puesto);
}

/// Ejemplo de uso en un widget que pinta el dorsal con el color del puesto.
///
/// ```dart
/// class DorsalJugador extends StatefulWidget {
///   const DorsalJugador({super.key, required this.jugadorData});
///
///   final Map<String, dynamic> jugadorData;
///
///   @override
///   State<DorsalJugador> createState() => _DorsalJugadorState();
/// }
///
/// class _DorsalJugadorState extends State<DorsalJugador> {
///   @override
///   void initState() {
///     super.initState();
///     cargarMapaColoresPuesto();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     final Color colorDorsal = obtenerColorParaJugadorSync(widget.jugadorData);
///     final String dorsal = (widget.jugadorData['dorsal'] ?? '').toString();
///
///     return CircleAvatar(
///       radius: 20,
///       backgroundColor: colorDorsal,
///       child: Text(
///         dorsal,
///         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
///       ),
///     );
///   }
/// }
/// ```
