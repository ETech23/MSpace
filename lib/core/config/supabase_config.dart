import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // IMPORTANT: Never hardcode these in production!
  // Use flutter run --dart-define or environment variables
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static Future<void> initialize() async {
    _validateRequiredEnv();

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: kDebugMode ? RealtimeLogLevel.info : RealtimeLogLevel.error,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 3,
      ),
    );
  }

  static void _validateRequiredEnv() {
    if (supabaseUrl == 'YOUR_SUPABASE_URL') {
      throw StateError(
        'Missing SUPABASE_URL. Build with --dart-define=SUPABASE_URL=https://<project>.supabase.co',
      );
    }

    final parsed = Uri.tryParse(supabaseUrl);
    final hasValidHost = parsed != null &&
        (parsed.scheme == 'https' || parsed.scheme == 'http') &&
        parsed.host.isNotEmpty;
    if (!hasValidHost) {
      throw StateError(
        'Invalid SUPABASE_URL "$supabaseUrl". Expected a full URL like https://<project>.supabase.co',
      );
    }

    if (supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY' ||
        supabaseAnonKey.trim().isEmpty) {
      throw StateError(
        'Missing SUPABASE_ANON_KEY. Build with --dart-define=SUPABASE_ANON_KEY=<anon-key>',
      );
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
  static RealtimeClient get realtime => client.realtime;
}
