import 'package:flutter/material.dart';

class NuevoPartidoScreen extends StatelessWidget {
  const NuevoPartidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo partido'),
      ),
      body: const Center(
        child: Text('Texto placeholder explicando qué irá aquí.'),
      ),
    );
  }
}
