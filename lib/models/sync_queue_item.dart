class SyncQueueItem {
  final String id;
  final String moduleName;
  final String recordId;
  final String? employeeId;
  final String actionType; // CREATE | UPDATE | DELETE
  final Map<String, dynamic> dataJson;
  String syncStatus; // Pending | Syncing | Success | Failed
  final DateTime createdAt;
  String? errorMessage;

  SyncQueueItem({
    required this.id,
    required this.moduleName,
    required this.recordId,
    this.employeeId,
    required this.actionType,
    required this.dataJson,
    this.syncStatus = 'Pending',
    required this.createdAt,
    this.errorMessage,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      moduleName: json['module_name'] as String,
      recordId: json['record_id'] as String,
      employeeId: json['employee_id'] as String?,
      actionType: json['action_type'] as String,
      dataJson: (json['data_json'] as Map<String, dynamic>?) ?? {},
      syncStatus: json['sync_status'] as String? ?? 'Pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module_name': moduleName,
      'record_id': recordId,
      'employee_id': employeeId,
      'action_type': actionType,
      'data_json': dataJson,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  SyncQueueItem copyWith({String? syncStatus, String? errorMessage}) {
    return SyncQueueItem(
      id: id,
      moduleName: moduleName,
      recordId: recordId,
      employeeId: employeeId,
      actionType: actionType,
      dataJson: dataJson,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
