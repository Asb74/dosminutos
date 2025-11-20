import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/equipo.dart';
import '../widgets/navigation_card_button.dart';
import 'jugadores_equipo_screen.dart';

class JugadoresEquiposScreen extends StatelessWidget {
  const JugadoresEquiposScreen({super.key, required this.club});

  final Club club;

  CollectionReference<Map<String, dynamic>> get _equiposRef =>
      FirebaseFirestore.instance.collection('Equipos');

  Stream<QuerySnapshot<Map<String, dynamic>>> _equiposStream() {
    return _equiposRef
        .where('clubId', isEqualTo: club.id)
        .orderBy('nombre')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Jugadores – ${club.apodo.isNotEmpty ? club.apodo : 'Club'}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _equiposStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar equipos: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text('No hay equipos registrados para este club.'));
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final equipo = Equipo.fromDoc(docs[index].id, docs[index].data());
                final subtitleParts = <String>[
                  if (equipo.categoria.trim().isNotEmpty)
                    'Categoría: ${equipo.categoria}',
                  if (equipo.sexo.trim().isNotEmpty) 'Sexo: ${equipo.sexo}',
                ];

                return NavigationCardButton(
                  icon: Icons.group,
                  title: equipo.nombre,
                  subtitle:
                      subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JugadoresEquipoScreen(
                        equipoId: equipo.id,
                        equipoNombre: equipo.nombre,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
