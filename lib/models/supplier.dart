class Supplier {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final bool isActive;

  Supplier({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.address,
    this.note,
    required this.isActive,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        note: json['note'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}
