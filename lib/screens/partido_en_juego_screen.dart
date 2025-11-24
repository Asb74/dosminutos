import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/partido.dart';
import 'cambios_screen.dart';

class PorteriaGridSelector extends StatelessWidget {
  const PorteriaGridSelector({
    Key? key,
    required this.onCuadranteSelected,
    this.cuadranteSeleccionado,
  }) : super(key: key);

  final ValueChanged<String> onCuadranteSelected;
  final String? cuadranteSeleccionado;

  static const List<List<String>> _cuadrantes = [
    ['ST', 'SC', 'SD'], // superior izquierda, centro, derecha
    ['MI', 'MC', 'MD'], // media izquierda, centro, derecha
    ['IB', 'IC', 'ID'], // inferior izquierda, centro, derecha
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/pista/porteria_zonas.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final localPos = details.localPosition;
                    final rowHeight = height / 3;
                    final colWidth = width / 3;

                    final rowIndex =
                        (localPos.dy / rowHeight).floor().clamp(0, 2);
                    final colIndex =
                        (localPos.dx / colWidth).floor().clamp(0, 2);

                    final codigo = _cuadrantes[rowIndex][colIndex];
                    onCuadranteSelected(codigo);
                  },
                  child: CustomPaint(
                    painter: _PorteriaGridPainter(
                      cuadranteSeleccionado: cuadranteSeleccionado,
                      cuadrantes: _cuadrantes,
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

class _PorteriaGridPainter extends CustomPainter {
  _PorteriaGridPainter({
    required this.cuadranteSeleccionado,
    required this.cuadrantes,
  });

  final String? cuadranteSeleccionado;
  final List<List<String>> cuadrantes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final highlightPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final rowHeight = size.height / 3;
    final colWidth = size.width / 3;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final left = j * colWidth;
        final top = i * rowHeight;
        final rect = Rect.fromLTWH(left, top, colWidth, rowHeight);

        if (cuadrantes[i][j] == cuadranteSeleccionado) {
          canvas.drawRect(rect, highlightPaint);
        }

        canvas.drawRect(rect, paint);

        final label = cuadrantes[i][j];
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout();
        final offset = Offset(
          rect.center.dx - textPainter.width / 2,
          rect.center.dy - textPainter.height / 2,
        );
        textPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PorteriaGridPainter oldDelegate) {
    return oldDelegate.cuadranteSeleccionado != cuadranteSeleccionado;
  }
}

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
  String? _zonaPorteriaSeleccionada;
  String? _accionSeleccionada;

  String? _contextoPendiente;

  bool _initialized = false;
  Partido? _partido;
  List<int> _jugadoresLocal = [];
  List<int> _jugadoresVisitante = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _maxSegundosPeriodo() {
    if (_periodoActual == '1º Tiempo' || _periodoActual == '2º Tiempo') {
      return 30 * 60;
    }
    if (_periodoActual == '1ª Prórroga' || _periodoActual == '2ª Prórroga') {
      return 5 * 60;
    }
    return 30 * 60;
  }

  void _startTimer() {
    if (_isPlaying) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _ticksSincePersist++;
      });

      final maxSegundos = _maxSegundosPeriodo();
      if (_elapsed.inSeconds >= maxSegundos) {
        setState(() {
          _elapsed = Duration(seconds: maxSegundos);
        });
        _pauseTimer();
        _mostrarSnackBar('Fin del periodo $_periodoActual');
        return;
      }
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

    final maxSegundos = _maxSegundosPeriodo();
    final clamped =
        parsed.inSeconds > maxSegundos ? Duration(seconds: maxSegundos) : parsed;

    setState(() {
      _elapsed = clamped;
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
    _timer?.cancel();
    _timer = null;

    final currentIndex = _periodos.indexOf(_periodoActual);
    final nextIndex = (currentIndex + 1) % _periodos.length;
    setState(() {
      _periodoActual = _periodos[nextIndex];
      _isPlaying = false;
      _elapsed = Duration.zero;
    });
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'periodoActual': _periodoActual,
      'segundoPartido': 0,
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
      'zonaPorteria': _zonaPorteriaSeleccionada,
      'periodo': _periodoActual,
      'tiempoJuego': _formatDuration(_elapsed),
    };
  }

