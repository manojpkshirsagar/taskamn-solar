class ImportHistory {
  final String id;
  final String fileName;
  final String moduleName;
  final DateTime importDate;
  final String importedBy;
  final int successCount;
  final int failedCount;

  ImportHistory({
    required this.id,
    required this.fileName,
    required this.moduleName,
    required this.importDate,
    required this.importedBy,
    required this.successCount,
    required this.failedCount,
  });

  factory ImportHistory.fromJson(Map<String, dynamic> json) {
    return ImportHistory(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      moduleName: json['module_name'] as String,
      importDate: DateTime.parse(json['import_date'] as String),
      importedBy: json['imported_by'] as String? ?? 'Admin',
      successCount: json['success_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'module_name': moduleName,
      'import_date': importDate.toIso8601String(),
      'imported_by': importedBy,
      'success_count': successCount,
      'failed_count': failedCount,
    };
  }
}

class ExportHistory {
  final String id;
  final String reportName;
  final String exportType;
  final DateTime exportDate;
  final String exportedBy;
  final int totalRecords;

  ExportHistory({
    required this.id,
    required this.reportName,
    required this.exportType,
    required this.exportDate,
    required this.exportedBy,
    required this.totalRecords,
  });

  factory ExportHistory.fromJson(Map<String, dynamic> json) {
    return ExportHistory(
      id: json['id'] as String,
      reportName: json['report_name'] as String,
      exportType: json['export_type'] as String,
      exportDate: DateTime.parse(json['export_date'] as String),
      exportedBy: json['exported_by'] as String? ?? 'Admin',
      totalRecords: json['total_records'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_name': reportName,
      'export_type': exportType,
      'export_date': exportDate.toIso8601String(),
      'exported_by': exportedBy,
      'total_records': totalRecords,
    };
  }
}
