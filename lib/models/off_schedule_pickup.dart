class OffSchedulePickup {
  final int id;
  final int serviceAccountId;
  final String serviceAccountName;
  final String address;
  final String pickupType;
  final String requestStatus;
  final String status;
  final int bagCount;
  final int unitPrice;
  final int baseAmount;
  final int extraFee;
  final int totalAmount;
  final DateTime requestedAt;
  final String requestedPickupDate;
  final String? requestedPickupTime;
  final AssignedCollector? assignedCollector;
  final String? rejectionReason;
  final String? photoUrl;
  final Invoice? invoice;
  final String? residentNote;
  final String? note;

  OffSchedulePickup({
    required this.id,
    required this.serviceAccountId,
    required this.serviceAccountName,
    required this.address,
    required this.pickupType,
    required this.requestStatus,
    required this.status,
    required this.bagCount,
    required this.unitPrice,
    required this.baseAmount,
    required this.extraFee,
    required this.totalAmount,
    required this.requestedAt,
    required this.requestedPickupDate,
    this.requestedPickupTime,
    this.assignedCollector,
    this.rejectionReason,
    this.photoUrl,
    this.invoice,
    this.residentNote,
    this.note,
  });

  factory OffSchedulePickup.fromJson(Map<String, dynamic> json) {
    return OffSchedulePickup(
      id: json['id'],
      serviceAccountId: json['service_account_id'],
      serviceAccountName: json['service_account_name'] ?? '',
      address: json['address'] ?? '',
      pickupType: json['pickup_type'] ?? 'request',
      requestStatus: json['request_status'] ?? 'sent',
      status: json['status'] ?? 'pending',
      bagCount: json['bag_count'] ?? 0,
      unitPrice: json['unit_price'] ?? 0,
      baseAmount: json['base_amount'] ?? 0,
      extraFee: json['extra_fee'] ?? 0,
      totalAmount: json['total_amount'] ?? 0,
      requestedAt: json['requested_at'] != null 
          ? DateTime.parse(json['requested_at']) 
          : (json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now()),
      requestedPickupDate: json['requested_pickup_date'],
      requestedPickupTime: json['requested_pickup_time'],
      assignedCollector: json['assigned_collector'] != null
          ? AssignedCollector.fromJson(json['assigned_collector'])
          : null,
      rejectionReason: json['rejection_reason'],
      photoUrl: json['photo_url'],
      invoice: json['invoice'] != null ? Invoice.fromJson(json['invoice']) : null,
      residentNote: json['resident_note'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_account_id': serviceAccountId,
      'service_account_name': serviceAccountName,
      'address': address,
      'pickup_type': pickupType,
      'request_status': requestStatus,
      'status': status,
      'bag_count': bagCount,
      'unit_price': unitPrice,
      'base_amount': baseAmount,
      'extra_fee': extraFee,
      'total_amount': totalAmount,
      'requested_at': requestedAt.toIso8601String(),
      'requested_pickup_date': requestedPickupDate,
      'requested_pickup_time': requestedPickupTime,
      'assigned_collector': assignedCollector?.toJson(),
      'rejection_reason': rejectionReason,
      'photo_url': photoUrl,
      'invoice': invoice?.toJson(),
      'resident_note': residentNote,
      'note': note,
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
