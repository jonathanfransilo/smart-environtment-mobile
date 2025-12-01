class OffSchedulePickup {
  final int id;
  final ServiceAccount? serviceAccount;
  final String pickupType;
  final String requestStatus;
  final String status;
  final int bagCount;
  final int baseAmount;
  final int extraFee;
  final int totalAmount;
  final DateTime? createdAt;
  final String requestedPickupDate;
  final String? requestedPickupTime;
  final AssignedCollector? assignedCollector;
  final String? rejectionReason;
  final String? photoUrl;
  final Invoice? invoice;
  final String? residentNote;
  final String? note;
  final String? collectorNotes;
  final DateTime? collectedAt;

  OffSchedulePickup({
    required this.id,
    this.serviceAccount,
    required this.pickupType,
    required this.requestStatus,
    required this.status,
    required this.bagCount,
    required this.baseAmount,
    required this.extraFee,
    required this.totalAmount,
    this.createdAt,
    required this.requestedPickupDate,
    this.requestedPickupTime,
    this.assignedCollector,
    this.rejectionReason,
    this.photoUrl,
    this.invoice,
    this.residentNote,
    this.note,
    this.collectorNotes,
    this.collectedAt,
  });

  // Convenience getters for backward compatibility
  int get serviceAccountId => serviceAccount?.id ?? 0;
  String get serviceAccountName => serviceAccount?.name ?? '';
  String get address => serviceAccount?.address ?? '';

  factory OffSchedulePickup.fromJson(Map<String, dynamic> json) {
    return OffSchedulePickup(
      id: json['id'] ?? 0,
      serviceAccount: json['service_account'] != null
          ? ServiceAccount.fromJson(json['service_account'])
          : null,
      pickupType: json['pickup_type'] ?? 'request',
      requestStatus: json['request_status'] ?? 'sent',
      status: json['status'] ?? 'pending',
      bagCount: json['bag_count'] ?? 0,
      baseAmount: (json['base_amount'] ?? 0).toInt(),
      extraFee: (json['extra_fee'] ?? 0).toInt(),
      totalAmount: (json['total_amount'] ?? 0).toInt(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      requestedPickupDate: json['requested_pickup_date'] ?? '',
      requestedPickupTime: json['requested_pickup_time'],
      assignedCollector: json['assigned_collector'] != null
          ? AssignedCollector.fromJson(json['assigned_collector'])
          : null,
      rejectionReason: json['rejection_reason'],
      photoUrl: json['photo_url'],
      invoice: json['invoice'] != null ? Invoice.fromJson(json['invoice']) : null,
      residentNote: json['resident_note'],
      note: json['note'],
      collectorNotes: json['collector_notes'],
      collectedAt: json['collected_at'] != null
          ? DateTime.parse(json['collected_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_account': serviceAccount?.toJson(),
      'pickup_type': pickupType,
      'request_status': requestStatus,
      'status': status,
      'bag_count': bagCount,
      'base_amount': baseAmount,
      'extra_fee': extraFee,
      'total_amount': totalAmount,
      'created_at': createdAt?.toIso8601String(),
      'requested_pickup_date': requestedPickupDate,
      'requested_pickup_time': requestedPickupTime,
      'assigned_collector': assignedCollector?.toJson(),
      'rejection_reason': rejectionReason,
      'photo_url': photoUrl,
      'invoice': invoice?.toJson(),
      'resident_note': residentNote,
      'note': note,
      'collector_notes': collectorNotes,
      'collected_at': collectedAt?.toIso8601String(),
    };
  }

  String getStatusLabel() {
    switch (requestStatus) {
      case 'sent':
        return 'Menunggu Penugasan';
      case 'processing':
        return 'Sedang Diproses';
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'completed':
        return 'Selesai';
      case 'paid':
        return 'Lunas';
      case 'rejected':
        return 'Ditolak';
      default:
        return requestStatus;
    }
  }

  String getStatusColor() {
    switch (requestStatus) {
      case 'sent':
        return 'blue';
      case 'processing':
        return 'orange';
      case 'pending':
        return 'purple';
      case 'completed':
        return 'green';
      case 'paid':
        return 'teal';
      case 'rejected':
        return 'red';
      default:
        return 'grey';
    }
  }
}

class ServiceAccount {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;

  ServiceAccount({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.contactPhone,
  });

  factory ServiceAccount.fromJson(Map<String, dynamic> json) {
    // Debug: Print all available keys
    print('🔍 [ServiceAccount] Parsing from JSON with keys: ${json.keys.toList()}');
    print('   Raw JSON: $json');
    
    return ServiceAccount(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      // ✅ PERBAIKAN: Coba beberapa kemungkinan field name untuk contact phone
      contactPhone: json['contact_phone'] ?? json['phone'] ?? json['contact_number'] ?? json['phone_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contact_phone': contactPhone,
    };
  }
}

class AssignedCollector {
  final int id;
  final String name;

  AssignedCollector({
    required this.id,
    required this.name,
  });

  factory AssignedCollector.fromJson(Map<String, dynamic> json) {
    return AssignedCollector(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class Invoice {
  final int id;
  final String invoiceNumber;
  final String status;
  final int totalAmount;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.totalAmount,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      invoiceNumber: json['invoice_number'],
      status: json['status'],
      totalAmount: json['total_amount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'status': status,
      'total_amount': totalAmount,
    };
  }
}
