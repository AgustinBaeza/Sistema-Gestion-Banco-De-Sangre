import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sqlite3/sqlite3.dart";
import "package:gestion_banco_sangre/basedatos/repositorio_bolsa.dart";
import "package:gestion_banco_sangre/modelos/bolsa_sangre.dart";
import "package:gestion_banco_sangre/modelos/ordenamiento_vencimiento.dart";
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

  // Metemos las bolsas directo a la tabla porque crear() no deja guardar bolsas vencidas
  void insertarBolsa({
    required String codigo,
    TipoSanguineo tipo = TipoSanguineo.oNegativo,
    String sede = "Concepcion",
    int volumenMl = 450,
    required DateTime ingreso,
    required DateTime vence,
  }) {
    db.execute(
      "INSERT INTO bolsas_sangre (codigo, tipo_sanguineo, sede, volumen_ml, "
      "fecha_ingreso, fecha_vencimiento) VALUES (?, ?, ?, ?, ?, ?)",
      [codigo, tipo.name, sede, volumenMl, fechaIso(ingreso), fechaIso(vence)],
    );
  }

  group("evaluacion de estado y casos negativos", () {
    test("clasifica disponible, proxima a vencer y vencida sin dias negativos", () {
      final ref = DateTime(2026, 11, 20);

      final disponible = UnidadOrdenada.evaluar(
        BolsaSangre(
          id: 1,
          codigo: "BS-0001",
          tipo: TipoSanguineo.aPositivo,
          sede: "Concepcion",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 11, 10),
          fechaVencimiento: DateTime(2026, 12, 10),
        ),
        fechaReferencia: ref,
      );
      expect(disponible.estado, EstadoVencimiento.disponible);
      expect(disponible.esApta, isTrue);
      expect(disponible.diasRestantes, 20);

      final porVencer = UnidadOrdenada.evaluar(
        BolsaSangre(
          id: 2,
          codigo: "BS-0002",
          tipo: TipoSanguineo.oNegativo,
          sede: "Concepcion",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 11, 1),
          fechaVencimiento: DateTime(2026, 11, 24),
        ),
        fechaReferencia: ref,
      );
      expect(porVencer.estado, EstadoVencimiento.proximaAVencer);
      expect(porVencer.esApta, isTrue);
      expect(porVencer.diasRestantes, 4);

      final vencida = UnidadOrdenada.evaluar(
        BolsaSangre(
          id: 3,
          codigo: "BS-0003",
          tipo: TipoSanguineo.bPositivo,
          sede: "Talca",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 10, 1),
          fechaVencimiento: DateTime(2026, 11, 15),
        ),
        fechaReferencia: ref,
      );
      expect(vencida.estado, EstadoVencimiento.vencida);
      expect(vencida.esApta, isFalse);
      expect(vencida.diasRestantes, 0);
      expect(vencida.detalleEstado, contains("Vencida hace 5 días"));
    });

    test("maneja datos invalidos o umbral negativo sin caerse", () {
      final ref = DateTime(2026, 11, 20);

      // Probamos con volumen negativo y dias de alerta negativos
      final volumenInvalido = UnidadOrdenada.evaluar(
        BolsaSangre(
          id: 1,
          codigo: "BS-ERR1",
          tipo: TipoSanguineo.oPositivo,
          sede: "Concepcion",
          volumenMl: -100,
          fechaIngreso: DateTime(2026, 11, 1),
          fechaVencimiento: DateTime(2026, 12, 1),
        ),
        fechaReferencia: ref,
        diasAlerta: -5,
      );
      expect(volumenInvalido.estado, EstadoVencimiento.vencida);
      expect(volumenInvalido.esApta, isFalse);
      expect(volumenInvalido.diasRestantes, 0);

      // Si la fecha de vencimiento viene antes que el ingreso
      final fechasInvertidas = UnidadOrdenada.evaluar(
        BolsaSangre(
          id: 2,
          codigo: "BS-ERR2",
          tipo: TipoSanguineo.oPositivo,
          sede: "Concepcion",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 11, 20),
          fechaVencimiento: DateTime(2026, 11, 10),
        ),
        fechaReferencia: ref,
      );
      expect(fechasInvertidas.estado, EstadoVencimiento.vencida);
      expect(fechasInvertidas.esApta, isFalse);
    });
  });

  group("ordenamiento cronologico por vencimiento", () {
    test("ordena primero las mas proximas a vencer y deja las vencidas al final", () {
      final ref = DateTime(2026, 11, 20);
      final bolsas = [
        BolsaSangre(
          id: 1,
          codigo: "BS-LEJANA",
          tipo: TipoSanguineo.aPositivo,
          sede: "Concepcion",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 11, 1),
          fechaVencimiento: DateTime(2026, 12, 12),
        ),
        BolsaSangre(
          id: 2,
          codigo: "BS-VENCIDA",
          tipo: TipoSanguineo.oNegativo,
          sede: "Concepcion",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 10, 1),
          fechaVencimiento: DateTime(2026, 11, 10),
        ),
        BolsaSangre(
          id: 3,
          codigo: "BS-URGENTE",
          tipo: TipoSanguineo.bNegativo,
          sede: "Concepcion",
          volumenMl: 450,
          fechaIngreso: DateTime(2026, 11, 1),
          fechaVencimiento: DateTime(2026, 11, 23),
        ),
      ];

      final ordenadas = ordenarUnidadesPorVencimiento(bolsas, fechaReferencia: ref);
      expect(
        ordenadas.map((u) => u.bolsa.codigo).toList(),
        ["BS-URGENTE", "BS-LEJANA", "BS-VENCIDA"],
      );
      expect(ordenadas.last.esApta, isFalse);

      // Al ordenar de mas lejana a mas cercana, las vencidas igual quedan abajo
      final inversas = ordenarUnidadesPorVencimiento(
        bolsas,
        fechaReferencia: ref,
        ascendente: false,
      );
      expect(
        inversas.map((u) => u.bolsa.codigo).toList(),
        ["BS-LEJANA", "BS-URGENTE", "BS-VENCIDA"],
      );
    });
  });

  group("consulta ordenada en RepositorioBolsa", () {
    test("filtra por sede y tipo manteniendo el orden por vencimiento", () {
      insertarBolsa(
        codigo: "BS-${++correlativo}",
        sede: "Concepcion",
        tipo: TipoSanguineo.oNegativo,
        ingreso: sumarDias(hoy, -10),
        vence: sumarDias(hoy, 25),
      );
      insertarBolsa(
        codigo: "BS-${++correlativo}",
        sede: "Concepcion",
        tipo: TipoSanguineo.oNegativo,
        ingreso: sumarDias(hoy, -20),
        vence: sumarDias(hoy, 3),
      );
      insertarBolsa(
        codigo: "BS-${++correlativo}",
        sede: "Concepcion",
        tipo: TipoSanguineo.oNegativo,
        ingreso: sumarDias(hoy, -45),
        vence: sumarDias(hoy, -2),
      );
      insertarBolsa(
        codigo: "BS-${++correlativo}",
        sede: "Talca",
        tipo: TipoSanguineo.aPositivo,
        ingreso: sumarDias(hoy, -5),
        vence: sumarDias(hoy, 15),
      );

      final conce = repo.listarOrdenadasPorVencimiento(
        sede: "Concepcion",
        tipo: TipoSanguineo.oNegativo,
      );
      expect(conce, hasLength(3));
      expect(conce[0].bolsa.codigo, "BS-2");
      expect(conce[0].estado, EstadoVencimiento.proximaAVencer);
      expect(conce[1].bolsa.codigo, "BS-1");
      expect(conce[1].estado, EstadoVencimiento.disponible);
      expect(conce[2].bolsa.codigo, "BS-3");
      expect(conce[2].estado, EstadoVencimiento.vencida);
    });
  });

  testWidgets("muestra alertas visuales y permite ocultar bolsas vencidas", (
    tester,
  ) async {
    insertarBolsa(
      codigo: "BS-ALERTA",
      sede: "Concepcion",
      tipo: TipoSanguineo.oNegativo,
      ingreso: sumarDias(hoy, -20),
      vence: sumarDias(hoy, 2),
    );
    insertarBolsa(
      codigo: "BS-CADUCA",
      sede: "Concepcion",
      tipo: TipoSanguineo.aPositivo,
      ingreso: sumarDias(hoy, -45),
      vence: sumarDias(hoy, -3),
    );

    await tester.pumpWidget(MaterialApp(home: InventarioPage(repo: repo)));

    expect(find.text("Control de vencimiento por unidad"), findsOneWidget);
    expect(find.text("Próxima a vencer"), findsOneWidget);
    expect(find.text("Vencida (No apta)"), findsOneWidget);
    expect(find.textContaining("BS-CADUCA"), findsOneWidget);

    // Hacemos scroll hasta el chip y lo desactivamos para ocultar las vencidas
    final filtroVencidas = find.text("Mostrar vencidas");
    await tester.ensureVisible(filtroVencidas);
    await tester.tap(filtroVencidas);
    await tester.pumpAndSettle();

    expect(find.textContaining("BS-CADUCA"), findsNothing);
    expect(find.textContaining("BS-ALERTA"), findsOneWidget);
  });
}