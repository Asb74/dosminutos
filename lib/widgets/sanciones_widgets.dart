import 'package:flutter/material.dart';

enum SancionVisualTipo {
  ninguna,
  dosMinActiva,
  amarilla,
  expulsadoRoja,
  expulsadoAzul,
}

class SancionEstado {
  int amarillas;
  int rojas;
  int azules;
  int dosMinTotales;
  List<int> dosMinRestantes;

  SancionEstado({
    this.amarillas = 0,
    this.rojas = 0,
    this.azules = 0,
    this.dosMinTotales = 0,
    List<int>? dosMinRestantes,
  }) : dosMinRestantes = dosMinRestantes ?? [];

  bool get tieneDosMinActiva => dosMinRestantes.any((s) => s > 0);

  bool get expulsado =>
      rojas > 0 || azules > 0 || amarillas >= 2 || dosMinTotales >= 3;

  bool get expulsadoPorDobleAmarilla =>
      amarillas >= 2 && rojas == 0 && azules == 0;

  bool get expulsadoPorTresDosMin =>
      dosMinTotales >= 3 && rojas == 0 && azules == 0;

  int get dosMinActivas => dosMinRestantes.where((s) => s > 0).length;

  SancionVisualTipo get tipoVisual {
    if (azules > 0) return SancionVisualTipo.expulsadoAzul;
    if (rojas > 0 || expulsadoPorTresDosMin || expulsadoPorDobleAmarilla) {
      return SancionVisualTipo.expulsadoRoja;
    }
    if (tieneDosMinActiva) return SancionVisualTipo.dosMinActiva;
    if (amarillas > 0) return SancionVisualTipo.amarilla;
    return SancionVisualTipo.ninguna;
  }
}

Widget buildSancionChip(SancionEstado? sancion) {
  if (sancion == null) return const SizedBox.shrink();

  switch (sancion.tipoVisual) {
    case SancionVisualTipo.expulsadoAzul:
      return _chip('AZ', Colors.indigo);

    case SancionVisualTipo.expulsadoRoja:
      return _chip('R', Colors.red.shade700);

    case SancionVisualTipo.dosMinActiva:
      final activas = sancion.dosMinActivas;
      final text = activas > 1 ? '${activas}x2\'' : "2'";
      return _chip(text, Colors.green);

    case SancionVisualTipo.amarilla:
      return _chip('A', Colors.orange);

    case SancionVisualTipo.ninguna:
      return const SizedBox.shrink();
  }
}

Widget _chip(String text, Color color) {
  return Container(
    constraints: const BoxConstraints(minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}
