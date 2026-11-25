import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sqlite3/sqlite3.dart";
import "package:gestion_banco_sangre/basedatos/repositorio_bolsa.dart";
import "package:gestion_banco_sangre/modelos/bolsa_sangre.dart";
import "package:gestion_banco_sangre/modelos/nivel_stock.dart";
import "package:gestion_banco_sangre/modelos/stock_sede.dart";
import "package:gestion_banco_sangre/pantallas/inventario.dart";

void main() {
  late Database db;
  late RepositorioBolsa repo;

  setUp(() {
    db = sqlite3.openInMemory();
    repo = RepositorioBolsa()..init(db);
  });

  tearDown(() => db.close());

  final hoy = fechaHoy();
  var correlativo = 0;

  /// Registra n bolsas vigentes con el repositorio
  Future<void> agregar(TipoSanguineo tipo, String sede, [int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await repo.crear(
        codigo: "BS-${(++correlativo).toString().padLeft(4, '0')}",
        tipo: tipo,
        sede: sede,
        volumenMl: 450,
        fechaIngreso: sumarDias(hoy, -2),
        fechaVencimiento: sumarDias(hoy, 40),
      );
    }
  }

  /// Inserta directo en la tabla, porque crear() no acepta bolsas vencidas
  void agregarConVencimiento(TipoSanguineo tipo, String sede, DateTime vence) {
    db.execute(
      "INSERT INTO bolsas_sangre (codigo, tipo_sanguineo, sede, volumen_ml, "
      "fecha_ingreso, fecha_vencimiento) VALUES (?, ?, ?, ?, ?, ?)",
      ["BS-V${++correlativo}", tipo.name, sede, 450,
       fechaIso(sumarDias(vence, -42)), fechaIso(vence)],
    );
  }

  group("umbrales de NivelStock", () {
    test("clasifica justo en los limites", () {
      expect(NivelStock.de(0), NivelStock.critico);
      expect(NivelStock.de(NivelStock.maxCritico), NivelStock.critico);
      expect(NivelStock.de(NivelStock.maxCritico + 1), NivelStock.bajo);
      expect(NivelStock.de(NivelStock.maxBajo), NivelStock.bajo);
      expect(NivelStock.de(NivelStock.maxBajo + 1), NivelStock.normal);
      expect(NivelStock.de(NivelStock.minAbundante - 1), NivelStock.normal);
      expect(NivelStock.de(NivelStock.minAbundante), NivelStock.abundante);
    });
  });

  group("evaluarStock", () {
    test("cruza tipos y sedes y deja en 0 las combinaciones sin bolsas", () {
      final filas = [
        StockSede(sede: "Concepcion", tipoSanguineo: "oNegativo", cantidad: 3),
      ];
      final r = evaluarStock(
        filas,
        ["Concepcion", "Talca"],
        [TipoSanguineo.oNegativo, TipoSanguineo.aPositivo],
      );
      expect(r, hasLength(4));
      final oNegConce = r.firstWhere(
        (c) => c.tipo == TipoSanguineo.oNegativo && c.sede == "Concepcion",
      );
      expect(oNegConce.cantidad, 3);
      expect(oNegConce.nivel, NivelStock.bajo);
      expect(r.where((c) => c.cantidad == 0), hasLength(3));
      expect(r.every((c) => c.enFalta), isTrue);
    });

    test("normal y abundante no cuentan como falta", () {
      final r = evaluarStock(
        [
          StockSede(sede: "A", tipoSanguineo: "aPositivo", cantidad: 8),
          StockSede(sede: "A", tipoSanguineo: "bPositivo", cantidad: 20),
        ],
        ["A"],
        [TipoSanguineo.aPositivo, TipoSanguineo.bPositivo],
      );
      expect(r.map((c) => c.nivel), [NivelStock.normal, NivelStock.abundante]);
      expect(r.any((c) => c.enFalta), isFalse);
    });
  });

  group("consulta de stock con filtros", () {
    setUp(() async {
      await agregar(TipoSanguineo.oNegativo, "Concepcion", 3);
      await agregar(TipoSanguineo.aPositivo, "Concepcion", 2);
      await agregar(TipoSanguineo.oNegativo, "Talca", 1);
    });

    test("sin filtros agrupa por sede y tipo", () {
      final r = repo.stockPorSedeYTipo();
      expect(r, hasLength(3));
      expect(r.fold(0, (s, f) => s + f.cantidad), 6);
    });

    test("filtra por sede", () {
      final r = repo.stockPorSedeYTipo(sede: "Talca");
      expect(r.single.tipoSanguineo, "oNegativo");
      expect(r.single.cantidad, 1);
    });

    test("filtra por tipo", () {
      final r = repo.stockPorSedeYTipo(tipo: TipoSanguineo.oNegativo);
      expect(r.map((f) => f.sede), ["Concepcion", "Talca"]);
    });

    test("filtra por sede y tipo a la vez", () {
      final r = repo.stockPorSedeYTipo(
        sede: "Concepcion",
        tipo: TipoSanguineo.aPositivo,
      );
      expect(r.single.cantidad, 2);
      expect(
        repo.stockPorSedeYTipo(sede: "Talca", tipo: TipoSanguineo.aPositivo),
        isEmpty,
      );
    });

    test("excluye las bolsas vencidas o que vencen hoy", () {
      agregarConVencimiento(TipoSanguineo.oNegativo, "Talca", sumarDias(hoy, -5));
      agregarConVencimiento(TipoSanguineo.oNegativo, "Talca", hoy);
      expect(repo.stockPorSedeYTipo(sede: "Talca").single.cantidad, 1);
    });

    test("una sede con solo bolsas vencidas aparece y queda en falta", () {
      agregarConVencimiento(TipoSanguineo.bNegativo, "Chillan", sumarDias(hoy, -1));
      expect(repo.sedes(), ["Chillan", "Concepcion", "Talca"]);
      final r = evaluarStock(
        repo.stockPorSedeYTipo(sede: "Chillan"),
        ["Chillan"],
        TipoSanguineo.values,
      );
      expect(r.every((c) => c.nivel == NivelStock.critico), isTrue);
    });
  });

  testWidgets("la pantalla muestra el resumen y el reporte de evaluacion", (
    tester,
  ) async {
    await tester.runAsync(() async {
      await agregar(TipoSanguineo.oNegativo, "Concepcion", 2);
    });
    await tester.pumpWidget(MaterialApp(home: InventarioPage(repo: repo)));

    // O- queda bajo (2) y los otros 7 tipos criticos (0)
    expect(find.text("Falta de stock (8)"), findsOneWidget);
    expect(find.text("Abundancia de stock (0)"), findsOneWidget);
    expect(find.text("O- en Concepcion"), findsOneWidget);
    expect(find.text("2 · Bajo"), findsOneWidget);
  });

  testWidgets("sin bolsas muestra el aviso", (tester) async {
    await tester.pumpWidget(MaterialApp(home: InventarioPage(repo: repo)));
    expect(find.text("Aún no hay bolsas registradas."), findsOneWidget);
  });
}