class PetModel {
  final String id;
  final String refugioId;
  final String name;
  final String species; // 'perro' o 'gato'
  final String? breed;
  final int age;
  final String gender; // 'Macho' o 'Hembra'
  final String size; // 'Pequeño', 'Mediano', 'Grande'
  final String description;
  final String healthStatus;
  final List<String> imageUrls;
  final bool isVaccinated;
  final bool isDewormed;
  final bool isSterilized;
  final bool hasMicrochip;
  final String? specialNeeds;
  final String status; // 'disponible', 'adoptado', 'reservado'
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  
  // Datos del refugio (para mostrar en detalle)
  String? refugioName;
  String? refugioPhone;

  PetModel({
    required this.id,
    required this.refugioId,
    required this.name,
    required this.species,
    this.breed,
    required this.age,
    required this.gender,
    required this.size,
    required this.description,
    this.healthStatus = '',
    required this.imageUrls,
    this.isVaccinated = false,
    this.isDewormed = false,
    this.isSterilized = false,
    this.hasMicrochip = false,
    this.specialNeeds,
    this.status = 'disponible',
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.refugioName,
    this.refugioPhone,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    return PetModel(
      id: json['id'] as String,
      refugioId: json['refugio_id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      age: json['age'] as int? ?? 0,
      gender: json['gender'] as String,
      size: json['size'] as String,
      description: json['description'] as String? ?? '',
      healthStatus: json['health_status'] as String? ?? '',
      imageUrls: json['image_urls'] != null 
          ? List<String>.from(json['image_urls'] as List)
          : [],
      isVaccinated: json['is_vaccinated'] as bool? ?? false,
      isDewormed: json['is_dewormed'] as bool? ?? false,
      isSterilized: json['is_sterilized'] as bool? ?? false,
      hasMicrochip: json['has_microchip'] as bool? ?? false,
      specialNeeds: json['special_needs'] as String?,
      status: json['status'] as String? ?? 'disponible',
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      refugioName: json['refugio_name'] as String?,
      refugioPhone: json['refugio_phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'refugio_id': refugioId,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'gender': gender,
      'size': size,
      'description': description,
      'health_status': healthStatus,
      'image_urls': imageUrls,
      'is_vaccinated': isVaccinated,
      'is_dewormed': isDewormed,
      'is_sterilized': isSterilized,
      'has_microchip': hasMicrochip,
      'special_needs': specialNeeds,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  PetModel copyWith({
    String? id,
    String? refugioId,
    String? name,
    String? species,
    String? breed,
    int? age,
    String? gender,
    String? size,
    String? description,
    String? healthStatus,
    List<String>? imageUrls,
    bool? isVaccinated,
    bool? isDewormed,
    bool? isSterilized,
    bool? hasMicrochip,
    String? specialNeeds,
    String? status,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    String? refugioName,
    String? refugioPhone,
  }) {
    return PetModel(
      id: id ?? this.id,
      refugioId: refugioId ?? this.refugioId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      size: size ?? this.size,
      description: description ?? this.description,
      healthStatus: healthStatus ?? this.healthStatus,
      imageUrls: imageUrls ?? this.imageUrls,
      isVaccinated: isVaccinated ?? this.isVaccinated,
      isDewormed: isDewormed ?? this.isDewormed,
      isSterilized: isSterilized ?? this.isSterilized,
      hasMicrochip: hasMicrochip ?? this.hasMicrochip,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      refugioName: refugioName ?? this.refugioName,
      refugioPhone: refugioPhone ?? this.refugioPhone,
    );
  }

  // Helpers
  bool get isAvailable => status == 'disponible';
  bool get isDog => species == 'perro';
  bool get isCat => species == 'gato';
  
  String get ageText {
    if (age == 0) return 'Cachorro';
    if (age == 1) return '1 año';
    return '$age años';
  }
  
  String get mainImage => imageUrls.isNotEmpty ? imageUrls.first : '';
  
  // Calcular distancia (si tienes ubicación del refugio)
  String getDistanceText(double? userLat, double? userLon) {
    if (latitude == null || longitude == null || userLat == null || userLon == null) {
      return '';
    }
    
    // Fórmula de Haversine simplificada
    const double earthRadius = 6371; // km
    final dLat = _toRadians(latitude! - userLat);
    final dLon = _toRadians(longitude! - userLon);
    
    final a = (dLat / 2).abs() * (dLat / 2).abs() +
        userLat.abs() * latitude!.abs() * (dLon / 2).abs() * (dLon / 2).abs();
    final c = 2 * (a.abs()).clamp(0.0, 1.0);
    final distance = earthRadius * c;
    
    if (distance < 1) {
      return '${(distance * 1000).toInt()} m';
    }
    return '${distance.toStringAsFixed(1)} km';
  }
  
  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180);
  }
}