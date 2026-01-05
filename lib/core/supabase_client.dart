// lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientManager {
  static const String supabaseUrl = 'TU_SUPABASE_URL';
  static const String supabaseAnonKey = 'TU_SUPABASE_ANON_KEY';
  
  static SupabaseClientManager? _instance;
  late final Supabase _supabase;
  
  SupabaseClientManager._();
  
  static SupabaseClientManager get instance {
    _instance ??= SupabaseClientManager._();
    return _instance!;
  }
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
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