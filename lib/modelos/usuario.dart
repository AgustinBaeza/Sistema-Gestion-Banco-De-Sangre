enum Rol { operador, personalCentroSalud, encagadoInventario }

class Usuario {
  final int id;
  final String nombreUsuario;
  final String passwordHash;
  final Rol rol;

  Usuario({
    required this.id,
    required this.nombreUsuario,
    required this.passwordHash,
    required this.rol,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "nombre_usuario": nombreUsuario,
    "password_hash": passwordHash,
    "rol": rol.name,
  };

  factory Usuario.fromMap(Map m) => Usuario(
    id: m["id"] as int,
    nombreUsuario: m["nombre_usuario"] as String,
    passwordHash: m["password_hash"] as String,
    rol: Rol.values.byName(m["rol"] as String),
  );
}
