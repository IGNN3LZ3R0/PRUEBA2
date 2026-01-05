import 'package:latlong2/latlong.dart';

class UserLocation {
  final double latitude;
  final double longitude;

  UserLocation({
    required this.latitude,
    required this.longitude,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}

class ShelterMarker {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final double latitude;
  final double longitude;
  final int petsCount;

  ShelterMarker({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.latitude,
    required this.longitude,
    this.petsCount = 0,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}