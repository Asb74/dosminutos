import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/evento_partido.dart';

class EventosService {
  static Future<void> addEvento(String partidoId, EventoPartido evento) async {
    final ref = FirebaseFirestore.instance
        .collection('Partidos')
        .doc(partidoId)
        .collection('Eventos')
        .doc(evento.id);

    await ref.set(evento.toMap());
  }

  static Stream<List<EventoPartido>> streamEventos(String partidoId) {
    return FirebaseFirestore.instance
        .collection('Partidos')
        .doc(partidoId)
        .collection('Eventos')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventoPartido.fromMap(doc.data()))
            .toList());
  }
}
