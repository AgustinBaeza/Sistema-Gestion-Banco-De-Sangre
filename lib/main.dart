import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "basedatos/conexion.dart";
import "basedatos/repositorio_bolsa.dart";
import "basedatos/repositorio_usuario.dart";
import "pantallas/formulario_bolsa.dart";
import "pantallas/inventario.dart";
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
 
/// Arma la pantalla segun la ruta. Sin sesion activa cualquier ruta
/// lleva al login, asi no se entra al formulario escribiendo la URL.
Route<void> generarRuta(RouteSettings settings) {
  final logueado = repoUsuario.usuarioActual != null;
  // En debug se puede entrar directo con /#/bolsas para probar el formulario.
  // En release (flutter build web) siempre exige iniciar sesion.
  if (settings.name == "/bolsas" && (logueado || kDebugMode)) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => FormularioBolsaPage(repo: repoBolsa),
    );
  }
  // US 3 / Tarea 3.1: vista del inventario. Por ahora solo en debug
  if (settings.name == "/inventario" && kDebugMode) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const InventarioPage(filas: inventarioEjemplo),
    );
  }
  return MaterialPageRoute(
    settings: const RouteSettings(name: "/"),
    builder: (_) => LoginScreen(repo: repoUsuario),
  );
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
      onGenerateRoute: generarRuta,
      // En web la ruta inicial viene de la URL; se arma una sola pantalla
      // para que no queden dos login apilados
      onGenerateInitialRoutes: (nombre) => [
        generarRuta(RouteSettings(name: nombre)),
      ],
    );
  }
}