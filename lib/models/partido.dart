import 'package:cloud_firestore/cloud_firestore.dart';

class Partido {
  final String id;
  final int idPartido;
  final String campeonatoId;
  final String campeonatoNombre;
  final String temporadaId;
  final String temporadaNombre;
  final String categoria;
  final String sexo;
  final String equipoLocalId;
  final String equipoLocalNombre;
  final String equipoVisitanteId;
  final String equipoVisitanteNombre;
  final DateTime fechaHora;
  final String pabellon;
  final String? jornada;
  final String? arbitro1Id;
  final String? arbitro2Id;
  final String? mesa1Id;
  final String? mesa2Id;
  final List<int> jugadoresConvocados;
  final List<int> staffConvocado;
  final String estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  Partido({
    this.id = '',
    required this.idPartido,
    required this.campeonatoId,
    required this.campeonatoNombre,
    required this.temporadaId,
    required this.temporadaNombre,
    required this.categoria,
    required this.sexo,
    required this.equipoLocalId,
    required this.equipoLocalNombre,
    required this.equipoVisitanteId,
    required this.equipoVisitanteNombre,
    required this.fechaHora,
    required this.pabellon,
    this.jornada,
    this.arbitro1Id,
    this.arbitro2Id,
    this.mesa1Id,
    this.mesa2Id,
    this.jugadoresConvocados = const [],
    this.staffConvocado = const [],
    this.estado = 'Programado',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'idPartido': idPartido,
      'campeonatoId': campeonatoId,
      'campeonatoNombre': campeonatoNombre,
      'temporadaId': temporadaId,
      'temporadaNombre': temporadaNombre,
      'categoria': categoria,
      'sexo': sexo,
      'equipoLocalId': equipoLocalId,
      'equipoLocalNombre': equipoLocalNombre,
      'equipoVisitanteId': equipoVisitanteId,
      'equipoVisitanteNombre': equipoVisitanteNombre,
      'fechaHora': Timestamp.fromDate(fechaHora),
      'pabellon': pabellon,
      'jornada': jornada,
      'arbitro1Id': arbitro1Id,
      'arbitro2Id': arbitro2Id,
      'mesa1Id': mesa1Id,
      'mesa2Id': mesa2Id,
      'jugadoresConvocados': jugadoresConvocados,
      'staffConvocado': staffConvocado,
      'estado': estado,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Partido.fromDoc(String id, Map<String, dynamic> data) {
    DateTime toDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    List<int> parseIntList(dynamic value) {
      if (value is Iterable) {
        return value
            .map((e) => (e as num?)?.toInt())
            .whereType<int>()
            .toList();
      }
      return [];
    }

    return Partido(
      id: id,
      idPartido: (data['idPartido'] as num?)?.toInt() ?? 0,
      campeonatoId: data['campeonatoId'] as String? ?? '',
      campeonatoNombre: data['campeonatoNombre'] as String? ?? '',
      temporadaId: data['temporadaId'] as String? ?? '',
      temporadaNombre: data['temporadaNombre'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      sexo: data['sexo'] as String? ?? '',
      equipoLocalId: data['equipoLocalId'] as String? ?? '',
      equipoLocalNombre: data['equipoLocalNombre'] as String? ?? '',
      equipoVisitanteId: data['equipoVisitanteId'] as String? ?? '',
      equipoVisitanteNombre: data['equipoVisitanteNombre'] as String? ?? '',
      fechaHora: toDate(data['fechaHora']),
      pabellon: data['pabellon'] as String? ?? '',
      jornada: data['jornada'] as String?,
      arbitro1Id: data['arbitro1Id'] as String?,
      arbitro2Id: data['arbitro2Id'] as String?,
      mesa1Id: data['mesa1Id'] as String?,
      mesa2Id: data['mesa2Id'] as String?,
      jugadoresConvocados: parseIntList(data['jugadoresConvocados']),
      staffConvocado: parseIntList(data['staffConvocado']),
      estado: data['estado'] as String? ?? 'Programado',
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }
}
