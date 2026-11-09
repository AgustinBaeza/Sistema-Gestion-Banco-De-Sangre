import "package:flutter_test/flutter_test.dart";
import "package:sqlite3/sqlite3.dart";
import "package:gestion_banco_sangre/basedatos/repositorio_usuario.dart";
import "package:gestion_banco_sangre/modelos/usuario.dart";

void main() {
  late Database db;
  late RepositorioUsuario repo;

  setUpAll(() {
    /// Base de datos en memoria: no deja archivos y parte siempre vacia.
    db = sqlite3.openInMemory();
    repo = RepositorioUsuario();
    repo.init(db);
  });

  tearDownAll(() => db.close());

  test("la tabla de usuarios existe y esta vacia al inicio", () {
    final tablas = db.select(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'usuarios'",
    );
    expect(tablas, isNotEmpty);
    expect(repo.listar(), isEmpty);
  });

  test("inserta y consulta un registro con id unico", () async {
    final u1 = await repo.crear("operador1", "Clave#2026", Rol.operador);
    final u2 = await repo.crear(
      "encargado1",
      "Otra#2026",
      Rol.encagadoInventario,
    );
    expect(u1.id, isNot(u2.id));
    expect(repo.buscarPorNombre("operador1")!.rol, Rol.operador);
  });

  test("la contraseña se guarda como hash bcrypt", () {
    final u = repo.buscarPorNombre("operador1")!;
    expect(u.passwordHash, isNot("Clave#2026"));
    expect(u.passwordHash.startsWith(r"$2"), isTrue);
  });

  test("el login valida bien la contraseña", () {
    expect(repo.autenticar("operador1", "Clave#2026"), isNotNull);
    expect(repo.autenticar("operador1", "incorrecta"), isNull);
  });

  test("rechaza usuarios duplicados", () async {
    expect(
      () => repo.crear("operador1", "x", Rol.operador),
      throwsA(isA<StateError>()),
    );
  });

  test("el nombre de usuario no distingue mayusculas", () async {
    expect(
      () => repo.crear("  OPERADOR1 ", "x", Rol.operador),
      throwsA(isA<StateError>()),
    );
  });
}
