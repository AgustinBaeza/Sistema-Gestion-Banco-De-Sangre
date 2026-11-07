import "package:sqlite3/wasm.dart";

Future<CommonDatabase> abrirBaseDatos() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse("sqlite3.wasm"));
  final fs = await IndexedDbFileSystem.open(dbName: "banco_sangre");
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  return sqlite.open("banco_sangre.db");
}
