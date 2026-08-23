class Purchase {
  final String id;
  final String storeId;
  final String? supplierId;
  final String purchaseNo;
  final int totalCost;
  final String? note;
  final String status; // draft | received | cancelled
  final DateTime createdAt;

  Purchase({
    required this.id,
    required this.storeId,
    this.supplierId,
    required this.purchaseNo,
    required this.totalCost,
    this.note,
    this.status = 'received',
    required this.createdAt,
  });

  bool get isDraft => status == 'draft';

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        supplierId: json['supplier_id'] as String?,
        purchaseNo: json['purchase_no'] as String,
        totalCost: (json['total_cost'] as num).toInt(),
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'received',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
