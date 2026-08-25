class PpobOrder {
  final String id;
  final String refId;
  final String customerNumber;
  final int sellPrice;
  final String status; // pending | success | failed
  final String? sn;
  final String? failureReason;
  final DateTime createdAt;

  PpobOrder({
    required this.id,
    required this.refId,
    required this.customerNumber,
    required this.sellPrice,
    required this.status,
    this.sn,
    this.failureReason,
    required this.createdAt,
  });

  factory PpobOrder.fromJson(Map<String, dynamic> json) => PpobOrder(
        id: json['id'] as String,
        refId: json['ref_id'] as String,
        customerNumber: json['customer_number'] as String,
        sellPrice: (json['sell_price'] as num).toInt(),
        status: json['status'] as String,
        sn: json['sn'] as String?,
        failureReason: json['failure_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
