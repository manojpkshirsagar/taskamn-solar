class Customer {
  final String id;
  final String name;
  final String mobileNumber;
  final String emailAddress;
  final String address;
  final String? consumerNumber;
  final double solarCapacity;
  final String stage; // 'Lead' | 'Survey' | 'Quotation' | 'Loan Process' | 'Approved' | 'Material Dispatch' | 'Installation' | 'Net Meter' | 'Subsidy' | 'Completed' | 'Cancelled'
  final int installationStage; // 1 to 11
  final String paymentMode; // 'Not Selected' | 'Cash' | 'Loan'
  final DateTime? createdAt;

  // Custom Human-Readable IDs
  final String? customerCode;
  final String? leadCode;
  final String? installationCode;
  final String? netMeterCode;
  final String? subsidyCode;
  final String? quotationCode;
  final String? paymentCode;

  Customer({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.emailAddress,
    required this.address,
    this.consumerNumber,
    required this.solarCapacity,
    required this.stage,
    required this.installationStage,
    this.paymentMode = 'Not Selected',
    this.createdAt,
    this.customerCode,
    this.leadCode,
    this.installationCode,
    this.netMeterCode,
    this.subsidyCode,
    this.quotationCode,
    this.paymentCode,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      mobileNumber: json['mobile_number'] as String,
      emailAddress: json['email_address'] as String? ?? '',
      address: json['address'] as String? ?? '',
      consumerNumber: json['consumer_number'] as String?,
      solarCapacity: (json['solar_capacity'] as num?)?.toDouble() ?? 0.0,
      stage: json['stage'] as String? ?? 'Lead',
      installationStage: json['installation_stage'] as int? ?? 1,
      paymentMode: json['payment_mode'] as String? ?? 'Not Selected',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      customerCode: json['customer_code'] as String?,
      leadCode: json['lead_code'] as String?,
      installationCode: json['installation_code'] as String?,
      netMeterCode: json['net_meter_code'] as String?,
      subsidyCode: json['subsidy_code'] as String?,
      quotationCode: json['quotation_code'] as String?,
      paymentCode: json['payment_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'email_address': emailAddress,
      'address': address,
      'consumer_number': consumerNumber,
      'solar_capacity': solarCapacity,
      'stage': stage,
      'installation_stage': installationStage,
      'payment_mode': paymentMode,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'customer_code': customerCode,
      'lead_code': leadCode,
      'installation_code': installationCode,
      'net_meter_code': netMeterCode,
      'subsidy_code': subsidyCode,
      'quotation_code': quotationCode,
      'payment_code': paymentCode,
    };
  }
}
