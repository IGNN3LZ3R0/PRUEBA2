import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/supabase_client.dart';
import '../../../core/constants.dart';
import 'models.dart';

class PetRepository {
  final SupabaseClient _supabase = SupabaseClientManager.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  // ========== OBTENER MASCOTAS ==========

  /// Obtener todas las mascotas disponibles
  Future<List<PetModel>> getPets() async {
    try {
      final response = await _supabase
          .from(AppConstants.petsTable)
          .select('''
            *,
            profiles!refugio_id (
              full_name,
              phone
            )
          ''')
          .eq('status', AppConstants.petAvailable)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final pet = PetModel.fromJson(json);
        // Agregar datos del refugio si están disponibles
        if (json['profiles'] != null) {
          return pet.copyWith(
            refugioName: json['profiles']['full_name'],
            refugioPhone: json['profiles']['phone'],
          );
        }
        return pet;
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener mascotas: $e');
    }
  }

  /// Obtener mascotas filtradas por especie
  Future<List<PetModel>> getPetsBySpecies(String species) async {
    try {
      final response = await _supabase
          .from(AppConstants.petsTable)
          .select('''
            *,
            profiles!refugio_id (
              full_name,
              phone
            )
          ''')
          .eq('status', AppConstants.petAvailable)
          .eq('species', species)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final pet = PetModel.fromJson(json);
        if (json['profiles'] != null) {
          return pet.copyWith(
            refugioName: json['profiles']['full_name'],
            refugioPhone: json['profiles']['phone'],
          );
        }
        return pet;
      }).toList();
    } catch (e) {
      throw Exception('Error al filtrar mascotas: $e');
    }
  }

  /// Buscar mascotas por nombre
  Future<List<PetModel>> searchPets(String query) async {
    try {
      final response = await _supabase
          .from(AppConstants.petsTable)
          .select('''
            *,
            profiles!refugio_id (
              full_name,
              phone
            )
          ''')
          .eq('status', AppConstants.petAvailable)
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final pet = PetModel.fromJson(json);
        if (json['profiles'] != null) {
          return pet.copyWith(
            refugioName: json['profiles']['full_name'],
            refugioPhone: json['profiles']['phone'],
          );
        }
        return pet;
      }).toList();
    } catch (e) {
      throw Exception('Error al buscar mascotas: $e');
    }
  }

  /// Obtener detalle de una mascota específica
  Future<PetModel?> getPetDetail(String petId) async {
    try {
      final response = await _supabase.from(AppConstants.petsTable).select('''
            *,
            profiles!refugio_id (
              full_name,
              phone,
              address
            )
          ''').eq('id', petId).single();

      final pet = PetModel.fromJson(response);
      if (response['profiles'] != null) {
        return pet.copyWith(
          refugioName: response['profiles']['full_name'],
          refugioPhone: response['profiles']['phone'],
        );
      }
      return pet;
    } catch (e) {
      throw Exception('Error al obtener detalle de mascota: $e');
    }
  }

  /// Obtener mascotas de un refugio específico (para panel de administración)
  Future<List<PetModel>> getRefugioPets(String refugioId) async {
    try {
      final response = await _supabase
          .from(AppConstants.petsTable)
          .select()
          .eq('refugio_id', refugioId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => PetModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al obtener mascotas del refugio: $e');
    }
  }

  // ========== CREAR/ACTUALIZAR/ELIMINAR ==========

  /// Crear nueva mascota
  Future<PetModel> createPet(PetModel pet) async {
    try {
      final response = await _supabase
          .from(AppConstants.petsTable)
          .insert(pet.toJson())
          .select()
          .single();

      return PetModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear mascota: $e');
    }
  }

  /// Actualizar mascota existente
  Future<void> updatePet(String petId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from(AppConstants.petsTable)
          .update(updates)
          .eq('id', petId);
    } catch (e) {
      throw Exception('Error al actualizar mascota: $e');
    }
  }

  /// Eliminar mascota
  Future<void> deletePet(String petId) async {
    try {
      await _supabase.from(AppConstants.petsTable).delete().eq('id', petId);
    } catch (e) {
      throw Exception('Error al eliminar mascota: $e');
    }
  }

  /// Cambiar estado de la mascota
  Future<void> updatePetStatus(String petId, String status) async {
    try {
      await updatePet(petId, {'status': status});
    } catch (e) {
      throw Exception('Error al actualizar estado: $e');
    }
  }

  // ========== MANEJO DE IMÁGENES ==========

  /// Seleccionar imagen de la galería
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Error al seleccionar imagen: $e');
    }
  }

  /// Seleccionar imagen de la cámara
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Error al tomar foto: $e');
    }
  }

  /// Seleccionar múltiples imágenes
  Future<List<File>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      return images.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      throw Exception('Error al seleccionar imágenes: $e');
    }
  }

  /// Eliminar imagen del storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extraer el path de la URL de forma robusta (soporta URLs públicas y otras variantes)
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;

      String? filePath;

      // Caso estándar: /.../pet_images/<petId>/<file>
      final bucketIndex = segments.indexOf(AppConstants.petImagesBucket);
      if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
        filePath = segments.sublist(bucketIndex + 1).join('/');
      } else {
        // Fallback: algunas URLs públicas incluyen "public" antes del bucket
        final publicIndex = segments.indexOf('public');
        if (publicIndex != -1 && publicIndex + 1 < segments.length) {
          final possibleBucketIndex = publicIndex + 1;
          if (segments[possibleBucketIndex] == AppConstants.petImagesBucket &&
              possibleBucketIndex < segments.length - 1) {
            filePath = segments.sublist(possibleBucketIndex + 1).join('/');
          }
        }
      }

      if (filePath == null || filePath.isEmpty) {
        throw Exception(
            'No se pudo extraer la ruta del archivo desde la URL: $imageUrl');
      }

      await _supabase.storage
          .from(AppConstants.petImagesBucket)
          .remove([filePath]);
    } catch (e) {
      throw Exception('Error al eliminar imagen: $e');
    }
  }

  /// Subir imagen al storage de Supabase
  Future<String> uploadImage(File image, String petId) async {
    try {
      final String fileName =
          '${petId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '$petId/$fileName';

      // Subir el archivo
      await _supabase.storage
          .from(AppConstants.petImagesBucket)
          .upload(filePath, image);

      // Obtener URL pública y validar
      final String publicUrl = _supabase.storage
          .from(AppConstants.petImagesBucket)
          .getPublicUrl(filePath);

      if (publicUrl.isEmpty) {
        throw Exception(
            'No se pudo obtener la URL pública para la imagen subida.');
      }

      return publicUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  /// Subir múltiples imágenes
  Future<List<String>> uploadMultipleImages(
      List<File> images, String petId) async {
    try {
      final List<String> uploadedUrls = [];

      for (final image in images) {
        final url = await uploadImage(image, petId);
        uploadedUrls.add(url);
      }

      return uploadedUrls;
    } catch (e) {
      throw Exception('Error al subir imágenes: $e');
    }
  }

// ========== ESTADÍSTICAS (Para panel de refugio) ==========

  /// Obtener estadísticas del refugio
  Future<Map<String, int>> getRefugioStats(String refugioId) async {
    try {
      // Total de mascotas
      final totalPets = await _supabase
          .from(AppConstants.petsTable)
          .select('id')
          .eq('refugio_id', refugioId);

      // Mascotas disponibles
      final availablePets = await _supabase
          .from(AppConstants.petsTable)
          .select('id')
          .eq('refugio_id', refugioId)
          .eq('status', AppConstants.petAvailable);

      // Mascotas adoptadas
      final adoptedPets = await _supabase
          .from(AppConstants.petsTable)
          .select('id')
          .eq('refugio_id', refugioId)
          .eq('status', AppConstants.petAdopted);

      return {
        'total': (totalPets as List).length,
        'disponibles': (availablePets as List).length,
        'adoptadas': (adoptedPets as List).length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}
