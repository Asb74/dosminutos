import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/campeonato.dart';
import '../models/temporada.dart';
import '../services/counter_service.dart';

class CampeonatosScreen extends StatelessWidget {
  const CampeonatosScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _campeonatosRef =>
      FirebaseFirestore.instance.collection('Campeonatos');

  Stream<QuerySnapshot<Map<String, dynamic>>> _campeonatosStream() {
    return _campeonatosRef.orderBy('apodo').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _temporadasStream() {
    return FirebaseFirestore.instance
        .collection('Temporadas')
        .orderBy('nombre')
        .snapshots();
  }

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

  static const List<String> _tipos = [
    'Liga',
    'Copa',
    'Amistoso',
  ];

  Future<void> _mostrarDialogoCampeonato(BuildContext context,
      {Campeonato? campeonato}) async {
    final formKey = GlobalKey<FormState>();
    final apodoController = TextEditingController(text: campeonato?.apodo ?? '');
    final nombreController =
        TextEditingController(text: campeonato?.nombre ?? '');
    final notasController = TextEditingController(text: campeonato?.notas ?? '');

    String? categoria =
        campeonato != null && campeonato.categoria.isNotEmpty
            ? campeonato.categoria
            : null;
    String? sexo = campeonato != null && campeonato.sexo.isNotEmpty
        ? campeonato.sexo
        : null;
    String? tipo = campeonato != null && campeonato.tipo.isNotEmpty
        ? campeonato.tipo
        : null;
    String? temporadaId =
        campeonato != null && campeonato.temporadaId.isNotEmpty
            ? campeonato.temporadaId
            : null;
    String? temporadaNombre = campeonato?.temporadaNombre;
    bool activo = campeonato?.activo ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(campeonato == null ? 'Crear campeonato' : 'Editar campeonato'),
          content: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
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
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _temporadasStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: LinearProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Text(
                              'Error al cargar temporadas: ${snapshot.error}',
                            );
                          }

                          final temporadas = snapshot.data?.docs
                                  .map((d) => Temporada.fromDoc(d.id, d.data()))
                                  .toList() ??
                              [];

                          if (temporadaId != null &&
                              temporadas
                                  .every((temporada) => temporada.id != temporadaId)) {
                            temporadaId = null;
                            temporadaNombre = null;
                          }

                          if (temporadas.isEmpty) {
                            return const Text('No hay temporadas registradas.');
                          }

                          return DropdownButtonFormField<String>(
                            value: temporadaId,
                            decoration: const InputDecoration(
                              labelText: 'Temporada',
                            ),
                            items: temporadas
                                .map(
                                  (temporada) => DropdownMenuItem(
                                    value: temporada.id,
                                    child: Text(temporada.nombre),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                temporadaId = value;
                                temporadaNombre = value == null
                                    ? null
                                    : temporadas
                                        .firstWhere((t) => t.id == value)
                                        .nombre;
                              });
                            },
                            validator: (value) => value == null
                                ? 'Selecciona una temporada'
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: categoria,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => categoria = value),
                        validator: (value) =>
                            value == null ? 'Selecciona la categoría' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: sexo,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: _sexos
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => sexo = value),
                        validator: (value) =>
                            value == null ? 'Selecciona el sexo' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: _tipos
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => tipo = value),
                        validator: (value) =>
                            value == null ? 'Selecciona el tipo' : null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: activo,
                        title: const Text('Activo'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: colorScheme.primary,
                        onChanged: (value) => setState(() => activo = value),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notasController,
                        decoration:
                            const InputDecoration(labelText: 'Notas (opcional)'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                );
              },
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

                final nuevoCampeonato = Campeonato(
                  id: campeonato?.id ?? '',
                  idCampeonato: campeonato?.idCampeonato ??
                      await CounterService.obtenerSiguienteId('campeonatos'),
                  apodo: apodoController.text.trim(),
                  nombre: nombreController.text.trim(),
                  temporadaId: temporadaId ?? '',
                  temporadaNombre: temporadaNombre ?? '',
                  categoria: categoria ?? '',
                  sexo: sexo ?? '',
                  tipo: tipo ?? '',
                  activo: activo,
                  notas: notasController.text.trim().isEmpty
                      ? null
                      : notasController.text.trim(),
                );

                if (campeonato == null) {
                  await _campeonatosRef.add(nuevoCampeonato.toMap());
                } else {
                  await _campeonatosRef.doc(campeonato.id).update(
                        nuevoCampeonato.toMap(),
                      );
                }

                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(campeonato == null ? 'Crear' : 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Campeonato campeonato) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar campeonato'),
        content: Text('¿Seguro que deseas eliminar "${campeonato.apodo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _campeonatosRef.doc(campeonato.id).delete();
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
        title: const Text('Campeonatos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoCampeonato(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _campeonatosStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child:
                    Text('Error al cargar campeonatos: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text('Aún no hay campeonatos registrados.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final campeonato = Campeonato.fromDoc(doc.id, doc.data());
                final subtitulo =
                    '${campeonato.nombre}  ·  ${campeonato.temporadaNombre}  ·  ${campeonato.categoria}  ·  ${campeonato.sexo}';

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
                      campeonato.apodo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(subtitulo),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () =>
                              _mostrarDialogoCampeonato(context, campeonato: campeonato),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmDelete(context, campeonato),
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
