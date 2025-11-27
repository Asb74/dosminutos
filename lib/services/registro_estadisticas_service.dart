import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> registrarEstadisticasDesdeAccion(
  String accion,
  String partidoId,
  String equipoIdPrincipal,
  int dorsalPrincipal,
  String? equipoIdSecundario,
  int? dorsalSecundario, {
  required String periodoActual,
  required int segundoActual,
  String? zonaSeleccionada,
}) async {
  final firestore = FirebaseFirestore.instance;
  final accionSnap =
      await firestore.collection('AccionEstadistica').doc(accion).get();

  final data = accionSnap.data();
  final principalCategorias = List<String>.from(
    (data != null && data['EstadisticaDorsalPrincipal'] is List)
        ? (data['EstadisticaDorsalPrincipal'] as List)
        : <String>[accion],
  );
  final secundarioCategorias = List<String>.from(
    (data != null && data['EstadisticaDorsalSecundario'] is List)
        ? (data['EstadisticaDorsalSecundario'] as List)
        : const <String>[],
  );

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
    required String categoria,
  }) {
    final docRef = statsRef.doc();
    batch.set(docRef, {
      'accion': accion,
      'categoria': categoria,
      'equipoId': equipoId,
      'dorsal': dorsal,
      'timestamp': FieldValue.serverTimestamp(),
      'periodo': periodoActual,
      'segundoPartido': segundoActual,
      'zona': zonaSeleccionada,
    });
  }

  for (final categoria in principalCategorias) {
    addStat(
      equipoId: equipoIdPrincipal,
      dorsal: dorsalPrincipal,
      categoria: categoria,
    );
  }

  if (registrarSecundario) {
    for (final categoria in secundarioCategorias) {
      addStat(
        equipoId: equipoIdSecundario!,
        dorsal: dorsalSecundario!,
        categoria: categoria,
      );
    }
  }

  await batch.commit();
}
