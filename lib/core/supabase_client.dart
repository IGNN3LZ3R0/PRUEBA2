import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseClientManager {
  // Cargar desde .env
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static SupabaseClientManager? _instance;
  
  SupabaseClientManager._();
  
  static SupabaseClientManager get instance {
    _instance ??= SupabaseClientManager._();
    return _instance!;
  }
  
  static Future<void> initialize() async {
    // Validar que las variables estén configuradas
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_URL y SUPABASE_ANON_KEY deben estar configurados en .env'
      );
    }
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  
  // Cliente de Supabase
  SupabaseClient get client => Supabase.instance.client;
  
  // Auth helpers
  User? get currentUser => client.auth.currentUser;
  String? get userId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;
  
  // Database
  PostgrestQueryBuilder from(String table) => client.from(table);
  
  // Storage
  SupabaseStorageClient get storage => client.storage;
}