import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "basedatos/conexion.dart";
import "basedatos/repositorio_bolsa.dart";
import "basedatos/repositorio_traslado.dart";
import "basedatos/repositorio_usuario.dart";
import "pantallas/formulario_bolsa.dart";
import "pantallas/inventario.dart";
import "pantallas/solicitud_traslado_screen.dart";
import "screens/login_screen.dart";

final repoUsuario = RepositorioUsuario();
final repoBolsa = RepositorioBolsa();
final repoTraslado = RepositorioTraslado();

const _sedesBase = [
  "Sede Central",
  "Sede Norte",
  "Sede Sur",
  "Concepcion",
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await abrirBaseDatos();
  repoUsuario.init(db);
  repoBolsa.init(db);
  repoTraslado.init(db);
  await repoUsuario.sembrarUsuarios();

  runApp(const MyApp());
}

List<String> _obtenerSedesParaTraslado() {
  final sedes = <String>{
    ...repoBolsa.sedes(),
    ..._sedesBase,
  };
  return sedes.toList();
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
  // vista del inventario por ahora solo en debug
  if (settings.name == "/inventario" && kDebugMode) {
    return MaterialPageRoute(
      settings: settings,
      // La pantalla consulta el stock al repositorio segun los filtros
      builder: (_) => InventarioPage(repo: repoBolsa),
    );
  }
  if (settings.name == "/traslados" && (logueado || kDebugMode)) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const _FlujoTrasladoConectado(),
    );
  }
  return MaterialPageRoute(
    settings: const RouteSettings(name: "/"),
    builder: (_) => LoginScreen(repo: repoUsuario),
  );
}

class _FlujoTrasladoConectado extends StatefulWidget {
  const _FlujoTrasladoConectado();

  @override
  State<_FlujoTrasladoConectado> createState() =>
      _FlujoTrasladoConectadoState();
}

class _FlujoTrasladoConectadoState extends State<_FlujoTrasladoConectado> {
  late List<String> _sedes;
  late Map<String, int> _stockMapa;

  @override
  void initState() {
    super.initState();
    _recargarEstado();
  }

  void _recargarEstado() {
    _sedes = _obtenerSedesParaTraslado();
    _stockMapa = repoTraslado.mapaStockDisponiblePorSedeYTipo(_sedes);
  }

  @override
  Widget build(BuildContext context) {
    return SolicitudTrasladoPage(
      sedesDisponibles: _sedes,
      stockActualPorSedeYTipo: _stockMapa,
      onEnviarSolicitud: (datos) async {
        final creada = await repoTraslado.crearSolicitudTraslado(
          sedeOrigen: datos.sedeOrigen,
          sedeDestino: datos.sedeDestino,
          tipoSanguineo: datos.tipoSanguineo,
          cantidad: datos.cantidad,
        );
        if (mounted) {
          setState(_recargarEstado);
        }
        return "Solicitud #${creada.id} creada (${creada.estado}): "
            "${creada.cantidad} unidad(es) de ${creada.tipoSanguineo.etiqueta} "
            "hacia ${creada.sedeDestino}. Se notificó a la sede de origen (${creada.sedeOrigen}).";
      },
    );
  }
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