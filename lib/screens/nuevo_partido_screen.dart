import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/arbitro.dart';
import '../models/campeonato.dart';
import '../models/equipo.dart';
import '../models/partido.dart';
import '../services/counter_service.dart';
import 'partido_en_juego_screen.dart';

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
  String? _selectedEquipoLocalId;
  String? _selectedEquipoVisitanteId;
  Equipo? _selectedEquipoLocal;
  Equipo? _selectedEquipoVisitante;
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
        .where('activo', isEqualTo: true)
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

  Future<List<Map<String, dynamic>>> _obtenerConvocadosEquipo(
    Equipo equipo,
  ) async {
    if (_selectedCampeonato == null) return [];

    final query = await FirebaseFirestore.instance
        .collection('Jugadores')
        .where('equipoId', isEqualTo: equipo.id)
        .where('categoria', isEqualTo: _selectedCampeonato!.categoria)
        .where('convocado', isEqualTo: true)
        .where('lesionado', isEqualTo: false)
        .where('sancionado', isEqualTo: false)
        .where('activo', isEqualTo: true)
        .get();

    return query.docs.map((doc) {
      final data = doc.data();
      final dorsal = (data['dorsal'] as num?) ?? (data['idJugador'] as num?);

      return {
        'dorsal': dorsal?.toInt() ?? 0,
        'nombre': data['nombre'] as String? ?? '',
        'posicion': data['posicion'] as String? ?? '',
        'enJuego': false,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _prepararConvocados(
    List<Map<String, dynamic>> jugadores,
  ) {
    final conv = jugadores
        .map((j) => {
              'dorsal': (j['dorsal'] as num?)?.toInt() ?? 0,
              'nombre': j['nombre'] as String? ?? '',
              'posicion': j['posicion'] as String? ?? '',
              'enJuego': false,
            })
        .toList();

    for (int i = 0; i < conv.length && i < 7; i++) {
      conv[i]['enJuego'] = true;
    }

    return conv;
  }

  /// Genera la alineación inicial de 7 jugadores en juego para un equipo.
  ///
  /// - Elige como portero el primer jugador con `posicion == 'Portero'`
  ///   tras ordenar por dorsal ascendente. Si no hay portero, usa el dorsal
  ///   más bajo.
  /// - El resto de jugadores de campo son los 6 primeros (por dorsal) excluyendo
  ///   al portero seleccionado.
  /// - Si hay menos de 7 convocados, devuelve la lista disponible respetando el
  ///   orden anterior.
  List<Map<String, dynamic>> buildJugadoresEnJuegoInicial(
    List<dynamic> convocados,
  ) {
    final jugadoresOrdenados = convocados
        .whereType<Map<String, dynamic>>()
        .map((jugador) {
          final dorsal = (jugador['dorsal'] as num?)?.toInt() ?? 0;
          final nombre = jugador['nombre'] as String? ?? '';
          final posicion = jugador['posicion'] as String? ?? '';

          // Clonamos el mapa para no modificar referencias externas.
          return {
            ...jugador,
            'dorsal': dorsal,
            'nombre': nombre,
            'posicion': posicion,
          };
        })
        .toList()
      ..sort(
        (a, b) => ((a['dorsal'] as num?)?.toInt() ?? 0)
            .compareTo((b['dorsal'] as num?)?.toInt() ?? 0),
      );

    if (jugadoresOrdenados.isEmpty) return [];

    final portero = jugadoresOrdenados.firstWhere(
      (jugador) =>
          (jugador['posicion'] as String?)?.toLowerCase() == 'portero',
      orElse: () => jugadoresOrdenados.first,
    );

    final jugadoresCampo = jugadoresOrdenados
        .where((jugador) => !identical(jugador, portero))
        .take(6)
        .toList();

    return [portero, ...jugadoresCampo];
  }

  Future<void> _autocompletarPabellonDesdeClub(Equipo? equipoLocal) async {
    if (equipoLocal?.clubId == null || equipoLocal!.clubId!.isEmpty) return;
    if (_pabellonController.text.trim().isNotEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('Clubes')
        .doc(equipoLocal.clubId)
        .get();

    final pabellon = snapshot.data()?['pabellon'] as String?;

    if (pabellon != null &&
        pabellon.trim().isNotEmpty &&
        _pabellonController.text.trim().isEmpty) {
      _pabellonController.text = pabellon;
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerConvocadosStaff(
      Equipo equipo) async {
    final query = await FirebaseFirestore.instance
        .collection('StaffTecnico')
        .where('equipoId', isEqualTo: equipo.id)
        .where('convocado', isEqualTo: true)
        .where('lesionado', isEqualTo: false)
        .where('sancionado', isEqualTo: false)
        .where('activo', isEqualTo: true)
        .get();

    return query.docs.map((doc) {
      final data = doc.data();

      return {
        'idStaff': (data['idStaff'] as num?)?.toInt() ?? 0,
        'nombre': data['nombre'] as String? ?? '',
        'cargo': data['cargo'] as String? ?? '',
      };
    }).toList();
  }

  Future<void> _crearPartido() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCampeonato == null) {
      _mostrarSnackBar('Selecciona un campeonato');
      return;
    }
    if (_selectedEquipoLocal == null) {
      _mostrarSnackBar('Debes seleccionar el equipo local.');
      return;
    }
    if (_selectedEquipoVisitante == null) {
      _mostrarSnackBar('Debes seleccionar el equipo visitante.');
      return;
    }
    if (_selectedEquipoLocal!.id == _selectedEquipoVisitante!.id) {
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
      final staffConvocadoLocal = _selectedEquipoLocal == null
          ? <Map<String, dynamic>>[]
          : await _obtenerConvocadosStaff(_selectedEquipoLocal!);
      final staffConvocadoVisitante = _selectedEquipoVisitante == null
          ? <Map<String, dynamic>>[]
          : await _obtenerConvocadosStaff(_selectedEquipoVisitante!);
      final convocadosLocalCompleto = _selectedEquipoLocal == null
          ? <Map<String, dynamic>>[]
          : await _obtenerConvocadosEquipo(_selectedEquipoLocal!);
      final convocadosVisitanteCompleto = _selectedEquipoVisitante == null
          ? <Map<String, dynamic>>[]
          : await _obtenerConvocadosEquipo(_selectedEquipoVisitante!);

      final convLocal = _prepararConvocados(convocadosLocalCompleto);
      final convVis = _prepararConvocados(convocadosVisitanteCompleto);

      final ahora = DateTime.now();
      final partido = Partido(
        idPartido: idPartido,
        campeonatoId: _selectedCampeonato!.id,
        campeonatoNombre: _selectedCampeonato!.apodo,
        temporadaId: _selectedCampeonato!.temporadaId,
        temporadaNombre: _selectedCampeonato!.temporadaNombre,
        categoria: _selectedCampeonato!.categoria,
        sexo: _selectedCampeonato!.sexo,
        equipoLocalId: _selectedEquipoLocal?.id ?? '',
        equipoLocalNombre: _selectedEquipoLocal?.nombre ?? '',
        equipoVisitanteId: _selectedEquipoVisitante?.id ?? '',
        equipoVisitanteNombre: _selectedEquipoVisitante?.nombre ?? '',
        fechaHora: _fechaHora!,
        pabellon: _pabellonController.text.trim(),
        jornada: _jornadaController.text.trim().isEmpty
            ? null
            : _jornadaController.text.trim(),
        arbitro1Id: _arbitro1Id,
        arbitro2Id: _arbitro2Id,
        mesa1Id: _mesa1Id,
        mesa2Id: _mesa2Id,
        convocadosLocal: convLocal,
        convocadosVisitante: convVis,
        staffConvocadoLocal: staffConvocadoLocal,
        staffConvocadoVisitante: staffConvocadoVisitante,
        estado: 'Programado',
        golesLocal: 0,
        golesVisitante: 0,
        periodo: 1,
        segundoPartido: 0,
        createdAt: ahora,
        updatedAt: ahora,
      );

      final partidoData = partido.toMap();
      partidoData['jugadoresEnJuegoLocal'] =
          buildJugadoresEnJuegoInicial(convLocal);
      partidoData['jugadoresEnJuegoVisitante'] =
          buildJugadoresEnJuegoInicial(convVis);

      final docRef = await FirebaseFirestore.instance
          .collection('Partidos')
          .add(partidoData);

      if (mounted) {
        await _mostrarDialogoExito(docRef.id);
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

  Future<void> _mostrarDialogoExito(String partidoId) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Partido creado correctamente'),
          content: const Text(
            'Puedes ir directamente al partido para empezar a registrar eventos.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PartidoEnJuegoScreen(
                      partidoId: partidoId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.sports_handball),
              label: const Text('Ir al partido'),
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
                        _selectedEquipoLocalId = null;
                        _selectedEquipoVisitanteId = null;
                        _selectedEquipoLocal = null;
                        _selectedEquipoVisitante = null;
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

                        if (_selectedEquipoLocalId != null &&
                            equipos
                                .every((e) => e.id != _selectedEquipoLocalId)) {
                          _selectedEquipoLocalId = null;
                          _selectedEquipoLocal = null;
                        }

                        if (_selectedEquipoVisitanteId != null &&
                            equipos.every(
                                (e) => e.id != _selectedEquipoVisitanteId)) {
                          _selectedEquipoVisitanteId = null;
                          _selectedEquipoVisitante = null;
                        }

                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedEquipoLocalId != null &&
                                      equipos.any(
                                          (e) => e.id == _selectedEquipoLocalId)
                                  ? _selectedEquipoLocalId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Equipo local',
                              ),
                              hint: const Text('Selecciona equipo local'),
                              items: equipos.map((equipo) {
                                return DropdownMenuItem<String>(
                                  value: equipo.id,
                                  child: Text(equipo.nombre),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                setState(() {
                                  _selectedEquipoLocalId = value;
                                  _selectedEquipoLocal = value == null
                                      ? null
                                      : equipos
                                          .firstWhere((e) => e.id == value);

                                  if (_selectedEquipoVisitanteId ==
                                      _selectedEquipoLocalId) {
                                    _selectedEquipoVisitanteId = null;
                                    _selectedEquipoVisitante = null;
                                  }
                                });

                                await _autocompletarPabellonDesdeClub(
                                  _selectedEquipoLocal,
                                );
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecciona un equipo local';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedEquipoVisitanteId != null &&
                                      equipos.any((e) =>
                                          e.id == _selectedEquipoVisitanteId)
                                  ? _selectedEquipoVisitanteId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Equipo visitante',
                              ),
                              hint: const Text('Selecciona equipo visitante'),
                              items: equipos.map((equipo) {
                                return DropdownMenuItem<String>(
                                  value: equipo.id,
                                  child: Text(equipo.nombre),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (value != null &&
                                      value == _selectedEquipoLocalId) {
                                    return;
                                  }

                                  _selectedEquipoVisitanteId = value;
                                  _selectedEquipoVisitante = value == null
                                      ? null
                                      : equipos
                                          .firstWhere((e) => e.id == value);
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecciona un equipo visitante';
                                }
                                if (value == _selectedEquipoLocalId) {
                                  return 'El equipo visitante debe ser distinto del local';
                                }
                                return null;
                              },
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
                                    child: Text(
                                      a.nombre,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
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
                                    child: Text(
                                      a.nombre,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
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
                                    child: Text(
                                      m.nombre,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
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
                                    child: Text(
                                      m.nombre,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
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
