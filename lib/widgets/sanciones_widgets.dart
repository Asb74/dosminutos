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

String? buildTextoDosMin(SancionEstado s) {
  if (s.dosMinTotales <= 0) return null;

  final completadas = (s.dosMinTotales - (s.tieneDosMinActiva ? 1 : 0));
  if (completadas <= 0) {
    return "2'";
  } else {
    return "${completadas}x2'";
  }
}

Widget buildSancionChips(SancionEstado? s) {
  if (s == null) return const SizedBox.shrink();

  final chips = <Widget>[];

  if (s.azules > 0) {
    chips.add(_chip('AZ', Colors.indigo));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }

  if (s.rojas > 0) {
    chips.add(_chip('R', Colors.red));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }

  final textoDosMin = buildTextoDosMin(s);
  final tieneDosMin = textoDosMin != null;
  final tieneAmarilla = s.amarillas > 0;

  if (tieneAmarilla && tieneDosMin) {
    chips.add(_chip('A', Colors.orange));
    chips.add(const SizedBox(width: 4));
    chips.add(_chip(textoDosMin, Colors.green));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }

  if (tieneDosMin) {
    chips.add(_chip(textoDosMin, Colors.green));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }

  if (tieneAmarilla) {
    chips.add(_chip('A', Colors.orange));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }

  return const SizedBox.shrink();
}

Widget buildSancionChip(SancionEstado? sancion) => buildSancionChips(sancion);

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
