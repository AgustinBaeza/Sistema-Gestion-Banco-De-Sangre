import "dart:js_interop";
import "package:sqlite3/wasm.dart";
import "package:web/web.dart" as web;
 
IndexedDbFileSystem? _fs;
 
Future<CommonDatabase> abrirBaseDatos() async {
  // Pide al navegador que no borre el almacenamiento por falta de espacio
  await web.window.navigator.storage.persist().toDart;
 
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse("sqlite3.wasm"));
  _fs = await IndexedDbFileSystem.open(dbName: "banco_sangre");
  sqlite.registerVirtualFileSystem(_fs!, makeDefault: true);
  return sqlite.open("banco_sangre.db");
}
 
/// Baja los cambios en memoria a IndexedDB
Future<void> persistir() async => _fs?.flush();
 