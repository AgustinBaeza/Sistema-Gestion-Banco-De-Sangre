import "package:flutter/material.dart";
import "basedatos/conexion.dart";
import "basedatos/repositorio_usuario.dart";

final repoUsuario = RepositorioUsuario();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await abrirBaseDatos();
  repoUsuario.init(db);
}
