import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/estadisticas_service.dart';

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

        final convocadosLocal = (data['convocadosLocal'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
        final convocadosVisitante =
            (data['convocadosVisitante'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
                .toList();

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
                            ),
                            _EquipoStatsTab(
                              equipoId: equipoVisitanteId,
                              nombreEquipo: equipoVisitanteNombre,
                              stats: stats,
                              mapaConvocados: mapaVisitantePorDorsal,
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

  const _EquipoStatsTab({
    Key? key,
    required this.equipoId,
    required this.nombreEquipo,
    required this.stats,
    required this.mapaConvocados,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (equipoId == null) {
      return const Center(child: Text('Sin datos de equipo.'));
    }

    final jugadores = stats.jugadoresDeEquipo(equipoId!).toList()
      ..sort((a, b) => a.dorsal.compareTo(b.dorsal));

    final resumen = stats.resumenEquipo(equipoId!);

    if (jugadores.isEmpty) {
      return const Center(child: Text('Sin acciones registradas todavía.'));
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
                        value: resumen.lanzamientos.toString()),
                    _ResumenChip(
                        label: 'Goles', value: resumen.goles.toString()),
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
                        label: "2'", value: resumen.suspensiones2Min.toString()),
                    _ResumenChip(
                        label: 'Amarillas',
                        value: resumen.tarjetasAmarillas.toString()),
                    _ResumenChip(
                        label: 'Rojas',
                        value: resumen.tarjetasRojas.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
        ...jugadores.map((p) {
          final nombre = _EstadisticasBody._nombreJugador(
            mapaConvocados,
            p.dorsal,
          );
          final posicion = _EstadisticasBody._posicionJugador(
            mapaConvocados,
            p.dorsal,
          );
          final esPortero = _EstadisticasBody._esPortero(
            mapaConvocados,
            p.dorsal,
          );
          final acierto = p.lanzamientos == 0
              ? '0.0%'
              : '${(p.porcentajeAcierto * 100).toStringAsFixed(1)}%';

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
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _MiniStat(
                              label: 'G/L',
                              value:
                                  '${p.goles}/${p.lanzamientos} ($acierto)',
                            ),
                            _MiniStat(
                              label: '7m',
                              value: '${p.goles7m}/${p.lanzamientos7m}',
                            ),
                            _MiniStat(
                              label: 'Perd',
                              value: p.perdidas.toString(),
                            ),
                            _MiniStat(
                              label: 'Rec',
                              value: p.recuperaciones.toString(),
                            ),
                            if (esPortero)
                              _MiniStat(
                                label: 'Paradas',
                                value:
                                    '${p.paradas}/${p.lanzamientosRecibidos}',
                              ),
                            _MiniStat(
                              label: "2'",
                              value: p.suspensiones2Min.toString(),
                            ),
                            if (p.tarjetasAmarillas > 0)
                              _MiniStat(
                                label: 'Amarillas',
                                value: p.tarjetasAmarillas.toString(),
                              ),
                            if (p.tarjetasRojas > 0)
                              _MiniStat(
                                label: 'Rojas',
                                value: p.tarjetasRojas.toString(),
                              ),
                          ],
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({
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
