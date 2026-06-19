class ServiceRequest {
  final String id;
  final String customerId;
  final String mobileNumber;
  final String complaintType;
  final String description;
  final String? photoUrl;
  final String status; // 'Open' | 'Assigned' | 'Resolved' | 'Closed'
  final DateTime? createdAt;
  final String? serviceRequestCode;

  ServiceRequest({
    required this.id,
    required this.customerId,
    required this.mobileNumber,
    required this.complaintType,
    required this.description,
    this.photoUrl,
    required this.status,
    this.createdAt,
    this.serviceRequestCode,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      mobileNumber: json['mobile_number'] as String,
      complaintType: json['complaint_type'] as String,
      description: json['description'] as String,
      photoUrl: json['photo_url'] as String?,
      status: json['status'] as String? ?? 'Open',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      serviceRequestCode: json['service_request_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'mobile_number': mobileNumber,
      'complaint_type': complaintType,
      'description': description,
      'photo_url': photoUrl,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'service_request_code': serviceRequestCode,
    };
  }
}
