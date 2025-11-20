import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/evento_partido.dart';
import '../models/jugador.dart';
import '../models/partido.dart';
import '../services/eventos_service.dart';
import '../widgets/zona_pista_selector.dart';

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
  Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;
  int _baseSeconds = 0;
  bool _isRunning = false;
  bool _hasStarted = false;
  int _periodoActual = 1;
  int _golesLocal = 0;
  int _golesVisitante = 0;
  Partido? _partido;
  bool _hasInitializedFromPartido = false;
  TipoAccion _selectedAccion = TipoAccion.gol;
  FaseJuego _faseSeleccionada = FaseJuego.ataque;
  String? _equipoSeleccionado;
  String? _jugadorSeleccionado;
  ZonaJuego? _zonaSeleccionada;

  final TextEditingController _notaController = TextEditingController();

  Future<List<Jugador>>? _convocadosFuture;
  List<int>? _ultimaListaConvocados;

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _baseSeconds += _stopwatch.elapsed.inSeconds;
    _elapsedSeconds = _baseSeconds;
    _persistTiempoPeriodo();
    _notaController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;

    if (!_hasStarted) {
      FirebaseFirestore.instance
          .collection('Partidos')
          .doc(widget.partidoId)
          .update({'estado': 'EnJuego'});
      _hasStarted = true;
    }

    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds = _baseSeconds + _stopwatch.elapsed.inSeconds;
      });
    });
    setState(() {
      _isRunning = true;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _stopwatch.stop();
    _baseSeconds += _stopwatch.elapsed.inSeconds;
    _elapsedSeconds = _baseSeconds;
    _stopwatch.reset();
    setState(() {
      _isRunning = false;
    });
    _persistTiempoPeriodo();
  }

  void _reiniciarPeriodo() {
    final estabaCorriendo = _isRunning;
    _stopTimer();
    setState(() {
      _periodoActual++;
      _baseSeconds = 0;
      _elapsedSeconds = 0;
      _stopwatch.reset();
    });
    _persistTiempoPeriodo(segundos: 0);
    if (estabaCorriendo) {
      _startTimer();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _initializeFromPartido(Partido partido) {
    setState(() {
      _partido = partido;
      _golesLocal = partido.golesLocal;
      _golesVisitante = partido.golesVisitante;
      _periodoActual = partido.periodo;
      _baseSeconds = partido.segundoPartido;
      _elapsedSeconds = partido.segundoPartido;
      _stopwatch = Stopwatch();
      _hasStarted = partido.estado == 'EnJuego' || partido.estado == 'Finalizado';
      _hasInitializedFromPartido = true;
    });
  }

  void _sincronizarPartido(Partido partido) {
    if (!_hasInitializedFromPartido || _partido?.id != partido.id) {
      _initializeFromPartido(partido);
      return;
    }

    setState(() {
      _partido = partido;
      _golesLocal = partido.golesLocal;
      _golesVisitante = partido.golesVisitante;
      _periodoActual = partido.periodo;
      if (!_isRunning) {
        _baseSeconds = partido.segundoPartido;
        _elapsedSeconds = partido.segundoPartido;
      }
    });
  }

  Future<void> _persistTiempoPeriodo({int? segundos}) async {
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'segundoPartido': segundos ?? _elapsedSeconds,
      'periodo': _periodoActual,
    });
  }

  Future<void> _actualizarMarcadorEnFirestore() async {
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'golesLocal': _golesLocal,
      'golesVisitante': _golesVisitante,
    });
  }

  Future<void> _finalizarPartido() async {
    if (_isRunning) {
      _stopTimer();
    }

    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'estado': 'Finalizado',
      'segundoPartido': _elapsedSeconds,
      'periodo': _periodoActual,
    });

    if (mounted) {
      _mostrarSnackBar('Partido finalizado');
    }
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
      periodo: _periodoActual,
      segundoPartido: _elapsedSeconds,
      equipoId: equipoId,
      jugadorId: _jugadorSeleccionado,
      tipoAccion: _selectedAccion,
      fase: _faseSeleccionada,
      zona: _zonaSeleccionada,
      resultado: null,
      esPenalty: false,
      nota: notaFinal.isEmpty ? null : notaFinal,
    );

    try {
      await EventosService.addEvento(widget.partidoId, evento);
      if (_selectedAccion == TipoAccion.gol) {
        setState(() {
          if (equipoId == partido.equipoLocalId) {
            _golesLocal++;
          } else if (equipoId == partido.equipoVisitanteId) {
            _golesVisitante++;
          }
        });
        await _actualizarMarcadorEnFirestore();
      }
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
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _sincronizarPartido(partido));
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
                    golesLocal: _golesLocal,
                    golesVisitante: _golesVisitante,
                  ),
                  const SizedBox(height: 16),
                  _Cronometro(
                    formato: _formatDuration(_elapsedSeconds),
                    periodo: _periodoActual,
                    isRunning: _isRunning,
                    onStart: _startTimer,
                    onStop: _stopTimer,
                    onReset: _reiniciarPeriodo,
                    onPeriodoChanged: (valor) {
                      if (valor < 1) return;
                      setState(() {
                        _periodoActual = valor;
                      });
                      _persistTiempoPeriodo();
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _finalizarPartido,
                      icon: const Icon(Icons.flag),
                      label: const Text('Finalizar partido'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Zona de lanzamiento',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ZonaPistaSelector(
                          zonaSeleccionada: _zonaSeleccionada,
                          onZonaSelected: (zona) {
                            setState(() {
                              _zonaSeleccionada = zona;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _zonaSeleccionada != null
                              ? 'Zona seleccionada: ${_zonaSeleccionada!.label}'
                              : 'Toca una zona para seleccionarla',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
    required this.golesLocal,
    required this.golesVisitante,
  });

  final Partido partido;
  final int golesLocal;
  final int golesVisitante;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estadoColor = _estadoChipColor(partido.estado, colorScheme);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${partido.equipoLocalNombre} vs ${partido.equipoVisitanteNombre}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(partido.estado),
                  backgroundColor: estadoColor,
                )
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha: ${partido.fechaHora.day}/${partido.fechaHora.month}/${partido.fechaHora.year}  ${partido.fechaHora.hour.toString().padLeft(2, '0')}:${partido.fechaHora.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ScoreBox(
                  equipo: partido.equipoLocalNombre,
                  goles: golesLocal,
                  color: colorScheme.primary,
                ),
                const Text(
                  '-',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                _ScoreBox(
                  equipo: partido.equipoVisitanteNombre,
                  goles: golesVisitante,
                  color: colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Periodo actual: ${partido.periodo}'),
          ],
        ),
      ),
    );
  }

  Color _estadoChipColor(String estado, ColorScheme colorScheme) {
    switch (estado) {
      case 'EnJuego':
        return Colors.green.shade200;
      case 'Finalizado':
        return Colors.red.shade200;
      default:
        return colorScheme.surfaceVariant;
    }
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
                  label: const Text('Iniciar'),
                ),
                ElevatedButton.icon(
                  onPressed: isRunning ? onStop : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pausar'),
                ),
                ElevatedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reiniciar periodo'),
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
