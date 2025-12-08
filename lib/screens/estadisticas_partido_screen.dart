import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/estadisticas_service.dart';
import '../services/puesto_color_service.dart';

List<Map<String, dynamic>> _convocadosOrdenados(
  Map<String, dynamic> data, {
  required bool esLocal,
}) {
  final key = esLocal ? 'convocadosLocal' : 'convocadosVisitante';
  final lista = (data[key] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  lista.sort((a, b) {
    final da = (a['dorsal'] as num?)?.toInt() ?? 0;
    final db = (b['dorsal'] as num?)?.toInt() ?? 0;
    return da.compareTo(db);
  });

  return lista;
}

class EstadisticasPartidoScreen extends StatefulWidget {
  final String partidoId;

  const EstadisticasPartidoScreen({
    Key? key,
    required this.partidoId,
  }) : super(key: key);

  @override
  State<EstadisticasPartidoScreen> createState() =>
      _EstadisticasPartidoScreenState();
}

class _EstadisticasPartidoScreenState extends State<EstadisticasPartidoScreen> {
  final ScrollController _scrollLocalVertical = ScrollController();
  final ScrollController _scrollVisitVertical = ScrollController();
  final ScrollController _scrollLocalHorizontal = ScrollController();
  final ScrollController _scrollVisitHorizontal = ScrollController();

  Map<String, dynamic>? _lastPartidoData;
  late final Future<Map<String, Color>> _coloresFuture;
  final Color _colorPorDefecto = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _coloresFuture = cargarMapaColoresPuesto();
  }

  @override
  void dispose() {
    _scrollLocalVertical.dispose();
    _scrollVisitVertical.dispose();
    _scrollLocalHorizontal.dispose();
    _scrollVisitHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Color>>(
      future: _coloresFuture,
      builder: (context, colorSnapshot) {
        if (colorSnapshot.connectionState == ConnectionState.waiting &&
            !colorSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Estadísticas'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final coloresPorPuesto = colorSnapshot.data ?? {};

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Estadísticas'),
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('Partidos')
                        .doc(widget.partidoId)
                        .snapshots(),
                    builder: (context, partidoSnapshot) {
                      if (partidoSnapshot.hasError) {
                        return Center(
                            child: Text('Error: ${partidoSnapshot.error}'));
                      }

                      if (partidoSnapshot.hasData &&
                          partidoSnapshot.data!.data() != null) {
                        _lastPartidoData = partidoSnapshot.data!.data();
                      }

                      if (_lastPartidoData == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = _lastPartidoData!;

                      return _EstadisticasBody(
                        partidoId: widget.partidoId,
                        partidoData: data,
                        scrollLocal: _scrollLocalVertical,
                        scrollVisit: _scrollVisitVertical,
                        scrollHorizontalLocal: _scrollLocalHorizontal,
                        scrollHorizontalVisit: _scrollVisitHorizontal,
                        coloresPorPuesto: coloresPorPuesto,
                        colorPorDefecto: _colorPorDefecto,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EstadisticasBody extends StatelessWidget {
  final String partidoId;
  final Map<String, dynamic> partidoData;
  final ScrollController scrollLocal;
  final ScrollController scrollVisit;
  final ScrollController scrollHorizontalLocal;
  final ScrollController scrollHorizontalVisit;
  final Map<String, Color> coloresPorPuesto;
  final Color colorPorDefecto;

  const _EstadisticasBody({
    required this.partidoId,
    required this.partidoData,
    required this.scrollLocal,
    required this.scrollVisit,
    required this.scrollHorizontalLocal,
    required this.scrollHorizontalVisit,
    required this.coloresPorPuesto,
    required this.colorPorDefecto,
  });

  static Map<int, Map<String, dynamic>> _mapearConvocadosPorDorsal(
      List<Map<String, dynamic>> lista) {
    final mapa = <int, Map<String, dynamic>>{};
    for (final j in lista) {
      final dorsal = (j['dorsal'] as num?)?.toInt();
      if (dorsal != null) {
        mapa[dorsal] = j;
      }
    }
    return mapa;
  }

  static String _nombreJugador(
      Map<int, Map<String, dynamic>> mapa, int dorsal) {
    final j = mapa[dorsal];
    if (j == null) return '#$dorsal';
    return (j['nombre'] as String? ?? '#$dorsal');
  }

  static String _posicionJugador(
      Map<int, Map<String, dynamic>> mapa, int dorsal) {
    final j = mapa[dorsal];
    return (j?['posicion'] as String?) ?? '';
  }

  static bool _esPortero(Map<int, Map<String, dynamic>> mapa, int dorsal) {
    final pos = _posicionJugador(mapa, dorsal).toLowerCase();
    return pos.contains('portero');
  }

  @override
  Widget build(BuildContext context) {
    final data = partidoData;
    final equipoLocalId = data['equipoLocalId'] as String?;
    final equipoVisitanteId = data['equipoVisitanteId'] as String?;
    final equipoLocalNombre =
        (data['equipoLocalNombre'] as String?) ?? 'Equipo local';
    final equipoVisitanteNombre =
        (data['equipoVisitanteNombre'] as String?) ?? 'Equipo visitante';

    final tiemposJugadosRaw =
        data['tiemposJugados'] as Map<String, dynamic>? ?? {};
    final Map<String, int> tiemposJugados = tiemposJugadosRaw.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    final convocadosLocal = _convocadosOrdenados(data, esLocal: true);
    final convocadosVisitante = _convocadosOrdenados(data, esLocal: false);

    final mapaLocalPorDorsal = _mapearConvocadosPorDorsal(convocadosLocal);
    final mapaVisitantePorDorsal =
        _mapearConvocadosPorDorsal(convocadosVisitante);

    return Column(
      children: [
        TabBar(
          tabs: [
            Tab(text: equipoLocalNombre),
            Tab(text: equipoVisitanteNombre),
          ],
        ),
        Expanded(
          child: _EstadisticasStreams(
            partidoId: partidoId,
            partidoData: data,
            equipoLocalId: equipoLocalId,
            equipoVisitanteId: equipoVisitanteId,
            equipoLocalNombre: equipoLocalNombre,
            equipoVisitanteNombre: equipoVisitanteNombre,
            mapaLocalPorDorsal: mapaLocalPorDorsal,
            mapaVisitantePorDorsal: mapaVisitantePorDorsal,
            convocadosLocal: convocadosLocal,
            convocadosVisitante: convocadosVisitante,
            tiemposJugados: tiemposJugados,
            scrollLocal: scrollLocal,
            scrollVisit: scrollVisit,
            scrollHorizontalLocal: scrollHorizontalLocal,
            scrollHorizontalVisit: scrollHorizontalVisit,
            coloresPorPuesto: coloresPorPuesto,
            colorPorDefecto: colorPorDefecto,
          ),
        ),
      ],
    );
  }
}

class _EstadisticasStreams extends StatefulWidget {
  final String partidoId;
  final Map<String, dynamic> partidoData;
  final String? equipoLocalId;
  final String? equipoVisitanteId;
  final String equipoLocalNombre;
  final String equipoVisitanteNombre;
  final Map<int, Map<String, dynamic>> mapaLocalPorDorsal;
  final Map<int, Map<String, dynamic>> mapaVisitantePorDorsal;
  final List<Map<String, dynamic>> convocadosLocal;
  final List<Map<String, dynamic>> convocadosVisitante;
  final Map<String, int> tiemposJugados;
  final ScrollController scrollLocal;
  final ScrollController scrollVisit;
  final ScrollController scrollHorizontalLocal;
  final ScrollController scrollHorizontalVisit;
  final Map<String, Color> coloresPorPuesto;
  final Color colorPorDefecto;

  const _EstadisticasStreams({
    required this.partidoId,
    required this.partidoData,
    required this.equipoLocalId,
    required this.equipoVisitanteId,
    required this.equipoLocalNombre,
    required this.equipoVisitanteNombre,
    required this.mapaLocalPorDorsal,
    required this.mapaVisitantePorDorsal,
    required this.convocadosLocal,
    required this.convocadosVisitante,
    required this.tiemposJugados,
    required this.scrollLocal,
    required this.scrollVisit,
    required this.scrollHorizontalLocal,
    required this.scrollHorizontalVisit,
    required this.coloresPorPuesto,
    required this.colorPorDefecto,
  });

  @override
  State<_EstadisticasStreams> createState() => _EstadisticasStreamsState();
}

class _EstadisticasStreamsState extends State<_EstadisticasStreams> {
  QuerySnapshot<Map<String, dynamic>>? _lastEstadisticasSnapshot;
  QuerySnapshot<Map<String, dynamic>>? _lastSancionesSnapshot;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ActaPartido')
          .doc(widget.partidoId)
          .collection('Estadisticas')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, estadisticasSnapshot) {
        if (estadisticasSnapshot.hasError) {
          return Center(child: Text('Error: ${estadisticasSnapshot.error}'));
        }

        if (estadisticasSnapshot.hasData && estadisticasSnapshot.data != null) {
          _lastEstadisticasSnapshot = estadisticasSnapshot.data;
        }

        if (_lastEstadisticasSnapshot == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ActaPartido')
              .doc(widget.partidoId)
              .collection('Sanciones')
              .orderBy('timestamp')
              .snapshots(),
          builder: (context, sancionesSnapshot) {
            if (sancionesSnapshot.hasError) {
              return Center(child: Text('Error: ${sancionesSnapshot.error}'));
            }

            if (sancionesSnapshot.hasData && sancionesSnapshot.data != null) {
              _lastSancionesSnapshot = sancionesSnapshot.data;
            }

            if (_lastSancionesSnapshot == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return FutureBuilder<PartidoStats>(
              future: calcularEstadisticasPartidoDesdeSnapshots(
                partidoData: widget.partidoData,
                datosSnapshot: _lastEstadisticasSnapshot!,
                sancionesSnapshot: _lastSancionesSnapshot!,
              ),
              builder: (context, statsSnapshot) {
                if (statsSnapshot.hasError) {
                  return Center(
                    child: Text('Error: ${statsSnapshot.error}'),
                  );
                }

                if (!statsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = statsSnapshot.data!;

                return TabBarView(
                  children: [
                    _EquipoStatsTab(
                      equipoId: widget.equipoLocalId,
                      nombreEquipo: widget.equipoLocalNombre,
                      stats: stats,
                      mapaConvocados: widget.mapaLocalPorDorsal,
                      convocados: widget.convocadosLocal,
                      tiemposJugados: widget.tiemposJugados,
                      scrollController: widget.scrollLocal,
                      horizontalController: widget.scrollHorizontalLocal,
                      coloresPorPuesto: widget.coloresPorPuesto,
                      colorPorDefecto: widget.colorPorDefecto,
                      esLocal: true,
                    ),
                    _EquipoStatsTab(
                      equipoId: widget.equipoVisitanteId,
                      nombreEquipo: widget.equipoVisitanteNombre,
                      stats: stats,
                      mapaConvocados: widget.mapaVisitantePorDorsal,
                      convocados: widget.convocadosVisitante,
                      tiemposJugados: widget.tiemposJugados,
                      scrollController: widget.scrollVisit,
                      horizontalController: widget.scrollHorizontalVisit,
                      coloresPorPuesto: widget.coloresPorPuesto,
                      colorPorDefecto: widget.colorPorDefecto,
                      esLocal: false,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EquipoStatsTab extends StatefulWidget {
  final String? equipoId;
  final String nombreEquipo;
  final PartidoStats stats;
  final Map<int, Map<String, dynamic>> mapaConvocados;
  final List<Map<String, dynamic>> convocados;
  final Map<String, int> tiemposJugados;
  final ScrollController scrollController;
  final ScrollController horizontalController;
  final bool esLocal;
  final Map<String, Color> coloresPorPuesto;
  final Color colorPorDefecto;

  const _EquipoStatsTab({
    Key? key,
    required this.equipoId,
    required this.nombreEquipo,
    required this.stats,
    required this.mapaConvocados,
    required this.convocados,
    required this.tiemposJugados,
    required this.scrollController,
    required this.horizontalController,
    required this.esLocal,
    required this.coloresPorPuesto,
    required this.colorPorDefecto,
  }) : super(key: key);

  @override
  State<_EquipoStatsTab> createState() => _EquipoStatsTabState();
}

class _EquipoStatsTabState extends State<_EquipoStatsTab>
    with AutomaticKeepAliveClientMixin {
  final Map<int, ScrollController> _horizontalControllersPorJugador = {};

  @override
  bool get wantKeepAlive => true;

  ScrollController _horizontalControllerParaJugador(int dorsal) {
    if (_horizontalControllersPorJugador.containsKey(dorsal)) {
      return _horizontalControllersPorJugador[dorsal]!;
    }

    if (_horizontalControllersPorJugador.isEmpty) {
      _horizontalControllersPorJugador[dorsal] = widget.horizontalController;
      return widget.horizontalController;
    }

    final controller = ScrollController();
    _horizontalControllersPorJugador[dorsal] = controller;
    return controller;
  }

  @override
  void dispose() {
    for (final controller in _horizontalControllersPorJugador.values) {
      if (controller != widget.horizontalController) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Color _colorParaJugador(int dorsal) {
    final datosJugador = widget.mapaConvocados[dorsal];
    final puesto = ((datosJugador?['posicionAtaque'] as String?) ??
            (datosJugador?['posicion'] as String?) ??
            '')
        .trim();
    if (puesto.isEmpty) return widget.colorPorDefecto;
    return widget.coloresPorPuesto[puesto] ?? widget.colorPorDefecto;
  }

  Color _textoPara(Color fondo) =>
      ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark
          ? Colors.white
          : Colors.black87;

  String formatTiempo(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _contadorJugador(StatsJugador jugador, String clave) {
    return jugador.contadores[clave] ?? 0;
  }

  int _contadorResumen(ResumenEquipo resumen, String clave) {
    return resumen.contadores[clave] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.equipoId == null) {
      return const Center(child: Text('Sin datos de equipo.'));
    }

    final statsPorDorsal = {
      for (final p in widget.stats.jugadoresDeEquipo(widget.equipoId!))
        p.dorsal: p,
    };

    final jugadores = <StatsJugador>[];
    final dorsalesAgregados = <int>{};

    for (final jugador in widget.convocados) {
      final dorsal = (jugador['dorsal'] as num?)?.toInt();
      if (dorsal == null) continue;
      final statsJugador =
          statsPorDorsal[dorsal] ??
              StatsJugador(equipoId: widget.equipoId!, dorsal: dorsal);

      statsJugador.nombre ??= jugador['nombre'] as String?;
      final posicionConv = (jugador['posicion'] as String?) ?? '';
      if (posicionConv.toLowerCase().contains('portero')) {
        statsJugador.esPortero = true;
      }

      final keyTiempo = '${widget.equipoId}#$dorsal';
      statsJugador.segsJugados =
          widget.tiemposJugados[keyTiempo] ?? statsJugador.segsJugados;

      jugadores.add(statsJugador);
      dorsalesAgregados.add(dorsal);
    }

    for (final p in statsPorDorsal.values) {
      if (dorsalesAgregados.contains(p.dorsal)) continue;
      final keyTiempo = '${widget.equipoId}#${p.dorsal}';
      p.segsJugados = widget.tiemposJugados[keyTiempo] ?? p.segsJugados;
      jugadores.add(p);
    }

    jugadores.sort((a, b) => a.dorsal.compareTo(b.dorsal));

    final resumen = widget.stats.resumenEquipo(widget.equipoId!);

    if (jugadores.isEmpty) {
      return const Center(child: Text('Sin convocados disponibles.'));
    }

    return ListView.builder(
      key:
          PageStorageKey<String>(widget.esLocal ? 'stats_local' : 'stats_visitante'),
      controller: widget.scrollController,
      itemCount: jugadores.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen ${widget.nombreEquipo}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _ResumenChip(
                          label: 'Lanzamientos',
                          value: resumen.lanzamientosTotales.toString()),
                      _ResumenChip(
                          label: 'Goles',
                          value: resumen.golesTotales.toString()),
                      _ResumenChip(
                        label: 'Acierto',
                        value:
                            '${(resumen.porcentajeAcierto * 100).toStringAsFixed(1)}%',
                      ),
                      _ResumenChip(
                        label: '6m',
                        value: '${resumen.goles6m}/${resumen.lanzamientos6m}',
                      ),
                      _ResumenChip(
                        label: '8m',
                        value: '${resumen.goles8m}/${resumen.lanzamientos8m}',
                      ),
                      _ResumenChip(
                        label: '9m',
                        value: '${resumen.goles9m}/${resumen.lanzamientos9m}',
                      ),
                      _ResumenChip(
                        label: '7m',
                        value: '${resumen.goles7m}/${resumen.lanzamientos7m}',
                      ),
                      _ResumenChip(
                        label: 'Línea',
                        value: _contadorResumen(resumen, 'Linea').toString(),
                      ),
                      _ResumenChip(
                          label: 'Perdidas',
                          value:
                              _contadorResumen(resumen, 'Perdida Posesión')
                                  .toString()),
                      _ResumenChip(
                          label: 'Recup.',
                          value:
                              _contadorResumen(resumen, 'Recuperación Posesión')
                                  .toString()),
                      _ResumenChip(
                        label: "2'",
                        value: _contadorResumen(resumen, '2 minutos')
                            .toString(),
                      ),
                      _ResumenChip(
                          label: 'Amarillas',
                          value: _contadorResumen(resumen, 'Tarjeta Amarilla')
                              .toString()),
                      _ResumenChip(
                          label: 'Rojas',
                          value:
                              _contadorResumen(resumen, 'Tarjeta Roja').toString()),
                      _ResumenChip(
                          label: 'Azules',
                          value:
                              _contadorResumen(resumen, 'Tarjeta Azul').toString()),
                      _ResumenChip(
                        label: 'Asist.',
                        value: _contadorResumen(resumen, 'Asistencia').toString(),
                      ),
                      _ResumenChip(
                        label: 'Golpes',
                        value: _contadorResumen(resumen, 'Golpe').toString(),
                      ),
                      _ResumenChip(
                        label: 'Paradas',
                        value: _contadorResumen(resumen, 'Parada').toString(),
                      ),
                      _ResumenChip(
                        label: 'G.Encaj',
                        value:
                            _contadorResumen(resumen, 'Gol Encajado').toString(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final p = jugadores[index - 1];
        final nombre = p.nombre ??
            _EstadisticasBody._nombreJugador(
              widget.mapaConvocados,
              p.dorsal,
            );
        final posicion = _EstadisticasBody._posicionJugador(
          widget.mapaConvocados,
          p.dorsal,
        );
        final baseColor = _colorParaJugador(p.dorsal);
        final textColor = _textoPara(baseColor);
        final String keyTiempo = '${widget.equipoId}#${p.dorsal}';
        final int segundosJugados = widget.tiemposJugados[keyTiempo] ?? 0;
        final acierto = p.lanzamientosTotales == 0
            ? '0.0%'
            : '${(p.golesTotales * 100 / p.lanzamientosTotales).toStringAsFixed(1)}%';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.dorsal.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (posicion.isNotEmpty)
                        Text(
                          posicion,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        key: PageStorageKey<String>(
                            'stats_${widget.esLocal ? 'local' : 'visitante'}_${p.dorsal}'),
                        scrollDirection: Axis.horizontal,
                        controller: _horizontalControllerParaJugador(p.dorsal),
                        child: Row(
                          children: () {
                            final perdidas =
                                _contadorJugador(p, 'Perdida Posesión');
                            final recuperaciones =
                                _contadorJugador(p, 'Recuperación Posesión');
                            final golpes = _contadorJugador(p, 'Golpe');
                            final asistencias =
                                _contadorJugador(p, 'Asistencia');
                            final lineas = _contadorJugador(p, 'Linea');
                            final exclusiones = _contadorJugador(p, '2 minutos');
                            final amarillas =
                                _contadorJugador(p, 'Tarjeta Amarilla');
                            final rojas = _contadorJugador(p, 'Tarjeta Roja');
                            final azules = _contadorJugador(p, 'Tarjeta Azul');
                            final paradas = _contadorJugador(p, 'Parada');
                            final golesEncajados =
                                _contadorJugador(p, 'Gol Encajado');

                            final chips = <Widget>[
                              _StatChip(
                                label: 'Tiempo',
                                value: formatTiempo(segundosJugados),
                              ),
                              _StatChip(
                                label: 'G/L',
                                value:
                                    '${p.golesTotales}/${p.lanzamientosTotales} ($acierto)',
                              ),
                              _StatChip(
                                label: '6m',
                                value: '${p.goles6m}/${p.lanzamientos6m}',
                              ),
                              _StatChip(
                                label: '8m',
                                value: '${p.goles8m}/${p.lanzamientos8m}',
                              ),
                              _StatChip(
                                label: '9m',
                                value: '${p.goles9m}/${p.lanzamientos9m}',
                              ),
                              _StatChip(
                                label: '7m',
                                value: '${p.goles7m}/${p.lanzamientos7m}',
                              ),
                              _StatChip(
                                label: 'Línea',
                                value: '$lineas',
                              ),
                              _StatChip(
                                label: 'Perd',
                                value: '$perdidas',
                              ),
                              _StatChip(
                                label: 'Rec',
                                value: '$recuperaciones',
                              ),
                              _StatChip(
                                label: 'Golpe',
                                value: '$golpes',
                              ),
                              _StatChip(
                                label: 'Asist.',
                                value: '$asistencias',
                              ),
                              _StatChip(
                                label: "2'",
                                value: '$exclusiones',
                              ),
                              _StatChip(
                                label: '🟨',
                                value: '$amarillas',
                              ),
                              _StatChip(
                                label: '🟥',
                                value: '$rojas',
                              ),
                              _StatChip(
                                label: '🟦',
                                value: '$azules',
                              ),
                            ];

                            if (esPortero) {
                              chips.addAll([
                                _StatChip(
                                  label: 'Paradas',
                                  value: '$paradas',
                                ),
                                _StatChip(
                                  label: 'G.Encaj',
                                  value: '$golesEncajados',
                                ),
                                _StatChip(
                                  label: '%Par',
                                  value: p.lanzamientosRecibidos > 0
                                      ? '${(paradas * 100 / p.lanzamientosRecibidos).toStringAsFixed(1)}%'
                                      : '0%',
                                ),
                              ]);
                            }

                            return chips;
                          }(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResumenChip extends StatelessWidget {
  final String label;
  final String value;

  const _ResumenChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
