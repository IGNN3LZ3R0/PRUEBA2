class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String userType; // 'adoptante' o 'refugio'
  final String? phone;
  final String? address;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    this.phone,
    this.address,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      userType: json['user_type'] as String? ?? 'adoptante',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'user_type': userType,
      'phone': phone,
      'address': address,
      'avatar_url': avatarUrl,
    };
  }

  // CopyWith para actualizar datos
  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? userType,
    String? phone,
    String? address,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      userType: userType ?? this.userType,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  bool get isRefugio => userType == 'refugio';
  bool get isAdoptante => userType == 'adoptante';
}