import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/partido.dart';
import 'cambios_screen.dart';

class PartidoEnJuegoScreen extends StatefulWidget {
  final String partidoId;

  const PartidoEnJuegoScreen({super.key, required this.partidoId});

  @override
  State<PartidoEnJuegoScreen> createState() => _PartidoEnJuegoScreenState();
}

class _PartidoEnJuegoScreenState extends State<PartidoEnJuegoScreen> {
  final List<String> _periodos = const [
    '1º Tiempo',
    '2º Tiempo',
    '1ª Prórroga',
    '2ª Prórroga',
  ];

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isPlaying = false;
  int _ticksSincePersist = 0;

  int _golesLocal = 0;
  int _golesVisitante = 0;
  String _periodoActual = '1º Tiempo';

  String? _equipoSeleccionado;
  int? _dorsalSeleccionado;
  String? _zonaSeleccionada;

  bool _initialized = false;
  Partido? _partido;

  List<int> get _dorsalesLocalEnJuego =>
      (_partido?.convocadosLocal ?? [])
          .where((j) => (j['enJuego'] ?? false) == true)
          .where((j) => j['dorsal'] != null)
          .map<int>((j) => (j['dorsal'] as num).toInt())
          .toList();

  List<int> get _dorsalesVisitanteEnJuego =>
      (_partido?.convocadosVisitante ?? [])
          .where((j) => (j['enJuego'] ?? false) == true)
          .where((j) => j['dorsal'] != null)
          .map<int>((j) => (j['dorsal'] as num).toInt())
          .toList();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initFromSnapshot(Partido partido, Map<String, dynamic> data) {
    if (_initialized || !mounted) return;

    final segundos = (data['segundoPartido'] as num?)?.toInt() ?? 0;

    setState(() {
      _partido = partido;
      _golesLocal = partido.golesLocal;
      _golesVisitante = partido.golesVisitante;
      _periodoActual = (data['periodoActual'] as String?) ?? _periodoActual;
      _elapsed = Duration(seconds: segundos);
      _equipoSeleccionado ??= 'local';
      _initialized = true;
    });
  }

