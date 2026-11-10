import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:gestion_banco_sangre/screens/login_screen.dart";
 
void main() {
  testWidgets("la pantalla de login se muestra", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
 
    expect(find.text("Banco de Sangre"), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
 