enum PaymentMethod {
  tunai,
  qris,
  transfer,
  kartu,
  lainnya,
  campuran;

  static PaymentMethod fromString(String value) => PaymentMethod.values
      .firstWhere((e) => e.name == value, orElse: () => PaymentMethod.tunai);

  String get label {
    switch (this) {
      case PaymentMethod.tunai:
        return 'Tunai';
      case PaymentMethod.qris:
        return 'QRIS';
      case PaymentMethod.transfer:
        return 'Transfer';
      case PaymentMethod.kartu:
        return 'Kartu';
      case PaymentMethod.lainnya:
        return 'Lainnya';
      case PaymentMethod.campuran:
        return 'Split/Campuran';
    }
  }
}

enum TransactionStatus {
  completed,
  void_,
  refunded;

  static TransactionStatus fromString(String value) {
    if (value == 'void') return TransactionStatus.void_;
    return TransactionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionStatus.completed,
    );
  }

  /// Nilai asli yang dipakai enum Postgres (`void`, bukan `void_`).
  String get dbValue => this == TransactionStatus.void_ ? 'void' : name;

  String get label {
    switch (this) {
      case TransactionStatus.completed:
        return 'Selesai';
      case TransactionStatus.void_:
        return 'Dibatalkan (Void)';
      case TransactionStatus.refunded:
        return 'Refund';
    }
  }
}

class Transaction {
  final String id;
  final String storeId;
  final String? staffId;
  final String? shiftId;
  final String invoiceNo;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final int paidAmount;
  final int changeAmount;
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final String? note;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.storeId,
    this.staffId,
    this.shiftId,
    required this.invoiceNo,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        staffId: json['staff_id'] as String?,
        shiftId: json['shift_id'] as String?,
        invoiceNo: json['invoice_no'] as String,
        subtotal: (json['subtotal'] as num).toInt(),
        discount: (json['discount'] as num?)?.toInt() ?? 0,
        tax: (json['tax'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num).toInt(),
        paidAmount: (json['paid_amount'] as num).toInt(),
        changeAmount: (json['change_amount'] as num?)?.toInt() ?? 0,
        paymentMethod: PaymentMethod.fromString(json['payment_method'] as String),
        status: TransactionStatus.fromString(json['status'] as String),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
