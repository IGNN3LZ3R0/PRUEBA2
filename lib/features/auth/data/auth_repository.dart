import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../../../core/constants.dart';
import 'models.dart';

class AuthRepository {
  final SupabaseClient _supabase = SupabaseClientManager.instance.client;

  // Login con email y contraseña
  Future<UserModel?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return await getUserProfile(response.user!.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  // Registro
  Future<UserModel?> register({
    required String email,
    required String password,
    required String fullName,
    required String userType,
  }) async {
    try {
      // 1. Crear usuario en Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // 2. Crear perfil en la tabla profiles
        final profile = {
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'user_type': userType,
        };

        await _supabase
            .from(AppConstants.profilesTable)
            .insert(profile);

        return UserModel.fromJson(profile);
      }
      return null;
    } catch (e) {
      throw Exception('Error al registrarse: $e');
    }
  }

  // Login con Google (BONUS +2 pts)
  Future<UserModel?> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'petadopt://auth/callback',
      );

      if (response) {
        // Esperar a que se complete la autenticación
        await Future.delayed(const Duration(seconds: 2));
        
        final user = _supabase.auth.currentUser;
        if (user != null) {
          // Verificar si el perfil existe
          final existingProfile = await _supabase
              .from(AppConstants.profilesTable)
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (existingProfile == null) {
            // Crear perfil para nuevo usuario de Google
            final profile = {
              'id': user.id,
              'email': user.email,
              'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? '',
              'user_type': AppConstants.userTypeAdoptante,
              'avatar_url': user.userMetadata?['avatar_url'],
            };

            await _supabase
                .from(AppConstants.profilesTable)
                .insert(profile);

            return UserModel.fromJson(profile);
          }

          return UserModel.fromJson(existingProfile);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  // Obtener perfil del usuario
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al obtener perfil: $e');
    }
  }

  // Actualizar perfil
  Future<void> updateProfile(UserModel user) async {
    try {
      await _supabase
          .from(AppConstants.profilesTable)
          .update(user.toJson())
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // Recuperar contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://tu-sitio-vercel.vercel.app/reset-password',
      );
    } catch (e) {
      throw Exception('Error al recuperar contraseña: $e');
    }
  }

  // Obtener usuario actual
  UserModel? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    
    // Retornar un modelo básico, luego cargar el perfil completo
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'] ?? '',
      userType: 'adoptante',
    );
  }

  // Stream de cambios de autenticación
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}