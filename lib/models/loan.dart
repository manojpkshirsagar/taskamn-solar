class Loan {
  final String id;
  final String customerId;
  final double loanAmount;
  final String bankName;
  final String? branch;
  final String status;
  final String? assignedEmployeeId;
  final String? remarks;
  final DateTime? createdAt;
  final String? loanCode;

  Loan({
    required this.id,
    required this.customerId,
    required this.loanAmount,
    required this.bankName,
    this.branch,
    required this.status,
    this.assignedEmployeeId,
    this.remarks,
    this.createdAt,
    this.loanCode,
  });

  static String normalizeStatus(String? status) {
    if (status == null) return 'Loan Application';
    if (status == 'Document Collection') return 'Loan Application';
    if (status == 'Bank Verification') return 'File at Bank';
    const validStatuses = [
      'Loan Application',
      'File Print',
      'File at Office',
      'File at Bank',
      'Bank Issue',
      'Bank Visit At Home',
      'Approved',
    ];
    if (status == 'Bank Issue or Approved') return 'Bank Issue';
    if (status == 'Approved / Reject-Reapplied') return 'Bank Issue';
    if (!validStatuses.contains(status)) {
      return 'Loan Application';
    }
    return status;
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      loanAmount: (json['loan_amount'] as num?)?.toDouble() ?? 0.0,
      bankName: json['bank_name'] as String,
      branch: json['branch'] as String?,
      status: normalizeStatus(json['status'] as String?),
      assignedEmployeeId: json['assigned_employee_id'] as String?,
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      loanCode: json['loan_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'loan_amount': loanAmount,
      'bank_name': bankName,
      'branch': branch,
      'status': status,
      'assigned_employee_id': assignedEmployeeId,
      'remarks': remarks,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'loan_code': loanCode,
    };
  }
}
