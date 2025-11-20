class Club {
  final String id;
  final int idClub;
  final String apodo;
  final String nombre;
  final String escudo;
  final bool activo;
  final String? ciudad;
  final String? provincia;
  final String? pais;
  final String? pabellon;
  final String? colorPrimario;
  final String? colorSecundario;
  final String? telefonoContacto;
  final String? emailContacto;
  final String? web;
  final String? notas;

  Club({
    this.id = '',
    required this.idClub,
    required this.apodo,
    required this.nombre,
    required this.escudo,
    this.activo = true,
    this.ciudad,
    this.provincia,
    this.pais,
    this.pabellon,
    this.colorPrimario,
    this.colorSecundario,
    this.telefonoContacto,
    this.emailContacto,
    this.web,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'idClub': idClub,
      'apodo': apodo,
      'nombre': nombre,
      'escudo': escudo,
      'activo': activo,
      'ciudad': ciudad,
      'provincia': provincia,
      'pais': pais,
      'pabellon': pabellon,
      'colorPrimario': colorPrimario,
      'colorSecundario': colorSecundario,
      'telefonoContacto': telefonoContacto,
      'emailContacto': emailContacto,
      'web': web,
      'notas': notas,
    };
  }

  factory Club.fromDoc(String id, Map<String, dynamic> data) {
    return Club(
      id: id,
      idClub: (data['idClub'] as num?)?.toInt() ?? 0,
      apodo: data['apodo'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      escudo: data['escudo'] as String? ?? '',
      activo: data['activo'] as bool? ?? true,
      ciudad: data['ciudad'] as String?,
      provincia: data['provincia'] as String?,
      pais: data['pais'] as String?,
      pabellon: data['pabellon'] as String?,
      colorPrimario: data['colorPrimario'] as String?,
      colorSecundario: data['colorSecundario'] as String?,
      telefonoContacto: data['telefonoContacto'] as String?,
      emailContacto: data['emailContacto'] as String?,
      web: data['web'] as String?,
      notas: data['notas'] as String?,
    );
  }
}
