import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:gestion_banco_sangre/basedatos/repositorio_usuario.dart';
import 'package:gestion_banco_sangre/screens/login_screen.dart';

void main() {
  late Database db;
  late RepositorioUsuario repo;

  // Se ejecuta antes de cada prueba para tener una base de datos limpia
  setUp(() async {
    db = sqlite3.openInMemory();
    repo = RepositorioUsuario();
    repo.init(db);
    // Esto crea el usuario "operador" con clave "Operador#2026"
    await repo.sembrarUsuarios(); 
  });

  // Se ejecuta al final para cerrar la base de datos
  tearDown(() {
    db.close();
  });

  testWidgets('Muestra error si los campos están vacíos', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(repo: repo)));

    // Toca el botón de iniciar sesión sin escribir nada
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle(); // Espera a que termine la animación

    // Verifica que salten las validaciones de los TextFormField
    expect(find.text('Por favor complete todos los campos obligatorios.'), findsOneWidget);
    expect(find.text('El usuario es obligatorio'), findsOneWidget);
  });

  testWidgets('Rechaza credenciales incorrectas y muestra error', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(repo: repo)));

    final camposTexto = find.byType(TextFormField);
    
    // Ingresa credenciales falsas
    await tester.enterText(camposTexto.first, 'usuarioInvalido');
    await tester.enterText(camposTexto.last, 'claveMala');
    
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Verifica que el sistema responda con el mensaje de rechazo
    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('Permite el acceso con credenciales correctas', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(repo: repo)));

    final camposTexto = find.byType(TextFormField);
    
    // Ingresa las credenciales reales sembradas en la base de datos
    await tester.enterText(camposTexto.first, 'operador');
    await tester.enterText(camposTexto.last, 'Operador#2026');
    
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Verifica que el sistema arroje el mensaje de éxito con el nombre y rol
    expect(find.text('Bienvenido, operador (operador)'), findsOneWidget);
  });
}