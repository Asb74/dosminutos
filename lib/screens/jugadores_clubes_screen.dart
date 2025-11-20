import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../widgets/navigation_card_button.dart';
import 'jugadores_equipos_screen.dart';

class JugadoresClubesScreen extends StatelessWidget {
  const JugadoresClubesScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _clubesRef =>
      FirebaseFirestore.instance.collection('Clubes');

  Stream<QuerySnapshot<Map<String, dynamic>>> _clubesStream() {
    return _clubesRef.orderBy('apodo').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jugadores – Clubes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona un club para gestionar sus jugadores.',
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

                      final subtitleParts = <String>[
                        club.nombre,
                        if ((club.ciudad ?? '').trim().isNotEmpty)
                          'Ciudad: ${club.ciudad}',
                      ];

                      return NavigationCardButton(
                        icon: Icons.groups,
                        title: club.apodo,
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : '${subtitleParts.join(' · ')}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JugadoresEquiposScreen(club: club),
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
