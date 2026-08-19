class Customer {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final String? memberCode;
  final int points;
  final String tier;
  final bool isActive;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.memberCode,
    required this.points,
    required this.tier,
    required this.isActive,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        memberCode: json['member_code'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        tier: json['tier'] as String? ?? 'regular',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
