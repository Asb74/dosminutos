import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/sanciones_widgets.dart';

class CambiosScreen extends StatefulWidget {
  final String partidoId;
  final String equipo; // 'local' o 'visitante'
  final int dorsal;
  final Map<String, dynamic> datosAccionBase;
  final SancionEstado? Function(String equipoClave, int dorsal)? getSancionEstado;

  const CambiosScreen({
    Key? key,
    required this.partidoId,
    required this.equipo,
    required this.dorsal,
    required this.datosAccionBase,
    this.getSancionEstado,
  }) : super(key: key);

  @override
  State<CambiosScreen> createState() => _CambiosScreenState();
}

class _CambiosScreenState extends State<CambiosScreen> {
  List<int> _parseJugadoresEnJuego(dynamic raw) {
    final lista = raw is List ? raw : <dynamic>[];

    return lista
        .map<int?>((item) {
          if (item is num) return item.toInt();
          if (item is Map<String, dynamic>) {
            return (item['dorsal'] as num?)?.toInt();
          }
          return null;
        })
        .whereType<int>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partido en juego'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('Partidos')
              .doc(widget.partidoId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text('No se encontró la información del partido.'),
              );
            }

            final data = snapshot.data!.data()!;
            final equipoLocalId = data['equipoLocalId'] as String?;
            final equipoVisitanteId = data['equipoVisitanteId'] as String?;
            final convocadosLocal = (data['convocadosLocal'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            final convocadosVisitante =
                (data['convocadosVisitante'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

            final jugadoresEnJuegoLocal =
                _parseJugadoresEnJuego(data['jugadoresEnJuegoLocal']);
            final jugadoresEnJuegoVisitante =
                _parseJugadoresEnJuego(data['jugadoresEnJuegoVisitante']);

            final esLocal = widget.equipo == 'local';
            final List<Map<String, dynamic>> convocados =
                esLocal ? convocadosLocal : convocadosVisitante;

            if (convocados.isEmpty) {
              return const Center(child: Text('No hay jugadores disponibles.'));
            }

            final banquillo =
                convocados.where((j) => (j['enJuego'] ?? false) != true).toList();

            final dorsalActual = widget.dorsal;
            final jugadorActualIndex = convocados.indexWhere(
              (j) => (j['dorsal'] as num?)?.toInt() == dorsalActual,
            );

            final jugadorActualEnJuego = jugadorActualIndex >= 0 &&
                (convocados[jugadorActualIndex]['enJuego'] ?? false) == true;

            if (!jugadorActualEnJuego) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, size: 36, color: Colors.orange),
                      SizedBox(height: 12),
                      Text(
                        'No se puede realizar el cambio porque el jugador seleccionado no está en juego.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('ActaPartido')
                  .doc(widget.partidoId)
                  .collection('Sanciones')
                  .snapshots(),
              builder: (context, sancionesSnapshot) {
                if (sancionesSnapshot.connectionState == ConnectionState.waiting &&
                    !sancionesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sancionesMap = <String, SancionEstado>{};

                if (sancionesSnapshot.hasData) {
                  for (final doc in sancionesSnapshot.data!.docs) {
                    final sancionData = doc.data();
                    final equipoId = sancionData['equipoId'] as String?;
                    final dorsalSancion = (sancionData['dorsal'] as num?)?.toInt();
                    final tipo = sancionData['tipo'] as String?;

                    if (equipoId == null || dorsalSancion == null || tipo == null) continue;

                    final key = '$equipoId#$dorsalSancion';
                    final estado = sancionesMap.putIfAbsent(key, () => SancionEstado());

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
                }

                SancionEstado? obtenerSancionEstado(int dorsalJugador) {
                  if (widget.getSancionEstado != null) {
                    return widget.getSancionEstado!(widget.equipo, dorsalJugador);
                  }

                  final equipoId = widget.equipo == 'local' ? equipoLocalId : equipoVisitanteId;
                  if (equipoId == null) return null;

                  return sancionesMap['$equipoId#$dorsalJugador'];
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.equipo == 'local'
                                      ? 'Convocados (local)'
                                      : 'Convocados (visitante)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                if (banquillo.isEmpty)
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        'No hay jugadores en el banquillo para este equipo.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: banquillo.length,
                                      separatorBuilder: (_, __) => const Divider(height: 16),
                                      itemBuilder: (context, index) {
                                        final jugador = banquillo[index];
                                        final dorsalJugador =
                                            (jugador['dorsal'] as num?)?.toInt();

                                        if (dorsalJugador == null) {
                                          return const SizedBox.shrink();
                                        }

                                        final sancion = obtenerSancionEstado(dorsalJugador);
                                        final bool expulsado = sancion?.expulsado ?? false;
                                        final bool tiene2Activa = sancion?.tieneDosMinActiva ?? false;

                                        final bool isDisabled = expulsado || tiene2Activa;

                                        final avatarColor = isDisabled
                                            ? colorScheme.primary.withOpacity(0.35)
                                            : colorScheme.primary;
                                        final textColor = isDisabled
                                            ? colorScheme.onPrimary.withOpacity(0.5)
                                            : colorScheme.onPrimary;

                                        return InkWell(
                                          onTap: isDisabled
                                              ? null
                                              : () => _hacerCambio(
                                                    jugador,
                                                    convocadosLocal,
                                                    convocadosVisitante,
                                                    jugadorActualIndex,
                                                    esLocal,
                                                    jugadoresEnJuegoLocal,
                                                    jugadoresEnJuegoVisitante,
                                                  ),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 56,
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      SizedBox(
                                                        height: 18,
                                                        child: Center(
                                                          child: buildSancionChips(sancion),
                                                        ),
                                                      ),
                                                      CircleAvatar(
                                                        radius: 24,
                                                        backgroundColor: avatarColor,
                                                        child: Text(
                                                          dorsalJugador.toString(),
                                                          style: TextStyle(
                                                            color: textColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        (jugador['nombre'] as String? ?? '')
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        jugador['posicion'] as String? ?? '',
                                                        style: TextStyle(
                                                          color: Colors.grey.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _hacerCambio(
    Map<String, dynamic> jugadorEntrante,
    List<Map<String, dynamic>> convocadosLocal,
    List<Map<String, dynamic>> convocadosVisitante,
    int jugadorActualIndex,
    bool esLocal,
    List<int> jugadoresEnJuegoLocal,
    List<int> jugadoresEnJuegoVisitante,
  ) async {
    if (jugadorActualIndex < 0) {
      // Si el jugador actual no está en el array, no hacemos nada.
      return;
    }

    final nuevosConvocadosLocal = convocadosLocal
        .map((j) => Map<String, dynamic>.from(j))
        .toList(growable: false);

    final nuevosConvocadosVisitante = convocadosVisitante
        .map((j) => Map<String, dynamic>.from(j))
        .toList(growable: false);

    final seleccionados = esLocal ? nuevosConvocadosLocal : nuevosConvocadosVisitante;

    seleccionados[jugadorActualIndex]['enJuego'] = false;

    final dorsalEntrante = (jugadorEntrante['dorsal'] as num?)?.toInt();
    final idxEntrante = seleccionados.indexWhere(
      (j) => (j['dorsal'] as num?)?.toInt() == dorsalEntrante,
    );

    if (idxEntrante >= 0) {
      seleccionados[idxEntrante]['enJuego'] = true;
    }

    final jugadoresEnJuego =
        esLocal ? List<int>.from(jugadoresEnJuegoLocal) : List<int>.from(jugadoresEnJuegoVisitante);

    if (dorsalEntrante != null && jugadoresEnJuego.isNotEmpty) {
      final idxActualEnJuego = jugadoresEnJuego.indexOf(widget.dorsal);

      if (idxActualEnJuego >= 0) {
        final posicionEntrante =
            (jugadorEntrante['posicion'] as String? ?? '').toLowerCase();
        final esPorteroEntrante = posicionEntrante == 'portero';

        if (esPorteroEntrante) {
          final temp = jugadoresEnJuego[0];
          jugadoresEnJuego[0] = dorsalEntrante;
          if (idxActualEnJuego < jugadoresEnJuego.length) {
            jugadoresEnJuego[idxActualEnJuego] = temp;
          }
        } else if (idxActualEnJuego == 0) {
          jugadoresEnJuego[0] = dorsalEntrante;
        } else if (idxActualEnJuego < jugadoresEnJuego.length) {
          jugadoresEnJuego[idxActualEnJuego] = dorsalEntrante;
        }
      }
    }

    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'convocadosLocal': nuevosConvocadosLocal,
      'convocadosVisitante': nuevosConvocadosVisitante,
      'jugadoresEnJuegoLocal': esLocal ? jugadoresEnJuego : jugadoresEnJuegoLocal,
      'jugadoresEnJuegoVisitante': esLocal ? jugadoresEnJuegoVisitante : jugadoresEnJuego,
    });

    if (mounted) Navigator.of(context).pop(true);
  }
}
