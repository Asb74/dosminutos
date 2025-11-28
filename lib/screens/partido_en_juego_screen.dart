import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/partido.dart';
import 'cambios_screen.dart';
import 'estadisticas_partido_screen.dart';
import '../widgets/sanciones_widgets.dart';
import '../services/registro_estadisticas_service.dart';

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
  final Map<String, SancionEstado> _estadoSanciones = {};
  Map<String, int> _tiemposJugadosCache = {};
  int _ultimoSegundoContabilizado = 0;
  int _tiempoNoPersistido = 0;
  final ValueNotifier<String> tiempoTexto = ValueNotifier<String>('00:00');

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

  // Estado del flujo de registro de acciones
  String? _equipoPrincipal;
  int? _dorsalPrincipal;
  String? _equipoSecundario;
  dynamic _dorsalSecundario;
  String? _zonaCampo;
  String? _zonaPorteria;
  String? _accionSeleccionada;

  bool _mostrandoZonas = true;
  bool _mostrandoAcciones = false;
  bool _mostrandoPorteria = false;
  bool _esperandoJugadorSecundario = false;

  bool _initialized = false;
  Partido? _partido;
  List<Map<String, dynamic>> _jugadoresLocal = [];
  List<Map<String, dynamic>> _jugadoresVisitante = [];
  bool _sancionesCargadas = false;

  String _keySancion(String equipoId, int dorsal) => '$equipoId#$dorsal';
  String _keyJugador(String equipoId, int dorsal) => '$equipoId#$dorsal';

  SancionEstado _getOrCreateSancion(String equipoId, int dorsal) {
    final key = _keySancion(equipoId, dorsal);
    return _estadoSanciones.putIfAbsent(key, () => SancionEstado());
  }

  SancionEstado? _getSancion(String equipoId, int dorsal) {
    final key = _keySancion(equipoId, dorsal);
    return _estadoSanciones[key];
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _timer?.cancel();
    tiempoTexto.dispose();
    WakelockPlus.disable();
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

  void _iniciarTimerLocal() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed += const Duration(seconds: 1);
      _ticksSincePersist++;
      tiempoTexto.value = _formatDuration(_elapsed);

      final currentSeconds = _elapsed.inSeconds;
      final delta = currentSeconds - _ultimoSegundoContabilizado;
      if (delta > 0) {
        _ultimoSegundoContabilizado = currentSeconds;
        _tiempoNoPersistido += delta;
      }

      final maxSegundos = _maxSegundosPeriodo();
      if (_elapsed.inSeconds >= maxSegundos) {
        _elapsed = Duration(seconds: maxSegundos);
        tiempoTexto.value = _formatDuration(_elapsed);
        _finalizarPeriodoPorTiempo();
        return;
      }

      if (_ticksSincePersist >= 15) {
        _persistTiempo();
        _ticksSincePersist = 0;
      }

      _tickSanciones();
    });

    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _finalizarPeriodoPorTiempo() async {
    await _pauseTimer();
    _mostrarSnackBar('Fin del periodo $_periodoActual');
  }

  Future<void> _startTimer() async {
    if (_isPlaying) return;

    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    await FirebaseFirestore.instance
        .collection('Partidos')
        .doc(widget.partidoId)
        .update({
      'segundoPartido': _elapsed.inSeconds,
      'periodoActual': _periodoActual,
      'timerRunning': true,
      'timerStartEpochMs': nowEpoch,
    });

    _iniciarTimerLocal();
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _isPlaying = false;
    });
    final segundos = _elapsed.inSeconds;
    await _flushTiemposJugados();
    await FirebaseFirestore.instance
        .collection('Partidos')
        .doc(widget.partidoId)
        .update({
      'segundoPartido': segundos,
      'periodoActual': _periodoActual,
      'timerRunning': false,
      'timerStartEpochMs': null,
    });
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
    tiempoTexto.value = _formatDuration(_elapsed);
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

    await _flushTiemposJugados();

    final currentIndex = _periodos.indexOf(_periodoActual);
    final nextIndex = (currentIndex + 1) % _periodos.length;
    setState(() {
      _periodoActual = _periodos[nextIndex];
      _isPlaying = false;
      _elapsed = Duration.zero;
      _ultimoSegundoContabilizado = 0;
    });
    tiempoTexto.value = _formatDuration(_elapsed);
    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'periodoActual': _periodoActual,
      'segundoPartido': 0,
      'timerRunning': false,
      'timerStartEpochMs': null,
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
    _ultimoSegundoContabilizado = _elapsed.inSeconds;
    final updateData = {
      'segundoPartido': _elapsed.inSeconds,
      'periodoActual': _periodoActual,
    };

    if (_isPlaying) {
      updateData['timerRunning'] = true;
      updateData['timerStartEpochMs'] = DateTime.now().millisecondsSinceEpoch;
    }

    await FirebaseFirestore.instance
        .collection('Partidos')
        .doc(widget.partidoId)
        .update(updateData);

    await _flushTiemposJugados();
  }

  Future<void> _flushTiemposJugados() async {
    if (_tiempoNoPersistido <= 0 || _partido == null) return;

    final delta = _tiempoNoPersistido;
    _tiempoNoPersistido = 0;

    final partido = _partido!;
    final tiempos = Map<String, int>.from(_tiemposJugadosCache);

    void addForList(List<Map<String, dynamic>> jugadores, String equipoId) {
      for (final j in jugadores) {
        final dorsal = (j['dorsal'] as num?)?.toInt();
        if (dorsal == null) continue;
        final key = '$equipoId#$dorsal';
        tiempos[key] = (tiempos[key] ?? 0) + delta;
      }
    }

    addForList(_jugadoresLocal, partido.equipoLocalId);
    addForList(_jugadoresVisitante, partido.equipoVisitanteId);

    _tiemposJugadosCache = tiempos;

    await FirebaseFirestore.instance
        .collection('Partidos')
        .doc(widget.partidoId)
        .update({'tiemposJugados': tiempos});
  }

  void _tickSanciones() {
    bool changed = false;

    _estadoSanciones.forEach((key, estado) {
      for (int i = 0; i < estado.dosMinRestantes.length; i++) {
        if (estado.dosMinRestantes[i] > 0) {
          estado.dosMinRestantes[i]--;
          changed = true;
        }
      }
      estado.dosMinRestantes.removeWhere((s) => s <= 0);
    });

    if (changed && mounted) {
      setState(() {});
    }
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

    await _pauseTimer();
    await _flushTiemposJugados();
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
      'equipo': _equipoPrincipal,
      'dorsal': _dorsalPrincipal,
      'zona': _zonaCampo,
      'zonaPorteria': _zonaPorteria,
      'periodo': _periodoActual,
      'tiempoJuego': _formatDuration(_elapsed),
    };
  }

  void _resetFlujoAccion() {
    // Vuelta al estado inicial de selección
    setState(() {
      _equipoPrincipal = null;
      _dorsalPrincipal = null;
      _equipoSecundario = null;
      _dorsalSecundario = null;
      _zonaCampo = null;
      _zonaPorteria = null;
      _accionSeleccionada = null;
      _mostrandoZonas = true;
      _mostrandoAcciones = false;
      _mostrandoPorteria = false;
      _esperandoJugadorSecundario = false;
    });
  }

  bool _requierePorteria(String accion) {
    return accion == 'Gol' || accion == 'Gol Contra' || accion == 'Parada';
  }

  Future<void> _preguntarAsistenciaSiProcede({
    required BuildContext context,
    required String partidoId,
    required String equipoIdGoleador,
    required int dorsalGoleador,
    required String periodo,
    required int segundoPartido,
    String? zonaDeJuego,
    String? zonaPorteria,
  }) async {
    final partidoActual = _partido;
    if (partidoActual == null) return;

    final esLocal = partidoActual.equipoLocalId == equipoIdGoleador;
    final esVisitante = partidoActual.equipoVisitanteId == equipoIdGoleador;
    if (!esLocal && !esVisitante) return;

    final jugadoresEnJuego = esLocal ? _jugadoresLocal : _jugadoresVisitante;

    final dorsalesDisponibles = jugadoresEnJuego
        .map((j) => (j['dorsal'] as num?)?.toInt())
        .whereType<int>()
        .where((dorsal) => dorsal != dorsalGoleador)
        .toList();

    if (dorsalesDisponibles.isEmpty) return;

    dorsalesDisponibles.sort();

    final dorsalAsistente = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selecciona asistente',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: dorsalesDisponibles.map((dorsal) {
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(dorsal),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dorsal.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (dorsalAsistente == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final accionSnap =
          await firestore.collection('AccionEstadistica').doc('Asistencia').get();
      final dataAccion = accionSnap.data();
      final principalRaw = dataAccion?['EstadisticaDorsalPrincipal'];
      final estadisticaPrincipal =
          principalRaw is String && principalRaw.trim().isNotEmpty
              ? principalRaw.trim()
              : 'Asistencia';

      final estadisticasRef = firestore
          .collection('ActaPartido')
          .doc(partidoId)
          .collection('Estadisticas');

      final dataAsistencia = <String, dynamic>{
        'accion': estadisticaPrincipal,
        'categoria': 'Asistencia',
        'dorsal': dorsalAsistente,
        'equipoId': equipoIdGoleador,
        'periodo': periodo,
        'segundoPartido': segundoPartido,
        'timestamp': FieldValue.serverTimestamp(),
        'zonaJuego': zonaDeJuego,
        'zona': zonaDeJuego,
      };

      if (zonaPorteria != null) {
        dataAsistencia['zonaPorteria'] = zonaPorteria;
      }

      await estadisticasRef.add(dataAsistencia);
    } catch (e) {
      _mostrarSnackBar('Error al registrar asistencia: $e');
    }
  }

  String? _equipoIdDesdeClave(String? clave) {
    if (clave == 'local') return _partido?.equipoLocalId;
    if (clave == 'visitante') return _partido?.equipoVisitanteId;
    return null;
  }

  String? _equipoIdDesdeClaveNoNull(String equipoClave) {
    return _equipoIdDesdeClave(equipoClave);
  }

  SancionEstado? _getSancionDesdeClave(String equipoClave, int dorsal) {
    final equipoId = _equipoIdDesdeClaveNoNull(equipoClave);
    if (equipoId == null) return null;
    return _getSancion(equipoId, dorsal);
  }

  void _seleccionarJugadorPrincipal(String equipo, int dorsal) {
    // Selecciona o deselecciona el jugador principal y prepara el flujo de selección
    final mismaSeleccion = _equipoPrincipal == equipo && _dorsalPrincipal == dorsal;

    if (mismaSeleccion) {
      _resetFlujoAccion();
      return;
    }

    setState(() {
      _equipoPrincipal = equipo;
      _dorsalPrincipal = dorsal;
      _equipoSecundario = null;
      _dorsalSecundario = null;
      _zonaCampo = null;
      _zonaPorteria = null;
      _accionSeleccionada = null;
      _mostrandoZonas = true;
      _mostrandoAcciones = false;
      _mostrandoPorteria = false;
      _esperandoJugadorSecundario = false;
    });
  }

  void _seleccionarZonaCampo(String zona) {
    if (_equipoPrincipal == null || _dorsalPrincipal == null) {
      _mostrarSnackBar('Selecciona primero un dorsal principal.');
      return;
    }

    final sancion = _getSancion(_equipoPrincipal!, _dorsalPrincipal!);
    final bool expulsado = sancion?.expulsado ?? false;

    if (expulsado) {
      _mostrarSnackBar('No se pueden registrar acciones con un jugador expulsado.');
      return;
    }

    setState(() {
      _zonaCampo = zona;
      _mostrandoZonas = false;
      _mostrandoAcciones = true;
      _mostrandoPorteria = false;
      _esperandoJugadorSecundario = false;
      _accionSeleccionada = null;
      _zonaPorteria = null;
      _equipoSecundario = null;
      _dorsalSecundario = null;
    });
  }

  void _onAccionFlujoSeleccionada(String accion) {
    if (_zonaCampo == null || _equipoPrincipal == null || _dorsalPrincipal == null) {
      _mostrarSnackBar('Selecciona dorsal principal y zona antes de la acción.');
      return;
    }

    setState(() {
      _accionSeleccionada = accion;
      if (_requierePorteria(accion)) {
        _mostrandoPorteria = true;
        _mostrandoAcciones = false;
        _mostrandoZonas = false;
        _esperandoJugadorSecundario = false;
      } else {
        _mostrandoAcciones = false;
        _mostrandoPorteria = false;
        _mostrandoZonas = false;
        _esperandoJugadorSecundario = true;
      }
    });
  }

  Future<void> _seleccionarJugadorSecundario(String equipo, int dorsal) async {
    if (!_esperandoJugadorSecundario) {
      _seleccionarJugadorPrincipal(equipo, dorsal);
    } else {
      await _onDorsalSecundarioSeleccionado(equipo, dorsal);
    }
  }

  Future<void> _onDorsalSecundarioSeleccionado(String equipo, int dorsal) async {
    setState(() {
      _equipoSecundario = equipo;
      _dorsalSecundario = dorsal;
    });

    print('--- REGISTRANDO ACCIÓN ---');
    print('equipoPrincipal: $_equipoPrincipal');
    print('dorsalPrincipal: $_dorsalPrincipal');
    print('equipoSecundario: $_equipoSecundario');
    print('dorsalSecundario: $_dorsalSecundario');
    print('zonaCampo: $_zonaCampo');
    print('zonaPorteria: $_zonaPorteria');
    print('accion: $_accionSeleccionada');

    await _registrarAccion();
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  /// Devuelve la lista de jugadores EN JUEGO a partir de los convocados
  /// usando el campo `enJuego == true`. Sirve tanto para local como visitante.
  List<Map<String, dynamic>> _parseJugadoresEnJuego(dynamic data) {
    final List<Map<String, dynamic>> lista = [];

    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          lista.add(Map<String, dynamic>.from(item));
        }
      }
    }

    lista.sort((a, b) {
      final posA = (a['posicion'] ?? '').toString().toLowerCase();
      final posB = (b['posicion'] ?? '').toString().toLowerCase();

      final esPorteroA = posA.contains('portero');
      final esPorteroB = posB.contains('portero');

      if (esPorteroA && !esPorteroB) return -1;
      if (!esPorteroA && esPorteroB) return 1;

      final dorsalA = (a['dorsal'] as num?)?.toInt() ?? 0;
      final dorsalB = (b['dorsal'] as num?)?.toInt() ?? 0;

      return dorsalA.compareTo(dorsalB);
    });

    return lista;
  }

  List<Map<String, dynamic>> _jugadoresEnJuegoDesdeConvocados(
    Map<String, dynamic> data, {
    required bool esLocal,
  }) {
    final keyConvocados = esLocal ? 'convocadosLocal' : 'convocadosVisitante';
    final raw = data[keyConvocados];

    final lista = _parseJugadoresEnJuego(raw)
        .where((j) => (j['enJuego'] as bool?) ?? false)
        .toList();

    // Nos quedamos como máximo con 7 (portero + 6 de campo)
    if (lista.length > 7) {
      return lista.sublist(0, 7);
    }
    return lista;
  }

  Future<void> _cargarSancionesIniciales() async {
    final partidaRef =
        FirebaseFirestore.instance.collection('ActaPartido').doc(widget.partidoId);

    final snap = await partidaRef.collection('Sanciones').get();

    _estadoSanciones.clear();

    for (final doc in snap.docs) {
      final data = doc.data();
      final equipoId = data['equipoId'] as String?;
      final dorsal = (data['dorsal'] as num?)?.toInt();
      final tipo = data['tipo'] as String?;

      if (equipoId == null || dorsal == null || tipo == null) continue;

      final estado = _getOrCreateSancion(equipoId, dorsal);

      switch (tipo) {
        case '2min':
          estado.dosMinTotales++;
          break;
        case 'amarilla':
          estado.amarillas++;
          break;
        case 'roja':
          estado.rojas++;
          break;
        case 'azul':
          estado.azules++;
          break;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  int? _getPorteroActualLocal() =>
      _jugadoresLocal.isNotEmpty ? (_jugadoresLocal.first['dorsal'] as num?)?.toInt() : null;
  int? _getPorteroActualVisitante() =>
      _jugadoresVisitante.isNotEmpty ? (_jugadoresVisitante.first['dorsal'] as num?)?.toInt() : null;

  void _ensureTiemposForConvocados(Partido partido, Map<String, dynamic> data) {
    final convLocal = (data['convocadosLocal'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final convVisitante = (data['convocadosVisitante'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final Map<String, int> nuevos = Map<String, int>.from(_tiemposJugadosCache);

    void addIfMissing(String? equipoId, List<Map<String, dynamic>> convs) {
      if (equipoId == null) return;
      for (final j in convs) {
        final dorsal = (j['dorsal'] as num?)?.toInt();
        if (dorsal == null) continue;
        final key = '$equipoId#$dorsal';
        nuevos.putIfAbsent(key, () => 0);
      }
    }

    addIfMissing(partido.equipoLocalId, convLocal);
    addIfMissing(partido.equipoVisitanteId, convVisitante);

    if (mounted) {
      setState(() {
        _tiemposJugadosCache = nuevos;
      });
    }
  }

  Future<void> _syncPartido(Partido partido, Map<String, dynamic> data) async {
    // Calculamos SIEMPRE los jugadores en juego desde convocados
    final jugadoresLocalEnJuego =
        _jugadoresEnJuegoDesdeConvocados(data, esLocal: true);
    final jugadoresVisitanteEnJuego =
        _jugadoresEnJuegoDesdeConvocados(data, esLocal: false);

    final baseSegundos = (data['segundoPartido'] as num?)?.toInt() ?? 0;
    final timerRunningRemoto = data['timerRunning'] as bool? ?? false;
    final timerStartEpochMs = data['timerStartEpochMs'] as int?;
    final periodoData = (data['periodoActual'] as String?) ?? _periodoActual;

    int totalSegundos = baseSegundos;
    if (timerRunningRemoto && timerStartEpochMs != null) {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final extra = ((nowEpoch - timerStartEpochMs) ~/ 1000);
      if (extra > 0) {
        totalSegundos += extra;
      }
    }

    final tiemposJugadosRaw = data['tiemposJugados'];
    if (tiemposJugadosRaw is Map<String, dynamic>) {
      _tiemposJugadosCache
        ..clear()
        ..addEntries(tiemposJugadosRaw.entries.map(
          (e) => MapEntry(e.key, (e.value as num?)?.toInt() ?? 0),
        ));
    }

    if (!_initialized) {
      _ultimoSegundoContabilizado =
          (data['segundoPartido'] as num?)?.toInt() ?? 0;
      _tiempoNoPersistido = 0;
    }

    int maxSegundos;
    if (periodoData == '1º Tiempo' || periodoData == '2º Tiempo') {
      maxSegundos = 30 * 60;
    } else if (periodoData == '1ª Prórroga' || periodoData == '2ª Prórroga') {
      maxSegundos = 5 * 60;
    } else {
      maxSegundos = _maxSegundosPeriodo();
    }
    if (totalSegundos > maxSegundos) {
      totalSegundos = maxSegundos;
    }

    setState(() {
      _partido = partido;
      _jugadoresLocal = jugadoresLocalEnJuego;
      _jugadoresVisitante = jugadoresVisitanteEnJuego;
      _golesLocal = partido.golesLocal;
      _golesVisitante = partido.golesVisitante;
      _periodoActual = periodoData;
      _elapsed = Duration(seconds: totalSegundos);
      _initialized = true;
    });
    tiempoTexto.value = _formatDuration(_elapsed);

    _ensureTiemposForConvocados(partido, data);

    if (!_sancionesCargadas) {
      _sancionesCargadas = true;
      await _cargarSancionesIniciales();
    }

    if (timerRunningRemoto) {
      if (!_isPlaying || _timer == null) {
        _iniciarTimerLocal();
      }
    } else {
      _timer?.cancel();
      _timer = null;
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _onSeleccionPorteria(String codigo) {
    setState(() {
      _zonaPorteria = codigo;
    });

    if (_accionSeleccionada == 'Gol' ||
        _accionSeleccionada == 'Gol Contra' ||
        _accionSeleccionada == 'Parada') {
      final equipoPrincipalActual = _equipoPrincipal;
      if (equipoPrincipalActual == null) {
        return;
      }
      final equipoContrario =
          equipoPrincipalActual == 'local' ? 'visitante' : 'local';
      final listaRival = equipoContrario == 'local'
          ? _jugadoresLocal
          : _jugadoresVisitante;
      final dorsalPortero = listaRival.isNotEmpty
          ? (listaRival.first['dorsal'] as num?)?.toInt()
          : null;

      setState(() {
        _equipoSecundario = equipoContrario;
        _dorsalSecundario = dorsalPortero;
        _mostrandoPorteria = false;
        _esperandoJugadorSecundario = false;
        _mostrandoZonas = false;
        _mostrandoAcciones = false;
      });

      _registrarAccion();
    } else {
      setState(() {
        _mostrandoPorteria = false;
        _esperandoJugadorSecundario = true;
        _mostrandoZonas = false;
        _mostrandoAcciones = false;
      });
    }
  }

  bool _esAccionSancion(String accion) {
    return accion == '2 minutos' ||
        accion == 'Tarjeta Amarilla' ||
        accion == 'Tarjeta Roja' ||
        accion == 'Tarjeta Azul';
  }

  Future<void> _aplicarYGuardarSancion(String accion) async {
    if (_equipoPrincipal == null || _dorsalPrincipal == null) return;

    final String? equipoId = _equipoIdDesdeClave(_equipoPrincipal);
    if (equipoId == null) return;
    final int dorsal = _dorsalPrincipal!;

    final estado = _getOrCreateSancion(equipoId, dorsal);

    String tipo;
    switch (accion) {
      case '2 minutos':
        tipo = '2min';
        estado.dosMinTotales++;
        estado.dosMinRestantes.add(120);
        break;
      case 'Tarjeta Amarilla':
        tipo = 'amarilla';
        estado.amarillas++;
        break;
      case 'Tarjeta Roja':
        tipo = 'roja';
        estado.rojas++;
        break;
      case 'Tarjeta Azul':
        tipo = 'azul';
        estado.azules++;
        break;
      default:
        return;
    }

    await FirebaseFirestore.instance
        .collection('ActaPartido')
        .doc(widget.partidoId)
        .collection('Sanciones')
        .add({
      'partidoId': widget.partidoId,
      'timestamp': FieldValue.serverTimestamp(),
      'periodo': _periodoActual,
      'tiempoJuego': _formatDuration(_elapsed),
      'equipoId': equipoId,
      'dorsal': dorsal,
      'tipo': tipo,
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _registrarAccion() async {
    try {
      if (_equipoPrincipal == null ||
          _dorsalPrincipal == null ||
          _accionSeleccionada == null ||
          _zonaCampo == null) {
        _mostrarSnackBar('Faltan datos para registrar la acción.');
        return;
      }

      if (_requierePorteria(_accionSeleccionada!) && _zonaPorteria == null) {
        _mostrarSnackBar('Selecciona una zona de la portería.');
        return;
      }

      final partidoRef =
          FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId);
      final equipoPrincipalId = _equipoIdDesdeClave(_equipoPrincipal);
      final equipoSecundarioId = _equipoIdDesdeClave(_equipoSecundario);
      final dorsalSecundario = (_dorsalSecundario as num?)?.toInt();

      if (equipoPrincipalId == null) {
        _mostrarSnackBar('No se pudo obtener el equipo principal.');
        return;
      }

      await registrarEstadisticasDesdeAccion(
        _accionSeleccionada!,
        widget.partidoId,
        equipoPrincipalId!,
        _dorsalPrincipal!,
        equipoSecundarioId,
        dorsalSecundario,
        periodoActual: _periodoActual,
        segundoActual: _elapsed.inSeconds,
        zonaDeJuego: _zonaCampo!,
        zonaPorteria: _zonaPorteria,
      );

      if (_accionSeleccionada == 'Gol' || _accionSeleccionada == 'Gol Contra') {
        await _preguntarAsistenciaSiProcede(
          context: context,
          partidoId: widget.partidoId,
          equipoIdGoleador: equipoPrincipalId,
          dorsalGoleador: _dorsalPrincipal!,
          periodo: _periodoActual,
          segundoPartido: _elapsed.inSeconds,
          zonaDeJuego: _zonaCampo,
          zonaPorteria: _zonaPorteria,
        );
      }

      if (_accionSeleccionada == 'Gol' || _accionSeleccionada == 'Gol Contra') {
        final incrementos = <String, dynamic>{};
        setState(() {
          if (_equipoPrincipal == 'local') {
            incrementos['golesLocal'] = FieldValue.increment(1);
            _golesLocal += 1;
          } else {
            incrementos['golesVisitante'] = FieldValue.increment(1);
            _golesVisitante += 1;
          }
        });
        if (incrementos.isNotEmpty) {
          await partidoRef.update(incrementos);
        }
      }

      if (_accionSeleccionada != null && _esAccionSancion(_accionSeleccionada!)) {
        await _aplicarYGuardarSancion(_accionSeleccionada!);
      }

      _resetFlujoAccion();
    } catch (e) {
      _mostrarSnackBar('Error al registrar la acción: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partido en juego'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Estadísticas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EstadisticasPartidoScreen(
                    partidoId: widget.partidoId,
                  ),
                ),
              );
            },
          ),
        ],
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
          final mostrarZonas = _mostrandoZonas;
          final mostrarAcciones = _mostrandoAcciones;
          final mostrarPorteria = _mostrandoPorteria;

          String tituloZona;
          if (_equipoPrincipal == null) {
            tituloZona = 'Selecciona dorsal principal';
          } else if (mostrarZonas) {
            tituloZona = 'Selecciona zona de juego';
          } else if (mostrarAcciones) {
            tituloZona = 'Selecciona la acción de ${_zonaCampo ?? ''}';
          } else if (mostrarPorteria) {
            tituloZona = 'Selecciona zona de la portería';
          } else if (_esperandoJugadorSecundario) {
            tituloZona = 'Selecciona dorsal secundario';
          } else {
            tituloZona = 'Selecciona dorsal principal';
          }

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
                  tiempoListenable: tiempoTexto,
                  isPlaying: _isPlaying,
                  onEditLocal: () => _editarGoles(esLocal: true),
                  onEditVisitante: () => _editarGoles(esLocal: false),
                  onCambiarPeriodo: _cambiarPeriodo,
                  onStart: () {
                    _startTimer();
                  },
                  onPause: () {
                    _pauseTimer();
                  },
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
                // Pequeña máquina de estados para alternar pista, acciones y portería
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: mostrarPorteria
                      ? Column(
                          key: const ValueKey('porteria'),
                          children: [
                            SizedBox(
                              height: 260,
                              child: PorteriaGridSelector(
                                cuadranteSeleccionado: _zonaPorteria,
                                onCuadranteSelected: _onSeleccionPorteria,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
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
                      : _esperandoJugadorSecundario
                          ? _SeleccionarJugadorSecundarioPanel(
                              key: const ValueKey('secundario'),
                              jugadoresLocal: _jugadoresLocal,
                              jugadoresVisitante: _jugadoresVisitante,
                              equipoPrincipal: _equipoPrincipal,
                              dorsalPrincipal: _dorsalPrincipal,
                              accionSeleccionada: _accionSeleccionada,
                              nombreEquipoLocal: partidoActual.equipoLocalNombre,
                              nombreEquipoVisitante: partidoActual.equipoVisitanteNombre,
                              onJugadorSeleccionado: (equipo, dorsal) async {
                                await _onDorsalSecundarioSeleccionado(equipo, dorsal);
                              },
                              getSancionEstado: _getSancionDesdeClave,
                            )
                          : mostrarAcciones
                              ? _AccionesPanel(
                                  key: const ValueKey('acciones'),
                                  zonaSeleccionada: _zonaCampo,
                                  onAccionSeleccionada: (_, accion) {
                                    _onAccionFlujoSeleccionada(accion);
                                  },
                                  onCancelar: _resetFlujoAccion,
                                )
                              : mostrarZonas
                                  ? Column(
                                      key: const ValueKey('zonas'),
                                      children: [
                                        SizedBox(
                                          height: 260,
                                          child: ZonaLanzamientoSelector(
                                            zonaSeleccionada: _zonaCampo,
                                            onZonaSelected: _seleccionarZonaCampo,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _zonaCampo == null
                                              ? 'Toca una zona para seleccionarla'
                                              : 'Zona seleccionada: $_zonaCampo',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                _JugadoresActivosSection(
                  titulo: '${partidoActual.equipoLocalNombre}',
                  jugadores: _jugadoresLocal,
                  seleccionadoEquipo: _equipoPrincipal,
                  seleccionadoDorsal: _dorsalPrincipal,
                  esperandoSecundario: _esperandoJugadorSecundario,
                  equipoClave: 'local',
                  onTap: _seleccionarJugadorSecundario,
                  getSancionEstado: _getSancionDesdeClave,
                ),
                const SizedBox(height: 8),
                _JugadoresActivosSection(
                  titulo: '${partidoActual.equipoVisitanteNombre}',
                  jugadores: _jugadoresVisitante,
                  seleccionadoEquipo: _equipoPrincipal,
                  seleccionadoDorsal: _dorsalPrincipal,
                  esperandoSecundario: _esperandoJugadorSecundario,
                  equipoClave: 'visitante',
                  onTap: _seleccionarJugadorSecundario,
                  getSancionEstado: _getSancionDesdeClave,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    if (_dorsalPrincipal == null || _equipoPrincipal == null) {
                      _mostrarSnackBar(
                        'Selecciona primero un jugador a sustituir',
                      );
                      return;
                    }

                    final cambioRealizado = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CambiosScreen(
                          partidoId: widget.partidoId,
                          equipo: _equipoPrincipal!,
                          dorsal: _dorsalPrincipal!,
                          datosAccionBase: _datosAccionBase(),
                          getSancionEstado: _getSancionDesdeClave,
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
    required this.tiempoListenable,
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
  final ValueListenable<String> tiempoListenable;
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
                    child: ValueListenableBuilder<String>(
                      valueListenable: tiempoListenable,
                      builder: (context, tiempo, _) {
                        return Text(
                          tiempo,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isPlaying
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                          ),
                        );
                      },
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

class _SeleccionarJugadorSecundarioPanel extends StatelessWidget {
  const _SeleccionarJugadorSecundarioPanel({
    required this.jugadoresLocal,
    required this.jugadoresVisitante,
    required this.equipoPrincipal,
    required this.dorsalPrincipal,
    this.accionSeleccionada,
    required this.nombreEquipoLocal,
    required this.nombreEquipoVisitante,
    required this.onJugadorSeleccionado,
    required this.getSancionEstado,
    Key? key,
  }) : super(key: key);

  final List<Map<String, dynamic>> jugadoresLocal;
  final List<Map<String, dynamic>> jugadoresVisitante;
  final String? equipoPrincipal;
  final int? dorsalPrincipal;
  final String? accionSeleccionada;
  final String nombreEquipoLocal;
  final String nombreEquipoVisitante;
  final Future<void> Function(String equipo, int dorsal) onJugadorSeleccionado;
  final SancionEstado? Function(String equipoClave, int dorsal) getSancionEstado;

  @override
  Widget build(BuildContext context) {
    Widget buildEquipo(String titulo, List<Map<String, dynamic>> jugadores, String equipoClave) {
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
            children: jugadores.map((jugador) {
              final dorsal = (jugador['dorsal'] as num?)?.toInt();
              if (dorsal == null) return const SizedBox.shrink();

              final esEquipoPrincipal = equipoClave == equipoPrincipal;
              final esDorsalPrincipal = esEquipoPrincipal && dorsalPrincipal == dorsal;
              final esPortero =
                  ((jugador['posicion'] as String?)?.toLowerCase() ?? '').contains('portero');
              final sancion = getSancionEstado(equipoClave, dorsal);
              final bool tiene2Activa = sancion?.tieneDosMinActiva ?? false;
              final bool expulsado = sancion?.expulsado ?? false;
              final baseColor = esPortero
                  ? Colors.lightBlue.shade200
                  : Colors.amber.shade100;

              final isDisabled =
                  (esEquipoPrincipal && !esDorsalPrincipal) || tiene2Activa || expulsado;
              final color = isDisabled
                  ? (esPortero ? baseColor : Colors.grey.shade300)
                  : baseColor;

              return GestureDetector(
                onTap: isDisabled ? null : () => onJugadorSeleccionado(equipoClave, dorsal),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 18,
                        child: Center(
                          child: buildSancionChips(sancion),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dorsal.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDisabled ? Colors.black45 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accionSeleccionada != null)
              Text(
                accionSeleccionada!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (accionSeleccionada != null) const SizedBox(height: 12),
            buildEquipo(nombreEquipoLocal, jugadoresLocal, 'local'),
            const SizedBox(height: 16),
            buildEquipo(nombreEquipoVisitante, jugadoresVisitante, 'visitante'),
          ],
        ),
      ),
    );
  }
}

class _JugadoresActivosSection extends StatelessWidget {
  const _JugadoresActivosSection({
    required this.titulo,
    required this.jugadores,
    required this.seleccionadoEquipo,
    required this.seleccionadoDorsal,
    required this.esperandoSecundario,
    required this.equipoClave,
    required this.onTap,
    required this.getSancionEstado,
  });

  final String titulo;
  final List<Map<String, dynamic>> jugadores;
  final String? seleccionadoEquipo;
  final int? seleccionadoDorsal;
  final bool esperandoSecundario;
  final String equipoClave;
  final Future<void> Function(String equipo, int dorsal) onTap;
  final SancionEstado? Function(String equipoClave, int dorsal) getSancionEstado;

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
          children: jugadores.map((jugador) {
            final dorsal = (jugador['dorsal'] as num?)?.toInt();
            if (dorsal == null) return const SizedBox.shrink();

            final isSelected = seleccionadoEquipo == equipoClave && seleccionadoDorsal == dorsal;
            final isEquipoPrincipal = seleccionadoEquipo == equipoClave;
            final esEquipoContrario = seleccionadoEquipo != null && seleccionadoEquipo != equipoClave;
            final esDorsalPrincipal = isEquipoPrincipal && seleccionadoDorsal == dorsal;
            final esPortero = jugadores.indexOf(jugador) == 0;
            final sancion = getSancionEstado(equipoClave, dorsal);
            final bool tiene2Activa = sancion?.tieneDosMinActiva ?? false;
            final bool expulsado = sancion?.expulsado ?? false;

            bool isDisabledBase = esperandoSecundario
                ? (esEquipoContrario ? false : !esDorsalPrincipal)
                : (isEquipoPrincipal && seleccionadoDorsal != null && seleccionadoDorsal != dorsal);

            final bool isDisabled = isDisabledBase || tiene2Activa || (expulsado && esperandoSecundario);

            final baseColor = esPortero
                ? (isSelected
                    ? Colors.lightBlue.shade400
                    : Colors.lightBlue.shade200)
                : (isSelected
                    ? Colors.amber.shade300
                    : Colors.amber.shade100);

            final color = isDisabled
                ? (esPortero ? baseColor : Colors.grey.shade300)
                : baseColor;

            return GestureDetector(
              onTap: isDisabled
                  ? null
                  : () {
                      onTap(equipoClave, dorsal);
                    },
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 18,
                      child: Center(
                        child: buildSancionChips(sancion),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                              ]
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
                  ],
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
