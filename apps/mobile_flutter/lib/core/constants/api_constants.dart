abstract final class ApiConstants {
  static const String supabaseUrl = String.fromEnvironment(
    'GREYEYE_SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'GREYEYE_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
