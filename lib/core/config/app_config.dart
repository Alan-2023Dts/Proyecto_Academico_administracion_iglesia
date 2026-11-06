class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const publicSupabaseUrl = String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_URL',
    );
    const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const publicSupabaseKey = String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    );

    return AppConfig(
      supabaseUrl: supabaseUrl.isNotEmpty ? supabaseUrl : publicSupabaseUrl,
      supabaseAnonKey: supabaseKey.isNotEmpty ? supabaseKey : publicSupabaseKey,
    );
  }

  bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
