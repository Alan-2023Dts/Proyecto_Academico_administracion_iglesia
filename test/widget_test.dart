import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_iglesia/app/app.dart';
import 'package:gestion_iglesia/core/config/app_config.dart';

void main() {
  testWidgets('muestra la pantalla de configuración sin credenciales', (
    tester,
  ) async {
    const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    await tester.pumpWidget(IglesiaApp(config: config));

    expect(find.text('Bienvenido a Iglesia'), findsOneWidget);
    expect(find.textContaining('Modo configuración:'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('valida credenciales básicas del formulario', (tester) async {
    const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    await tester.pumpWidget(IglesiaApp(config: config));

    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
  });
}
