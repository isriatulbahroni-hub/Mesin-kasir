class ProductCategory {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;

  ProductCategory({
    required this.id,
    required this.storeId,
    required this.name,
    required this.sortOrder,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}
