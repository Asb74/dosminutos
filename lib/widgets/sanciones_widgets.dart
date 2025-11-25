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
    if (amarillas > 0) return SancionVisualTipo.amarilla;
    if (tieneDosMinActiva) return SancionVisualTipo.dosMinActiva;
    return SancionVisualTipo.ninguna;
  }
}

Widget? buildSancionChip(SancionEstado? sancion) {
  if (sancion == null) return null;

  switch (sancion.tipoVisual) {
    case SancionVisualTipo.dosMinActiva:
      final activas = sancion.dosMinActivas;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${activas}x 2\'',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

    case SancionVisualTipo.amarilla:
      return Container(
        width: 12,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.yellow,
          borderRadius: BorderRadius.circular(2),
        ),
      );

    case SancionVisualTipo.expulsadoRoja:
      return Container(
        width: 12,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(2),
        ),
      );

    case SancionVisualTipo.expulsadoAzul:
      return Container(
        width: 12,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(2),
        ),
      );

    case SancionVisualTipo.ninguna:
      return null;
  }
}
