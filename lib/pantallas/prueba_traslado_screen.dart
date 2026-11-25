import 'package:flutter/material.dart';
import '../basedatos/conexion.dart';
import '../basedatos/repositorio_bolsa.dart';
import '../basedatos/repositorio_traslado.dart';
import '../modelos/bolsa_sangre.dart';
import 'solicitud_traslado_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await abrirBaseDatos();
  final repoBolsa = RepositorioBolsa()..init(db);
  final repoTraslado = RepositorioTraslado()..init(db);

  // Si aún no hay bolsas registradas, inserta datos de prueba para probar excedentes y escasez
  if (repoBolsa.listar().isEmpty) {
    final hoy = fechaHoy();
    final vence = sumarDias(hoy, 25);

    for (int i = 1; i <= 15; i++) {
      await repoBolsa.crear(
        codigo: 'BS-NRT-${i.toString().padLeft(3, '0')}',
        tipo: TipoSanguineo.oPositivo,
        sede: 'Sede Norte',
        volumenMl: 450,
        fechaIngreso: hoy,
        fechaVencimiento: vence,
      );
    }

    for (int i = 1; i <= 2; i++) {
      await repoBolsa.crear(
        codigo: 'BS-CNT-${i.toString().padLeft(3, '0')}',
        tipo: TipoSanguineo.oPositivo,
        sede: 'Sede Central',
        volumenMl: 450,
        fechaIngreso: hoy,
        fechaVencimiento: vence,
      );
    }
  }

  runApp(_AppPruebaTraslado(repoTraslado: repoTraslado));
}

class _AppPruebaTraslado extends StatefulWidget {
  const _AppPruebaTraslado({required this.repoTraslado});

  final RepositorioTraslado repoTraslado;

  @override
  State<_AppPruebaTraslado> createState() => _AppPruebaTrasladoState();
}

class _AppPruebaTrasladoState extends State<_AppPruebaTraslado> {
  static const _sedes = ['Sede Central', 'Sede Norte', 'Sede Sur', 'Concepcion'];
  late Map<String, int> _stockMapa;

  @override
  void initState() {
    super.initState();
    _recargarStock();
  }

  void _recargarStock() {
    _stockMapa = widget.repoTraslado.mapaStockDisponiblePorSedeYTipo(_sedes);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba US 7 - Solicitud de Traslado',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB91C1C)),
      ),
      home: SolicitudTrasladoPage(
        sedesDisponibles: _sedes,
        stockActualPorSedeYTipo: _stockMapa,
        onEnviarSolicitud: (datos) async {
          final creada = await widget.repoTraslado.crearSolicitudTraslado(
            sedeOrigen: datos.sedeOrigen,
            sedeDestino: datos.sedeDestino,
            tipoSanguineo: datos.tipoSanguineo,
            cantidad: datos.cantidad,
          );
          setState(_recargarStock);
          return 'Solicitud #${creada.id} creada (${creada.estado}): '
              '${creada.cantidad} unidad(es) de ${creada.tipoSanguineo.etiqueta} '
              'hacia ${creada.sedeDestino}. Se notificó a la sede de origen (${creada.sedeOrigen}).';
        },
      ),
    );
  }
}