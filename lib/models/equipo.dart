class Equipo {
  final String id;
  final String nombre;
  final String? categoria;
  final String? club;

  Equipo({
    this.id = '',
    required this.nombre,
    this.categoria,
    this.club,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'club': club,
    };
  }

  factory Equipo.fromDoc(String id, Map<String, dynamic> data) {
    return Equipo(
      id: id,
      nombre: data['nombre'] as String? ?? '',
      categoria: data['categoria'] as String?,
      club: data['club'] as String?,
    );
  }
}
