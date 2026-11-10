import "package:flutter/material.dart";
import "basedatos/conexion.dart";
import "basedatos/repositorio_bolsa.dart";
import "basedatos/repositorio_usuario.dart";
import "screens/login_screen.dart";
 
final repoUsuario = RepositorioUsuario();
final repoBolsa = RepositorioBolsa();
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  final db = await abrirBaseDatos();
  repoUsuario.init(db);
  repoBolsa.init(db);
  await repoUsuario.sembrarUsuarios();
 
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Gestion y Movilizacion de Sangre",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Mismo rojo que el login y el boton "Guardar bolsa"
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB91C1C)),
      ),
      home: LoginScreen(repo: repoUsuario, repoBolsa: repoBolsa),
    );
  }
}