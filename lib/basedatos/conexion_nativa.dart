import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqlite3/common.dart";
import "package:sqlite3/sqlite3.dart";

Future<CommonDatabase> abrirBaseDatos() async {
  final carpeta = await getApplicationDocumentsDirectory();
  return sqlite3.open(p.join(carpeta.path, "banco_sangre.db"));
}
