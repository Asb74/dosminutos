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
            final List<dynamic> convocadosRaw = widget.equipo == 'local'
                ? (data['convocadosLocal'] ?? [])
                : (data['convocadosVisitante'] ?? []);

            final jugadores = convocadosRaw
                .map(
                  (e) => JugadorConvocado.fromMap(
                    Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
                  ),
                )
                .toList();

            if (jugadores.isEmpty) {
              return const Center(child: Text('No hay jugadores disponibles.'));
            }

            final jugadorActual = jugadores.firstWhere(
              (j) => j.dorsal == widget.dorsal,
              orElse: () => jugadores.firstWhere(
                (j) => j.enJuego,
                orElse: () => jugadores.first,
              ),
            );

            final banquillo = jugadores
                .where((j) => !j.enJuego && j.dorsal != jugadorActual.dorsal)
                .toList();

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
                                      onTap: () =>
                                          _realizarCambio(jugador, jugadores),
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
                                                jugador.dorsal.toString(),
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
                                                    jugador.nombre.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    jugador.posicion,
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

  Future<void> _realizarCambio(
    JugadorConvocado entra,
    List<JugadorConvocado> jugadores,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection('Partidos')
        .doc(widget.partidoId);

    final actualIndex = jugadores.indexWhere((j) => j.dorsal == widget.dorsal);
    final entraIndex = jugadores.indexWhere((j) => j.dorsal == entra.dorsal);

    if (actualIndex == -1 || entraIndex == -1) return;

    final updated = List<JugadorConvocado>.from(jugadores);
    updated[actualIndex] = JugadorConvocado(
      dorsal: updated[actualIndex].dorsal,
      nombre: updated[actualIndex].nombre,
      posicion: updated[actualIndex].posicion,
      enJuego: false,
    );
    updated[entraIndex] = JugadorConvocado(
      dorsal: updated[entraIndex].dorsal,
      nombre: updated[entraIndex].nombre,
      posicion: updated[entraIndex].posicion,
      enJuego: true,
    );

    await docRef.update({
      widget.equipo == 'local'
          ? 'convocadosLocal'
          : 'convocadosVisitante':
          updated.map((j) => j.toMap()).toList(),
    });

    if (mounted) Navigator.of(context).pop();
  }
}

class JugadorConvocado {
  final int dorsal;
  final String nombre;
  final String posicion;
  final bool enJuego;

  JugadorConvocado({
    required this.dorsal,
    required this.nombre,
    required this.posicion,
    required this.enJuego,
  });

  factory JugadorConvocado.fromMap(Map<String, dynamic> map) {
    return JugadorConvocado(
      dorsal: (map['dorsal'] as num?)?.toInt() ?? 0,
      nombre: (map['nombre'] as String?) ?? '',
      posicion: (map['posicion'] as String?) ?? '',
      enJuego: map['enJuego'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dorsal': dorsal,
      'nombre': nombre,
      'posicion': posicion,
      'enJuego': enJuego,
    };
  }
}
