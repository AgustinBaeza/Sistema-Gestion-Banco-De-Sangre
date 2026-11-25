import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:gestion_banco_sangre/basedatos/repositorio_bolsa.dart';
import 'package:gestion_banco_sangre/basedatos/repositorio_traslado.dart';
import 'package:gestion_banco_sangre/modelos/bolsa_sangre.dart';
import 'package:gestion_banco_sangre/pantallas/solicitud_traslado_screen.dart';

void main() {
  group('RepositorioTraslado - Task 7.3 (validación y stock excedente)', () {
    late RepositorioBolsa repoBolsa;
    late RepositorioTraslado repoTraslado;

    setUp(() async {
      final db = sqlite3.openInMemory();
      repoBolsa = RepositorioBolsa()..init(db);
      repoTraslado = RepositorioTraslado()..init(db);

      final hoy = fechaHoy();
      final vence = sumarDias(hoy, 20);

      // 10 bolsas O+ vigentes en Sede Norte (mínimo O+ = 6 => excedente = 4)
      for (int i = 1; i <= 10; i++) {
        await repoBolsa.crear(
          codigo: 'BS-NRT-${i.toString().padLeft(3, '0')}',
          tipo: TipoSanguineo.oPositivo,
          sede: 'Sede Norte',
          volumenMl: 450,
          fechaIngreso: hoy,
          fechaVencimiento: vence,
        );
      }

      // 2 bolsas O+ vigentes en Sede Central (escasez: bajo mínimo de 6)
      for (int i = 1; i <= 2; i++) {
        await repoBolsa.crear(
          codigo: 'BS-CNT-${i.toString().padLeft(3, '0')}',
          tipo: TipoSanguineo.oPositivo,
          sede: 'Sede Central',
          volumenMl: 450,
          fechaIngreso: hoy,
          fechaVencimiento: vence,
        );
      }
    });

    test('calcula stock mínimo, óptimo y máximo según tipo sanguíneo', () {
      final nivelesPositivo = repoTraslado.calcularNivelesStock(
        tipoSanguineo: TipoSanguineo.oPositivo,
      );
      expect(nivelesPositivo.stockMinimo, 6);
      expect(nivelesPositivo.stockOptimo, 15);
      expect(nivelesPositivo.stockMaximo, 24);

      final nivelesNegativo = repoTraslado.calcularNivelesStock(
        tipoSanguineo: TipoSanguineo.oNegativo,
      );
      expect(nivelesNegativo.stockMinimo, 4);
      expect(nivelesNegativo.stockOptimo, 10);
      expect(nivelesNegativo.stockMaximo, 16);
    });

    test('crea solicitud válida cuando hay excedente sobre stock mínimo', () async {
      final solicitud = await repoTraslado.crearSolicitudTraslado(
        sedeOrigen: 'Sede Norte',
        sedeDestino: 'Sede Central',
        tipoSanguineo: TipoSanguineo.oPositivo,
        cantidad: 3,
      );

      expect(solicitud.id, isNotNull);
      expect(solicitud.sedeOrigen, 'Sede Norte');
      expect(solicitud.sedeDestino, 'Sede Central');
      expect(solicitud.cantidad, 3);
      expect(solicitud.notificacionEnviada, isTrue);
      expect(solicitud.estado, 'pendiente');

      // De 10 bolsas vigentes en Sede Norte, 3 quedan reservadas => 7 disponibles
      // Excedente restante sobre mínimo (6) = 1
      expect(
        repoTraslado.obtenerStockDisponibleOrigen(
          sedeOrigen: 'Sede Norte',
          tipoSanguineo: TipoSanguineo.oPositivo,
        ),
        7,
      );
      expect(repoTraslado.listarSolicitudes().length, 1);
    });

    test('rechaza solicitud si excede el stock excedente en origen', () async {
      // Sede Norte tiene 10 bolsas O+ y mínimo 6 => máximo trasladable es 4
      expect(
        () => repoTraslado.crearSolicitudTraslado(
          sedeOrigen: 'Sede Norte',
          sedeDestino: 'Sede Central',
          tipoSanguineo: TipoSanguineo.oPositivo,
          cantidad: 5,
        ),
        throwsA(isA<StateError>()),
      );

      expect(repoTraslado.listarSolicitudes(), isEmpty);
    });

    test('rechaza solicitud si sede origen y destino son iguales o cantidad <= 0',
        () async {
      expect(
        () => repoTraslado.crearSolicitudTraslado(
          sedeOrigen: 'Sede Norte',
          sedeDestino: 'Sede Norte',
          tipoSanguineo: TipoSanguineo.oPositivo,
          cantidad: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repoTraslado.crearSolicitudTraslado(
          sedeOrigen: 'Sede Norte',
          sedeDestino: 'Sede Central',
          tipoSanguineo: TipoSanguineo.oPositivo,
          cantidad: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SolicitudTrasladoPage - Task 7.3 (interfaz y validaciones)', () {
    testWidgets('muestra error si cantidad supera excedente sobre mínimo',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: SolicitudTrasladoPage(
            sedesDisponibles: ['Sede Central', 'Sede Norte'],
            stockActualPorSedeYTipo: {
              'Sede Central|oPositivo': 2,
              'Sede Norte|oPositivo': 10,
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '6');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('excedente sobre el stock mínimo'),
        findsOneWidget,
      );
    });

    testWidgets('crea solicitud válida e informa notificación a sede de origen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      DatosSolicitudTraslado? datosRecibidos;

      await tester.pumpWidget(
        MaterialApp(
          home: SolicitudTrasladoPage(
            sedesDisponibles: const ['Sede Central', 'Sede Norte'],
            stockActualPorSedeYTipo: const {
              'Sede Central|aPositivo': 2,
              'Sede Norte|aPositivo': 12, // mínimo 6 => excedente 6
            },
            onEnviarSolicitud: (datos) async {
              datosRecibidos = datos;
              return null;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tester.pump();

      final boton = find.widgetWithText(FilledButton, 'Solicitar traslado');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(datosRecibidos, isNotNull);
      expect(datosRecibidos!.cantidad, 4);
      expect(datosRecibidos!.notificacionEnviada, isTrue);
      expect(
        find.textContaining('Se notificó a la sede de origen (Sede Norte)'),
        findsWidgets,
      );
    });
  });
}