import 'package:sqlite3/common.dart';
import '../modelos/bolsa_sangre.dart';
import '../modelos/nivel_stock.dart';
import '../modelos/solicitud_traslado.dart';
import 'conexion.dart';

class RepositorioTraslado {
  late final CommonDatabase _db;

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

  /// Umbrales alineados con `NivelStock` de US4:
  /// - Mínimo seguro para no caer en stock bajo: NivelStock.maxBajo + 1 (5)
  /// - Óptimo de referencia: punto medio entre mínimo y abundante
  /// - Máximo de referencia: NivelStock.minAbundante (15)
  NivelesStockReferencia calcularNivelesStock({
    required TipoSanguineo tipoSanguineo,
    int factorCapacidadSede = 1,
  }) {
    final int factor = factorCapacidadSede < 1 ? 1 : factorCapacidadSede;
    final int minimo = (NivelStock.maxBajo + 1) * factor;
    final int maximo = NivelStock.minAbundante * factor;
    final int optimo = ((minimo + maximo) / 2).round();

    return NivelesStockReferencia(
      stockMinimo: minimo,
      stockOptimo: optimo,
      stockMaximo: maximo,
    );
  }

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

  Map<String, int> mapaStockDisponiblePorSedeYTipo(List<String> sedes) {
    final mapa = <String, int>{};
    for (final sede in sedes) {
      for (final tipo in TipoSanguineo.values) {
        mapa['$sede|${tipo.name}'] = obtenerStockDisponibleOrigen(
          sedeOrigen: sede,
          tipoSanguineo: tipo,
        );
      }
    }
    return mapa;
  }

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
      throw ArgumentError(
        'La sede de origen y la sede de destino son obligatorias.',
      );
    }

    if (origen.toLowerCase() == destino.toLowerCase()) {
      throw ArgumentError(
        'La sede de origen y la sede de destino deben ser distintas.',
      );
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

  List<SolicitudTraslado> listarSolicitudes() {
    final filas = _db.select(
      'SELECT * FROM solicitudes_traslado ORDER BY id DESC',
    );
    return filas.map((f) => SolicitudTraslado.fromMap(f)).toList();
  }
}