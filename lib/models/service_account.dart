class ServiceAccount {
  ServiceAccount({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.contactPhone,
    this.kecamatanName,
    this.kelurahanName,
    this.rwName,
    this.hariPengangkutan,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String status;
  final String? contactPhone;
  final String? kecamatanName;
  final String? kelurahanName;
  final String? rwName;
  final String? hariPengangkutan;

  factory ServiceAccount.fromJson(Map<String, dynamic> json) {
    final areaData = json['area'];
    final areaMap = areaData is Map<String, dynamic> ? areaData : null;
    final parentData = areaMap?['parent'];
    final parentMap = parentData is Map<String, dynamic> ? parentData : null;
    final rwData = json['rw'];
    final rwMap = rwData is Map<String, dynamic> ? rwData : null;

    return ServiceAccount(
      id: json['id'].toString(),
      name: (json['name'] ?? json['nama'] ?? '-') as String,
      address: (json['address'] ?? json['alamat_lengkap'] ?? '-') as String,
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'active',
      contactPhone:
          json['contact_phone']?.toString() ?? json['phone']?.toString(),
      kecamatanName:
          json['kecamatan']?.toString() ?? parentMap?['name']?.toString(),
      kelurahanName:
          json['kelurahan']?.toString() ?? areaMap?['name']?.toString(),
      // Try multiple paths for RW name
      rwName:
          json['rw_name']?.toString() ??
          rwMap?['name']?.toString() ??
          rwMap?['code']?.toString() ??
          json['rw']?.toString(),
      hariPengangkutan: json['hari_pengangkutan']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'contact_phone': contactPhone,
      'kecamatan': kecamatanName,
      'kelurahan': kelurahanName,
      'rw': rwName,
      'hari_pengangkutan': hariPengangkutan,
    };
  }
}
