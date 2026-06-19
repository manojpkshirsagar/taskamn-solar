class InstallationPhotos {
  final String id;
  final String customerId;
  final String? roofPhotoUrl;
  final String? installationPhotoUrl;
  final String? inverterPhotoUrl;
  final String? meterPhotoUrl;
  final String? customerSignatureUrl;
  final DateTime? updatedAt;

  InstallationPhotos({
    required this.id,
    required this.customerId,
    this.roofPhotoUrl,
    this.installationPhotoUrl,
    this.inverterPhotoUrl,
    this.meterPhotoUrl,
    this.customerSignatureUrl,
    this.updatedAt,
  });

  factory InstallationPhotos.fromJson(Map<String, dynamic> json) {
    return InstallationPhotos(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      roofPhotoUrl: json['roof_photo_url'] as String?,
      installationPhotoUrl: json['installation_photo_url'] as String?,
      inverterPhotoUrl: json['inverter_photo_url'] as String?,
      meterPhotoUrl: json['meter_photo_url'] as String?,
      customerSignatureUrl: json['customer_signature_url'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'roof_photo_url': roofPhotoUrl,
      'installation_photo_url': installationPhotoUrl,
      'inverter_photo_url': inverterPhotoUrl,
      'meter_photo_url': meterPhotoUrl,
      'customer_signature_url': customerSignatureUrl,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
