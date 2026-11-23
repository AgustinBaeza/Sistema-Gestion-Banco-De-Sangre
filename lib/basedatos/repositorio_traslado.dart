import 'package:sqlite3/common.dart';
import '../modelos/bolsa_sangre.dart';
import '../modelos/solicitud_traslado.dart';
import 'conexion.dart';

class RepositorioTraslado {
  late final CommonDatabase _db;

  /// Inicializa la base de datos y crea la tabla de solicitudes de traslado si no existe
  void init(CommonDatabase db) {
    _db = db;

    final tipos = TipoSanguineo.values.map((t) => "'${t.name}'").join(', ');

    _db.execute("""
      CREATE TABLE IF NOT EXISTS solicitudes_traslado (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        sede_origen          TEXT NOT NULL,
        sede_destino         TEXT NOT NULL,
        tipo_sanguineo       TEXT NOT NULL CHECK (tipo_sanguineo IN ($tipos)),
        cantidad             INTEGER NOT NULL CHECK (cantidad > 0),
        stock_minimo         INTEGER NOT NULL,
        stock_optimo         INTEGER NOT NULL,
        stock_maximo         INTEGER NOT NULL,
        estado               TEXT NOT NULL DEFAULT 'pendiente',
        notificacion_enviada INTEGER NOT NULL DEFAULT 1,
        fecha_creacion       TEXT NOT NULL
      )
    """);
  }

  /// Calcula los niveles de stock mínimo, óptimo y máximo según tipo sanguíneo
  NivelesStockReferencia calcularNivelesStock({
    required TipoSanguineo tipoSanguineo,
    int factorCapacidadSede = 1,
  }) {
    final int factor = factorCapacidadSede < 1 ? 1 : factorCapacidadSede;
    final bool esRhNegativo = tipoSanguineo.name.endsWith('Negativo');

    final int minimoBase = esRhNegativo ? 4 : 6;
    final int optimoBase = (minimoBase * 2.5).round();
    final int maximoBase = minimoBase * 4;

    return NivelesStockReferencia(
      stockMinimo: minimoBase * factor,
      stockOptimo: optimoBase * factor,
      stockMaximo: maximoBase * factor,
    );
  }

  /// Consulta el stock vigente en `bolsas_sangre` (fecha_vencimiento > hoy)
  /// descontando solicitudes pendientes ya comprometidas desde esa sede origen
  int obtenerStockDisponibleOrigen({
    required String sedeOrigen,
    required TipoSanguineo tipoSanguineo,
  }) {
    final tablas = _db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='bolsas_sangre'",
    );
    if (tablas.isEmpty) {
      return 0;
    }

    final filas = _db.select(
      """
      SELECT CAST(COUNT(id) AS INTEGER) AS cantidad
      FROM bolsas_sangre
      WHERE TRIM(LOWER(sede)) = TRIM(LOWER(?))
        AND tipo_sanguineo = ?
        AND fecha_vencimiento > ?
      """,
      [sedeOrigen, tipoSanguineo.name, fechaIso(fechaHoy())],
    );

    final int totalVigentes =
        filas.isEmpty ? 0 : ((filas.first['cantidad'] as int?) ?? 0);

    final comprometidas = _db.select(
      """
      SELECT CAST(COALESCE(SUM(cantidad), 0) AS INTEGER) AS reservadas
      FROM solicitudes_traslado
      WHERE TRIM(LOWER(sede_origen)) = TRIM(LOWER(?))
        AND tipo_sanguineo = ?
        AND estado = 'pendiente'
      """,
      [sedeOrigen, tipoSanguineo.name],
    );

    final int reservadas = comprometidas.isEmpty
        ? 0
        : ((comprometidas.first['reservadas'] as int?) ?? 0);

