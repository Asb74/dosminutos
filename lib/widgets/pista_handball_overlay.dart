import 'package:flutter/material.dart';

import '../models/evento_partido.dart';

class PistaHandballOverlay extends StatelessWidget {
  // NUEVO: widget que superpone zonas clicables sobre la imagen de pista
  final ZonaJuego? zonaSeleccionada;
  final ValueChanged<ZonaJuego> onZonaSelected;

  const PistaHandballOverlay({
    Key? key,
    required this.zonaSeleccionada,
    required this.onZonaSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2, // ancho:alto aproximado de medio campo
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          Widget zonaBox(ZonaJuego zona, Rect rect) {
            final isSelected = zonaSeleccionada == zona;
            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: InkWell(
                onTap: () => onZonaSelected(zona),
                child: Container(
                  color: isSelected
                      ? Colors.orange.withOpacity(0.35)
                      : Colors.transparent,
                ),
              ),
            );
          }

          // Define las 11 zonas (usamos rectángulos aproximados sobre la imagen)
          final rowHeight = h / 3;

          return Stack(
            children: [
              // Fondo: imagen de la pista
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/pista/pista_handball.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Zonas 6m (cinco columnas)
              zonaBox(ZonaJuego.seisED,
                  Rect.fromLTWH(0, rowHeight * 2, w / 5, rowHeight)),
              zonaBox(ZonaJuego.seisLD,
                  Rect.fromLTWH(w / 5, rowHeight * 2, w / 5, rowHeight)),
              zonaBox(ZonaJuego.seisC,
                  Rect.fromLTWH(2 * w / 5, rowHeight * 2, w / 5, rowHeight)),
              zonaBox(ZonaJuego.seisLE,
                  Rect.fromLTWH(3 * w / 5, rowHeight * 2, w / 5, rowHeight)),
              zonaBox(ZonaJuego.seisEE,
                  Rect.fromLTWH(4 * w / 5, rowHeight * 2, w / 5, rowHeight)),

              // Zonas 8m (tres columnas)
              zonaBox(
                  ZonaJuego.ochoD, Rect.fromLTWH(0, rowHeight, w / 3, rowHeight)),
              zonaBox(ZonaJuego.ochoC,
                  Rect.fromLTWH(w / 3, rowHeight, w / 3, rowHeight)),
              zonaBox(ZonaJuego.ochoE,
                  Rect.fromLTWH(2 * w / 3, rowHeight, w / 3, rowHeight)),

              // Zonas 9m (tres columnas)
              zonaBox(
                  ZonaJuego.nueveD, Rect.fromLTWH(0, 0, w / 3, rowHeight)),
              zonaBox(ZonaJuego.nueveC,
                  Rect.fromLTWH(w / 3, 0, w / 3, rowHeight)),
              zonaBox(ZonaJuego.nueveE,
                  Rect.fromLTWH(2 * w / 3, 0, w / 3, rowHeight)),
            ],
          );
        },
      ),
    );
  }
}
