class LabelCategory {
  final String id;
  final String categoryName;
  final DateTime? createdAt;

  LabelCategory({
    required this.id,
    required this.categoryName,
    this.createdAt,
  });

  factory LabelCategory.fromJson(Map<String, dynamic> json) {
    return LabelCategory(
      id: json['id'] as String,
      categoryName: json['category_name'] as String,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': categoryName,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
