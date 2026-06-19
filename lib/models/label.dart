class Label {
  final String id;
  final String categoryId;
  final String labelName;
  final bool isActive;
  final DateTime? createdAt;

  Label({
    required this.id,
    required this.categoryId,
    required this.labelName,
    this.isActive = true,
    this.createdAt,
  });

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      labelName: json['label_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'label_name': labelName,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
