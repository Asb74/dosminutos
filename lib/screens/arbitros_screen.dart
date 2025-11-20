import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/arbitro.dart';

class ArbitrosScreen extends StatelessWidget {
  const ArbitrosScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _arbitrosRef =>
      FirebaseFirestore.instance.collection('Arbitros');

  static const List<String> _tipos = [
    'Principal',
    'Auxiliar',
    'Mesa',
  ];

  Future<void> _mostrarDialogo(BuildContext context, {Arbitro? arbitro}) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: arbitro?.nombre ?? '');
    final numeroLicenciaController =
        TextEditingController(text: arbitro?.numeroLicencia ?? '');
    final comiteController = TextEditingController(text: arbitro?.comite ?? '');
    final telefonoController = TextEditingController(text: arbitro?.telefono ?? '');
    final emailController = TextEditingController(text: arbitro?.email ?? '');
    final notasController = TextEditingController(text: arbitro?.notas ?? '');
    String? tipo = arbitro?.tipo ?? _tipos.first;
    bool activo = arbitro?.activo ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(arbitro == null ? 'Crear árbitro' : 'Editar árbitro'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: _tipos
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (value) => setState(() => tipo = value),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: numeroLicenciaController,
                        decoration:
                            const InputDecoration(labelText: 'Número de licencia (opcional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: comiteController,
                        decoration: const InputDecoration(labelText: 'Comité (opcional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email (opcional)'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: activo,
                        onChanged: (value) => setState(() => activo = value),
                        title: const Text('Activo'),
                      ),
                      TextFormField(
                        controller: notasController,
                        decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                        maxLines: 3,
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

                    final nuevoArbitro = Arbitro(
                      id: arbitro?.id ?? '',
                      nombre: nombreController.text.trim(),
                      tipo: tipo ?? _tipos.first,
                      numeroLicencia: numeroLicenciaController.text.trim().isEmpty
                          ? null
                          : numeroLicenciaController.text.trim(),
                      comite:
                          comiteController.text.trim().isEmpty ? null : comiteController.text.trim(),
                      telefono: telefonoController.text.trim().isEmpty
                          ? null
                          : telefonoController.text.trim(),
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                      activo: activo,
                      notas: notasController.text.trim().isEmpty
                          ? null
                          : notasController.text.trim(),
                    );

                    if (arbitro == null) {
                      await _arbitrosRef.add(nuevoArbitro.toMap());
                    } else {
                      await _arbitrosRef.doc(arbitro.id).update(nuevoArbitro.toMap());
                    }

                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text(arbitro == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, Arbitro arbitro) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar árbitro'),
        content: Text('¿Seguro que deseas eliminar "${arbitro.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _arbitrosRef.doc(arbitro.id).delete();
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
        title: const Text('Árbitros'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogo(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _arbitrosRef.orderBy('nombre').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar árbitros: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Aún no hay árbitros registrados.'));
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final arbitro = Arbitro.fromDoc(docs[index].id, docs[index].data());
                final subtitleParts = [
                  arbitro.tipo,
                  if ((arbitro.comite ?? '').trim().isNotEmpty) arbitro.comite!,
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
                      arbitro.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(subtitleParts.join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () => _mostrarDialogo(context, arbitro: arbitro),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarEliminar(context, arbitro),
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
