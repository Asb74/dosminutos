import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';

class ClubesScreen extends StatelessWidget {
  const ClubesScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _clubesRef =>
      FirebaseFirestore.instance.collection('Clubes');

  Stream<QuerySnapshot<Map<String, dynamic>>> _clubesStream() {
    return _clubesRef.orderBy('apodo').snapshots();
  }

  Future<int> _obtenerSiguienteIdClub() async {
    final contadoresRef =
        FirebaseFirestore.instance.collection('Contadores').doc('clubes');

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

  Future<void> _mostrarDialogoClub(BuildContext context, {Club? club}) async {
    final formKey = GlobalKey<FormState>();

    final apodoController = TextEditingController(text: club?.apodo ?? '');
    final nombreController = TextEditingController(text: club?.nombre ?? '');
    final escudoController = TextEditingController(text: club?.escudo ?? '');
    final ciudadController = TextEditingController(text: club?.ciudad ?? '');
    final provinciaController =
        TextEditingController(text: club?.provincia ?? '');
    final paisController = TextEditingController(text: club?.pais ?? '');
    final pabellonController =
        TextEditingController(text: club?.pabellon ?? '');
    final colorPrimarioController =
        TextEditingController(text: club?.colorPrimario ?? '');
    final colorSecundarioController =
        TextEditingController(text: club?.colorSecundario ?? '');
    final telefonoController =
        TextEditingController(text: club?.telefonoContacto ?? '');
    final emailController =
        TextEditingController(text: club?.emailContacto ?? '');
    final webController = TextEditingController(text: club?.web ?? '');
    final notasController = TextEditingController(text: club?.notas ?? '');
    bool activo = club?.activo ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(club == null ? 'Crear club' : 'Editar club'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: apodoController,
                        decoration: const InputDecoration(labelText: 'Apodo'),
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El apodo es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nombreController,
                        decoration:
                            const InputDecoration(labelText: 'Nombre oficial'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: escudoController,
                        decoration: const InputDecoration(
                          labelText: 'Escudo (archivo PNG)',
                          helperText: 'Ejemplo: 001.png o idClub.png',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El escudo es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ciudadController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: provinciaController,
                        decoration:
                            const InputDecoration(labelText: 'Provincia'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: paisController,
                        decoration: const InputDecoration(labelText: 'País'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pabellonController,
                        decoration: const InputDecoration(labelText: 'Pabellón'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: colorPrimarioController,
                        decoration: const InputDecoration(labelText: 'Color primario'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: colorSecundarioController,
                        decoration:
                            const InputDecoration(labelText: 'Color secundario'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telefonoController,
                        decoration:
                            const InputDecoration(labelText: 'Teléfono de contacto'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration:
                            const InputDecoration(labelText: 'Email de contacto'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: webController,
                        decoration: const InputDecoration(labelText: 'Web'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notasController,
                        decoration: const InputDecoration(labelText: 'Notas'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        value: activo,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        activeColor: colorScheme.primary,
                        onChanged: (value) {
                          setState(() => activo = value);
                        },
                      ),
                    ],
                  );
                },
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

                final datos = {
                  'apodo': apodoController.text.trim(),
                  'nombre': nombreController.text.trim(),
                  'escudo': escudoController.text.trim(),
                  'ciudad': ciudadController.text.trim().isEmpty
                      ? null
                      : ciudadController.text.trim(),
                  'provincia': provinciaController.text.trim().isEmpty
                      ? null
                      : provinciaController.text.trim(),
                  'pais': paisController.text.trim().isEmpty
                      ? null
                      : paisController.text.trim(),
                  'pabellon': pabellonController.text.trim().isEmpty
                      ? null
                      : pabellonController.text.trim(),
                  'colorPrimario': colorPrimarioController.text.trim().isEmpty
                      ? null
                      : colorPrimarioController.text.trim(),
                  'colorSecundario': colorSecundarioController.text.trim().isEmpty
                      ? null
                      : colorSecundarioController.text.trim(),
                  'telefonoContacto': telefonoController.text.trim().isEmpty
                      ? null
                      : telefonoController.text.trim(),
                  'emailContacto': emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                  'web': webController.text.trim().isEmpty
                      ? null
                      : webController.text.trim(),
                  'notas': notasController.text.trim().isEmpty
                      ? null
                      : notasController.text.trim(),
                  'activo': activo,
                };

                if (club == null) {
                  final nuevoIdClub = await _obtenerSiguienteIdClub();
                  await _clubesRef.add({
                    ...datos,
                    'idClub': nuevoIdClub,
                  });
                } else {
                  await _clubesRef.doc(club.id).update(datos);
                }

                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(club == null ? 'Crear' : 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmarEliminarClub(BuildContext context, Club club) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar club'),
        content: Text('¿Seguro que deseas eliminar "${club.apodo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _clubesRef.doc(club.id).delete();
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
        title: const Text('Clubes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoClub(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _clubesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar clubes: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text('No hay clubes. Pulsa + para crear el primero.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final club = Club.fromDoc(doc.id, doc.data());

                final details = <String>[
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(
                      club.apodo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: details.isEmpty
                        ? null
                        : Text(details.join('  ·  ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () => _mostrarDialogoClub(
                            context,
                            club: club,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarEliminarClub(
                            context,
                            club,
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
