/// Model untuk TPS (Tempat Pembuangan Sementara)
class TPS {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? capacityVolume;
  final double? capacityWeight;
  final String status;
  final TPSKecamatan? kecamatan;
  final TPSKelurahan? kelurahan;
  final TPSRW? rw;
  final String? imageUrl;

  TPS({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.capacityVolume,
    this.capacityWeight,
    this.status = 'active',
    this.kecamatan,
    this.kelurahan,
    this.rw,
    this.imageUrl,
  });

  factory TPS.fromJson(Map<String, dynamic> json) {
    return TPS(
      id: json['id'] as int,
      name: json['name']?.toString() ?? 'TPS',
      address: json['address']?.toString() ?? '-',
      latitude: json['latitude'] != null 
          ? double.tryParse(json['latitude'].toString()) 
          : null,
      longitude: json['longitude'] != null 
          ? double.tryParse(json['longitude'].toString()) 
          : null,
      capacityVolume: json['capacity_volume'] != null 
          ? double.tryParse(json['capacity_volume'].toString()) 
          : null,
      capacityWeight: json['capacity_weight'] != null 
          ? double.tryParse(json['capacity_weight'].toString()) 
          : null,
      status: json['status']?.toString() ?? 'active',
      kecamatan: json['kecamatan'] != null 
          ? TPSKecamatan.fromJson(json['kecamatan']) 
          : null,
      kelurahan: json['kelurahan'] != null 
          ? TPSKelurahan.fromJson(json['kelurahan']) 
          : null,
      rw: json['rw'] != null 
          ? TPSRW.fromJson(json['rw']) 
          : null,
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'capacity_volume': capacityVolume,
      'capacity_weight': capacityWeight,
      'status': status,
      'kecamatan': kecamatan?.toJson(),
      'kelurahan': kelurahan?.toJson(),
      'rw': rw?.toJson(),
      'image_url': imageUrl,
    };
  }
}

class TPSKecamatan {
  final int id;
  final String name;

  TPSKecamatan({required this.id, required this.name});

  factory TPSKecamatan.fromJson(Map<String, dynamic> json) {
    return TPSKecamatan(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class TPSKelurahan {
  final int id;
  final String name;

  TPSKelurahan({required this.id, required this.name});

  factory TPSKelurahan.fromJson(Map<String, dynamic> json) {
    return TPSKelurahan(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class TPSRW {
  final int id;
  final String name;

  TPSRW({required this.id, required this.name});

  factory TPSRW.fromJson(Map<String, dynamic> json) {
    return TPSRW(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
