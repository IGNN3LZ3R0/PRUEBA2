import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models.dart';

class LocationRepository {
  // ========== CONSTANTES ==========
  static const double DEFAULT_SEARCH_RADIUS_METERS = 5000; // 5 km
  static const double MIN_SEARCH_RADIUS_METERS = 1000; // 1 km
  static const double MAX_SEARCH_RADIUS_METERS = 20000; // 20 km

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

  // ========== NUEVO: VERIFICAR SI ESTÁ DENTRO DEL RADIO ==========
  /// Verifica si una ubicación está dentro del radio especificado
  bool isWithinRadius({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    double radiusInMeters = DEFAULT_SEARCH_RADIUS_METERS,
  }) {
    final distance = calculateDistance(userLat, userLon, targetLat, targetLon);
    return distance <= radiusInMeters;
  }

  // ========== NUEVO: FILTRAR LISTA POR RADIO ==========
  /// Filtra una lista de refugios por radio de búsqueda
  List<T> filterByRadius<T>({
    required List<T> items,
    required double userLat,
    required double userLon,
    required double Function(T) getItemLat,
    required double Function(T) getItemLon,
    double radiusInMeters = DEFAULT_SEARCH_RADIUS_METERS,
  }) {
    return items.where((item) {
      return isWithinRadius(
        userLat: userLat,
        userLon: userLon,
        targetLat: getItemLat(item),
        targetLon: getItemLon(item),
        radiusInMeters: radiusInMeters,
      );
    }).toList();
  }

  // ========== ABRIR CONFIGURACIÓN ==========
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Permission.location.request();
  }
}
