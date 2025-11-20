import 'package:cloud_firestore/cloud_firestore.dart';

class Jugador {
  final String id;
  final int idJugador;
  final String equipoId;
  final String equipoNombre;
  final String apodo;
  final String nombre;
  final int dorsal;
  final String posicionAtaque;
  final String? posicionDefensa;
  final DateTime? fechaNacimiento;
  final String categoria;
  final String manoDominante;
  final bool convocado;
  final bool lesionado;
  final bool sancionado;
  final bool activo;
  final String? notas;

  Jugador({
    this.id = '',
    required this.idJugador,
    required this.equipoId,
    required this.equipoNombre,
    required this.apodo,
    required this.nombre,
    required this.dorsal,
    required this.posicionAtaque,
    this.posicionDefensa,
    this.fechaNacimiento,
    required this.categoria,
    required this.manoDominante,
    this.convocado = true,
    this.lesionado = false,
    this.sancionado = false,
    this.activo = true,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'idJugador': idJugador,
      'equipoId': equipoId,
      'equipoNombre': equipoNombre,
      'apodo': apodo,
      'nombre': nombre,
      'dorsal': dorsal,
      'posicionAtaque': posicionAtaque,
      'posicionDefensa': posicionDefensa,
      'fechaNacimiento': fechaNacimiento,
      'categoria': categoria,
      'manoDominante': manoDominante,
      'convocado': convocado,
      'lesionado': lesionado,
      'sancionado': sancionado,
      'activo': activo,
      'notas': notas,
    };
  }

  factory Jugador.fromDoc(String id, Map<String, dynamic> data) {
    final fecha = data['fechaNacimiento'];
    return Jugador(
      id: id,
      idJugador: (data['idJugador'] as num?)?.toInt() ?? 0,
      equipoId: data['equipoId'] as String? ?? '',
      equipoNombre: data['equipoNombre'] as String? ?? '',
      apodo: data['apodo'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      dorsal: (data['dorsal'] as num?)?.toInt() ?? 0,
      posicionAtaque: data['posicionAtaque'] as String? ?? '',
      posicionDefensa: data['posicionDefensa'] as String?,
      fechaNacimiento: fecha is DateTime
          ? fecha
          : fecha is Timestamp
              ? fecha.toDate()
              : null,
      categoria: data['categoria'] as String? ?? '',
      manoDominante: data['manoDominante'] as String? ?? '',
      convocado: data['convocado'] as bool? ?? true,
      lesionado: data['lesionado'] as bool? ?? false,
      sancionado: data['sancionado'] as bool? ?? false,
      activo: data['activo'] as bool? ?? true,
      notas: data['notas'] as String?,
    );
  }
}
