enum StaffRole {
  owner,
  admin,
  kasir;

  static StaffRole fromString(String value) {
    return StaffRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaffRole.kasir,
    );
  }

  String get label {
    switch (this) {
      case StaffRole.owner:
        return 'Owner';
      case StaffRole.admin:
        return 'Admin';
      case StaffRole.kasir:
        return 'Kasir';
    }
  }

  /// Owner & admin boleh void/refund transaksi, kelola produk, lihat laporan penuh.
  bool get canManage => this == StaffRole.owner || this == StaffRole.admin;

  bool get isOwner => this == StaffRole.owner;
}

class Staff {
  final String id;
  final String storeId;
  final String userId;
  final StaffRole role;
  final String fullName;
  final bool isActive;
  final DateTime? shiftOpenAt;
  final DateTime createdAt;

  Staff({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.role,
    required this.fullName,
    required this.isActive,
    this.shiftOpenAt,
    required this.createdAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        userId: json['user_id'] as String,
        role: StaffRole.fromString(json['role'] as String),
        fullName: json['full_name'] as String,
        isActive: json['is_active'] as bool? ?? true,
        shiftOpenAt: json['shift_open_at'] != null
            ? DateTime.parse(json['shift_open_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isShiftOpen => shiftOpenAt != null;
}
