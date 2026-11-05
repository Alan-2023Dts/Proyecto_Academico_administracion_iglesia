import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_iglesia/app/app.dart';
import 'package:gestion_iglesia/core/config/app_config.dart';

void main() {
  testWidgets('muestra el login sin aviso de configuración', (tester) async {
    const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    await tester.pumpWidget(IglesiaApp(config: config));

    expect(find.text('Bienvenido a Iglesia'), findsOneWidget);
    expect(find.textContaining('Modo configuración:'), findsNothing);
    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('valida credenciales básicas del formulario', (tester) async {
    const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    await tester.pumpWidget(IglesiaApp(config: config));

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pump();

    expect(find.text('Escribe tu nombre'), findsOneWidget);
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
  });
}
