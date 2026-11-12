import 'package:sqlite3/common.dart';
import '../modelos/stock_sede.dart';
import 'conexion.dart';

class RepositorioStock {
  late final CommonDatabase _db;

  /// Inicializa la base de datos y crea la tabla de unidades de sangre si no existe
  void init(CommonDatabase db) {
    _db = db;
    
    _db.execute("""
      CREATE TABLE IF NOT EXISTS unidades_sangre (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        sede             TEXT NOT NULL,
        tipo_sanguineo   TEXT NOT NULL,
        estado           TEXT NOT NULL,
        fecha_expiracion TEXT NOT NULL
      )
    """);
  }

  /// Excluye unidades no disponibles o vencidas (comparando con la fecha actual)
  /// Soporta filtros opcionales por sede y tipo sanguíneo 
  List<StockSede> consultarStockPorSedeYTipo({
    String? sedeFiltro, 
    String? tipoFiltro,
  }) {
    final String fechaActual = DateTime.now().toIso8601String();

    String query = """
      SELECT 
        sede, 
        tipo_sanguineo, 
        CAST(COUNT(id) AS INTEGER) AS cantidad
      FROM unidades_sangre
      WHERE estado = 'disponible' 
        AND fecha_expiracion > ?
    """;

    final List<Object?> parametros = [fechaActual];

    // Aplicar filtros individuales o combinados
    if (sedeFiltro != null && sedeFiltro.trim().isNotEmpty) {
      query += " AND sede = ?";
      parametros.add(sedeFiltro.trim());
    }

    if (tipoFiltro != null && tipoFiltro.trim().isNotEmpty) {
      query += " AND tipo_sanguineo = ?";
      parametros.add(tipoFiltro.trim());
    }

    query += """
      GROUP BY sede, tipo_sanguineo
      ORDER BY sede, tipo_sanguineo
    """;

    final filas = _db.select(query, parametros);

    return filas.map((fila) => StockSede.fromMap(fila)).toList();
  }

  /// Método auxiliar útil para insertar registros de prueba 
  Future<void> insertarUnidadPrueba({
    required String sede,
    required String tipoSanguineo,
    required String estado,
    required String fechaExpiracion,
  }) async {
    _db.execute(
      "INSERT INTO unidades_sangre (sede, tipo_sanguineo, estado, fecha_expiracion) VALUES (?, ?, ?, ?)",
      [sede, tipoSanguineo, estado, fechaExpiracion],
    );
    await persistir();
  }
}