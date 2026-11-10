import "package:flutter/material.dart";
import "basedatos/conexion.dart";
import "basedatos/repositorio_bolsa.dart";
import "basedatos/repositorio_usuario.dart";
import "pantallas/formulario_bolsa.dart";
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginScreen(),
      routes: {
        // Temporal: mientras el login no autentica, se entra con /#/bolsas.
        "/bolsas": (_) => FormularioBolsaPage(repo: repoBolsa),
      },
    );
  }
}