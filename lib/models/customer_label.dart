class CustomerLabel {
  final String id;
  final String customerId;
  final String labelId;
  final DateTime? createdAt;

  CustomerLabel({
    required this.id,
    required this.customerId,
    required this.labelId,
    this.createdAt,
  });

  factory CustomerLabel.fromJson(Map<String, dynamic> json) {
    return CustomerLabel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      labelId: json['label_id'] as String,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'label_id': labelId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
