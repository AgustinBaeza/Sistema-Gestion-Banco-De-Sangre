import "package:flutter/material.dart";
import "basedatos/conexion.dart";
import "basedatos/repositorio_usuario.dart";
import "screens/login_screen.dart";
 
final repoUsuario = RepositorioUsuario();
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  final db = await abrirBaseDatos();
  repoUsuario.init(db);
  await repoUsuario.sembrarUsuarios();
 
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Gestión y Movilización de Sangre",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginScreen(),
    );
  }
}