    return (totalVigentes - reservadas).clamp(0, totalVigentes);
  }

  /// Devuelve un mapa listo para alimentar `SolicitudTrasladoPage.stockActualPorSedeYTipo`
  /// a partir de las bolsas vigentes en la base de datos
  Map<String, int> mapaStockDisponiblePorSedeYTipo(List<String> sedes) {
    final mapa = <String, int>{};
    for (final sede in sedes) {
      for (final tipo in TipoSanguineo.values) {
        final disponible = obtenerStockDisponibleOrigen(
          sedeOrigen: sede,
          tipoSanguineo: tipo,
        );
        mapa['$sede|${tipo.name}'] = disponible;
      }
    }
    return mapa;
  }

  /// Valida y crea una solicitud de traslado verificando:
  /// 1) Datos válidos y sedes distintas
  /// 2) Cálculo de stock mínimo, óptimo y máximo
  /// 3) Excedente disponible en origen por encima del stock mínimo
  Future<SolicitudTraslado> crearSolicitudTraslado({
    required String sedeOrigen,
    required String sedeDestino,
    required TipoSanguineo tipoSanguineo,
    required int cantidad,
    int? stockDisponibleOverride,
    int factorCapacidadSede = 1,
  }) async {
    final String origen = sedeOrigen.trim();
    final String destino = sedeDestino.trim();

    if (origen.isEmpty || destino.isEmpty) {
      throw ArgumentError('La sede de origen y la sede de destino son obligatorias.');
    }

    if (origen.toLowerCase() == destino.toLowerCase()) {
      throw ArgumentError('La sede de origen y la sede de destino deben ser distintas.');
    }

    if (cantidad <= 0) {
      throw ArgumentError('La cantidad a trasladar debe ser mayor a 0.');
    }

    final niveles = calcularNivelesStock(
      tipoSanguineo: tipoSanguineo,
      factorCapacidadSede: factorCapacidadSede,
    );

    final int stockOrigen = stockDisponibleOverride ??
        obtenerStockDisponibleOrigen(
          sedeOrigen: origen,
          tipoSanguineo: tipoSanguineo,
        );

    final int excedenteDisponible = niveles.excedenteSobreMinimo(stockOrigen);

    if (cantidad > excedenteDisponible) {
      throw StateError(
        'Stock excedente insuficiente en $origen para ${tipoSanguineo.etiqueta}: '
        'disponible $stockOrigen, mínimo ${niveles.stockMinimo}, '
        'excedente trasladable $excedenteDisponible.',
      );
    }

    final ahora = DateTime.now();
    final fechaStr = ahora.toIso8601String();

    _db.execute(
      """
      INSERT INTO solicitudes_traslado (
        sede_origen,
        sede_destino,
        tipo_sanguineo,
        cantidad,
        stock_minimo,
        stock_optimo,
        stock_maximo,
        estado,
        notificacion_enviada,
        fecha_creacion
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pendiente', 1, ?)
      """,
      [
        origen,
        destino,
        tipoSanguineo.name,
        cantidad,
        niveles.stockMinimo,
        niveles.stockOptimo,
        niveles.stockMaximo,
        fechaStr,
      ],
    );

    // Se lee antes del await para no mezclarlo con otro insert
    final int nuevoId = _db.lastInsertRowId;

    await persistir();

    return SolicitudTraslado(
      id: nuevoId,
      sedeOrigen: origen,
      sedeDestino: destino,
      tipoSanguineo: tipoSanguineo,
      cantidad: cantidad,
      stockMinimo: niveles.stockMinimo,
      stockOptimo: niveles.stockOptimo,
      stockMaximo: niveles.stockMaximo,
      estado: 'pendiente',
      notificacionEnviada: true,
      fechaCreacion: ahora,
    );
  }

  /// Lista todas las solicitudes de traslado registradas
  List<SolicitudTraslado> listarSolicitudes() {
    final filas = _db.select(
      'SELECT * FROM solicitudes_traslado ORDER BY id DESC',
    );
    return filas.map((f) => SolicitudTraslado.fromMap(f)).toList();
  }
}