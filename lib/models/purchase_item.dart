class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  final int quantity;
  final int costPrice;
  final int subtotal;
  final String? productName; // diisi manual dari join, bukan dari kolom asli

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.costPrice,
    required this.subtotal,
    this.productName,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json['id'] as String,
        purchaseId: json['purchase_id'] as String,
        productId: json['product_id'] as String,
        quantity: (json['quantity'] as num).toInt(),
        costPrice: (json['cost_price'] as num).toInt(),
        subtotal: (json['subtotal'] as num).toInt(),
        productName: json['products'] != null ? json['products']['name'] as String? : null,
      );
}
