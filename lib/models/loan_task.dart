class LoanTask {
  final String id;
  final String loanId;
  final String taskType;
  final bool isCompleted;
  final DateTime? dueDate;
  final String? remarks;
  final DateTime? completedAt;
  final DateTime? createdAt;

  LoanTask({
    required this.id,
    required this.loanId,
    required this.taskType,
    required this.isCompleted,
    this.dueDate,
    this.remarks,
    this.completedAt,
    this.createdAt,
  });

  factory LoanTask.fromJson(Map<String, dynamic> json) {
    return LoanTask(
      id: json['id'] as String,
      loanId: json['loan_id'] as String,
      taskType: json['task_type'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null,
      remarks: json['remarks'] as String?,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loan_id': loanId,
      'task_type': taskType,
      'is_completed': isCompleted,
      if (dueDate != null) 'due_date': '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
      'remarks': remarks,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  LoanTask copyWith({
    String? id,
    String? loanId,
    String? taskType,
    bool? isCompleted,
    DateTime? dueDate,
    String? remarks,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return LoanTask(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      taskType: taskType ?? this.taskType,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      remarks: remarks ?? this.remarks,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
