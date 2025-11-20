import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/staff_tecnico.dart';

class StaffEquipoScreen extends StatefulWidget {
  const StaffEquipoScreen({super.key, required this.equipoId, required this.equipoNombre});

  final String equipoId;
  final String equipoNombre;

  @override
  State<StaffEquipoScreen> createState() => _StaffEquipoScreenState();
}

class _StaffEquipoScreenState extends State<StaffEquipoScreen> {
  CollectionReference<Map<String, dynamic>> get _staffRef =>
      FirebaseFirestore.instance.collection('StaffTecnico');

  static const List<String> _cargos = [
    'Entrenador',
    'Oficial',
    'Auxiliar',
    'Staff Técnico',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream() {
    return _staffRef
        .where('equipoId', isEqualTo: widget.equipoId)
        .orderBy('idStaff')
        .snapshots();
  }

  Future<int> _obtenerSiguienteIdStaff() async {
    final contadorRef = FirebaseFirestore.instance.collection('Contadores').doc('staff');

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

  Future<void> _mostrarDialogoStaff(BuildContext context, {StaffTecnico? staff}) async {
    final formKey = GlobalKey<FormState>();

    final apodoController = TextEditingController(text: staff?.apodo ?? '');
    final nombreController = TextEditingController(text: staff?.nombre ?? '');
    final telefonoController = TextEditingController(text: staff?.telefono ?? '');
    final emailController = TextEditingController(text: staff?.email ?? '');
    final identificacionController =
        TextEditingController(text: staff?.identificacion ?? '');
    final especialidadController = TextEditingController(text: staff?.especialidad ?? '');
    final notasController = TextEditingController(text: staff?.notas ?? '');

    DateTime? fechaNacimiento = staff?.fechaNacimiento;
    String? cargo = staff?.cargo ?? _cargos.first;
    bool convocado = staff?.convocado ?? true;
    bool lesionado = staff?.lesionado ?? false;
    bool sancionado = staff?.sancionado ?? false;
    bool activo = staff?.activo ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(staff == null ? 'Crear miembro del staff' : 'Editar miembro del staff'),
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
                        value: cargo,
                        decoration: const InputDecoration(labelText: 'Cargo'),
                        items: _cargos
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (value) => setState(() => cargo = value),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Selecciona el cargo' : null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: convocado,
                        onChanged: (value) => setState(() => convocado = value),
                        title: const Text('Convocado'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: lesionado,
                        onChanged: (value) => setState(() => lesionado = value),
                        title: const Text('Lesionado'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: sancionado,
                        onChanged: (value) => setState(() => sancionado = value),
                        title: const Text('Sancionado'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: activo,
                        onChanged: (value) => setState(() => activo = value),
                        title: const Text('Activo'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      TextFormField(
                        controller: telefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: identificacionController,
                        decoration: const InputDecoration(labelText: 'Identificación'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: especialidadController,
                        decoration: const InputDecoration(labelText: 'Especialidad'),
                      ),
                      const SizedBox(height: 12),
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

                    final data = StaffTecnico(
                      id: staff?.id ?? '',
                      idStaff: staff?.idStaff ?? 0,
                      equipoId: widget.equipoId,
                      equipoNombre: widget.equipoNombre,
                      apodo: apodoController.text.trim(),
                      nombre: nombreController.text.trim(),
                      fechaNacimiento: fechaNacimiento,
                      cargo: cargo ?? _cargos.first,
                      activo: activo,
                      convocado: convocado,
                      lesionado: lesionado,
                      sancionado: sancionado,
                      telefono: telefonoController.text.trim().isEmpty
                          ? null
                          : telefonoController.text.trim(),
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                      identificacion: identificacionController.text.trim().isEmpty
                          ? null
                          : identificacionController.text.trim(),
                      especialidad: especialidadController.text.trim().isEmpty
                          ? null
                          : especialidadController.text.trim(),
                      notas: notasController.text.trim().isEmpty
                          ? null
                          : notasController.text.trim(),
                    );

                    if (staff == null) {
                      final nuevoId = await _obtenerSiguienteIdStaff();
                      await _staffRef.add(data.copyWith(idStaff: nuevoId).toMap());
                    } else {
                      await _staffRef.doc(staff.id).update({
                        'apodo': data.apodo,
                        'nombre': data.nombre,
                        'fechaNacimiento': data.fechaNacimiento,
                        'cargo': data.cargo,
                        'activo': data.activo,
                        'convocado': data.convocado,
                        'lesionado': data.lesionado,
                        'sancionado': data.sancionado,
                        'telefono': data.telefono,
                        'email': data.email,
                        'identificacion': data.identificacion,
                        'especialidad': data.especialidad,
                        'notas': data.notas,
                      });
                    }

                    if (mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text(staff == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarEliminar(StaffTecnico staff) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar miembro del staff'),
          content: Text('¿Seguro que deseas eliminar a ${staff.apodo}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _staffRef.doc(staff.id).delete();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Eliminar'),
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
        title: Text('Staff – ${widget.equipoNombre}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoStaff(context),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _staffStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar staff: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('No hay miembros del staff. Pulsa + para añadir el primero.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final staff = StaffTecnico.fromDoc(docs[index].id, docs[index].data());
                final estados = <String>[];
                if (staff.convocado) estados.add('Convocado');
                if (staff.lesionado) estados.add('Lesionado');
                if (staff.sancionado) estados.add('Sancionado');
                if (!staff.activo) estados.add('Inactivo');

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
                      '${staff.apodo} (${staff.idStaff})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.especialidad?.isNotEmpty == true
                              ? '${staff.cargo} · ${staff.especialidad}'
                              : staff.cargo,
                        ),
                        if (estados.isNotEmpty)
                          Text(
                            estados.join(' · '),
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.8),
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
                          onPressed: () => _mostrarDialogoStaff(context, staff: staff),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarEliminar(staff),
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

extension on StaffTecnico {
  StaffTecnico copyWith({int? idStaff}) {
    return StaffTecnico(
      id: id,
      idStaff: idStaff ?? this.idStaff,
      equipoId: equipoId,
      equipoNombre: equipoNombre,
      apodo: apodo,
      nombre: nombre,
      fechaNacimiento: fechaNacimiento,
      cargo: cargo,
      activo: activo,
      convocado: convocado,
      lesionado: lesionado,
      sancionado: sancionado,
      telefono: telefono,
      email: email,
      identificacion: identificacion,
      especialidad: especialidad,
      notas: notas,
    );
  }
}
