class PpobProduct {
  final String id;
  final String h2hProductCode;
  final String category;
  final String? operatorName;
  final String name;
  final int basePrice;
  final int sellPrice;
  final bool isActive;

  PpobProduct({
    required this.id,
    required this.h2hProductCode,
    required this.category,
    this.operatorName,
    required this.name,
    required this.basePrice,
    required this.sellPrice,
    required this.isActive,
  });

  factory PpobProduct.fromJson(Map<String, dynamic> json) => PpobProduct(
        id: json['id'] as String,
        h2hProductCode: json['h2h_product_code'] as String,
        category: json['category'] as String,
        operatorName: json['operator'] as String?,
        name: json['name'] as String,
        basePrice: (json['base_price'] as num).toInt(),
        sellPrice: (json['sell_price'] as num).toInt(),
        isActive: json['is_active'] as bool? ?? true,
      );
}
