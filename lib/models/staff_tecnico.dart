import 'package:cloud_firestore/cloud_firestore.dart';

class StaffTecnico {
  final String id;
  final int idStaff;
  final String equipoId;
  final String equipoNombre;
  final String apodo;
  final String nombre;
  final DateTime? fechaNacimiento;
  final String cargo;
  final bool activo;
  final bool convocado;
  final bool lesionado;
  final bool sancionado;
  final String? telefono;
  final String? email;
  final String? identificacion;
  final String? especialidad;
  final String? notas;

  StaffTecnico({
    this.id = '',
    required this.idStaff,
    required this.equipoId,
    required this.equipoNombre,
    required this.apodo,
    required this.nombre,
    this.fechaNacimiento,
    required this.cargo,
    this.activo = true,
    this.convocado = true,
    this.lesionado = false,
    this.sancionado = false,
    this.telefono,
    this.email,
    this.identificacion,
    this.especialidad,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'idStaff': idStaff,
      'equipoId': equipoId,
      'equipoNombre': equipoNombre,
      'apodo': apodo,
      'nombre': nombre,
      'fechaNacimiento': fechaNacimiento,
      'cargo': cargo,
      'activo': activo,
      'convocado': convocado,
      'lesionado': lesionado,
      'sancionado': sancionado,
      'telefono': telefono,
      'email': email,
      'identificacion': identificacion,
      'especialidad': especialidad,
      'notas': notas,
    };
  }

  factory StaffTecnico.fromDoc(String id, Map<String, dynamic> data) {
    final fecha = data['fechaNacimiento'];
    return StaffTecnico(
      id: id,
      idStaff: (data['idStaff'] as num?)?.toInt() ?? 0,
      equipoId: data['equipoId'] as String? ?? '',
      equipoNombre: data['equipoNombre'] as String? ?? '',
      apodo: data['apodo'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      fechaNacimiento: fecha is DateTime
          ? fecha
          : fecha is Timestamp
              ? fecha.toDate()
              : null,
      cargo: data['cargo'] as String? ?? '',
      activo: data['activo'] as bool? ?? true,
      convocado: data['convocado'] as bool? ?? true,
      lesionado: data['lesionado'] as bool? ?? false,
      sancionado: data['sancionado'] as bool? ?? false,
      telefono: data['telefono'] as String?,
      email: data['email'] as String?,
      identificacion: data['identificacion'] as String?,
      especialidad: data['especialidad'] as String?,
      notas: data['notas'] as String?,
    );
  }
}
