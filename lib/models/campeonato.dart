class Campeonato {
  final String id;
  final int idCampeonato;
  final String apodo;
  final String nombre;
  final String temporadaId;
  final String temporadaNombre;
  final String categoria;
  final String sexo;
  final String tipo;
  final bool activo;
  final String? organizador;
  final String? nivel;
  final String? color;
  final String? notas;

  Campeonato({
    this.id = '',
    required this.idCampeonato,
    required this.apodo,
    required this.nombre,
    required this.temporadaId,
    required this.temporadaNombre,
    required this.categoria,
    required this.sexo,
    required this.tipo,
    this.activo = true,
    this.organizador,
    this.nivel,
    this.color,
    this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'idCampeonato': idCampeonato,
      'apodo': apodo,
      'nombre': nombre,
      'temporadaId': temporadaId,
      'temporadaNombre': temporadaNombre,
      'categoria': categoria,
      'sexo': sexo,
      'tipo': tipo,
      'activo': activo,
      'organizador': organizador,
      'nivel': nivel,
      'color': color,
      'notas': notas,
    };
  }

  factory Campeonato.fromDoc(String id, Map<String, dynamic> data) {
    return Campeonato(
      id: id,
      idCampeonato: (data['idCampeonato'] as num?)?.toInt() ?? 0,
      apodo: data['apodo'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      temporadaId: data['temporadaId'] as String? ?? '',
      temporadaNombre: data['temporadaNombre'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      sexo: data['sexo'] as String? ?? '',
      tipo: data['tipo'] as String? ?? '',
      activo: data['activo'] as bool? ?? true,
      organizador: data['organizador'] as String?,
      nivel: data['nivel'] as String?,
      color: data['color'] as String?,
      notas: data['notas'] as String?,
    );
  }
}
