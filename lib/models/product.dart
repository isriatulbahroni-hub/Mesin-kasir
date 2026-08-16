class Product {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? sku;
  final String? photoUrl;
  final int sellingPrice;
  final int costPrice;
  final int? stock;
  final int lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.sku,
    this.photoUrl,
    required this.sellingPrice,
    required this.costPrice,
    this.stock,
    required this.lowStockThreshold,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get tracksStock => stock != null;
  bool get isLowStock => tracksStock && stock! <= lowStockThreshold;
  bool get isOutOfStock => tracksStock && stock! <= 0;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        categoryId: json['category_id'] as String?,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        photoUrl: json['photo_url'] as String?,
        sellingPrice: (json['selling_price'] as num).toInt(),
        costPrice: (json['cost_price'] as num).toInt(),
        stock: json['stock'] == null ? null : (json['stock'] as num).toInt(),
        lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 5,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toInsert() => {
        'store_id': storeId,
        'category_id': categoryId,
        'name': name,
        'sku': sku,
        'photo_url': photoUrl,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'stock': stock,
        'low_stock_threshold': lowStockThreshold,
        'is_active': isActive,
      };
}
