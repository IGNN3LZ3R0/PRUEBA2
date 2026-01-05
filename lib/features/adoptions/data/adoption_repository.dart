import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../../../core/constants.dart';
import 'models.dart';

class AdoptionRepository {
  final SupabaseClient _supabase = SupabaseClientManager.instance.client;

  // ========== CREAR SOLICITUD ==========
  Future<AdoptionRequestModel> createRequest({
    required String petId,
    required String adoptanteId,
    required String refugioId,
    required String petName,
    required String refugioName,
    required String adoptanteName,
    String? message,
  }) async {
    try {
      final data = {
        'pet_id': petId,
        'adoptante_id': adoptanteId,
        'refugio_id': refugioId,
        'pet_name': petName,
        'refugio_name': refugioName,
        'adoptante_name': adoptanteName,
        'message': message,
        'status': AppConstants.statusPending,
      };

      final response = await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .insert(data)
          .select()
          .single();

      return AdoptionRequestModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear solicitud: $e');
    }
  }

  // ========== OBTENER SOLICITUDES DEL ADOPTANTE ==========
  Future<List<AdoptionRequestModel>> getAdoptanteRequests(
      String adoptanteId) async {
    try {
      final response = await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .select()
          .eq('adoptante_id', adoptanteId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AdoptionRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener solicitudes: $e');
    }
  }

  // ========== OBTENER SOLICITUDES DEL REFUGIO ==========
  Future<List<AdoptionRequestModel>> getRefugioRequests(
      String refugioId) async {
    try {
      final response = await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .select()
          .eq('refugio_id', refugioId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AdoptionRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener solicitudes: $e');
    }
  }

  // ========== ACTUALIZAR ESTADO DE SOLICITUD ==========
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .update({'status': status}).eq('id', requestId);
    } catch (e) {
      throw Exception('Error al actualizar solicitud: $e');
    }
  }

  // ========== APROBAR SOLICITUD ==========
  Future<void> approveRequest(String requestId, String petId) async {
    try {
      // 1. Actualizar solicitud a aprobada
      await updateRequestStatus(requestId, AppConstants.statusApproved);

      // 2. Marcar mascota como adoptada
      await _supabase
          .from(AppConstants.petsTable)
          .update({'status': AppConstants.petAdopted}).eq('id', petId);

      // 3. Rechazar otras solicitudes de la misma mascota
      await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .update({'status': AppConstants.statusRejected})
          .eq('pet_id', petId)
          .neq('id', requestId);
    } catch (e) {
      throw Exception('Error al aprobar solicitud: $e');
    }
  }

  // ========== RECHAZAR SOLICITUD ==========
  Future<void> rejectRequest(String requestId) async {
    try {
      await updateRequestStatus(requestId, AppConstants.statusRejected);
    } catch (e) {
      throw Exception('Error al rechazar solicitud: $e');
    }
  }

  // ========== ESTADÍSTICAS ==========
  Future<Map<String, int>> getRequestStats(
      String userId, bool isRefugio) async {
    try {
      final field = isRefugio ? 'refugio_id' : 'adoptante_id';

      final pending = await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .select('id')
          .eq(field, userId)
          .eq('status', AppConstants.statusPending);

      final approved = await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .select('id')
          .eq(field, userId)
          .eq('status', AppConstants.statusApproved);

      final rejected = await _supabase
          .from(AppConstants.adoptionRequestsTable)
          .select('id')
          .eq(field, userId)
          .eq('status', AppConstants.statusRejected);

      return {
        'pendientes': (pending as List).length,
        'aprobadas': (approved as List).length,
        'rechazadas': (rejected as List).length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}
