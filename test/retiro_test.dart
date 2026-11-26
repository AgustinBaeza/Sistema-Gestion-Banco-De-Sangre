import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:gestion_banco_sangre/basedatos/repositorio_bolsa.dart';
import 'package:gestion_banco_sangre/modelos/bolsa_sangre.dart';
import 'package:gestion_banco_sangre/modelos/estado_unidad.dart';
import 'package:gestion_banco_sangre/screens/formulario_retiro.dart';

void main() {
  late Database db;
  late RepositorioBolsa repo;

  setUp(() {
    // Cada prueba utiliza una base de datos independiente.
    db = sqlite3.openInMemory();
    repo = RepositorioBolsa()..init(db);
  });

  tearDown(() {
    db.close();
  });

  Future<void> crearBolsa({
    String codigo = 'TEST-001',
    String sede = 'Concepcion',
  }) async {
    await repo.crear(
      codigo: codigo,
      tipo: TipoSanguineo.aPositivo,
      sede: sede,
      volumenMl: 450,
      fechaIngreso: sumarDias(fechaHoy(), -2),
      fechaVencimiento: sumarDias(fechaHoy(), 40),
    );
  }

  group('US5 - Registro de retiro', () {
    test('Retiro valido guarda estado, motivo y fecha', () async {
      await crearBolsa();

      await repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Uso de unidad');

      final bolsa = repo.listar().single;

      expect(bolsa.estado, EstadoUnidad.retirada);
      expect(bolsa.motivoRetiro, 'Uso de unidad');
      expect(bolsa.fechaRetiro, isNotNull);
    });

    test('El retiro disminuye el stock en una unidad', () async {
      await crearBolsa(codigo: 'TEST-001');
      await crearBolsa(codigo: 'TEST-002');

      expect(repo.stockPorSedeYTipo().single.cantidad, 2);

      await repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Uso de unidad');

      final stock = repo.stockPorSedeYTipo();

      expect(stock.single.cantidad, 1);

      // Las bolsas se conservan para mantener trazabilidad.
      expect(repo.listar(), hasLength(2));
    });

    test('No permite retirar dos veces la misma unidad', () async {
      await crearBolsa();

      await repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Uso de unidad');

      await expectLater(
        repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Descarte'),
        throwsA(isA<StateError>()),
      );

      final bolsa = repo.listar().single;

      expect(bolsa.estado, EstadoUnidad.retirada);
      expect(bolsa.motivoRetiro, 'Uso de unidad');
    });

    test('Rechaza un codigo que no existe', () async {
      await expectLater(
        repo.retirarUnidad(codigo: 'TEST-404', motivo: 'Uso de unidad'),
        throwsA(isA<StateError>()),
      );

      expect(repo.listar(), isEmpty);
    });

    test('Rechaza motivos de retiro invalidos', () async {
      await crearBolsa();

      await expectLater(
        repo.retirarUnidad(codigo: 'TEST-001', motivo: ''),
        throwsA(isA<ArgumentError>()),
      );

      expect(repo.listar().single.estado, EstadoUnidad.disponible);
    });

    test('No permite retirar una unidad en transito', () async {
      await crearBolsa();

      // Simulamos una unidad despachada por la US8.
      db.execute(
        "UPDATE bolsas_sangre SET estado = 'EN_TRANSITO' "
        "WHERE codigo = ?",
        ['TEST-001'],
      );

      await expectLater(
        repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Uso de unidad'),
        throwsA(isA<StateError>()),
      );

      expect(repo.listar().single.estado, EstadoUnidad.enTransito);
    });

    test('Una unidad vencida requiere motivo Vencimiento', () async {
      await crearBolsa();

      // Simulamos el paso del tiempo sin esperar dias reales.
      db.execute(
        'UPDATE bolsas_sangre SET fecha_vencimiento = ? '
        'WHERE codigo = ?',
        [fechaIso(sumarDias(fechaHoy(), -1)), 'TEST-001'],
      );

      await expectLater(
        repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Uso de unidad'),
        throwsA(isA<StateError>()),
      );

      await repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Vencimiento');

      expect(repo.listar().single.estado, EstadoUnidad.retirada);
    });

    test('Un nuevo repositorio recupera el retiro guardado', () async {
      await crearBolsa();

      await repo.retirarUnidad(codigo: 'TEST-001', motivo: 'Descarte');

      // Reutilizamos la misma base de datos SQLite.
      final otroRepo = RepositorioBolsa()..init(db);
      final bolsa = otroRepo.listar().single;

      expect(bolsa.estado, EstadoUnidad.retirada);
      expect(bolsa.motivoRetiro, 'Descarte');
      expect(otroRepo.stockPorSedeYTipo(), isEmpty);
    });
  });

  group('US5 - Formulario de retiro', () {
    testWidgets('Valida los campos obligatorios', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: FormularioRetiroPage(repo: repo)),
      );

      await tester.tap(find.text('Verificar unidad'));
      await tester.pump();

      expect(find.text('Ingresa el código de la unidad'), findsOneWidget);

      expect(find.text('Selecciona un motivo'), findsOneWidget);
    });

    testWidgets('Permite confirmar un retiro desde la interfaz', (
      tester,
    ) async {
      await crearBolsa();

      await tester.pumpWidget(
        MaterialApp(home: FormularioRetiroPage(repo: repo)),
      );

      await tester.enterText(find.byType(TextFormField).first, 'TEST-001');

      final selector = find.byType(DropdownButtonFormField<String>);

      await tester.tap(selector);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Uso de unidad').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verificar unidad'));
      await tester.pumpAndSettle();

      expect(find.text('Unidad encontrada'), findsOneWidget);

      final botonRetiro = find.text('Confirmar retiro');

      await tester.ensureVisible(botonRetiro);
      await tester.pumpAndSettle();
      await tester.tap(botonRetiro);
      await tester.pumpAndSettle();

      final bolsa = repo.listar().single;

      expect(bolsa.estado, EstadoUnidad.retirada);
      expect(bolsa.motivoRetiro, 'Uso de unidad');
      expect(repo.stockPorSedeYTipo(), isEmpty);
    });
  });
}
