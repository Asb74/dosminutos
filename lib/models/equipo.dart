class Equipo {
  final String id;
  final String nombre;
  final String categoria;
  final String sexo;
  final String? clubId;
  final String? clubNombre;
  final bool activo;
  final String? notas;

  Equipo({
    this.id = '',
    required this.nombre,
    required this.categoria,
    required this.sexo,
    this.clubId,
    this.clubNombre,
    this.activo = true,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'sexo': sexo,
      'clubId': clubId,
      'clubNombre': clubNombre,
      'activo': activo,
      'notas': notas,
    };
  }

  factory Equipo.fromDoc(String id, Map<String, dynamic> data) {
    return Equipo(
      id: id,
      nombre: data['nombre'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      sexo: data['sexo'] as String? ?? '',
      clubId: data['clubId'] as String?,
      clubNombre: data['clubNombre'] as String?,
      activo: data['activo'] as bool? ?? true,
      notas: data['notas'] as String?,
    );
  }
}
