import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/jugador.dart';

class JugadoresEquipoScreen extends StatefulWidget {
  const JugadoresEquipoScreen({super.key, required this.equipoId, required this.equipoNombre});

  final String equipoId;
  final String equipoNombre;

  @override
  State<JugadoresEquipoScreen> createState() => _JugadoresEquipoScreenState();
}

class _JugadoresEquipoScreenState extends State<JugadoresEquipoScreen> {
  CollectionReference<Map<String, dynamic>> get _jugadoresRef =>
      FirebaseFirestore.instance.collection('Jugadores');

  static const List<String> _categorias = [
    'Senior',
    'Juvenil',
    'Cadete',
    'Infantil',
    'Alevín',
  ];

  static const List<String> _posicionesAtaque = [
    'Portero',
    'Lateral Izquierdo',
    'Central',
    'Lateral Derecho',
    'Extremo Izquierdo',
    'Extremo Derecho',
    'Pivote',
  ];

  static const List<String> _posicionesDefensa = [
    'Portero',
    'Lateral',
    'Central',
    'Extremo',
    'Pivote',
  ];

  static const List<String> _manosDominantes = [
    'Derecha',
    'Izquierda',
    'Ambidiestro',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _jugadoresStream() {
    return _jugadoresRef
        .where('equipoId', isEqualTo: widget.equipoId)
        .orderBy('idJugador')
        .snapshots();
  }

  Future<int> _obtenerSiguienteIdJugador() async {
    final contadorRef =
        FirebaseFirestore.instance.collection('Contadores').doc('jugadores');

    return FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(contadorRef);

      int ultimoId = 0;
      if (snapshot.exists) {
        ultimoId = (snapshot.data()?['ultimoId'] as num?)?.toInt() ?? 0;
      } else {
        transaction.set(contadorRef, {'ultimoId': 0});
      }

      final nuevoId = ultimoId + 1;
      transaction.update(contadorRef, {'ultimoId': nuevoId});

      return nuevoId;
    });
  }

  Future<void> _mostrarDialogoJugador({Jugador? jugador}) async {
    final formKey = GlobalKey<FormState>();
    final apodoController = TextEditingController(text: jugador?.apodo ?? '');
    final nombreController = TextEditingController(text: jugador?.nombre ?? '');
    final dorsalController = TextEditingController(
      text: jugador == null
          ? ''
          : jugador.dorsal == 0
              ? ''
              : jugador.dorsal.toString(),
    );
    final notasController = TextEditingController(text: jugador?.notas ?? '');

    String? posicionAtaque = jugador?.posicionAtaque;
    String? posicionDefensa = jugador?.posicionDefensa;
    String? categoria = jugador?.categoria;
    String? manoDominante = jugador?.manoDominante ?? _manosDominantes.first;
    DateTime? fechaNacimiento = jugador?.fechaNacimiento;
    bool convocado = jugador?.convocado ?? true;
    bool lesionado = jugador?.lesionado ?? false;
    bool sancionado = jugador?.sancionado ?? false;
    bool activo = jugador?.activo ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(jugador == null ? 'Crear jugador' : 'Editar jugador'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: apodoController,
                        decoration: const InputDecoration(labelText: 'Apodo'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre completo'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dorsalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dorsal'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          final numero = int.tryParse(value.trim());
                          if (numero == null || numero < 1 || numero > 99) {
                            return 'Debe estar entre 1 y 99';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: posicionAtaque,
                        decoration: const InputDecoration(labelText: 'Posición ataque'),
                        items: _posicionesAtaque
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (value) => setState(() => posicionAtaque = value),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Selecciona la posición' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: posicionDefensa,
                        decoration: const InputDecoration(labelText: 'Posición defensa (opcional)'),
                        items: [null, ..._posicionesDefensa]
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p ?? 'Sin especificar'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => posicionDefensa = value),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: TextEditingController(
                          text: fechaNacimiento == null
                              ? ''
                              : '${fechaNacimiento!.day.toString().padLeft(2, '0')}/'
                                  '${fechaNacimiento!.month.toString().padLeft(2, '0')}/'
                                  '${fechaNacimiento!.year}',
                        ),
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fechaNacimiento ?? DateTime(now.year - 18),
                            firstDate: DateTime(1900),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked != null) {
                            setState(() => fechaNacimiento = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: categoria,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (value) => setState(() => categoria = value),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Selecciona la categoría' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: manoDominante,
                        decoration: const InputDecoration(labelText: 'Mano dominante'),
                        items: _manosDominantes
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (value) => setState(() => manoDominante = value),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Selecciona la mano dominante' : null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: convocado,
                        onChanged: (value) => setState(() => convocado = value),
                        title: const Text('Convocado'),
                      ),
                      SwitchListTile(
                        value: lesionado,
                        onChanged: (value) => setState(() => lesionado = value),
                        title: const Text('Lesionado'),
                      ),
                      SwitchListTile(
                        value: sancionado,
                        onChanged: (value) => setState(() => sancionado = value),
                        title: const Text('Sancionado'),
                      ),
                      SwitchListTile(
                        value: activo,
                        onChanged: (value) => setState(() => activo = value),
                        title: const Text('Activo'),
                      ),
                      TextFormField(
                        controller: notasController,
                        decoration: const InputDecoration(labelText: 'Notas'),
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

                    final data = Jugador(
                      id: jugador?.id ?? '',
                      idJugador: jugador?.idJugador ?? 0,
                      equipoId: widget.equipoId,
                      equipoNombre: widget.equipoNombre,
                      apodo: apodoController.text.trim(),
                      nombre: nombreController.text.trim(),
                      dorsal: int.parse(dorsalController.text.trim()),
                      posicionAtaque: posicionAtaque ?? '',
                      posicionDefensa: posicionDefensa,
                      fechaNacimiento: fechaNacimiento,
                      categoria: categoria ?? '',
                      manoDominante: manoDominante ?? _manosDominantes.first,
                      convocado: convocado,
                      lesionado: lesionado,
                      sancionado: sancionado,
                      activo: activo,
                      notas: notasController.text.trim().isEmpty
                          ? null
                          : notasController.text.trim(),
                    );

                    if (jugador == null) {
                      final nuevoId = await _obtenerSiguienteIdJugador();
                      await _jugadoresRef.add(
                        data.copyWith(idJugador: nuevoId).toMap(),
                      );
                    } else {
                      await _jugadoresRef.doc(jugador.id).update({
                        'apodo': data.apodo,
                        'nombre': data.nombre,
                        'dorsal': data.dorsal,
                        'posicionAtaque': data.posicionAtaque,
                        'posicionDefensa': data.posicionDefensa,
                        'fechaNacimiento': data.fechaNacimiento,
                        'categoria': data.categoria,
                        'manoDominante': data.manoDominante,
                        'convocado': data.convocado,
                        'lesionado': data.lesionado,
                        'sancionado': data.sancionado,
                        'activo': data.activo,
                        'notas': data.notas,
                      });
                    }

                    if (mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text(jugador == null ? 'Crear' : 'Guardar'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Jugadores – ${widget.equipoNombre}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoJugador(),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _jugadoresStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar jugadores: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('Aún no hay jugadores para este equipo.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final jugador = Jugador.fromDoc(docs[index].id, docs[index].data());
                final estados = <String>[];
                if (jugador.convocado) estados.add('Convocado');
                if (jugador.lesionado) estados.add('Lesionado');
                if (jugador.sancionado) estados.add('Sancionado');

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
                      '${jugador.apodo} (${jugador.idJugador})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dorsal: ${jugador.dorsal}'),
                        Text('${jugador.posicionAtaque} · ${jugador.categoria}'),
                        if (estados.isNotEmpty)
                          Text(
                            estados.join(' · '),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () => _mostrarDialogoJugador(jugador: jugador),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () async {
                            await _jugadoresRef.doc(jugador.id).delete();
                          },
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

extension on Jugador {
  Jugador copyWith({int? idJugador, int? dorsal}) {
    return Jugador(
      id: id,
      idJugador: idJugador ?? this.idJugador,
      equipoId: equipoId,
      equipoNombre: equipoNombre,
      apodo: apodo,
      nombre: nombre,
      dorsal: dorsal ?? this.dorsal,
      posicionAtaque: posicionAtaque,
      posicionDefensa: posicionDefensa,
      fechaNacimiento: fechaNacimiento,
      categoria: categoria,
      manoDominante: manoDominante,
      convocado: convocado,
      lesionado: lesionado,
      sancionado: sancionado,
      activo: activo,
      notas: notas,
    );
  }
}
