import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/arbitro.dart';
import '../models/campeonato.dart';
import '../models/equipo.dart';
import '../models/partido.dart';
import '../services/counter_service.dart';

class NuevoPartidoScreen extends StatefulWidget {
  const NuevoPartidoScreen({super.key});

  @override
  State<NuevoPartidoScreen> createState() => _NuevoPartidoScreenState();
}

class _NuevoPartidoScreenState extends State<NuevoPartidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pabellonController = TextEditingController();
  final _jornadaController = TextEditingController();

  String? _selectedCampeonatoId;
  Campeonato? _selectedCampeonato;
  Equipo? _equipoLocal;
  Equipo? _equipoVisitante;
  String? _arbitro1Id;
  String? _arbitro2Id;
  String? _mesa1Id;
  String? _mesa2Id;
  DateTime? _fechaHora;

  bool _guardando = false;

  @override
  void dispose() {
    _pabellonController.dispose();
    _jornadaController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _campeonatosStream() {
    return FirebaseFirestore.instance
        .collection('Campeonatos')
        .where('activo', isEqualTo: true)
        .orderBy('apodo')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _equiposStream() {
    if (_selectedCampeonato == null) return null;

    return FirebaseFirestore.instance
        .collection('Equipos')
        .where('categoria', isEqualTo: _selectedCampeonato!.categoria)
        .where('sexo', isEqualTo: _selectedCampeonato!.sexo)
        .orderBy('nombre')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _arbitrosPrincipalesStream() {
    return FirebaseFirestore.instance
        .collection('Arbitros')
        .where('activo', isEqualTo: true)
        .where('tipo', isEqualTo: 'Principal')
        .orderBy('nombre')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _arbitrosMesaStream() {
    return FirebaseFirestore.instance
        .collection('Arbitros')
        .where('activo', isEqualTo: true)
        .where('tipo', isEqualTo: 'Mesa')
        .orderBy('nombre')
        .snapshots();
  }

  Future<void> _seleccionarFechaHora(BuildContext context) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora ?? ahora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha == null) return;

    final tiempo = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora ?? ahora),
    );

    if (tiempo == null) return;

    setState(() {
      _fechaHora = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        tiempo.hour,
        tiempo.minute,
      );
    });
  }

  Future<List<int>> _obtenerConvocadosJugadores() async {
    if (_selectedCampeonato == null || _equipoLocal == null) return [];

    final query = await FirebaseFirestore.instance
        .collection('Jugadores')
        .where('equipoId', isEqualTo: _equipoLocal!.id)
        .where('categoria', isEqualTo: _selectedCampeonato!.categoria)
        .where('convocado', isEqualTo: true)
        .where('lesionado', isEqualTo: false)
        .where('sancionado', isEqualTo: false)
        .where('activo', isEqualTo: true)
        .get();

    return query.docs
        .map((doc) => (doc.data()['idJugador'] as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  Future<List<int>> _obtenerConvocadosStaff() async {
    if (_equipoLocal == null) return [];

    final query = await FirebaseFirestore.instance
        .collection('StaffTecnico')
        .where('equipoId', isEqualTo: _equipoLocal!.id)
        .where('convocado', isEqualTo: true)
        .where('lesionado', isEqualTo: false)
        .where('sancionado', isEqualTo: false)
        .where('activo', isEqualTo: true)
        .get();

    return query.docs
        .map((doc) => (doc.data()['idStaff'] as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  Future<void> _crearPartido() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCampeonato == null) {
      _mostrarSnackBar('Selecciona un campeonato');
      return;
    }
    if (_equipoLocal == null || _equipoVisitante == null) {
      _mostrarSnackBar('Selecciona los equipos local y visitante');
      return;
    }
    if (_equipoLocal!.id == _equipoVisitante!.id) {
      _mostrarSnackBar('Los equipos no pueden ser iguales');
      return;
    }
    if (_fechaHora == null) {
      _mostrarSnackBar('Selecciona fecha y hora');
      return;
    }

    setState(() => _guardando = true);

    try {
      final idPartido =
          await CounterService.obtenerSiguienteId('partidos');

      final jugadoresConvocados = await _obtenerConvocadosJugadores();
      final staffConvocado = await _obtenerConvocadosStaff();

      final ahora = DateTime.now();
      final partido = Partido(
        idPartido: idPartido,
        campeonatoId: _selectedCampeonato!.id,
        campeonatoNombre: _selectedCampeonato!.apodo,
        temporadaId: _selectedCampeonato!.temporadaId,
        temporadaNombre: _selectedCampeonato!.temporadaNombre,
        categoria: _selectedCampeonato!.categoria,
        sexo: _selectedCampeonato!.sexo,
        equipoLocalId: _equipoLocal!.id,
        equipoLocalNombre: _equipoLocal!.nombre,
        equipoVisitanteId: _equipoVisitante!.id,
        equipoVisitanteNombre: _equipoVisitante!.nombre,
        fechaHora: _fechaHora!,
        pabellon: _pabellonController.text.trim(),
        jornada: _jornadaController.text.trim().isEmpty
            ? null
            : _jornadaController.text.trim(),
        arbitro1Id: _arbitro1Id,
        arbitro2Id: _arbitro2Id,
        mesa1Id: _mesa1Id,
        mesa2Id: _mesa2Id,
        jugadoresConvocados: jugadoresConvocados,
        staffConvocado: staffConvocado,
        estado: 'Programado',
        createdAt: ahora,
        updatedAt: ahora,
      );

      await FirebaseFirestore.instance
          .collection('Partidos')
          .add(partido.toMap());

      if (mounted) {
        Navigator.of(context).pop();
        _mostrarSnackBar('Partido creado correctamente');
      }
    } catch (e) {
      _mostrarSnackBar('Error al crear partido: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo partido'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Campeonato',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _campeonatosStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Error al cargar campeonatos: ${snapshot.error}',
                    );
                  }

                  final campeonatos = snapshot.data?.docs
                          .map((d) => Campeonato.fromDoc(d.id, d.data()))
                          .toList() ??
                      [];

                  final hasSelected = _selectedCampeonatoId != null &&
                      campeonatos
                          .any((c) => c.id == _selectedCampeonatoId);

                  if (campeonatos.isEmpty) {
                    _selectedCampeonatoId = null;
                    _selectedCampeonato = null;
                    return const Text(
                        'No hay campeonatos activos disponibles.');
                  }

                  if (!hasSelected) {
                    _selectedCampeonatoId = null;
                    _selectedCampeonato = null;
                  } else {
                    _selectedCampeonato = campeonatos.firstWhere(
                      (c) => c.id == _selectedCampeonatoId,
                    );
                  }

                  final dropdownValue = hasSelected ? _selectedCampeonatoId : null;

                  return DropdownButtonFormField<String>(
                    value: dropdownValue,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona un campeonato',
                    ),
                    hint: const Text('Selecciona un campeonato'),
                    items: campeonatos
                        .map(
                          (campeonato) => DropdownMenuItem<String>(
                            value: campeonato.id,
                            child: Text(campeonato.apodo),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCampeonatoId = value;
                        _selectedCampeonato = value == null
                            ? null
                            : campeonatos.firstWhere((c) => c.id == value);
                        _equipoLocal = null;
                        _equipoVisitante = null;
                      });
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecciona un campeonato'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Equipos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _selectedCampeonato == null
                  ? const Text('Primero elige un campeonato para ver los equipos.')
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _equiposStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Text(
                            'Error al cargar equipos: ${snapshot.error}',
                          );
                        }

                        final equipos = snapshot.data?.docs
                                .map((d) => Equipo.fromDoc(d.id, d.data()))
                                .toList() ??
                            [];

                        if (equipos.isEmpty) {
                          return const Text(
                              'No hay equipos para la categoría y sexo seleccionados.');
                        }

                        if (_equipoLocal != null &&
                            equipos.every((e) => e.id != _equipoLocal!.id)) {
                          _equipoLocal = null;
                        }

                        if (_equipoVisitante != null &&
                            equipos.every((e) => e.id != _equipoVisitante!.id)) {
                          _equipoVisitante = null;
                        }

                        return Column(
                          children: [
                            DropdownButtonFormField<Equipo>(
                              value: _equipoLocal,
                              decoration: const InputDecoration(
                                labelText: 'Equipo local',
                              ),
                              items: equipos
                                  .map(
                                    (equipo) => DropdownMenuItem(
                                      value: equipo,
                                      child: Text(equipo.nombre),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _equipoLocal = value;
                                });
                              },
                              validator: (value) => value == null
                                  ? 'Selecciona el equipo local'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Equipo>(
                              value: _equipoVisitante,
                              decoration: const InputDecoration(
                                labelText: 'Equipo visitante',
                              ),
                              items: equipos
                                  .map(
                                    (equipo) => DropdownMenuItem(
                                      value: equipo,
                                      child: Text(equipo.nombre),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _equipoVisitante = value;
                                });
                              },
                              validator: (value) => value == null
                                  ? 'Selecciona el equipo visitante'
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
              const SizedBox(height: 16),
              const Text(
                'Datos del partido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fechaHora == null
                          ? 'Sin fecha seleccionada'
                          : 'Fecha: ${_fechaHora!.day}/${_fechaHora!.month}/${_fechaHora!.year}  ${_fechaHora!.hour.toString().padLeft(2, '0')}:${_fechaHora!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _seleccionarFechaHora(context),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Elegir fecha y hora'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pabellonController,
                decoration: const InputDecoration(labelText: 'Pabellón'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El pabellón es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jornadaController,
                decoration: const InputDecoration(labelText: 'Jornada (opcional)'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Árbitros y mesa (opcional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _arbitrosPrincipalesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('Error al cargar árbitros: ${snapshot.error}');
                  }

                  final arbitros = snapshot.data?.docs
                          .map((d) => Arbitro.fromDoc(d.id, d.data()))
                          .toList() ??
                      [];

                  if (_arbitro1Id != null &&
                      arbitros.every((a) => a.id != _arbitro1Id)) {
                    _arbitro1Id = null;
                  }

                  if (_arbitro2Id != null &&
                      arbitros.every((a) => a.id != _arbitro2Id)) {
                    _arbitro2Id = null;
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _arbitro1Id,
                          decoration: const InputDecoration(
                            labelText: 'Árbitro 1',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin asignar'),
                            ),
                            ...arbitros
                                .map(
                                  (a) => DropdownMenuItem<String?>(
                                    value: a.id,
                                    child: Text(a.nombre),
                                  ),
                                )
                                .toList(),
                          ],
                          onChanged: (value) => setState(() => _arbitro1Id = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _arbitro2Id,
                          decoration: const InputDecoration(
                            labelText: 'Árbitro 2',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin asignar'),
                            ),
                            ...arbitros
                                .map(
                                  (a) => DropdownMenuItem<String?>(
                                    value: a.id,
                                    child: Text(a.nombre),
                                  ),
                                )
                                .toList(),
                          ],
                          onChanged: (value) => setState(() => _arbitro2Id = value),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _arbitrosMesaStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('Error al cargar mesa: ${snapshot.error}');
                  }

                  final mesas = snapshot.data?.docs
                          .map((d) => Arbitro.fromDoc(d.id, d.data()))
                          .toList() ??
                      [];

                  if (_mesa1Id != null && mesas.every((m) => m.id != _mesa1Id)) {
                    _mesa1Id = null;
                  }

                  if (_mesa2Id != null && mesas.every((m) => m.id != _mesa2Id)) {
                    _mesa2Id = null;
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _mesa1Id,
                          decoration: const InputDecoration(
                            labelText: 'Mesa 1',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin asignar'),
                            ),
                            ...mesas
                                .map(
                                  (m) => DropdownMenuItem<String?>(
                                    value: m.id,
                                    child: Text(m.nombre),
                                  ),
                                )
                                .toList(),
                          ],
                          onChanged: (value) => setState(() => _mesa1Id = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _mesa2Id,
                          decoration: const InputDecoration(
                            labelText: 'Mesa 2',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin asignar'),
                            ),
                            ...mesas
                                .map(
                                  (m) => DropdownMenuItem<String?>(
                                    value: m.id,
                                    child: Text(m.nombre),
                                  ),
                                )
                                .toList(),
                          ],
                          onChanged: (value) => setState(() => _mesa2Id = value),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _crearPartido,
                  icon: const Icon(Icons.sports_handball),
                  label: Text(_guardando ? 'Guardando...' : 'Crear partido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
