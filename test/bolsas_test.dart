
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
 
  /// Fechas relativas a hoy para que los tests no fallen con el tiempo
  final hoy = fechaHoy();
  final ingreso = sumarDias(hoy, -2);
  final vence = sumarDias(ingreso, BolsaSangre.vidaUtilDias);
 
  Future<BolsaSangre> crear({
    String codigo = "BS-0001",
    int volumen = 450,
    DateTime? fechaIngreso,
    DateTime? fechaVencimiento,
  }) => repo.crear(
    codigo: codigo,
    tipo: TipoSanguineo.oNegativo,
    volumenMl: volumen,
    fechaIngreso: fechaIngreso ?? ingreso,
    fechaVencimiento: fechaVencimiento ?? vence,
  );
 
  test("guarda una bolsa con todos sus datos", () async {
    final b = await crear(codigo: " bs-0001 ");
    expect(b.codigo, "BS-0001");
    final guardada = repo.listar().single;
    expect(guardada.tipo, TipoSanguineo.oNegativo);
    expect(guardada.volumenMl, 450);
    expect(guardada.fechaIngreso, ingreso);
    expect(guardada.fechaVencimiento, vence);
  });
 
  test("rechaza codigos duplicados sin distinguir mayusculas", () async {
    await crear(codigo: "BS-0001");
    await expectLater(crear(codigo: "bs-0001"), throwsA(isA<StateError>()));
  });
 
  test(
    "rechaza vencimiento anterior al ingreso y volumen fuera de rango",
    () async {
      await expectLater(
        crear(codigo: "BS-0002", fechaVencimiento: sumarDias(ingreso, -1)),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        crear(codigo: "BS-0003", volumen: 5000),
        throwsA(isA<ArgumentError>()),
      );
      expect(repo.listar(), isEmpty);
    },
  );
 
  test("rechaza unidades vencidas (RF-02)", () async {
    await expectLater(
      crear(
        codigo: "BS-0004",
        fechaIngreso: sumarDias(hoy, -40),
        fechaVencimiento: sumarDias(hoy, -1),
      ),
      throwsA(isA<ArgumentError>()),
    );
    // Si vence hoy tampoco se considera apta
    await expectLater(
      crear(codigo: "BS-0005", fechaVencimiento: hoy),
      throwsA(isA<ArgumentError>()),
    );
    expect(repo.listar(), isEmpty);
  });
 
  test("rechaza vencimiento mayor a 42 dias desde el ingreso", () async {
    await expectLater(
      crear(
        codigo: "BS-0006",
        fechaVencimiento: sumarDias(ingreso, BolsaSangre.vidaUtilDias + 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
 
  test("rechaza fecha de ingreso futura", () async {
    await expectLater(
      crear(
        codigo: "BS-0007",
        fechaIngreso: sumarDias(hoy, 1),
        fechaVencimiento: sumarDias(hoy, 10),
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
 
  testWidgets("el formulario avisa cuando el formato es incorrecto", (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: FormularioBolsaPage(repo: repo)));
 
    await tester.enterText(
      find.widgetWithText(TextFormField, "Codigo identificador *"),
      "ab",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Volumen (mL) *"),
      "50",
    );
    await tester.pump();
 
    // El codigo se pasa a mayusculas al escribir
    expect(find.text("AB"), findsOneWidget);
    expect(
      find.text("Usa entre 4 y 20 caracteres (A-Z, 0-9, -)"),
      findsOneWidget,
    );
    expect(find.text("Debe estar entre 100 y 600 mL"), findsOneWidget);
  });
 
  testWidgets("registra una bolsa completa y sugiere el vencimiento", (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: FormularioBolsaPage(repo: repo)));
 
    await tester.enterText(
      find.widgetWithText(TextFormField, "Codigo identificador *"),
      "BS-0200",
    );
 
    await tester.tap(find.byType(DropdownButtonFormField<TipoSanguineo>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("O-").last);
    await tester.pumpAndSettle();
 
    await tester.enterText(
      find.widgetWithText(TextFormField, "Volumen (mL) *"),
      "450",
    );
 
    // Se elige hoy como ingreso: el vencimiento se llena con hoy + 42 dias
    final campoIngreso = find.widgetWithText(
      TextFormField,
      "Fecha de ingreso *",
    );
    await tester.ensureVisible(campoIngreso);
    await tester.tap(campoIngreso);
    await tester.pumpAndSettle();
    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();
 
    expect(find.text(formatearFecha(hoy)), findsOneWidget);
    final sugerido = sumarDias(hoy, BolsaSangre.vidaUtilDias);
    expect(find.text(formatearFecha(sugerido)), findsOneWidget);
 
    final boton = find.text("Guardar bolsa");
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
 
    final guardada = repo.listar().single;
    expect(guardada.codigo, "BS-0200");
    expect(guardada.tipo, TipoSanguineo.oNegativo);
    expect(guardada.fechaVencimiento, sugerido);
    expect(find.text("Bolsa BS-0200 registrada correctamente"), findsOneWidget);
    // El formulario queda limpio para la siguiente unidad
    expect(find.text("BS-0200"), findsNothing);
  });
}