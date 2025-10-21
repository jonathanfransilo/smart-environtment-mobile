class PaymentTransaction {
  final int? id;
  final String? orderId;
  final int invoiceId;
  final double amount;
  final String? paymentMethod;
  final String? paymentType;
  final String? paymentChannel;
  final String? providerTransactionId;
  final String? midtransTransactionId;
  final String status;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiredAt;

  // Additional fields dari response API
  final String? snapToken;
  final String? snapRedirectUrl;
  final String? qrisString;
  final String? deeplink;
  final VirtualAccountInfo? virtualAccount;

  PaymentTransaction({
    this.id,
    this.orderId,
    required this.invoiceId,
    required this.amount,
    this.paymentMethod,
    this.paymentType,
    this.paymentChannel,
    this.providerTransactionId,
    this.midtransTransactionId,
    required this.status,
    this.metadata,
    this.createdAt,
    this.updatedAt,
    this.expiredAt,
    this.snapToken,
    this.snapRedirectUrl,
    this.qrisString,
    this.deeplink,
    this.virtualAccount,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    // Handle virtual account data
    VirtualAccountInfo? vaInfo;
    if (json['va_number'] != null && json['bank'] != null) {
      vaInfo = VirtualAccountInfo(
        bank: json['bank'],
        vaNumber: json['va_number'],
      );
    }

    return PaymentTransaction(
      id: json['id'],
      orderId: json['order_id'],
      invoiceId: json['invoice_id'] ?? 0, // Backend sends order_id, but we need invoice_id
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'midtrans',
      paymentType: json['payment_type'],
      paymentChannel: json['payment_channel'],
      providerTransactionId: json['provider_transaction_id'],
      midtransTransactionId: json['midtrans_transaction_id'],
      status: json['status'] ?? 'pending',
      metadata: json['metadata'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.tryParse(json['expired_at'])
          : null,
      snapToken: json['snap_token'],
      snapRedirectUrl: json['snap_redirect_url'],
      qrisString: json['qr_string'] ?? json['qris_string'],
      deeplink: json['payment_url'] ?? json['deeplink'],
      virtualAccount: vaInfo ?? (json['virtual_account'] != null
          ? VirtualAccountInfo.fromJson(json['virtual_account'])
          : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_type': paymentType,
      'payment_channel': paymentChannel,
      'provider_transaction_id': providerTransactionId,
      'midtrans_transaction_id': midtransTransactionId,
      'status': status,
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'expired_at': expiredAt?.toIso8601String(),
      'snap_token': snapToken,
      'snap_redirect_url': snapRedirectUrl,
      'qris_string': qrisString,
      'deeplink': deeplink,
      'virtual_account': virtualAccount?.toJson(),
    };
  }

  // Helper untuk check status
  bool get isPending => status == 'pending';
  bool get isSuccess =>
      status == 'settlement' || status == 'success' || status == 'capture';
  bool get isFailed =>
      status == 'failed' || status == 'cancelled' || status == 'expired';
}

class VirtualAccountInfo {
  final String? bank;
  final String? vaNumber;
  final String? expiryTime;

  VirtualAccountInfo({
    this.bank,
    this.vaNumber,
    this.expiryTime,
  });

  factory VirtualAccountInfo.fromJson(Map<String, dynamic> json) {
    return VirtualAccountInfo(
      bank: json['bank'],
      vaNumber: json['va_number'],
      expiryTime: json['expiry_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank': bank,
      'va_number': vaNumber,
      'expiry_time': expiryTime,
    };
  }
}

class PaymentMethod {
  final String id;
  final String name;
  final String type; // 'virtual_account', 'qris', 'ewallet'
  final String? iconPath;
  final List<PaymentChannel>? channels;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.iconPath,
    this.channels,
  });
}

class PaymentChannel {
  final String id;
  final String name;
  final String? iconPath;
  final String? description;

  PaymentChannel({
    required this.id,
    required this.name,
    this.iconPath,
    this.description,
  });
}
