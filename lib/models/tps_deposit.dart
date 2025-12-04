import 'tps.dart';

/// Model untuk TPS Deposit (Riwayat Setor ke TPS)
class TPSDeposit {
  final int id;
  final int collectorId;
  final int garbageDumpId;
  final DateTime depositedAt;
  final double latitude;
  final double longitude;
  final String? notes;
  final TPS? garbageDump;
  final DateTime? createdAt;

  TPSDeposit({
    required this.id,
    required this.collectorId,
    required this.garbageDumpId,
    required this.depositedAt,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.garbageDump,
    this.createdAt,
  });

  factory TPSDeposit.fromJson(Map<String, dynamic> json) {
    return TPSDeposit(
      id: json['id'] as int,
      collectorId: json['collector_id'] as int? ?? 0,
      garbageDumpId: json['garbage_dump_id'] as int? ?? 0,
      depositedAt: json['deposited_at'] != null 
          ? DateTime.parse(json['deposited_at'].toString())
          : DateTime.now(),
      latitude: json['latitude'] != null 
          ? double.tryParse(json['latitude'].toString()) ?? 0.0
          : 0.0,
      longitude: json['longitude'] != null 
          ? double.tryParse(json['longitude'].toString()) ?? 0.0
          : 0.0,
      notes: json['notes']?.toString(),
      garbageDump: json['garbage_dump'] != null 
          ? TPS.fromJson(json['garbage_dump'])
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collector_id': collectorId,
      'garbage_dump_id': garbageDumpId,
      'deposited_at': depositedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'garbage_dump': garbageDump?.toJson(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Format tanggal untuk display
  String get formattedDate {
    return '${depositedAt.day}/${depositedAt.month}/${depositedAt.year}';
  }

  /// Format waktu untuk display
  String get formattedTime {
    return '${depositedAt.hour.toString().padLeft(2, '0')}:${depositedAt.minute.toString().padLeft(2, '0')}';
  }

  /// Nama TPS
  String get tpsName => garbageDump?.name ?? 'TPS';

  /// Alamat TPS
  String get tpsAddress => garbageDump?.address ?? '-';
}
