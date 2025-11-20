import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/campeonato.dart';
import '../services/counter_service.dart';

class CampeonatosScreen extends StatefulWidget {
  const CampeonatosScreen({super.key});

  @override
  State<CampeonatosScreen> createState() => _CampeonatosScreenState();
}

class _CampeonatosScreenState extends State<CampeonatosScreen> {
  final CollectionReference<Map<String, dynamic>> _campeonatosRef =
      FirebaseFirestore.instance.collection('Campeonatos');
  final CollectionReference<Map<String, dynamic>> _temporadasRef =
      FirebaseFirestore.instance.collection('Temporadas');

  Future<void> _confirmarEliminar(Campeonato campeonato) async {
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

  Future<void> _mostrarDialogoCampeonato(BuildContext context,
      {Campeonato? campeonato}) async {
    final formKey = GlobalKey<FormState>();

    final apodoController = TextEditingController(text: campeonato?.apodo ?? '');
    final nombreController = TextEditingController(text: campeonato?.nombre ?? '');
    final organizadorController =
        TextEditingController(text: campeonato?.organizador ?? '');
    final nivelController = TextEditingController(text: campeonato?.nivel ?? '');
    final colorController = TextEditingController(text: campeonato?.color ?? '');
    final notasController = TextEditingController(text: campeonato?.notas ?? '');

    String? temporadaId = campeonato?.temporadaId;
    String? temporadaNombre = campeonato?.temporadaNombre;
    String categoria = campeonato?.categoria ?? _categorias.first;
    String sexo = campeonato?.sexo ?? _sexos.first;
    String tipo = campeonato?.tipo ?? _tipos.first;
    bool activo = campeonato?.activo ?? true;

    final temporadasFuture = _temporadasRef.orderBy('orden').get();

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                campeonato == null ? 'Crear campeonato' : 'Editar campeonato',
              ),
              content: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: temporadasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final temporadas = snapshot.data?.docs ?? [];

                  if (temporadas.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No hay temporadas. Crea una temporada antes de añadir campeonatos.',
                      ),
                    );
                  }

                  if (temporadaId == null && temporadas.isNotEmpty) {
                    temporadaId = temporadas.first.id;
                    temporadaNombre =
                        temporadas.first.data()['nombre'] as String? ?? '';
                  }

                  return Form(
                    key: formKey,
                    child: SingleChildScrollView(
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
                          DropdownButtonFormField<String>(
                            value: temporadaId,
                            decoration:
                                const InputDecoration(labelText: 'Temporada'),
                            items: temporadas
                                .map(
                                  (doc) => DropdownMenuItem(
                                    value: doc.id,
                                    child:
                                        Text(doc.data()['nombre'] as String? ?? ''),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                temporadaId = value;
                                final temporadaSeleccionada = temporadas.firstWhere(
                                    (t) => t.id == value,
                                    orElse: () => temporadas.first);
                                temporadaNombre =
                                    temporadaSeleccionada.data()['nombre']
                                            as String? ??
                                        '';
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Selecciona una temporada';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: categoria,
                            decoration:
                                const InputDecoration(labelText: 'Categoría'),
                            items: _categorias
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => categoria = value);
                            },
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
                            onChanged: (value) {
                              if (value != null) setState(() => sexo = value);
                            },
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
                            onChanged: (value) {
                              if (value != null) setState(() => tipo = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: organizadorController,
                            decoration: const InputDecoration(
                              labelText: 'Organizador (opcional)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: nivelController,
                            decoration:
                                const InputDecoration(labelText: 'Nivel (opcional)'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: colorController,
                            decoration: const InputDecoration(
                              labelText: 'Color (ej: #FFD600)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: notasController,
                            decoration:
                                const InputDecoration(labelText: 'Notas (opcional)'),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
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
                      ),
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (temporadaId == null || temporadaNombre == null) return;

                    final data = {
                      'apodo': apodoController.text.trim(),
                      'nombre': nombreController.text.trim(),
                      'temporadaId': temporadaId,
                      'temporadaNombre': temporadaNombre,
                      'categoria': categoria,
                      'sexo': sexo,
                      'tipo': tipo,
                      'activo': activo,
                      'organizador': organizadorController.text.trim().isEmpty
                          ? null
                          : organizadorController.text.trim(),
                      'nivel': nivelController.text.trim().isEmpty
                          ? null
                          : nivelController.text.trim(),
                      'color': colorController.text.trim().isEmpty
                          ? null
                          : colorController.text.trim(),
                      'notas': notasController.text.trim().isEmpty
                          ? null
                          : notasController.text.trim(),
                    };

                    if (campeonato == null) {
                      final nuevoId =
                          await CounterService.obtenerSiguienteId('campeonatos');
                      await _campeonatosRef.add({
                        'idCampeonato': nuevoId,
                        ...data,
                      });
                    } else {
                      await _campeonatosRef.doc(campeonato.id).update(data);
                    }

                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text(campeonato == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
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
          stream: _campeonatosRef.orderBy('apodo').snapshots(),
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
                child: Text(
                  'No hay campeonatos. Pulsa + para crear el primero.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final campeonato =
                    Campeonato.fromDoc(docs[index].id, docs[index].data());

                final subtitulo =
                    '${campeonato.nombre}\n${campeonato.temporadaNombre} · ${campeonato.categoria} · ${campeonato.sexo} · ${campeonato.tipo}';

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
                          onPressed: () => _confirmarEliminar(campeonato),
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

const List<String> _categorias = [
  'Senior',
  'Juvenil',
  'Cadete',
  'Infantil',
  'Alevín',
];

const List<String> _sexos = [
  'Masculino',
  'Femenino',
  'Mixto',
];

const List<String> _tipos = [
  'Liga',
  'Copa',
  'Playoff',
  'Amistoso',
];
