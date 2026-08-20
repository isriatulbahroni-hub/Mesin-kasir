class ApprovalRequest {
  final String id;
  final String storeId;
  final String requestedBy;
  final String? approvedBy;
  final String requestType; // void | refund | discount | stock_adjustment | cash_out | price_change
  final String? recordId;
  final int? amount;
  final String? reason;
  final String status; // pending | approved | rejected | cancelled
  final String? decisionNote;
  final DateTime createdAt;
  final DateTime? decidedAt;

  ApprovalRequest({
    required this.id,
    required this.storeId,
    required this.requestedBy,
    this.approvedBy,
    required this.requestType,
    this.recordId,
    this.amount,
    this.reason,
    required this.status,
    this.decisionNote,
    required this.createdAt,
    this.decidedAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) => ApprovalRequest(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        requestedBy: json['requested_by'] as String,
        approvedBy: json['approved_by'] as String?,
        requestType: json['request_type'] as String,
        recordId: json['record_id'] as String?,
        amount: json['amount'] != null ? (json['amount'] as num).toInt() : null,
        reason: json['reason'] as String?,
        status: json['status'] as String,
        decisionNote: json['decision_note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        decidedAt: json['decided_at'] != null ? DateTime.parse(json['decided_at'] as String) : null,
      );

  String get typeLabel => switch (requestType) {
        'void' => 'Void Transaksi',
        'refund' => 'Refund',
        'discount' => 'Diskon Khusus',
        'stock_adjustment' => 'Penyesuaian Stok',
        'cash_out' => 'Kas Keluar',
        'price_change' => 'Ubah Harga',
        _ => requestType,
      };

  String get statusLabel => switch (status) {
        'pending' => 'Menunggu',
        'approved' => 'Disetujui',
        'rejected' => 'Ditolak',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };
}
