import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/temporada.dart';

class TemporadasScreen extends StatelessWidget {
  const TemporadasScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _temporadasRef =>
      FirebaseFirestore.instance.collection('Temporadas');

  Future<void> _mostrarDialogo(BuildContext context, {Temporada? temporada}) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: temporada?.nombre ?? '');
    final categoriaController = TextEditingController(text: temporada?.categoria ?? '');
    final ordenController =
        TextEditingController(text: temporada?.orden.toString() ?? '0');
    final descripcionController =
        TextEditingController(text: temporada?.descripcion ?? '');
    DateTime? fechaInicio = temporada?.fechaInicio;
    DateTime? fechaFin = temporada?.fechaFin;
    bool activa = temporada?.activa ?? false;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(temporada == null ? 'Crear temporada' : 'Editar temporada'),
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
                      TextFormField(
                        controller: TextEditingController(
                          text: fechaInicio == null
                              ? ''
                              : '${fechaInicio!.day.toString().padLeft(2, '0')}/'
                                  '${fechaInicio!.month.toString().padLeft(2, '0')}/'
                                  '${fechaInicio!.year}',
                        ),
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Fecha inicio'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => fechaInicio = picked);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: TextEditingController(
                          text: fechaFin == null
                              ? ''
                              : '${fechaFin!.day.toString().padLeft(2, '0')}/'
                                  '${fechaFin!.month.toString().padLeft(2, '0')}/'
                                  '${fechaFin!.year}',
                        ),
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Fecha fin'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fechaFin ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => fechaFin = picked);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: categoriaController,
                        decoration:
                            const InputDecoration(labelText: 'Categoría (opcional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ordenController,
                        decoration: const InputDecoration(labelText: 'Orden'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Debe ser un número';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: activa,
                        onChanged: (value) => setState(() => activa = value),
                        title: const Text('Activa'),
                      ),
                      TextFormField(
                        controller: descripcionController,
                        decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
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

                    if (activa) {
                      final otrasTemporadas = await _temporadasRef.get();
                      for (final doc in otrasTemporadas.docs) {
                        if (doc.id != temporada?.id) {
                          await doc.reference.update({'activa': false});
                        }
                      }
                    }

                    final nuevaTemporada = Temporada(
                      id: temporada?.id ?? '',
                      nombre: nombreController.text.trim(),
                      fechaInicio: fechaInicio,
                      fechaFin: fechaFin,
                      activa: activa,
                      categoria: categoriaController.text.trim().isEmpty
                          ? null
                          : categoriaController.text.trim(),
                      orden: int.parse(ordenController.text.trim()),
                      descripcion: descripcionController.text.trim().isEmpty
                          ? null
                          : descripcionController.text.trim(),
                    );

                    if (temporada == null) {
                      await _temporadasRef.add(nuevaTemporada.toMap());
                    } else {
                      await _temporadasRef.doc(temporada.id).update(nuevaTemporada.toMap());
                    }

                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text(temporada == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, Temporada temporada) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar temporada'),
        content: Text('¿Seguro que deseas eliminar "${temporada.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _temporadasRef.doc(temporada.id).delete();
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
        title: const Text('Temporadas'),
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
          stream: _temporadasRef.orderBy('orden').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar temporadas: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Aún no hay temporadas registradas.'));
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final temporada = Temporada.fromDoc(docs[index].id, docs[index].data());
                final fechaInicio = temporada.fechaInicio != null
                    ? '${temporada.fechaInicio!.day.toString().padLeft(2, '0')}/'
                        '${temporada.fechaInicio!.month.toString().padLeft(2, '0')}/'
                        '${temporada.fechaInicio!.year}'
                    : '';
                final fechaFin = temporada.fechaFin != null
                    ? '${temporada.fechaFin!.day.toString().padLeft(2, '0')}/'
                        '${temporada.fechaFin!.month.toString().padLeft(2, '0')}/'
                        '${temporada.fechaFin!.year}'
                    : '';
                final rangoFechas =
                    fechaInicio.isEmpty && fechaFin.isEmpty ? '' : '$fechaInicio - $fechaFin';

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
                      temporada.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rangoFechas.isNotEmpty) Text(rangoFechas),
                        Text(temporada.activa ? 'Activa' : 'Inactiva'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () => _mostrarDialogo(context, temporada: temporada),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarEliminar(context, temporada),
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
