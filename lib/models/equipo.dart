class Equipo {
  final String id;
  final String nombre;
  final String categoria;
  final String sexo;
  final String? club;
  final bool activo;
  final String? notas;

  Equipo({
    this.id = '',
    required this.nombre,
    required this.categoria,
    required this.sexo,
    this.club,
    this.activo = true,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'sexo': sexo,
      'club': club,
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
      club: data['club'] as String?,
      activo: data['activo'] as bool? ?? true,
      notas: data['notas'] as String?,
    );
  }
}
