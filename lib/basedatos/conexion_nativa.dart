import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqlite3/common.dart";
import "package:sqlite3/sqlite3.dart";
 
Future<CommonDatabase> abrirBaseDatos() async {
  final carpeta = await getApplicationDocumentsDirectory();
  final ruta = p.join(carpeta.path, "banco_sangre.db");
  debugPrint("Base de datos en: $ruta");
  return sqlite3.open(ruta);
}
 
/// En escritorio SQLite ya escribe a disco, no hay nada que hacer
Future<void> persistir() async {}
 