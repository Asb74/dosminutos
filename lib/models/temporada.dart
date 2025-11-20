import 'package:cloud_firestore/cloud_firestore.dart';

class Temporada {
  final String id;
  final String nombre;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool activa;
  final String? categoria;
  final int orden;
  final String? descripcion;

  Temporada({
    this.id = '',
    required this.nombre,
    this.fechaInicio,
    this.fechaFin,
    this.activa = false,
    this.categoria,
    this.orden = 0,
    this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'fechaInicio': fechaInicio,
      'fechaFin': fechaFin,
      'activa': activa,
      'categoria': categoria,
      'orden': orden,
      'descripcion': descripcion,
    };
  }

  factory Temporada.fromDoc(String id, Map<String, dynamic> data) {
    DateTime? toDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return Temporada(
      id: id,
      nombre: data['nombre'] as String? ?? '',
      fechaInicio: toDate(data['fechaInicio']),
      fechaFin: toDate(data['fechaFin']),
      activa: data['activa'] as bool? ?? false,
      categoria: data['categoria'] as String?,
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      descripcion: data['descripcion'] as String?,
    );
  }
}
