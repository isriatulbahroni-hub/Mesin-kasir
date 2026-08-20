class Device {
  final String id;
  final String storeId;
  final String? staffId;
  final String deviceKey;
  final String deviceName;
  final String? platform;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  Device({
    required this.id,
    required this.storeId,
    this.staffId,
    required this.deviceKey,
    required this.deviceName,
    this.platform,
    this.appVersion,
    this.lastSeenAt,
    this.revokedAt,
    required this.createdAt,
  });

  bool get isRevoked => revokedAt != null;
  bool get isThisDevice => false; // di-override secara kontekstual saat render

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        staffId: json['staff_id'] as String?,
        deviceKey: json['device_key'] as String,
        deviceName: json['device_name'] as String,
        platform: json['platform'] as String?,
        appVersion: json['app_version'] as String?,
        lastSeenAt: json['last_seen_at'] != null ? DateTime.parse(json['last_seen_at'] as String) : null,
        revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
