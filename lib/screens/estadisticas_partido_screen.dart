import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/estadisticas_service.dart';

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

class EstadisticasPartidoScreen extends StatelessWidget {
  final String partidoId;

  const EstadisticasPartidoScreen({
    Key? key,
    required this.partidoId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
      ),
      body: _EstadisticasBody(partidoId: partidoId),
    );
  }
}

class _EstadisticasBody extends StatelessWidget {
  final String partidoId;

  const _EstadisticasBody({
    required this.partidoId,
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Partidos')
          .doc(partidoId)
          .snapshots(),
      builder: (context, partidoSnapshot) {
        if (partidoSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (partidoSnapshot.hasError) {
          return Center(child: Text('Error: ${partidoSnapshot.error}'));
        }

        if (!partidoSnapshot.hasData || partidoSnapshot.data?.data() == null) {
          return const Center(
            child: Text('No se encontró la información del partido.'),
          );
        }

        final data = partidoSnapshot.data!.data()!;
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

        final mapaLocalPorDorsal =
            _mapearConvocadosPorDorsal(convocadosLocal);
        final mapaVisitantePorDorsal =
            _mapearConvocadosPorDorsal(convocadosVisitante);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ActaPartido')
              .doc(partidoId)
              .collection('Datos')
              .orderBy('timestamp')
              .snapshots(),
          builder: (context, datosSnapshot) {
            if (datosSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (datosSnapshot.hasError) {
              return Center(child: Text('Error: ${datosSnapshot.error}'));
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('ActaPartido')
                  .doc(partidoId)
                  .collection('Sanciones')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, sancionesSnapshot) {
                if (sancionesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (sancionesSnapshot.hasError) {
                  return Center(
                      child: Text('Error: ${sancionesSnapshot.error}'));
                }

                if (!datosSnapshot.hasData || !sancionesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = calcularEstadisticasPartidoDesdeSnapshots(
                  partidoData: data,
                  datosSnapshot: datosSnapshot.data!,
                  sancionesSnapshot: sancionesSnapshot.data!,
                );

                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: equipoLocalNombre),
                          Tab(text: equipoVisitanteNombre),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _EquipoStatsTab(
                              equipoId: equipoLocalId,
                              nombreEquipo: equipoLocalNombre,
                              stats: stats,
                              mapaConvocados: mapaLocalPorDorsal,
                              convocados: convocadosLocal,
                              tiemposJugados: tiemposJugados,
                            ),
                            _EquipoStatsTab(
                              equipoId: equipoVisitanteId,
                              nombreEquipo: equipoVisitanteNombre,
                              stats: stats,
                              mapaConvocados: mapaVisitantePorDorsal,
                              convocados: convocadosVisitante,
                              tiemposJugados: tiemposJugados,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EquipoStatsTab extends StatelessWidget {
  final String? equipoId;
  final String nombreEquipo;
  final PartidoStats stats;
  final Map<int, Map<String, dynamic>> mapaConvocados;
  final List<Map<String, dynamic>> convocados;
  final Map<String, int> tiemposJugados;

  const _EquipoStatsTab({
    Key? key,
    required this.equipoId,
    required this.nombreEquipo,
    required this.stats,
    required this.mapaConvocados,
    required this.convocados,
    required this.tiemposJugados,
  }) : super(key: key);

  String formatTiempo(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (equipoId == null) {
      return const Center(child: Text('Sin datos de equipo.'));
    }

    final statsPorDorsal = {
      for (final p in stats.jugadoresDeEquipo(equipoId!)) p.dorsal: p,
    };

    final jugadores = <StatsJugador>[];
    final dorsalesAgregados = <int>{};

    for (final jugador in convocados) {
      final dorsal = (jugador['dorsal'] as num?)?.toInt();
      if (dorsal == null) continue;
      final statsJugador =
          statsPorDorsal[dorsal] ?? StatsJugador(equipoId: equipoId!, dorsal: dorsal);

      statsJugador.nombre ??= jugador['nombre'] as String?;
      final posicionConv = (jugador['posicion'] as String?) ?? '';
      if (posicionConv.toLowerCase().contains('portero')) {
        statsJugador.esPortero = true;
      }

      final keyTiempo = '$equipoId#$dorsal';
      statsJugador.segsJugados = tiemposJugados[keyTiempo] ?? statsJugador.segsJugados;

      jugadores.add(statsJugador);
      dorsalesAgregados.add(dorsal);
    }

    for (final p in statsPorDorsal.values) {
      if (dorsalesAgregados.contains(p.dorsal)) continue;
      final keyTiempo = '$equipoId#${p.dorsal}';
      p.segsJugados = tiemposJugados[keyTiempo] ?? p.segsJugados;
      jugadores.add(p);
    }

    jugadores.sort((a, b) => a.dorsal.compareTo(b.dorsal));

    final resumen = stats.resumenEquipo(equipoId!);

    if (jugadores.isEmpty) {
      return const Center(child: Text('Sin convocados disponibles.'));
    }

    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen $nombreEquipo',
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
                      label: '7m',
                      value: '${resumen.goles7m}/${resumen.lanzamientos7m}',
                    ),
                    _ResumenChip(
                        label: 'Perdidas',
                        value: resumen.perdidas.toString()),
                    _ResumenChip(
                        label: 'Recup.',
                        value: resumen.recuperaciones.toString()),
                    _ResumenChip(
                        label: "2'", value: resumen.exclusiones2m.toString()),
                    _ResumenChip(
                        label: 'Amarillas',
                        value: resumen.amarillas.toString()),
                    _ResumenChip(
                        label: 'Rojas', value: resumen.rojas.toString()),
                    _ResumenChip(
                        label: 'Azules', value: resumen.azules.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
        ...jugadores.map((p) {
          final nombre = p.nombre ??
              _EstadisticasBody._nombreJugador(
                mapaConvocados,
                p.dorsal,
              );
          final posicion = _EstadisticasBody._posicionJugador(
            mapaConvocados,
            p.dorsal,
          );
          final esPortero = p.esPortero ||
              _EstadisticasBody._esPortero(
                mapaConvocados,
                p.dorsal,
              );
          final String keyTiempo = '$equipoId#${p.dorsal}';
          final int segundosJugados = tiemposJugados[keyTiempo] ?? 0;
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
                      color: esPortero
                          ? Colors.lightBlue.shade200
                          : Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.dorsal.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
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
                                value:
                                    '${p.goles6m}/${p.lanzamientos6m}',
                              ),
                              _StatChip(
                                label: '8m',
                                value:
                                    '${p.goles8m}/${p.lanzamientos8m}',
                              ),
                              _StatChip(
                                label: '9m',
                                value:
                                    '${p.goles9m}/${p.lanzamientos9m}',
                              ),
                              _StatChip(
                                label: '7m',
                                value:
                                    '${p.goles7m}/${p.lanzamientos7m}',
                              ),
                              _StatChip(
                                label: 'Perd',
                                value: '${p.perdidas}',
                              ),
                              _StatChip(
                                label: 'Rec',
                                value: '${p.recuperaciones}',
                              ),
                              _StatChip(
                                label: 'Golpe',
                                value: '${p.golpesCometidos}',
                              ),
                              _StatChip(
                                label: 'Prov.G',
                                value: '${p.golpesProvocados}',
                              ),
                              _StatChip(
                                label: "2'",
                                value: '${p.exclusiones2m}',
                              ),
                              _StatChip(
                                label: '🟨',
                                value: '${p.amarillas}',
                              ),
                              _StatChip(
                                label: '🟥',
                                value: '${p.rojas}',
                              ),
                              _StatChip(
                                label: '🟦',
                                value: '${p.azules}',
                              ),
                              if (esPortero) ...[
                                _StatChip(
                                  label: 'Par',
                                  value: '${p.paradas}',
                                ),
                                _StatChip(
                                  label: 'Enc',
                                  value: '${p.golesEncajados}',
                                ),
                                _StatChip(
                                  label: '%Par',
                                  value: p.lanzamientosRecibidos > 0
                                      ? '${(p.paradas * 100 / p.lanzamientosRecibidos).toStringAsFixed(1)}%'
                                      : '0%',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
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
