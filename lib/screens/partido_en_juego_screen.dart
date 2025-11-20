import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/evento_partido.dart';
import '../models/jugador.dart';
import '../models/partido.dart';
import '../services/eventos_service.dart';

class PartidoEnJuegoScreen extends StatefulWidget {
  final String partidoId;

  const PartidoEnJuegoScreen({
    Key? key,
    required this.partidoId,
  }) : super(key: key);

  @override
  State<PartidoEnJuegoScreen> createState() => _PartidoEnJuegoScreenState();
}

class _PartidoEnJuegoScreenState extends State<PartidoEnJuegoScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  int _periodo = 1;
  TipoAccion _selectedAccion = TipoAccion.gol;
  FaseJuego _faseSeleccionada = FaseJuego.ataque;
  String? _equipoSeleccionado;
  String? _jugadorSeleccionado;

  final TextEditingController _notaController = TextEditingController();

  Future<List<Jugador>>? _convocadosFuture;
  List<int>? _ultimaListaConvocados;

  @override
  void dispose() {
    _timer?.cancel();
    _notaController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
    setState(() {
      _isRunning = true;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _elapsedSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _cargarConvocadosSiNecesario(Partido partido) {
    final ids = partido.jugadoresConvocados;
    if (_convocadosFuture != null && listEquals(_ultimaListaConvocados, ids)) {
      return;
    }
    _ultimaListaConvocados = List<int>.from(ids);
    _convocadosFuture = _obtenerConvocados(ids);
  }

  Future<List<Jugador>> _obtenerConvocados(List<int> ids) async {
    if (ids.isEmpty) return [];

    final jugadores = <Jugador>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('Jugadores')
          .where('idJugador', whereIn: chunk)
          .get();
      jugadores.addAll(
        snapshot.docs.map((doc) => Jugador.fromDoc(doc.id, doc.data())),
      );
    }

    jugadores.sort((a, b) => a.dorsal.compareTo(b.dorsal));
    return jugadores;
  }

  Future<void> _registrarEvento(Partido partido) async {
    final equipoId = _equipoSeleccionado ?? partido.equipoLocalId;
    final notaFinal = _notaController.text.trim();

    if (equipoId.isEmpty) {
      _mostrarSnackBar('Selecciona un equipo para registrar el evento');
      return;
    }

    final eventoRef = FirebaseFirestore.instance
        .collection('Partidos')
        .doc(widget.partidoId)
        .collection('Eventos')
        .doc();

    final evento = EventoPartido(
      id: eventoRef.id,
      timestamp: DateTime.now(),
      periodo: _periodo,
      segundoPartido: _elapsedSeconds,
      equipoId: equipoId,
      jugadorId: _jugadorSeleccionado,
      tipoAccion: _selectedAccion,
      fase: _faseSeleccionada,
      zona: null,
      resultado: null,
      esPenalty: false,
      nota: notaFinal.isEmpty ? null : notaFinal,
    );

    try {
      await EventosService.addEvento(widget.partidoId, evento);
      _mostrarSnackBar('Evento registrado');
      setState(() {
        _jugadorSeleccionado = null;
        _notaController.clear();
      });
    } catch (e) {
      _mostrarSnackBar('Error al registrar evento: $e');
    }
  }

  void _mostrarSnackBar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partido en juego'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Partidos')
            .doc(widget.partidoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text('No se encontró el partido.'));
          }

          final partido =
              Partido.fromDoc(snapshot.data!.id, snapshot.data!.data()!);
          _cargarConvocadosSiNecesario(partido);
          _equipoSeleccionado ??= partido.equipoLocalId;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PartidoHeader(
                    partido: partido,
                    eventosStream: EventosService.streamEventos(widget.partidoId),
                  ),
                  const SizedBox(height: 16),
                  _Cronometro(
                    formato: _formatDuration(_elapsedSeconds),
                    periodo: _periodo,
                    isRunning: _isRunning,
                    onStart: _startTimer,
                    onStop: _stopTimer,
                    onReset: _resetTimer,
                    onPeriodoChanged: (valor) {
                      _resetTimer();
                      setState(() {
                        _periodo = valor;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _ConvocadosList(future: _convocadosFuture),
                  const SizedBox(height: 16),
                  _RegistroEvento(
                    partido: partido,
                    convocadosFuture: _convocadosFuture,
                    equipoSeleccionado: _equipoSeleccionado,
                    jugadorSeleccionado: _jugadorSeleccionado,
                    tipoAccion: _selectedAccion,
                    fase: _faseSeleccionada,
                    notaController: _notaController,
                    onEquipoChange: (value) => setState(() {
                      _equipoSeleccionado = value;
                    }),
                    onJugadorChange: (value) => setState(() {
                      _jugadorSeleccionado = value;
                    }),
                    onAccionChange: (value) => setState(() {
                      _selectedAccion = value;
                    }),
                    onFaseChange: (value) => setState(() {
                      _faseSeleccionada = value;
                    }),
                    onGuardar: () => _registrarEvento(partido),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PartidoHeader extends StatelessWidget {
  const _PartidoHeader({
    required this.partido,
    required this.eventosStream,
  });

  final Partido partido;
  final Stream<List<EventoPartido>> eventosStream;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${partido.equipoLocalNombre} vs ${partido.equipoVisitanteNombre}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha: ${partido.fechaHora.day}/${partido.fechaHora.month}/${partido.fechaHora.year}  ${partido.fechaHora.hour.toString().padLeft(2, '0')}:${partido.fechaHora.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<EventoPartido>>(
              stream: eventosStream,
              builder: (context, snapshot) {
                final eventos = snapshot.data ?? [];
                final golesLocal = eventos
                    .where((e) =>
                        e.tipoAccion == TipoAccion.gol &&
                        e.equipoId == partido.equipoLocalId)
                    .length;
                final golesVisitante = eventos
                    .where((e) =>
                        e.tipoAccion == TipoAccion.gol &&
                        e.equipoId == partido.equipoVisitanteId)
                    .length;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ScoreBox(
                      equipo: partido.equipoLocalNombre,
                      goles: golesLocal,
                      color: colorScheme.primary,
                    ),
                    const Text(
                      '-',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    _ScoreBox(
                      equipo: partido.equipoVisitanteNombre,
                      goles: golesVisitante,
                      color: colorScheme.secondary,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.equipo,
    required this.goles,
    required this.color,
  });

  final String equipo;
  final int goles;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          equipo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            goles.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _Cronometro extends StatelessWidget {
  const _Cronometro({
    required this.formato,
    required this.periodo,
    required this.isRunning,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onPeriodoChanged,
  });

  final String formato;
  final int periodo;
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;
  final ValueChanged<int> onPeriodoChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cronómetro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periodo'),
                    Row(
                      children: [
                        IconButton(
                          onPressed: periodo > 1
                              ? () => onPeriodoChanged(periodo - 1)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          'P$_periodLabel',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onPeriodoChanged(periodo + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  formato,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                ElevatedButton.icon(
                  onPressed: isRunning ? onStop : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Stop'),
                ),
                ElevatedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  String get _periodLabel => periodo.toString().padLeft(2, '0');
}

class _ConvocadosList extends StatelessWidget {
  const _ConvocadosList({required this.future});

  final Future<List<Jugador>>? future;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Convocados (local)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (future == null)
              const Text('Cargando lista de convocados...')
            else
              FutureBuilder<List<Jugador>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final jugadores = snapshot.data ?? [];
                  if (jugadores.isEmpty) {
                    return const Text('No hay jugadores convocados disponibles.');
                  }

                  return Column(
                    children: jugadores
                        .map(
                          (j) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              child: Text(j.dorsal.toString()),
                            ),
                            title: Text(j.nombre),
                            subtitle: Text(j.posicionAtaque),
                          ),
                        )
                        .toList(),
                  );
                },
              )
          ],
        ),
      ),
    );
  }
}

class _RegistroEvento extends StatelessWidget {
  const _RegistroEvento({
    required this.partido,
    required this.convocadosFuture,
    required this.equipoSeleccionado,
    required this.jugadorSeleccionado,
    required this.tipoAccion,
    required this.fase,
    required this.notaController,
    required this.onEquipoChange,
    required this.onJugadorChange,
    required this.onAccionChange,
    required this.onFaseChange,
    required this.onGuardar,
  });

  final Partido partido;
  final Future<List<Jugador>>? convocadosFuture;
  final String? equipoSeleccionado;
  final String? jugadorSeleccionado;
  final TipoAccion tipoAccion;
  final FaseJuego fase;
  final TextEditingController notaController;
  final ValueChanged<String?> onEquipoChange;
  final ValueChanged<String?> onJugadorChange;
  final ValueChanged<TipoAccion> onAccionChange;
  final ValueChanged<FaseJuego> onFaseChange;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrar evento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Equipo'),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: partido.equipoLocalId,
                  label: Text(partido.equipoLocalNombre),
                ),
                ButtonSegment(
                  value: partido.equipoVisitanteId,
                  label: Text(partido.equipoVisitanteNombre),
                ),
              ],
              selected: {equipoSeleccionado ?? partido.equipoLocalId},
              onSelectionChanged: (value) => onEquipoChange(value.first),
            ),
            const SizedBox(height: 12),
            Text('Acción'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Gol'),
                  selected: tipoAccion == TipoAccion.gol,
                  onSelected: (_) => onAccionChange(TipoAccion.gol),
                ),
                ChoiceChip(
                  label: const Text('Parada'),
                  selected: tipoAccion == TipoAccion.parada,
                  onSelected: (_) => onAccionChange(TipoAccion.parada),
                ),
                ChoiceChip(
                  label: const Text('Falta'),
                  selected: tipoAccion == TipoAccion.falta,
                  onSelected: (_) => onAccionChange(TipoAccion.falta),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Fase'),
            const SizedBox(height: 4),
            SegmentedButton<FaseJuego>(
              segments: const [
                ButtonSegment(
                  value: FaseJuego.ataque,
                  label: Text('Ataque'),
                  icon: Icon(Icons.sports_handball),
                ),
                ButtonSegment(
                  value: FaseJuego.defensa,
                  label: Text('Defensa'),
                  icon: Icon(Icons.shield_outlined),
                ),
              ],
              selected: {fase},
              onSelectionChanged: (value) => onFaseChange(value.first),
            ),
            const SizedBox(height: 12),
            Text('Jugador (opcional)'),
            const SizedBox(height: 4),
            if (convocadosFuture == null)
              const Text('Cargando jugadores...')
            else
              FutureBuilder<List<Jugador>>(
                future: convocadosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final jugadores = snapshot.data ?? [];
                  return DropdownButtonFormField<String?>(
                    value: jugadorSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona jugador',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin jugador asociado'),
                      ),
                      ...jugadores.map(
                        (j) => DropdownMenuItem<String?>(
                          value: j.idJugador.toString(),
                          child: Text('${j.dorsal} - ${j.nombre}'),
                        ),
                      ),
                    ],
                    onChanged: onJugadorChange,
                  );
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notaController,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onGuardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar evento'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