  void _resetFlujoAccion() {
    setState(() {
      _zonaSeleccionada = null;
      _zonaPorteriaSeleccionada = null;
      _accionSeleccionada = null;
      _equipoSeleccionado = null;
      _dorsalSeleccionado = null;
      _contextoPendiente = null;
    });
  }

  bool _requierePorteria(String accion) {
    return accion == 'Gol' || accion == 'Gol Contra' || accion == 'Parada';
  }

  void _onAccionSeleccionada(String contexto, String accion) {
    if (_zonaSeleccionada == null) {
      _mostrarSnackBar('Selecciona primero una zona de juego');
      return;
    }

    setState(() {
      _accionSeleccionada = accion;
      _contextoPendiente = contexto;
      _zonaPorteriaSeleccionada = _requierePorteria(accion)
          ? null
          : _zonaPorteriaSeleccionada;
      _equipoSeleccionado = null;
      _dorsalSeleccionado = null;
    });
  }

  void _seleccionarJugador(String equipo, int dorsal) {
    final yaSeleccionado =
        _equipoSeleccionado == equipo && _dorsalSeleccionado == dorsal;

    setState(() {
      if (yaSeleccionado) {
        _equipoSeleccionado = null;
        _dorsalSeleccionado = null;
      } else {
        _equipoSeleccionado = equipo;
        _dorsalSeleccionado = dorsal;
      }
    });

    final accion = _accionSeleccionada;
    if (accion != null &&
        _zonaSeleccionada != null &&
        (!_requierePorteria(accion) || _zonaPorteriaSeleccionada != null) &&
        !yaSeleccionado) {
      _confirmarAccionConJugador();
    }
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  List<int> _parseJugadoresEnJuego(dynamic data) {
    return (data as List<dynamic>? ?? [])
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  int? _buscarPorteroInicial(List<Map<String, dynamic>> convocados) {
    for (final jugador in convocados) {
      final posicion = (jugador['posicion'] as String? ?? '').toLowerCase();
      if (posicion == 'portero') {
        return (jugador['dorsal'] as num?)?.toInt();
      }
    }
    return null;
  }

  List<int> _generarJugadoresIniciales(List<Map<String, dynamic>> convocados) {
    final dorsalesOrdenados = convocados
        .map((j) => (j['dorsal'] as num?)?.toInt())
        .whereType<int>()
        .toList()
      ..sort();

    if (dorsalesOrdenados.isEmpty) return [];

    final portero = _buscarPorteroInicial(convocados) ?? dorsalesOrdenados.first;
    final resto = dorsalesOrdenados.where((d) => d != portero).toList();
    return [portero, ...resto];
  }

  int? _getPorteroActualLocal() =>
      _jugadoresLocal.isNotEmpty ? _jugadoresLocal.first : null;
  int? _getPorteroActualVisitante() =>
      _jugadoresVisitante.isNotEmpty ? _jugadoresVisitante.first : null;

  Future<void> _syncPartido(Partido partido, Map<String, dynamic> data) async {
    final convocadosLocal = (data['convocadosLocal'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final convocadosVisitante =
        (data['convocadosVisitante'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    var jugadoresLocalEnJuego =
        _parseJugadoresEnJuego(data['jugadoresEnJuegoLocal']);
    var jugadoresVisitanteEnJuego =
        _parseJugadoresEnJuego(data['jugadoresEnJuegoVisitante']);

    final updates = <String, dynamic>{};

    if (jugadoresLocalEnJuego.isEmpty) {
      jugadoresLocalEnJuego = _generarJugadoresIniciales(convocadosLocal);
      updates['jugadoresEnJuegoLocal'] = jugadoresLocalEnJuego;
    }

    if (jugadoresVisitanteEnJuego.isEmpty) {
      jugadoresVisitanteEnJuego = _generarJugadoresIniciales(convocadosVisitante);
      updates['jugadoresEnJuegoVisitante'] = jugadoresVisitanteEnJuego;
    }

    if (updates.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('Partidos')
          .doc(widget.partidoId)
          .update(updates);
    }

    if (_initialized && _partido?.id == partido.id) {
      final haCambiadoLocal = !_listasIguales(_jugadoresLocal, jugadoresLocalEnJuego);
      final haCambiadoVisitante =
          !_listasIguales(_jugadoresVisitante, jugadoresVisitanteEnJuego);

      setState(() {
        _partido = partido;
        if (haCambiadoLocal) _jugadoresLocal = jugadoresLocalEnJuego;
        if (haCambiadoVisitante) _jugadoresVisitante = jugadoresVisitanteEnJuego;
        _golesLocal = partido.golesLocal;
        _golesVisitante = partido.golesVisitante;
        _periodoActual = (data['periodoActual'] as String?) ?? _periodoActual;
        final segundos = (data['segundoPartido'] as num?)?.toInt() ?? 0;
        if (!_isPlaying) {
          _elapsed = Duration(seconds: segundos);
        }
      });
      return;
    }

    setState(() {
      _partido = partido;
      _jugadoresLocal = jugadoresLocalEnJuego;
      _jugadoresVisitante = jugadoresVisitanteEnJuego;
      _golesLocal = partido.golesLocal;
      _golesVisitante = partido.golesVisitante;
      _periodoActual = (data['periodoActual'] as String?) ?? _periodoActual;
      final segundos = (data['segundoPartido'] as num?)?.toInt() ?? 0;
      _elapsed = Duration(seconds: segundos);
      _equipoSeleccionado ??= 'local';
      _initialized = true;
    });
  }

  bool _listasIguales(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onSeleccionPorteria(String codigo) {
    setState(() {
      _zonaPorteriaSeleccionada = codigo;
    });
  }

  Future<void> _confirmarAccionConJugador() async {
    final accion = _accionSeleccionada;
    if (accion == null ||
        _zonaSeleccionada == null ||
        _equipoSeleccionado == null ||
        _dorsalSeleccionado == null) {
      _mostrarSnackBar('Selecciona zona, acción y jugador principal.');
      return;
    }

    if (_requierePorteria(accion) && _zonaPorteriaSeleccionada == null) {
      _mostrarSnackBar('Selecciona la zona de la portería.');
      return;
    }

    final equipoPrincipal = _equipoSeleccionado!;
    final partidoRef =
        FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId);

    String? equipoSecundario;
    int? dorsalSecundario;

    final porteroLocal = _getPorteroActualLocal();
    final porteroVisitante = _getPorteroActualVisitante();

    if (accion == 'Gol' || accion == 'Gol Contra' || accion == 'Parada') {
      if (equipoPrincipal == 'local') {
        equipoSecundario = 'visitante';
        dorsalSecundario = porteroVisitante;
      } else {
        equipoSecundario = 'local';
        dorsalSecundario = porteroLocal;
      }
    } else if (accion == 'Pasivo') {
      equipoSecundario = equipoPrincipal;
    }

    final datos = {
      'partidoId': widget.partidoId,
      'equipoPrincipal': equipoPrincipal,
      'dorsalPrincipal': _dorsalSeleccionado,
      'equipoSecundario': equipoSecundario,
      'dorsalSecundario': dorsalSecundario,
      'zonaJuego': _zonaSeleccionada,
      'zonaPorteria': _zonaPorteriaSeleccionada,
      'accion': accion,
      'contexto': _contextoPendiente,
      'periodo': _periodoActual,
      'segundoPartido': _elapsed.inSeconds,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await partidoRef.collection('ActaPartido').add(datos);

    if (accion == 'Gol' || accion == 'Gol Contra') {
      final incrementos = <String, dynamic>{};
      if (accion == 'Gol') {
        if (equipoPrincipal == 'local') {
          incrementos['golesLocal'] = FieldValue.increment(1);
        } else {
          incrementos['golesVisitante'] = FieldValue.increment(1);
        }
      } else {
        if (equipoPrincipal == 'local') {
          incrementos['golesVisitante'] = FieldValue.increment(1);
        } else {
          incrementos['golesLocal'] = FieldValue.increment(1);
        }
      }

      if (incrementos.isNotEmpty) {
        await partidoRef.update(incrementos);
      }
    }

    _resetFlujoAccion();
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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _syncPartido(partido, data);
          });

          if (!_initialized || _partido == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final partidoActual = _partido!;
          final mostrarPorteria = _accionSeleccionada != null &&
              _requierePorteria(_accionSeleccionada!) &&
              _zonaPorteriaSeleccionada == null;

          final esperandoJugador = _accionSeleccionada != null &&
              _zonaSeleccionada != null &&
              (!_requierePorteria(_accionSeleccionada!) ||
                  _zonaPorteriaSeleccionada != null);

          final tituloZona = _zonaSeleccionada == null
              ? 'Selecciona primero una zona de juego'
              : _accionSeleccionada == null
                  ? 'Selecciona la acción de $_zonaSeleccionada'
                  : mostrarPorteria
                      ? 'Selecciona zona de la portería'
                      : 'Selecciona dorsal para $_accionSeleccionada';

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
                  tituloZona,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: mostrarPorteria
                      ? Column(
                          key: const ValueKey('porteria'),
                          children: [
                            SizedBox(
                              height: 260,
                              child: PorteriaGridSelector(
                                cuadranteSeleccionado: _zonaPorteriaSeleccionada,
                                onCuadranteSelected: (codigo) {
                                  _onSeleccionPorteria(codigo);
                                  if (esperandoJugador &&
                                      _equipoSeleccionado != null &&
                                      _dorsalSeleccionado != null) {
                                    _confirmarAccionConJugador();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toca un cuadrante de la portería',
                              textAlign: TextAlign.center,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: _resetFlujoAccion,
                                icon: const Icon(Icons.close),
                              ),
                            )
                          ],
                        )
                      : Column(
                          key: const ValueKey('zonas'),
                          children: [
                            SizedBox(
                              height: 260,
                              child: ZonaLanzamientoSelector(
                                zonaSeleccionada: _zonaSeleccionada,
                                onZonaSelected: (zona) {
                                  setState(() {
                                    _zonaSeleccionada = zona;
                                    _accionSeleccionada = null;
                                    _zonaPorteriaSeleccionada = null;
                                    _equipoSeleccionado = null;
                                    _dorsalSeleccionado = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _zonaSeleccionada == null
                                  ? 'Toca una zona para seleccionarla'
                                  : 'Zona seleccionada: $_zonaSeleccionada',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            _AccionesPanel(
                              key: const ValueKey('acciones'),
                              zonaSeleccionada: _zonaSeleccionada,
                              onAccionSeleccionada: (contexto, accion) {
                                _onAccionSeleccionada(contexto, accion);
                              },
                              onCancelar: _resetFlujoAccion,
                            ),
                            if (_accionSeleccionada != null && !mostrarPorteria)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Selecciona el dorsal que realiza la acción',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _JugadoresActivosSection(
                  titulo: partidoActual.equipoLocalNombre.toUpperCase(),
                  dorsales: _jugadoresLocal,
                  seleccionadoEquipo: _equipoSeleccionado,
                  seleccionadoDorsal: _dorsalSeleccionado,
                  equipoClave: 'local',
                  onTap: _seleccionarJugador,
                ),
                const SizedBox(height: 8),
                _JugadoresActivosSection(
                  titulo: partidoActual.equipoVisitanteNombre.toUpperCase(),
                  dorsales: _jugadoresVisitante,
                  seleccionadoEquipo: _equipoSeleccionado,
                  seleccionadoDorsal: _dorsalSeleccionado,
                  equipoClave: 'visitante',
                  onTap: _seleccionarJugador,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    if (_dorsalSeleccionado == null || _equipoSeleccionado == null) {
                      _mostrarSnackBar(
                        'Selecciona primero un jugador a sustituir',
                      );
                      return;
                    }

                    final cambioRealizado = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CambiosScreen(
                          partidoId: widget.partidoId,
                          equipo: _equipoSeleccionado!,
                          dorsal: _dorsalSeleccionado!,
                          datosAccionBase: _datosAccionBase(),
                        ),
                      ),
                    );

                    if (cambioRealizado == true) {
                      _resetFlujoAccion();
                    }
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
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tiempo,
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color:
                            isPlaying ? Colors.greenAccent : Colors.orangeAccent,
                      ),
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
    ['7M'],
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

    final highlight = Paint()
      ..color = Colors.yellow.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final rowHeight = size.height / zonas.length;

    for (int i = 0; i < zonas.length; i++) {
      final columns = zonas[i].length;
      final columnWidth = size.width / columns;

      final top = i * rowHeight;

      for (int j = 0; j < columns; j++) {
        final left = j * columnWidth;
        final rect = Rect.fromLTWH(left, top, columnWidth, rowHeight);
        if (zonas[i][j] == selected) {
          canvas.drawRect(rect, highlight);
        }

        canvas.drawRect(rect, paint);

        textPainter.text = TextSpan(
          text: zonas[i][j],
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        );
        textPainter.layout();
        final offset = Offset(
          rect.center.dx - textPainter.width / 2,
          rect.center.dy - textPainter.height / 2,
        );
        textPainter.paint(canvas, offset);
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
            final isDisabled = seleccionadoEquipo == equipoClave &&
                seleccionadoDorsal != null &&
                seleccionadoDorsal != dorsal;
            final esPortero = dorsales.indexOf(dorsal) == 0;
            final baseColor = esPortero
                ? (isSelected
                    ? Colors.lightBlue.shade400
                    : Colors.lightBlue.shade200)
                : (isSelected ? Colors.amber.shade300 : Colors.amber.shade100);

            final color = isDisabled ? Colors.grey.shade300 : baseColor;

            return GestureDetector(
              onTap: isDisabled ? null : () => onTap(equipoClave, dorsal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
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
                    color: isDisabled
                        ? Colors.black45
                        : (isSelected ? Colors.black : Colors.black87),
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

class _AccionesPanel extends StatelessWidget {
  const _AccionesPanel({
    super.key,
    required this.onAccionSeleccionada,
    required this.zonaSeleccionada,
    required this.onCancelar,
  });

  final void Function(String contexto, String accion) onAccionSeleccionada;
  final String? zonaSeleccionada;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tituloZona = zonaSeleccionada == null
        ? 'Selecciona la acción'
        : 'Selecciona la acción de $zonaSeleccionada';

    Widget buildBoton(String texto, String contexto) {
      return FilledButton.tonal(
        onPressed: () => onAccionSeleccionada(contexto, texto),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        child: Text(texto),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tituloZona,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna ATAQUE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ataque',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildBoton('Gol', 'ataque'),
                          buildBoton('Gol Contra', 'ataque'),
                          buildBoton('Fallo', 'ataque'),
                          buildBoton('Parada', 'ataque'),
                          buildBoton('Bloqueo', 'ataque'),
                          buildBoton('Perdida', 'ataque'),
                          buildBoton('Pasivo', 'ataque'),
                          buildBoton('Línea', 'ataque'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Columna DEFENSA
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Defensa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildBoton('Golpe', 'defensa'),
                          buildBoton('2 minutos', 'defensa'),
                          buildBoton('Tarjeta Amarilla', 'defensa'),
                          buildBoton('Tarjeta Roja', 'defensa'),
                          buildBoton('Tarjeta Azul', 'defensa'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Cancelar acción',
                onPressed: onCancelar,
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
