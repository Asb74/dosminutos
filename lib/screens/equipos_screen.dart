import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import 'equipos_de_club_screen.dart';

class EquiposScreen extends StatelessWidget {
  const EquiposScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _clubesRef =>
      FirebaseFirestore.instance.collection('Clubes');

  Stream<QuerySnapshot<Map<String, dynamic>>> _clubesStream() {
    return _clubesRef.orderBy('apodo').snapshots();
  }

  void _abrirEquiposDeClub(BuildContext context, Club club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquiposDeClubScreen(club: club),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos por club'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona un club para gestionar sus equipos.',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _clubesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child:
                          Text('Error al cargar clubes: ${snapshot.error}'),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No hay clubes registrados.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final club = Club.fromDoc(docs[index].id, docs[index].data());
                      final detalles = <String>[
                        club.nombre,
                        if ((club.ciudad ?? '').trim().isNotEmpty)
                          'Ciudad: ${club.ciudad}',
                        if ((club.pabellon ?? '').trim().isNotEmpty)
                          'Pabellón: ${club.pabellon}',
                      ];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          onTap: () => _abrirEquiposDeClub(context, club),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          title: Text(
                            club.apodo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: detalles.isEmpty
                              ? null
                              : Text(detalles.join('  ·  ')),
                          trailing: IconButton(
                            icon: const Icon(Icons.groups),
                            tooltip: 'Ver equipos',
                            onPressed: () =>
                                _abrirEquiposDeClub(context, club),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
