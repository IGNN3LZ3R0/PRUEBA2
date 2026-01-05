class AdoptionRequestModel {
  final String id;
  final String petId;
  final String adoptanteId;
  final String refugioId;
  final String petName;
  final String refugioName;
  final String adoptanteName;
  final String status; // 'pendiente', 'aprobada', 'rechazada'
  final String? message;
  final DateTime createdAt;

  AdoptionRequestModel({
    required this.id,
    required this.petId,
    required this.adoptanteId,
    required this.refugioId,
    required this.petName,
    required this.refugioName,
    required this.adoptanteName,
    required this.status,
    this.message,
    required this.createdAt,
  });

  factory AdoptionRequestModel.fromJson(Map<String, dynamic> json) {
    return AdoptionRequestModel(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      adoptanteId: json['adoptante_id'] as String,
      refugioId: json['refugio_id'] as String,
      petName: json['pet_name'] as String? ?? '',
      refugioName: json['refugio_name'] as String? ?? '',
      adoptanteName: json['adoptante_name'] as String? ?? '',
      status: json['status'] as String? ?? 'pendiente',
      message: json['message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'adoptante_id': adoptanteId,
      'refugio_id': refugioId,
      'pet_name': petName,
      'refugio_name': refugioName,
      'adoptante_name': adoptanteName,
      'status': status,
      'message': message,
    };
  }

  // Helpers
  bool get isPending => status == 'pendiente';
  bool get isApproved => status == 'aprobada';
  bool get isRejected => status == 'rechazada';

  String get statusText {
    switch (status) {
      case 'pendiente':
        return 'Pendiente';
      case 'aprobada':
        return 'Aprobada';
      case 'rechazada':
        return 'Rechazada';
      default:
        return status;
    }
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Hace un momento';
    }
  }
}