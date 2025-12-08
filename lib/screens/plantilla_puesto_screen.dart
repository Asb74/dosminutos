
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/puesto_color_service.dart';

class PlantillaPuestoScreen extends StatefulWidget {
  const PlantillaPuestoScreen({super.key});

  @override
  State<PlantillaPuestoScreen> createState() => _PlantillaPuestoScreenState();
}

class _PlantillaPuestoScreenState extends State<PlantillaPuestoScreen> {
  static const _puestos = [
    'Portero',
    'Central',
    'Extremo Derecho',
    'Extremo Izquierdo',
    'Lateral Derecho',
    'Lateral Izquierdo',
    'Pivote',
  ];

  final _coleccion =
      FirebaseFirestore.instance.collection('PlantillaPuesto');

  Future<void> _mostrarFormulario({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final formKey = GlobalKey<FormState>();
    String? puestoSeleccionado = doc?.data()?['puesto'] as String?;
    Color colorSeleccionado = colorFromHex(
      (doc?.data()?['colorHex'] as String?) ?? '#9E9E9E',
    );
    final colorController =
        TextEditingController(text: colorToHex(colorSeleccionado));

    Future<void> seleccionarColor() async {
      final nuevoColor = await showDialog<Color>(
        context: context,
        builder: (context) {
          Color colorTemporal = colorSeleccionado;
          return AlertDialog(
            title: const Text('Selecciona un color'),
            content: SingleChildScrollView(
              child: BlockPicker(
                pickerColor: colorTemporal,
                onColorChanged: (color) {
                  colorTemporal = color;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(colorTemporal),
                child: const Text('Seleccionar'),
              ),
            ],
          );
        },
      );

      if (nuevoColor != null) {
        setState(() {
          colorSeleccionado = nuevoColor;
          colorController.text = colorToHex(nuevoColor);
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(doc == null ? 'Nuevo puesto' : 'Editar puesto'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: puestoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Puesto'),
                  items: _puestos
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: doc == null
                      ? (value) => puestoSeleccionado = value
                      : (value) {
                          puestoSeleccionado = value;
                        },
                  validator: (value) =>
                      value == null ? 'Selecciona un puesto' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color (#RRGGBB)',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Introduce un color';
                          }
                          final hex = value.trim();
                          final regex = RegExp(r'^#?[0-9a-fA-F]{6}$');
                          if (!regex.hasMatch(hex)) {
                            return 'Formato inválido';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final hex = value.trim();
                          final regex = RegExp(r'^#?[0-9a-fA-F]{6}$');
                          if (regex.hasMatch(hex)) {
                            try {
                              colorSeleccionado = colorFromHex(hex);
                            } catch (_) {}
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: seleccionarColor,
                      child: CircleAvatar(
                        backgroundColor: colorSeleccionado,
                        radius: 20,
                        child: const Icon(Icons.color_lens, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
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

                final puesto = puestoSeleccionado;
                if (puesto == null) return;

                final snapshot = await _coleccion.get();
                final existe = snapshot.docs.any((d) {
                  final data = d.data();
                  return data['puesto'] == puesto && d.id != doc?.id;
                });

                if (existe) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ya existe un registro para ese puesto.'),
                      ),
                    );
                  }
                  return;
                }

                final colorHex = colorToHex(colorSeleccionado);

                if (doc == null) {
                  int maxId = 0;
                  for (final d in snapshot.docs) {
                    final id = int.tryParse(d.id) ?? 0;
                    if (id > maxId) maxId = id;
                  }
                  final nextId = (maxId + 1).toString();
                  await _coleccion.doc(nextId).set({
                    'puesto': puesto,
                    'colorHex': colorHex,
                  });
                } else {
                  await doc.reference.update({
                    'puesto': puesto,
                    'colorHex': colorHex,
                  });
                }

                limpiarCacheColoresPuesto();

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        doc == null
                            ? 'Puesto creado correctamente'
                            : 'Puesto actualizado',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantilla por puesto'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _coleccion.orderBy('puesto').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No hay puestos configurados.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final puesto = data['puesto'] as String? ?? 'Sin puesto';
              final colorHex = data['colorHex'] as String? ?? '#9E9E9E';
              final color = () {
                try {
                  return colorFromHex(colorHex);
                } catch (_) {
                  return Colors.grey;
                }
              }();
              final textColor = ThemeData.estimateBrightnessForColor(color) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black87;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      puesto.substring(0, 1),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(puesto),
                  subtitle: Text(colorHex),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _mostrarFormulario(doc: doc),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
