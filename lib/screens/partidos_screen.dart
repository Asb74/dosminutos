import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/partido.dart';
import 'partido_en_juego_screen.dart';

class PartidosScreen extends StatelessWidget {
  const PartidosScreen({Key? key}) : super(key: key);

  Color _estadoColor(String estado, ColorScheme colorScheme) {
    switch (estado) {
      case 'EnJuego':
        return Colors.green.shade200;
      case 'Finalizado':
        return Colors.red.shade200;
      default:
        return colorScheme.surfaceVariant;
    }
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partidos'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Partidos')
            .orderBy('fechaHora', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar partidos: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No hay partidos registrados.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index];
              final partido = Partido.fromDoc(data.id, data.data());
              final fechaFormateada = _formatearFecha(partido.fechaHora);
              final chipColor = _estadoColor(partido.estado, colorScheme);

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    '${partido.equipoLocalNombre} vs ${partido.equipoVisitanteNombre}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${partido.campeonatoNombre} · $fechaFormateada'),
                      const SizedBox(height: 4),
                      Text(
                        'Marcador: ${partido.golesLocal} - ${partido.golesVisitante} · Estado: ${partido.estado}',
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(partido.estado),
                    backgroundColor: chipColor,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PartidoEnJuegoScreen(
                          partidoId: data.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
