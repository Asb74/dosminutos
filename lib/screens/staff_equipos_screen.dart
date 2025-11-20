import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/equipo.dart';
import 'staff_equipo_screen.dart';

class StaffEquiposScreen extends StatelessWidget {
  const StaffEquiposScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _equiposRef =>
      FirebaseFirestore.instance.collection('Equipos');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff técnico – Equipos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _equiposRef.orderBy('nombre').snapshots(),
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
              return const Center(child: Text('No hay equipos registrados.'));
            }

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final equipo = Equipo.fromDoc(docs[index].id, docs[index].data());
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffEquipoScreen(
                        equipoId: equipo.id,
                        equipoNombre: equipo.nombre,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          child: const Icon(Icons.group),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          equipo.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${equipo.categoria} · ${equipo.sexo}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.75),
                          ),
                        ),
                      ],
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
