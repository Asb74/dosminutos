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
  final List<Map<String, dynamic>> convocadosLocal;
  final List<Map<String, dynamic>> convocadosVisitante;
  final List<Map<String, dynamic>> staffConvocadoLocal;
  final List<Map<String, dynamic>> staffConvocadoVisitante;
  final String estado;
  final int golesLocal;
  final int golesVisitante;
  final int periodo;
  final int segundoPartido;
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
    this.convocadosLocal = const [],
    this.convocadosVisitante = const [],
    this.staffConvocadoLocal = const [],
    this.staffConvocadoVisitante = const [],
    this.estado = 'Programado',
    this.golesLocal = 0,
    this.golesVisitante = 0,
    this.periodo = 1,
    this.segundoPartido = 0,
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
      'convocadosLocal': convocadosLocal,
      'convocadosVisitante': convocadosVisitante,
      'staffConvocadoLocal': staffConvocadoLocal,
      'staffConvocadoVisitante': staffConvocadoVisitante,
      'estado': estado,
      'golesLocal': golesLocal,
      'golesVisitante': golesVisitante,
      'periodo': periodo,
      'segundoPartido': segundoPartido,
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
      convocadosLocal:
          (data['convocadosLocal'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      convocadosVisitante:
          (data['convocadosVisitante'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      staffConvocadoLocal:
          (data['staffConvocadoLocal'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      staffConvocadoVisitante:
          (data['staffConvocadoVisitante'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      estado: data['estado'] as String? ?? 'Programado',
      golesLocal: (data['golesLocal'] as num?)?.toInt() ?? 0,
      golesVisitante: (data['golesVisitante'] as num?)?.toInt() ?? 0,
      periodo: (data['periodo'] as num?)?.toInt() ?? 1,
      segundoPartido: (data['segundoPartido'] as num?)?.toInt() ?? 0,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }
}
