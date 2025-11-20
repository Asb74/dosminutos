class Arbitro {
  final String id;
  final String nombre;
  final String tipo;
  final String? numeroLicencia;
  final String? comite;
  final String? telefono;
  final String? email;
  final bool activo;
  final String? notas;

  Arbitro({
    this.id = '',
    required this.nombre,
    required this.tipo,
    this.numeroLicencia,
    this.comite,
    this.telefono,
    this.email,
    this.activo = true,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'tipo': tipo,
      'numeroLicencia': numeroLicencia,
      'comite': comite,
      'telefono': telefono,
      'email': email,
      'activo': activo,
      'notas': notas,
    };
  }

  factory Arbitro.fromDoc(String id, Map<String, dynamic> data) {
    return Arbitro(
      id: id,
      nombre: data['nombre'] as String? ?? '',
      tipo: data['tipo'] as String? ?? '',
      numeroLicencia: data['numeroLicencia'] as String?,
      comite: data['comite'] as String?,
      telefono: data['telefono'] as String?,
      email: data['email'] as String?,
      activo: data['activo'] as bool? ?? true,
      notas: data['notas'] as String?,
    );
  }
}