  void _startTimer() {
    if (_isPlaying) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _ticksSincePersist++;
      });
      if (_ticksSincePersist >= 15) {
        _persistTiempo();
        _ticksSincePersist = 0;
      }
    });

    setState(() {
      _isPlaying = true;
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _isPlaying = false;
    });
    _persistTiempo();
    _ticksSincePersist = 0;
  }

  Future<void> _editarTiempo() async {
    final controller = TextEditingController(text: _formatDuration(_elapsed));
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar tiempo'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(hintText: 'MM:SS o HH:MM:SS'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (resultado == null || resultado.isEmpty) return;

    final parsed = _parseDuration(resultado);
    if (parsed == null) {
      _mostrarSnackBar('Formato de tiempo no válido. Usa MM:SS o HH:MM:SS');
      return;
    }

    setState(() {
      _elapsed = parsed;
    });
    _persistTiempo();
  }

  Duration? _parseDuration(String input) {
    final parts = input.split(':');
    if (parts.length < 2 || parts.length > 3) return null;

    try {
      final hours = parts.length == 3 ? int.parse(parts[0]) : 0;
      final minutes = int.parse(parts[parts.length - 2]);
      final seconds = int.parse(parts.last);
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final buffer = StringBuffer();
    if (hours > 0) {
      buffer.write(hours.toString().padLeft(2, '0'));
      buffer.write(':');
    }
    buffer.write(minutes.toString().padLeft(2, '0'));
    buffer.write(':');
    buffer.write(seconds.toString().padLeft(2, '0'));
    return buffer.toString();
  }

  Future<void> _cambiarPeriodo() async {
    final currentIndex = _periodos.indexOf(_periodoActual);
    final nextIndex = (currentIndex + 1) % _periodos.length;
    setState(() {
      _periodoActual = _periodos[nextIndex];
    });
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'periodoActual': _periodoActual,
    });
  }

  Future<void> _editarGoles({required bool esLocal}) async {
    final controller = TextEditingController(
      text: esLocal ? _golesLocal.toString() : _golesVisitante.toString(),
    );

    final confirmado = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(esLocal ? 'Goles local' : 'Goles visitante'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Introduce goles'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text) ?? 0;
                Navigator.of(context).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (confirmado == null) return;

    setState(() {
      if (esLocal) {
        _golesLocal = confirmado;
      } else {
        _golesVisitante = confirmado;
      }
    });

    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'golesLocal': _golesLocal,
      'golesVisitante': _golesVisitante,
    });
  }

  Future<void> _persistTiempo() async {
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'segundoPartido': _elapsed.inSeconds,
      'periodoActual': _periodoActual,
    });
  }

  Future<void> _finalizarPartido() async {
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar partido'),
        content: const Text(
          '¿Seguro que quieres finalizar el partido? No podrás seguir registrando acciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (aceptar != true) return;

    _pauseTimer();
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'estado': 'Finalizado',
      'segundoPartido': _elapsed.inSeconds,
      'periodoActual': _periodoActual,
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Map<String, dynamic> _datosAccionBase() {
    return {
      'equipo': _equipoSeleccionado,
      'dorsal': _dorsalSeleccionado,
      'zona': _zonaSeleccionada,
      'periodo': _periodoActual,
      'tiempoJuego': _formatDuration(_elapsed),
    };
  }

  void _seleccionarJugador(String equipo, int dorsal) {
    setState(() {
      _equipoSeleccionado = equipo;
      _dorsalSeleccionado = dorsal;
    });
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  void _syncPartido(Partido partido, Map<String, dynamic> data) {
    if (!mounted || _isPlaying) return;

    final segundos = (data['segundoPartido'] as num?)?.toInt();
    final nuevoPeriodo = (data['periodoActual'] as String?) ?? _periodoActual;

    final shouldUpdateTiempo =
        segundos != null && _elapsed.inSeconds != segundos && !_isPlaying;
    final shouldUpdatePeriodo = nuevoPeriodo != _periodoActual;
    final shouldUpdateGoles = partido.golesLocal != _golesLocal ||
        partido.golesVisitante != _golesVisitante;

    if (!shouldUpdateTiempo && !shouldUpdatePeriodo && !shouldUpdateGoles) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _partido = partido;
        if (shouldUpdateGoles) {
          _golesLocal = partido.golesLocal;
          _golesVisitante = partido.golesVisitante;
        }
        if (shouldUpdatePeriodo) {
          _periodoActual = nuevoPeriodo;
        }
        if (shouldUpdateTiempo && !_isPlaying && segundos != null) {
          _elapsed = Duration(seconds: segundos);
        }
        _equipoSeleccionado ??= 'local';
      });
    });
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text('No se encontró la información del partido.'));
          }

          final data = snapshot.data!.data()!;
          final partido = Partido.fromDoc(snapshot.data!.id, data);

          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initFromSnapshot(partido, data);
            });
          } else {
            _syncPartido(partido, data);
          }

          if (!_initialized || _partido == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final partidoActual = _partido!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MarcadorWidget(
                  partido: partidoActual,
                  golesLocal: _golesLocal,
                  golesVisitante: _golesVisitante,
                  periodoActual: _periodoActual,
                  tiempo: _formatDuration(_elapsed),
                  isPlaying: _isPlaying,
                  onEditLocal: () => _editarGoles(esLocal: true),
                  onEditVisitante: () => _editarGoles(esLocal: false),
                  onCambiarPeriodo: _cambiarPeriodo,
                  onStart: _startTimer,
                  onPause: _pauseTimer,
                  onEditTiempo: _editarTiempo,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _finalizarPartido,
                  icon: const Icon(Icons.flag),
                  label: const Text('Finalizar partido'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Zona de lanzamiento',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: ZonaLanzamientoSelector(
                    zonaSeleccionada: _zonaSeleccionada,
                    onZonaSelected: (zona) {
                      setState(() {
                        _zonaSeleccionada = zona;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _JugadoresActivosSection(
                  titulo: partidoActual.equipoLocalNombre.toUpperCase(),
                  dorsales: _dorsalesLocalEnJuego,
                  seleccionadoEquipo: _equipoSeleccionado,
                  seleccionadoDorsal: _dorsalSeleccionado,
                  equipoClave: 'local',
                  onTap: _seleccionarJugador,
                ),
                const SizedBox(height: 8),
                _JugadoresActivosSection(
                  titulo: partidoActual.equipoVisitanteNombre.toUpperCase(),
                  dorsales: _dorsalesVisitanteEnJuego,
                  seleccionadoEquipo: _equipoSeleccionado,
                  seleccionadoDorsal: _dorsalSeleccionado,
                  equipoClave: 'visitante',
                  onTap: _seleccionarJugador,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (_dorsalSeleccionado == null || _equipoSeleccionado == null) {
                      _mostrarSnackBar(
                        'Selecciona primero un jugador a sustituir',
                      );
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CambiosScreen(
                          partidoId: widget.partidoId,
                          equipo: _equipoSeleccionado!,
                          dorsal: _dorsalSeleccionado!,
                          datosAccionBase: _datosAccionBase(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('Cambios'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MarcadorWidget extends StatelessWidget {
  const _MarcadorWidget({
    required this.partido,
    required this.golesLocal,
    required this.golesVisitante,
    required this.periodoActual,
    required this.tiempo,
    required this.isPlaying,
    required this.onEditLocal,
    required this.onEditVisitante,
    required this.onCambiarPeriodo,
    required this.onStart,
    required this.onPause,
    required this.onEditTiempo,
  });

  final Partido partido;
  final int golesLocal;
  final int golesVisitante;
  final String periodoActual;
  final String tiempo;
  final bool isPlaying;
  final VoidCallback onEditLocal;
  final VoidCallback onEditVisitante;
  final VoidCallback onCambiarPeriodo;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onEditTiempo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    partido.equipoLocalNombre.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    partido.equipoVisitanteNombre.toUpperCase(),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GolesBox(
                  goles: golesLocal,
                  onLongPress: onEditLocal,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '-',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                _GolesBox(
                  goles: golesVisitante,
                  onLongPress: onEditVisitante,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onCambiarPeriodo,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Periodo actual: $periodoActual',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onStart,
                  onDoubleTap: onPause,
                  onLongPress: onEditTiempo,
                  child: Text(
                    tiempo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isPlaying ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GolesBox extends StatelessWidget {
  const _GolesBox({required this.goles, required this.onLongPress});

  final int goles;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          goles.toString(),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class ZonaLanzamientoSelector extends StatefulWidget {
  const ZonaLanzamientoSelector({
    required this.onZonaSelected,
    this.zonaSeleccionada,
    super.key,
  });

  final ValueChanged<String> onZonaSelected;
  final String? zonaSeleccionada;

  @override
  State<ZonaLanzamientoSelector> createState() => _ZonaLanzamientoSelectorState();
}

class _ZonaLanzamientoSelectorState extends State<ZonaLanzamientoSelector> {
  final List<List<String>> _zonas = const [
    ['L9D', 'C9C', 'L9I'],
    ['L8D', 'C8C', 'L8I'],
    ['E6D', 'L6D', 'C6C', 'L6I', 'E6I'],
    ['7M1', '7M2'],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight > 0 ? constraints.maxHeight : width * 0.7;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/pista/pista_handball.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final localPosition = details.localPosition;
                    final rowHeight = height / _zonas.length;
                    final rowIndex = (localPosition.dy / rowHeight).clamp(0, _zonas.length - 1).floor();
                    final columnas = _zonas[rowIndex].length;
                    final colWidth = width / columnas;
                    final colIndex = (localPosition.dx / colWidth).clamp(0, columnas - 1).floor();
                    final zona = _zonas[rowIndex][colIndex];
                    widget.onZonaSelected(zona);
                  },
                  child: CustomPaint(
                    painter: _ZonaGridPainter(
                      zonas: _zonas,
                      selected: widget.zonaSeleccionada,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZonaGridPainter extends CustomPainter {
  _ZonaGridPainter({required this.zonas, this.selected});

  final List<List<String>> zonas;
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rowHeight = size.height / zonas.length;

    for (int i = 0; i < zonas.length; i++) {
      final columns = zonas[i].length;
      final columnWidth = size.width / columns;

      final top = i * rowHeight;

      for (int j = 0; j < columns; j++) {
        final left = j * columnWidth;
        final rect = Rect.fromLTWH(left, top, columnWidth, rowHeight);
        canvas.drawRect(rect, paint);

        if (zonas[i][j] == selected) {
          final highlight = Paint()
            ..color = Colors.yellow.withOpacity(0.25)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, highlight);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ZonaGridPainter oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.zonas != zonas;
  }
}

class _JugadoresActivosSection extends StatelessWidget {
  const _JugadoresActivosSection({
    required this.titulo,
    required this.dorsales,
    required this.seleccionadoEquipo,
    required this.seleccionadoDorsal,
    required this.equipoClave,
    required this.onTap,
  });

  final String titulo;
  final List<int> dorsales;
  final String? seleccionadoEquipo;
  final int? seleccionadoDorsal;
  final String equipoClave;
  final void Function(String equipo, int dorsal) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: dorsales.map((dorsal) {
            final isSelected = seleccionadoEquipo == equipoClave && seleccionadoDorsal == dorsal;
            return GestureDetector(
              onTap: () => onTap(equipoClave, dorsal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.shade300 : Colors.amber.shade100,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  dorsal.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected ? Colors.black : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
