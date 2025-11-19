import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/equipo.dart';

class EquiposScreen extends StatelessWidget {
  const EquiposScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _equiposRef =>
      FirebaseFirestore.instance.collection('Equipos');

  Stream<QuerySnapshot<Map<String, dynamic>>> _equiposStream() {
    return _equiposRef.orderBy('nombre').snapshots();
  }

  Future<void> _showEquipoDialog(BuildContext context, {Equipo? equipo}) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: equipo?.nombre ?? '');
    final categoriaController =
        TextEditingController(text: equipo?.categoria ?? '');
    final clubController = TextEditingController(text: equipo?.club ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(equipo == null ? 'Crear equipo' : 'Editar equipo'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es requerido';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: categoriaController,
                    decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
                  ),
                  TextFormField(
                    controller: clubController,
                    decoration: const InputDecoration(labelText: 'Club (opcional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final nuevoEquipo = Equipo(
                  nombre: nombreController.text.trim(),
                  categoria: categoriaController.text.trim().isEmpty
                      ? null
                      : categoriaController.text.trim(),
                  club: clubController.text.trim().isEmpty
                      ? null
                      : clubController.text.trim(),
                  id: equipo?.id ?? '',
                );

                if (equipo == null) {
                  await _equiposRef.add(nuevoEquipo.toMap());
                } else {
                  await _equiposRef.doc(equipo.id).update(nuevoEquipo.toMap());
                }

                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text(equipo == null ? 'Crear' : 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Equipo equipo) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar equipo'),
        content: Text('¿Seguro que deseas eliminar "${equipo.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _equiposRef.doc(equipo.id).delete();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEquipoDialog(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
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
              return const Center(
                child: Text('Aún no hay equipos registrados.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final equipo = Equipo.fromDoc(doc.id, doc.data());
                final subtitleParts = [
                  if ((equipo.categoria ?? '').trim().isNotEmpty)
                    'Categoría: ${equipo.categoria}',
                  if ((equipo.club ?? '').trim().isNotEmpty)
                    'Club: ${equipo.club}',
                ];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(
                      equipo.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: subtitleParts.isEmpty
                        ? null
                        : Text(subtitleParts.join('  ·  ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () => _showEquipoDialog(
                            context,
                            equipo: equipo,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmDelete(context, equipo),
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
