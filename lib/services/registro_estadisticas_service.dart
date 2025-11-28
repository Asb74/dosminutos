import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> registrarEstadisticasDesdeAccion(
  String categoria,
  String partidoId,
  String equipoIdPrincipal,
  int dorsalPrincipal,
  String? equipoIdSecundario,
  int? dorsalSecundario, {
  required String periodoActual,
  required int segundoActual,
  required String zonaDeJuego,
  String? zonaPorteria,
}) async {
  final firestore = FirebaseFirestore.instance;
  final accionSnap =
      await firestore.collection('AccionEstadistica').doc(categoria).get();

  final data = accionSnap.data();
  final textoPrincipal =
      data != null && data['EstadisticaDorsalPrincipal'] is String
          ? data['EstadisticaDorsalPrincipal'] as String
          : categoria;
  final textoSecundario =
      data != null && data['EstadisticaDorsalSecundario'] is String
          ? data['EstadisticaDorsalSecundario'] as String
          : categoria;

  final statsRef = firestore
      .collection('ActaPartido')
      .doc(partidoId)
      .collection('Estadisticas');

  final registrarSecundario = equipoIdSecundario != null &&
      dorsalSecundario != null &&
      equipoIdSecundario != equipoIdPrincipal;

  final batch = firestore.batch();

  void addStat({
    required String equipoId,
    required int dorsal,
    required String accion,
  }) {
    final docRef = statsRef.doc();
    final data = <String, dynamic>{
      'accion': accion,
      'categoria': categoria,
      'equipoId': equipoId,
      'dorsal': dorsal,
      'timestamp': FieldValue.serverTimestamp(),
      'periodo': periodoActual,
      'segundoPartido': segundoActual,
      'zonaJuego': zonaDeJuego,
      'zona': zonaDeJuego,
    };

    if (zonaPorteria != null) {
      data['zonaPorteria'] = zonaPorteria;
    }

    batch.set(docRef, data);
  }

  addStat(
    equipoId: equipoIdPrincipal,
    dorsal: dorsalPrincipal,
    accion: textoPrincipal,
  );

  // Log principal stat creation
  // ignore: avoid_print
  print(
      'Estadística principal -> categoría: $categoria, accion: $textoPrincipal, dorsal: $dorsalPrincipal, equipoId: $equipoIdPrincipal, zonaJuego: $zonaDeJuego, zonaPorteria: $zonaPorteria');

  if (registrarSecundario) {
    addStat(
      equipoId: equipoIdSecundario!,
      dorsal: dorsalSecundario!,
      accion: textoSecundario,
    );

    // Log secondary stat creation
    // ignore: avoid_print
    print(
        'Estadística secundaria -> categoría: $categoria, accion: $textoSecundario, dorsal: $dorsalSecundario, equipoId: $equipoIdSecundario, zonaJuego: $zonaDeJuego, zonaPorteria: $zonaPorteria');
  }

  await batch.commit();
}
