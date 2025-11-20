import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/equipo.dart';
import 'jugadores_equipo_screen.dart';
import 'staff_equipo_screen.dart';

class EquiposDeClubScreen extends StatelessWidget {
  EquiposDeClubScreen({super.key, required this.club});

  final Club club;

  final CollectionReference<Map<String, dynamic>> _equiposRef =
      FirebaseFirestore.instance.collection('Equipos');

  static const List<String> _categorias = [
    'Senior',
    'Juvenil',
    'Cadete',
    'Infantil',
    'Alevín',
  ];

  static const List<String> _sexos = [
    'Masculino',
    'Femenino',
    'Mixto',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _equiposStream() {
    return _equiposRef
        .where('clubId', isEqualTo: club.id)
        .orderBy('nombre')
        .snapshots();
  }

  Future<void> _showEquipoDialog(BuildContext context, {Equipo? equipo}) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: equipo?.nombre ?? '');
    final notasController = TextEditingController(text: equipo?.notas ?? '');
    String? categoria =
        equipo?.categoria.isNotEmpty == true ? equipo!.categoria : null;
    String? sexo = equipo?.sexo.isNotEmpty == true ? equipo!.sexo : null;
    bool activo = equipo?.activo ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(equipo == null ? 'Crear equipo' : 'Editar equipo'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Club: ${club.apodo}',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: categoria,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map((cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (value) => setState(() => categoria = value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Selecciona una categoría'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: sexo,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: _sexos
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) => setState(() => sexo = value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Selecciona el sexo'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notasController,
                        decoration:
                            const InputDecoration(labelText: 'Notas (opcional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: activo,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        activeColor: colorScheme.primary,
                        onChanged: (value) => setState(() => activo = value),
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

                    final equipoData = Equipo(
                      id: equipo?.id ?? '',
                      nombre: nombreController.text.trim(),
                      categoria: categoria ?? '',
                      sexo: sexo ?? '',
                      clubId: club.id,
                      clubNombre: club.apodo,
                      activo: activo,
                      notas: notasController.text.trim().isEmpty
                          ? null
                          : notasController.text.trim(),
                    );

                    if (equipo == null) {
                      await _equiposRef.add(equipoData.toMap());
                    } else {
                      await _equiposRef.doc(equipo.id).update(equipoData.toMap());
                    }

                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(equipo == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
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
        title: Text('Equipos de ${club.apodo}'),
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
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Este club aún no tiene equipos.'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showEquipoDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear primer equipo'),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final equipo = Equipo.fromDoc(docs[index].id, docs[index].data());
                final subtitleParts = [
                  if (equipo.categoria.trim().isNotEmpty)
                    'Categoría: ${equipo.categoria}',
                  if (equipo.sexo.trim().isNotEmpty) 'Sexo: ${equipo.sexo}',
                  if (!equipo.activo) 'Inactivo',
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
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person),
                          tooltip: 'Jugadores',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JugadoresEquipoScreen(
                                equipoId: equipo.id,
                                equipoNombre: equipo.nombre,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.group),
                          tooltip: 'Staff técnico',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffEquipoScreen(
                                equipoId: equipo.id,
                                equipoNombre: equipo.nombre,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () =>
                              _showEquipoDialog(context, equipo: equipo),
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
