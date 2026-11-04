import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import '../core/config/app_config.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';

class IglesiaApp extends StatelessWidget {
  final AppConfig config;

  const IglesiaApp({required this.config, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iglesia',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AuthGate(config: config),
    );
  }
}

class AuthGate extends StatelessWidget {
  final AppConfig config;

  const AuthGate({required this.config, super.key});

  @override
  Widget build(BuildContext context) {
    if (!config.isConfigured) {
      return LoginPage(config: config);
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return LoginPage(config: config);
        }
        return const DashboardPage();
      },
    );
  }
}
