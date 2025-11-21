import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CambiosScreen extends StatefulWidget {
  final String partidoId;
  final String equipo; // 'local' o 'visitante'
  final int dorsal;
  final Map<String, dynamic> datosAccionBase;

  const CambiosScreen({
    Key? key,
    required this.partidoId,
    required this.equipo,
    required this.dorsal,
    required this.datosAccionBase,
  }) : super(key: key);

  @override
  State<CambiosScreen> createState() => _CambiosScreenState();
}

class _CambiosScreenState extends State<CambiosScreen> {
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
            final convocadosLocal = (data['convocadosLocal'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            final convocadosVisitante =
                (data['convocadosVisitante'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

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
                                    return InkWell(
                                      onTap: () => _hacerCambio(
                                        jugador,
                                        convocadosLocal,
                                        convocadosVisitante,
                                        jugadorActualIndex,
                                        esLocal,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: colorScheme.primary,
                                              child: Text(
                                                (jugador['dorsal'] as num?)
                                                        ?.toInt()
                                                        .toString() ??
                                                    '-',
                                                style: TextStyle(
                                                  color: colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
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

    await FirebaseFirestore.instance.collection('Partidos').doc(widget.partidoId).update({
      'convocadosLocal': nuevosConvocadosLocal,
      'convocadosVisitante': nuevosConvocadosVisitante,
    });

    if (mounted) Navigator.of(context).pop();
  }
}
