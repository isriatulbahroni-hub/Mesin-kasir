class Store {
  final String id;
  final String ownerId;
  final String name;
  final String? address;
  final String? qrisImageUrl;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address,
    this.qrisImageUrl,
    required this.createdAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        qrisImageUrl: json['qris_image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toInsert() => {
        'owner_id': ownerId,
        'name': name,
        'address': address,
      };
}
