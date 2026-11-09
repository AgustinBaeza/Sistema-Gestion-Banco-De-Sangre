import "package:bcrypt/bcrypt.dart";
import "../modelos/usuario.dart";
import "package:sqlite3/common.dart";
import "conexion.dart";
 
class RepositorioUsuario {
  static const _sqliteConstraintUnique = 2067;
 
  late final CommonDatabase _db;
 
  /// Recibe una base de datos ya abierta y crea la tabla si no existe
  void init(CommonDatabase db) {
    _db = db;
 
    final roles = Rol.values.map((r) => "'${r.name}'").join(", ");
 
    _db.execute("""
      CREATE TABLE IF NOT EXISTS usuarios (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_usuario TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash  TEXT NOT NULL,
        rol            TEXT NOT NULL CHECK (rol IN ($roles))
      )
    """);
  }
 
  Future<Usuario> crear(
    String nombreUsuario,
    String passwordPlano,
    Rol rol,
  ) async {
    final clave = nombreUsuario.trim().toLowerCase();
 
    /// Validaciones
    if (clave.isEmpty || passwordPlano.isEmpty) {
      throw ArgumentError("Usuario y contraseña son obligatorios");
    }
 
    final hash = BCrypt.hashpw(passwordPlano, BCrypt.gensalt());
 
    try {
      _db.execute(
        "INSERT INTO usuarios (nombre_usuario, password_hash, rol) "
        "VALUES (?, ?, ?)",
        [clave, hash, rol.name],
      );
    } on SqliteException catch (e) {
      if (e.extendedResultCode == _sqliteConstraintUnique) {
        throw StateError("El usuario ya existe");
      }
      rethrow;
    }
 
    // En web baja los cambios a IndexedDB; en escritorio no hace nada
    await persistir();
 
    return Usuario(
      id: _db.lastInsertRowId,
      nombreUsuario: clave,
      passwordHash: hash,
      rol: rol,
    );
  }
 
  /// Usuarios de desarrollo, uno por rol, solo si la tabla está vacía
  /// Cambia las claves antes de entregar
  Future<void> sembrarUsuarios() async {
    if (listar().isNotEmpty) return;
    await crear("operador", "Operador#2026", Rol.operador);
    await crear("centrosalud", "Centro#2026", Rol.personalCentroSalud);
    await crear("encargado", "Encargado#2026", Rol.encagadoInventario);
  }
 
  Usuario? buscarPorNombre(String nombreUsuario) {
    final filas = _db.select(
      "SELECT id, nombre_usuario, password_hash, rol "
      "FROM usuarios WHERE nombre_usuario = ?",
      [nombreUsuario.trim().toLowerCase()],
    );
    return filas.isEmpty ? null : Usuario.fromMap(filas.first);
  }
 
  Usuario? autenticar(String nombreUsuario, String passwordPlano) {
    final u = buscarPorNombre(nombreUsuario);
    if (u == null) return null;
    return BCrypt.checkpw(passwordPlano, u.passwordHash) ? u : null;
  }
 
  List<Usuario> listar() {
    final filas = _db.select(
      "SELECT id, nombre_usuario, password_hash, rol FROM usuarios ORDER BY id",
    );
    return filas.map((f) => Usuario.fromMap(f)).toList();
  }
}