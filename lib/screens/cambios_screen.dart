import 'package:flutter/material.dart';

class CambiosScreen extends StatelessWidget {
  const CambiosScreen({
    super.key,
    required this.partidoId,
    required this.equipo,
    required this.dorsal,
    this.datosAccionBase,
  });

  final String partidoId;
  final String equipo;
  final int dorsal;
  final Map<String, dynamic>? datosAccionBase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambios'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cambios (pendiente de implementar)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text('Partido: $partidoId'),
              Text('Equipo: $equipo'),
              Text('Dorsal: $dorsal'),
              if (datosAccionBase != null) ...[
                const SizedBox(height: 12),
                const Text('Datos base capturados:'),
                Text(datosAccionBase.toString()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
