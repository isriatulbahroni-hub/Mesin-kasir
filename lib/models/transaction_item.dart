class TransactionItem {
  final String id;
  final String transactionId;
  final String? productId;
  final String productName;
  final int price;
  final int costPrice;
  final int quantity;
  final int discount;
  final int subtotal;

  TransactionItem({
    required this.id,
    required this.transactionId,
    this.productId,
    required this.productName,
    required this.price,
    required this.costPrice,
    required this.quantity,
    required this.discount,
    required this.subtotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: json['id'] as String,
        transactionId: json['transaction_id'] as String,
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String,
        price: (json['price'] as num).toInt(),
        costPrice: (json['cost_price'] as num?)?.toInt() ?? 0,
        quantity: (json['quantity'] as num).toInt(),
        discount: (json['discount'] as num?)?.toInt() ?? 0,
        subtotal: (json['subtotal'] as num).toInt(),
      );
}
