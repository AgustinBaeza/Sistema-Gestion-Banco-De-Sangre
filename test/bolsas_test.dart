import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sqlite3/sqlite3.dart";
import "package:gestion_banco_sangre/basedatos/repositorio_bolsa.dart";
import "package:gestion_banco_sangre/modelos/bolsa_sangre.dart";
import "package:gestion_banco_sangre/pantallas/formulario_bolsa.dart";

void main() {
  late Database db;
  late RepositorioBolsa repo;

  setUp(() {
    db = sqlite3.openInMemory();
    repo = RepositorioBolsa()..init(db);
  });

  tearDown(() => db.close());

  final ingreso = DateTime(2026, 11, 1);
  final vence = DateTime(2026, 12, 6);

  test("guarda una bolsa con todos sus datos", () {
    final b = repo.crear(
      codigo: " bs-0001 ",
      tipo: TipoSanguineo.oNegativo,
      volumenMl: 450,
      fechaIngreso: ingreso,
      fechaVencimiento: vence,
    );
    expect(b.codigo, "BS-0001");
    final guardada = repo.listar().single;
    expect(guardada.tipo, TipoSanguineo.oNegativo);
    expect(guardada.volumenMl, 450);
    expect(guardada.fechaVencimiento, vence);
  });

  test("rechaza codigos duplicados sin distinguir mayusculas", () {
    repo.crear(
      codigo: "BS-0001",
      tipo: TipoSanguineo.aPositivo,
      volumenMl: 450,
      fechaIngreso: ingreso,
      fechaVencimiento: vence,
    );
    expect(
      () => repo.crear(
        codigo: "bs-0001",
        tipo: TipoSanguineo.aPositivo,
        volumenMl: 450,
        fechaIngreso: ingreso,
        fechaVencimiento: vence,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test("rechaza vencimiento anterior al ingreso y volumen fuera de rango", () {
    expect(
      () => repo.crear(
        codigo: "BS-0002",
        tipo: TipoSanguineo.bPositivo,
        volumenMl: 450,
        fechaIngreso: vence,
        fechaVencimiento: ingreso,
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repo.crear(
        codigo: "BS-0003",
        tipo: TipoSanguineo.bPositivo,
        volumenMl: 5000,
        fechaIngreso: ingreso,
        fechaVencimiento: vence,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  testWidgets("el formulario avisa de los campos obligatorios vacios", (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: FormularioBolsaPage(repo: repo)));

    final boton = find.text("Guardar bolsa");
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump();

    expect(find.text("El codigo es obligatorio"), findsOneWidget);
    expect(find.text("Selecciona un tipo sanguineo"), findsOneWidget);
    expect(find.text("El volumen es obligatorio"), findsOneWidget);
    expect(find.text("Selecciona la fecha de ingreso"), findsOneWidget);
    expect(find.text("Selecciona la fecha de vencimiento"), findsOneWidget);
    expect(repo.listar(), isEmpty);
  });
}
