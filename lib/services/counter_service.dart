import 'package:cloud_firestore/cloud_firestore.dart';

class CounterService {
  static Future<int> obtenerSiguienteId(String contador) async {
    final contadoresRef =
        FirebaseFirestore.instance.collection('Contadores').doc(contador);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(contadoresRef);
      int ultimoId = 0;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        ultimoId = (data?['ultimoId'] as num?)?.toInt() ?? 0;
      } else {
        transaction.set(contadoresRef, {'ultimoId': 0});
      }

      final nuevoId = ultimoId + 1;
      transaction.set(contadoresRef, {'ultimoId': nuevoId});
      return nuevoId;
    });
  }
}
