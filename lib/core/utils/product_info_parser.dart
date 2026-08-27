// Parser keterangan produk dari `name` (nama produk H2H). Nama produk
// H2H sudah punya info kuota/masa aktif dalam teks bebas, contoh:
//   "Telkomsel Data 42 GB 28 Hari (Jabo - jabar)" -> 42 GB, 28 Hari
//   "10 Diamond Free Fire" -> item game, bukan kuota
// Diekstrak jadi info terstruktur biar bisa ditampilkan sebagai badge
// yang jelas kebaca, bukan cuma nempel di tengah nama produk yang panjang.
//
// Port dari logic yang sama persis dipakai di backend NexaPay
// (productInfoParser.js) -- supaya konsisten hasilnya di kedua aplikasi.

class ProductInfo {
  final String? quota; // "42 GB" atau "42 GB + 10 GB"
  final String? validity; // "28 Hari" atau "2 Bulan"
  final int bonusCount;
  const ProductInfo({this.quota, this.validity, this.bonusCount = 0});
  bool get hasAny => quota != null || validity != null;
}

final _quotaPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*(GB|MB)\b', caseSensitive: false);
final _hariPattern = RegExp(r'(\d+)\s*Hari\b', caseSensitive: false);
final _bulanPattern = RegExp(r'(\d+)\s*Bulan\b', caseSensitive: false);

ProductInfo parseProductInfo(String name) {
  final quotaMatches = _quotaPattern.allMatches(name).toList();
  String? quota;
  if (quotaMatches.isNotEmpty) {
    quota = quotaMatches.map((m) {
      final amount = m.group(1)!.replaceAll(',', '.');
      final unit = m.group(2)!.toUpperCase();
      return '$amount $unit';
    }).join(' + ');
  }

  String? validity;
  final hariMatch = _hariPattern.firstMatch(name);
  if (hariMatch != null) {
    validity = '${hariMatch.group(1)} Hari';
  } else {
    final bulanMatch = _bulanPattern.firstMatch(name);
    if (bulanMatch != null) validity = '${bulanMatch.group(1)} Bulan';
  }

  final bonusCount = name.split('+').length - 1;

  return ProductInfo(quota: quota, validity: validity, bonusCount: bonusCount > 0 ? bonusCount : 0);
}
