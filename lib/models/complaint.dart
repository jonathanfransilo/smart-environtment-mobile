/// Model untuk foto complaint
class ComplaintPhoto {
  final int id;
  final String url;
  final int order;

  ComplaintPhoto({required this.id, required this.url, required this.order});

  factory ComplaintPhoto.fromJson(Map<String, dynamic> json) {
    return ComplaintPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'url': url, 'order': order};
  }
}

class Complaint {
  final String id;
  final String userId;
  final String? serviceAccountId;
  final String? assigneeId;
  final String type; // Jenis keluhan
  final String description;
  final String? location; // Lokasi kejadian
  final String status; // 'open', 'in_progress', 'resolved', 'rejected'
  final List<ComplaintPhoto> photos; // Evidence photos
  final DateTime createdAt;
  final DateTime updatedAt;

  Complaint({
    required this.id,
    required this.userId,
    this.serviceAccountId,
    this.assigneeId,
    required this.type,
    required this.description,
    this.location,
    required this.status,
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final photosList = json['photos'] as List<dynamic>?;
    final photos = photosList != null
        ? photosList
              .map((p) => ComplaintPhoto.fromJson(p as Map<String, dynamic>))
              .toList()
        : <ComplaintPhoto>[];

    // Parse dates with fallback
    DateTime createdAt;
    DateTime updatedAt;
    try {
      createdAt = DateTime.parse(json['created_at']);
    } catch (e) {
      createdAt = DateTime.now();
    }
    try {
      updatedAt = DateTime.parse(json['updated_at'] ?? json['created_at']);
    } catch (e) {
      updatedAt = createdAt;
    }

    return Complaint(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      serviceAccountId: json['service_account_id']?.toString(),
      assigneeId: json['assignee_id']?.toString(),
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      location: json['address']?.toString(), // API menggunakan field 'address'
      status: json['status'] ?? 'open',
      photos: photos,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'service_account_id': serviceAccountId,
      'assignee_id': assigneeId,
      'type': type,
      'description': description,
      'location': location,
      'status': status,
      'photos': photos.map((p) => p.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get status display text in Indonesian
  String get statusText {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Menunggu';
      case 'in_progress':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  /// Get type display text in Indonesian
  String get typeText {
    switch (type.toLowerCase()) {
      // Tipe dari dokumentasi API
      case 'sampah_tidak_diangkut':
        return 'Sampah Tidak Diangkut';
      case 'sampah_menumpuk':
        return 'Sampah Menumpuk';
      case 'jadwal_tidak_sesuai':
        return 'Jadwal Tidak Sesuai';
      case 'pelayanan_buruk':
        return 'Pelayanan Buruk';
      case 'petugas_tidak_datang':
        return 'Petugas Tidak Datang';
      case 'lainnya':
        return 'Lainnya';
      // Legacy types (backward compatibility)
      case 'illegal_dumping':
        return 'Pembuangan Sampah Sembarangan';
      case 'uncollected_waste':
        return 'Sampah Tidak Diangkut';
      case 'damaged_facility':
        return 'Fasilitas Rusak';
      case 'other':
        return 'Lainnya';
      default:
        return type;
    }
  }

  Complaint copyWith({
    String? id,
    String? userId,
    String? serviceAccountId,
    String? assigneeId,
    String? type,
    String? description,
    String? status,
    List<ComplaintPhoto>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Complaint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serviceAccountId: serviceAccountId ?? this.serviceAccountId,
      assigneeId: assigneeId ?? this.assigneeId,
      type: type ?? this.type,
      description: description ?? this.description,
      status: status ?? this.status,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
