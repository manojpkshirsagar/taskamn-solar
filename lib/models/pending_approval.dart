class PendingApproval {
  final String id;
  final String moduleName; // customers | tasks | loans | service_requests | payments | installation_photos | customer_labels
  final String recordId;
  final String employeeId;
  final String? customerId;
  final String actionType; // CREATE | UPDATE | DELETE
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic> newData;
  String status; // Pending | Approved | Rejected
  String? rejectionReason;
  final DateTime createdAt;
  DateTime? approvedAt;
  String? approvedBy;

  // Transient display helpers (not persisted)
  String? employeeName;
  String? customerName;

  PendingApproval({
    required this.id,
    required this.moduleName,
    required this.recordId,
    required this.employeeId,
    this.customerId,
    required this.actionType,
    this.oldData,
    required this.newData,
    this.status = 'Pending',
    this.rejectionReason,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.employeeName,
    this.customerName,
  });

  factory PendingApproval.fromJson(Map<String, dynamic> json) {
    return PendingApproval(
      id: json['id'] as String,
      moduleName: json['module_name'] as String,
      recordId: json['record_id'] as String,
      employeeId: json['employee_id'] as String,
      customerId: json['customer_id'] as String?,
      actionType: json['action_type'] as String,
      oldData: json['old_data'] != null
          ? Map<String, dynamic>.from(json['old_data'] as Map)
          : null,
      newData: Map<String, dynamic>.from(json['new_data'] as Map),
      status: json['status'] as String? ?? 'Pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      approvedBy: json['approved_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module_name': moduleName,
      'record_id': recordId,
      'employee_id': employeeId,
      'customer_id': customerId,
      'action_type': actionType,
      'old_data': oldData,
      'new_data': newData,
      'status': status,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
    };
  }

  PendingApproval copyWith({
    String? status,
    String? rejectionReason,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return PendingApproval(
      id: id,
      moduleName: moduleName,
      recordId: recordId,
      employeeId: employeeId,
      customerId: customerId,
      actionType: actionType,
      oldData: oldData,
      newData: newData,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      employeeName: employeeName,
      customerName: customerName,
    );
  }
}
