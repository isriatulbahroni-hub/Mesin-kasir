class Promotion {
  final String id;
  final String storeId;
  final String name;
  final String promotionType; // 'percentage' | 'fixed' | 'voucher' | 'buy_x_get_y' | 'bundle'
  final int value;
  final int minimumPurchase;
  final int? maximumDiscount;
  final int? usageLimit;
  final int usedCount;
  final String? code;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  Promotion({
    required this.id,
    required this.storeId,
    required this.name,
    required this.promotionType,
    required this.value,
    required this.minimumPurchase,
    this.maximumDiscount,
    this.usageLimit,
    required this.usedCount,
    this.code,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  /// Tipe yang bisa dihitung & diterapkan otomatis oleh app saat ini.
  /// 'buy_x_get_y'/'bundle' butuh logika substitusi item yang belum dibuat.
  bool get isSupported => promotionType == 'percentage' || promotionType == 'fixed' || promotionType == 'voucher';

  /// Hitung nominal diskon untuk subtotal tertentu, sudah dibatasi
  /// maximumDiscount (kalau ada) dan tidak pernah melebihi subtotal itu
  /// sendiri. Tipe 'voucher' dihitung sebagai nominal tetap (value),
  /// sama seperti 'fixed', bedanya cuma cara aktivasinya (kode vs pilih list).
  int computeDiscount(int subtotal) {
    if (subtotal < minimumPurchase) return 0;
    int raw;
    switch (promotionType) {
      case 'percentage':
        raw = (subtotal * value / 100).round();
        break;
      case 'fixed':
      case 'voucher':
        raw = value;
        break;
      default:
        return 0;
    }
    if (maximumDiscount != null) raw = raw > maximumDiscount! ? maximumDiscount! : raw;
    return raw.clamp(0, subtotal);
  }

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String,
        promotionType: json['promotion_type'] as String,
        value: (json['value'] as num).toInt(),
        minimumPurchase: (json['minimum_purchase'] as num?)?.toInt() ?? 0,
        maximumDiscount: (json['maximum_discount'] as num?)?.toInt(),
        usageLimit: (json['usage_limit'] as num?)?.toInt(),
        usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
        code: json['code'] as String?,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        isActive: json['is_active'] as bool? ?? true,
      );
}
