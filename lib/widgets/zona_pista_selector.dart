import 'package:flutter/material.dart';

import '../models/evento_partido.dart';

class ZonaPistaSelector extends StatelessWidget {
  final ZonaJuego? zonaSeleccionada;
  final ValueChanged<ZonaJuego> onZonaSelected;

  const ZonaPistaSelector({
    Key? key,
    required this.zonaSeleccionada,
    required this.onZonaSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final rowHeight = h / 3;

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
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    color: isSelected
                        ? Colors.orange.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    zona.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200, width: 2),
                  ),
                ),
              ),

              zonaBox(
                ZonaJuego.seisED,
                Rect.fromLTWH(0, rowHeight * 2, w / 5, rowHeight),
              ),
              zonaBox(
                ZonaJuego.seisLD,
                Rect.fromLTWH(w / 5, rowHeight * 2, w / 5, rowHeight),
              ),
              zonaBox(
                ZonaJuego.seisC,
                Rect.fromLTWH(2 * w / 5, rowHeight * 2, w / 5, rowHeight),
              ),
              zonaBox(
                ZonaJuego.seisLE,
                Rect.fromLTWH(3 * w / 5, rowHeight * 2, w / 5, rowHeight),
              ),
              zonaBox(
                ZonaJuego.seisEE,
                Rect.fromLTWH(4 * w / 5, rowHeight * 2, w / 5, rowHeight),
              ),

              zonaBox(
                ZonaJuego.ochoD,
                Rect.fromLTWH(0, rowHeight, w / 3, rowHeight),
              ),
              zonaBox(
                ZonaJuego.ochoC,
                Rect.fromLTWH(w / 3, rowHeight, w / 3, rowHeight),
              ),
              zonaBox(
                ZonaJuego.ochoE,
                Rect.fromLTWH(2 * w / 3, rowHeight, w / 3, rowHeight),
              ),

              zonaBox(
                ZonaJuego.nueveD,
                Rect.fromLTWH(0, 0, w / 3, rowHeight),
              ),
              zonaBox(
                ZonaJuego.nueveC,
                Rect.fromLTWH(w / 3, 0, w / 3, rowHeight),
              ),
              zonaBox(
                ZonaJuego.nueveE,
                Rect.fromLTWH(2 * w / 3, 0, w / 3, rowHeight),
              ),
            ],
          );
        },
      ),
    );
  }
}
