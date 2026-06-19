class Payment {
  final String id;
  final String customerId;
  final double amount;
  final String paymentMode; // Cash | Cheque | Online | Bank Transfer
  final DateTime paymentDate;
  final String? receiptNumber;
  final String? remarks;
  final String? paymentCode;
  final DateTime? createdAt;

  Payment({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.paymentMode,
    required this.paymentDate,
    this.receiptNumber,
    this.remarks,
    this.paymentCode,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String? ?? 'Cash',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      receiptNumber: json['receipt_number'] as String?,
      remarks: json['remarks'] as String?,
      paymentCode: json['payment_code'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'payment_mode': paymentMode,
      'payment_date': paymentDate.toIso8601String().split('T')[0],
      'receipt_number': receiptNumber,
      'remarks': remarks,
      'payment_code': paymentCode,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
