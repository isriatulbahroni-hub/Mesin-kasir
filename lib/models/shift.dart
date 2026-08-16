class Shift {
  final String id;
  final String storeId;
  final String staffId;
  final int openingCash;
  final int? closingCash;
  final int? expectedCash;
  final int? cashDifference;
  final DateTime openedAt;
  final DateTime? closedAt;

  Shift({
    required this.id,
    required this.storeId,
    required this.staffId,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.cashDifference,
    required this.openedAt,
    this.closedAt,
  });

  bool get isOpen => closedAt == null;

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        staffId: json['staff_id'] as String,
        openingCash: (json['opening_cash'] as num).toInt(),
        closingCash: (json['closing_cash'] as num?)?.toInt(),
        expectedCash: (json['expected_cash'] as num?)?.toInt(),
        cashDifference: (json['cash_difference'] as num?)?.toInt(),
        openedAt: DateTime.parse(json['opened_at'] as String),
        closedAt: json['closed_at'] != null
            ? DateTime.parse(json['closed_at'] as String)
            : null,
      );
}
