class Task {
  final String id;
  final String customerId;
  final String taskType; // 'Site Survey' | 'Quotation Follow-up' | 'Installation' | 'Net Meter Application' | 'Inspection' | 'Subsidy Documents' | 'Payment Collection' | 'Service Visit'
  final String? assignedEmployeeId;
  final DateTime dueDate;
  final String priority; // 'Low' | 'Medium' | 'High'
  final String? remarks;
  final String status; // 'Pending' | 'In Progress' | 'Completed' | 'Hold'
  final DateTime? createdAt;
  final String? taskCode;

  Task({
    required this.id,
    required this.customerId,
    required this.taskType,
    this.assignedEmployeeId,
    required this.dueDate,
    required this.priority,
    this.remarks,
    required this.status,
    this.createdAt,
    this.taskCode,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      taskType: json['task_type'] as String,
      assignedEmployeeId: json['assigned_employee_id'] as String?,
      dueDate: DateTime.parse(json['due_date'] as String),
      priority: json['priority'] as String? ?? 'Medium',
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'Pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      taskCode: json['task_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'task_type': taskType,
      'assigned_employee_id': assignedEmployeeId,
      'due_date': '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
      'priority': priority,
      'remarks': remarks,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'task_code': taskCode,
    };
  }
}
