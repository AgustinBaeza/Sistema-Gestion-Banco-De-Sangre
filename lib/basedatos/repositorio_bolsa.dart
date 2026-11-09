import "package:sqlite3/common.dart";
import "../modelos/bolsa_sangre.dart";

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
        volumen_ml        INTEGER NOT NULL CHECK (volumen_ml > 0),
        fecha_ingreso     TEXT NOT NULL,
        fecha_vencimiento TEXT NOT NULL CHECK (fecha_vencimiento > fecha_ingreso)
      )
    """);
  }

  BolsaSangre crear({
    required String codigo,
    required TipoSanguineo tipo,
    required int volumenMl,
    required DateTime fechaIngreso,
    required DateTime fechaVencimiento,
  }) {
    final clave = codigo.trim().toUpperCase();

    /// Validaciones
    if (!BolsaSangre.codigoRegex.hasMatch(clave)) {
      throw ArgumentError("Codigo invalido");
    }
    if (volumenMl < BolsaSangre.volumenMinMl ||
        volumenMl > BolsaSangre.volumenMaxMl) {
      throw ArgumentError(
        "El volumen debe estar entre ${BolsaSangre.volumenMinMl} y "
        "${BolsaSangre.volumenMaxMl} mL",
      );
    }
    if (!fechaVencimiento.isAfter(fechaIngreso)) {
      throw ArgumentError(
        "El vencimiento debe ser posterior a la fecha de ingreso",
      );
    }

    try {
      _db.execute(
        "INSERT INTO bolsas_sangre "
        "(codigo, tipo_sanguineo, volumen_ml, fecha_ingreso, fecha_vencimiento) "
        "VALUES (?, ?, ?, ?, ?)",
        [
          clave,
          tipo.name,
          volumenMl,
          fechaIso(fechaIngreso),
          fechaIso(fechaVencimiento),
        ],
      );
    } on SqliteException catch (e) {
      if (e.extendedResultCode == _sqliteConstraintUnique) {
        throw StateError("Ya existe una bolsa con ese codigo");
      }
      rethrow;
    }

    return BolsaSangre(
      id: _db.lastInsertRowId,
      codigo: clave,
      tipo: tipo,
      volumenMl: volumenMl,
      fechaIngreso: fechaIngreso,
      fechaVencimiento: fechaVencimiento,
    );
  }

  List<BolsaSangre> listar() {
    final filas = _db.select(
      "SELECT id, codigo, tipo_sanguineo, volumen_ml, "
      "fecha_ingreso, fecha_vencimiento "
      "FROM bolsas_sangre ORDER BY id DESC",
    );
    return filas.map((f) => BolsaSangre.fromMap(f)).toList();
  }
}
