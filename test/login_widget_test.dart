import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_banco_sangre/screens/login_screen.dart';

void main() {
  testWidgets('Verifica renderizado y muestra aviso temporal al iniciar sesión', (WidgetTester tester) async {
    // Levantamos la pantalla para probar
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Revisamos que estén los textos y botones básicos
    expect(find.text('Acceso al sistema'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Rellenamos los campos con texto de prueba
    final camposTexto = find.byType(TextField);
    await tester.enterText(camposTexto.first, 'usuario_prueba');
    await tester.enterText(camposTexto.last, 'clave_prueba');

    // Simulamos el click en el botón
    await tester.tap(find.byType(ElevatedButton));
    
    // Actualizamos la vista para que procese el clic
    await tester.pump();

    // Comprobamos que salga el aviso temporal 
    expect(find.text('La autenticación todavía no está disponible.'), findsOneWidget);
  });
}