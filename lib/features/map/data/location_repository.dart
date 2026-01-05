import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models.dart';

class LocationRepository {
  // ========== PERMISOS ==========
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  // ========== OBTENER UBICACIÓN ACTUAL ==========
  Future<UserLocation> getCurrentLocation() async {
    try {
      // Verificar permisos
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
      }

      if (!hasPermission) {
        throw Exception('Permiso de ubicación denegado');
      }

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
            'Los servicios de ubicación están deshabilitados. Por favor actívalos en la configuración.');
      }

      // Obtener ubicación
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      throw Exception('Error al obtener ubicación: $e');
    }
  }

  // ========== STREAM DE UBICACIÓN ==========
  Stream<UserLocation> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ));
  }

  // ========== CALCULAR DISTANCIA ==========
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Retorna distancia en metros
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  // ========== ABRIR CONFIGURACIÓN ==========
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Permission.location.request();
  }
}