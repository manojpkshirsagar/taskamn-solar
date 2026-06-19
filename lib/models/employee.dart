class Employee {
  final String id;
  final String name;
  final String mobileNumber;
  final String designation;
  final String role; // 'admin' | 'employee'
  final DateTime? createdAt;
  final String? employeeCode;

  Employee({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.designation,
    required this.role,
    this.createdAt,
    this.employeeCode,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      mobileNumber: json['mobile_number'] as String,
      designation: json['designation'] as String,
      role: json['role'] as String,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      employeeCode: json['employee_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'designation': designation,
      'role': role,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'employee_code': employeeCode,
    };
  }
}
