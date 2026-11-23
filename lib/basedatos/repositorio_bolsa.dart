import "package:sqlite3/common.dart";
import "../modelos/bolsa_sangre.dart";
import "../modelos/stock_sede.dart";
import "conexion.dart";
 
class RepositorioBolsa {
  static const _sqliteConstraintUnique = 2067;
 
  late final CommonDatabase _db;
 
  /// Recibe una base de datos ya abierta y crea la tabla si no existe
  void init(CommonDatabase db) {
    _db = db;
 
    final tipos = TipoSanguineo.values.map((t) => "'${t.name}'").join(", ");
 
    _db.execute("""
      CREATE TABLE IF NOT EXISTS bolsas_sangre (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo            TEXT NOT NULL UNIQUE COLLATE NOCASE,
        tipo_sanguineo    TEXT NOT NULL CHECK (tipo_sanguineo IN ($tipos)),
        sede              TEXT NOT NULL,
        volumen_ml        INTEGER NOT NULL CHECK (volumen_ml > 0),
        fecha_ingreso     TEXT NOT NULL,
        fecha_vencimiento TEXT NOT NULL CHECK (fecha_vencimiento > fecha_ingreso)
      )
    """);

    // Migracion: las bases creadas antes de la sede no tienen la columna, idealmente eliminar la migracion cuando ya no haya bases de datos antiguas
    final columnas = _db.select("PRAGMA table_info(bolsas_sangre)");
    if (!columnas.any((c) => c["name"] == "sede")) {
      _db.execute(
        "ALTER TABLE bolsas_sangre "
        "ADD COLUMN sede TEXT NOT NULL DEFAULT 'Desconocida'",
      );
    }
  }
 
  Future<BolsaSangre> crear({
    required String codigo,
    required TipoSanguineo tipo,
    required String sede,
    required int volumenMl,
    required DateTime fechaIngreso,
    required DateTime fechaVencimiento,
  }) async {
    final clave = codigo.trim().toUpperCase();
    final sedeLimpia = sede.trim();
    final ingreso = soloFecha(fechaIngreso);
    final vence = soloFecha(fechaVencimiento);
    final hoy = fechaHoy();

    /// Validaciones
    if (!BolsaSangre.codigoRegex.hasMatch(clave)) {
      throw ArgumentError("Codigo invalido");
    }
    if (sedeLimpia.isEmpty) {
      throw ArgumentError("La sede es obligatoria");
    }
    if (volumenMl < BolsaSangre.volumenMinMl ||
        volumenMl > BolsaSangre.volumenMaxMl) {
      throw ArgumentError(
        "El volumen debe estar entre ${BolsaSangre.volumenMinMl} y "
        "${BolsaSangre.volumenMaxMl} mL",
      );
    }
    if (ingreso.isAfter(hoy)) {
      throw ArgumentError("La fecha de ingreso no puede ser futura");
    }
    if (!vence.isAfter(ingreso)) {
      throw ArgumentError(
        "El vencimiento debe ser posterior a la fecha de ingreso",
      );
    }
    // Informe, RF-02 y CU-02 7.a: no se registran unidades vencidas
    if (!vence.isAfter(hoy)) {
      throw ArgumentError("La unidad ya esta vencida, no se puede registrar");
    }
    // Los globulos rojos duran como maximo 42 dias desde la extraccion,
    // y el ingreso siempre es igual o posterior a la extraccion
    if (vence.isAfter(sumarDias(ingreso, BolsaSangre.vidaUtilDias))) {
      throw ArgumentError(
        "El vencimiento no puede superar ${BolsaSangre.vidaUtilDias} dias "
        "desde el ingreso",
      );
    }
 
    try {
      _db.execute(
        "INSERT INTO bolsas_sangre "
        "(codigo, tipo_sanguineo, sede, volumen_ml, fecha_ingreso, "
        "fecha_vencimiento) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        [clave, tipo.name, sedeLimpia, volumenMl, fechaIso(ingreso), fechaIso(vence)],
      );
    } on SqliteException catch (e) {
      if (e.extendedResultCode == _sqliteConstraintUnique) {
        throw StateError("Ya existe una bolsa con ese codigo");
      }
      rethrow;
    }
 
    // Se lee antes del await para no mezclarlo con otro insert
    final id = _db.lastInsertRowId;
 
    // En web baja los cambios a IndexedDB; en escritorio no hace nada
    await persistir();
 
    return BolsaSangre(
      id: id,
      codigo: clave,
      tipo: tipo,
      sede: sedeLimpia,
      volumenMl: volumenMl,
      fechaIngreso: ingreso,
      fechaVencimiento: vence,
    );
  }

  List<BolsaSangre> listar() {
    final filas = _db.select(
      "SELECT id, codigo, tipo_sanguineo, sede, volumen_ml, "
      "fecha_ingreso, fecha_vencimiento "
      "FROM bolsas_sangre ORDER BY id DESC",
    );
    return filas.map((f) => BolsaSangre.fromMap(f)).toList();
  }

  /// Stock disponible para el inventario: cuenta las bolsas agrupadas por
  /// sede y tipo sanguineo, excluyendo las unidades ya vencidas (RF-02).
  List<StockSede> stockPorSedeYTipo() {
    final filas = _db.select(
      "SELECT sede, tipo_sanguineo, "
      "CAST(COUNT(id) AS INTEGER) AS cantidad "
      "FROM bolsas_sangre "
      "WHERE fecha_vencimiento > ? "
      "GROUP BY sede, tipo_sanguineo "
      "ORDER BY sede, tipo_sanguineo",
      [fechaIso(fechaHoy())],
    );
    return filas.map((f) => StockSede.fromMap(f)).toList();
  }
}