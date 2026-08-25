// Deteksi operator seluler dari 4 digit awal nomor HP Indonesia.
// Data prefix diadaptasi dari github.com/Novriyaldi/prefix_phone_number
// (per 24 Agu 2026) -- dengan 2 perbaikan atas data aslinya:
//   1. File JSON sumbernya sendiri sebenarnya invalid (ada koma yang
//      hilang antara blok "smart" dan "three").
//   2. Prefix 0811 (Telkomsel/HALO) tidak ada di data asli, ditambahkan
//      manual berdasarkan cross-check ke sumber lain.
//
// Dipakai buat fitur "baca kartu": begitu kasir ngetik nomor tujuan,
// produk yang ditampilkan otomatis difilter cuma yang match operatornya
// -- mencegah salah beli produk (misal beli pulsa Telkomsel buat nomor XL).

enum PhoneOperator { telkomsel, indosat, xl, axis, three, smartfren }

extension PhoneOperatorLabel on PhoneOperator {
  String get label => switch (this) {
        PhoneOperator.telkomsel => 'Telkomsel',
        PhoneOperator.indosat => 'Indosat',
        PhoneOperator.xl => 'XL',
        PhoneOperator.axis => 'AXIS',
        PhoneOperator.three => 'Tri (3)',
        PhoneOperator.smartfren => 'Smartfren',
      };

  // Dipakai buat cocokkin nama operator produk dari katalog (field
  // `operator` di ppob_products, biasanya nama brand dari provider) --
  // matching longgar (contains, case-insensitive) karena penamaan brand
  // suka bervariasi ("Telkomsel", "TELKOMSEL DATA", dst).
  List<String> get matchKeywords => switch (this) {
        PhoneOperator.telkomsel => ['telkomsel', 'simpati', 'as ', 'halo', 'by.u', 'byu'],
        PhoneOperator.indosat => ['indosat', 'im3', 'mentari', 'ooredoo'],
        PhoneOperator.xl => ['xl'],
        PhoneOperator.axis => ['axis'],
        PhoneOperator.three => ['three', 'tri '],
        PhoneOperator.smartfren => ['smartfren', 'smart'],
      };
}

const Map<String, PhoneOperator> _prefixMap = {
  // Telkomsel (+ 0811 by.U/Halo, tidak ada di data sumber asli)
  '0811': PhoneOperator.telkomsel,
  '0812': PhoneOperator.telkomsel,
  '0813': PhoneOperator.telkomsel,
  '0821': PhoneOperator.telkomsel,
  '0822': PhoneOperator.telkomsel,
  '0823': PhoneOperator.telkomsel,
  '0851': PhoneOperator.telkomsel,
  '0852': PhoneOperator.telkomsel,
  '0853': PhoneOperator.telkomsel,
  // Indosat
  '0814': PhoneOperator.indosat,
  '0815': PhoneOperator.indosat,
  '0816': PhoneOperator.indosat,
  '0855': PhoneOperator.indosat,
  '0856': PhoneOperator.indosat,
  '0857': PhoneOperator.indosat,
  '0858': PhoneOperator.indosat,
  // XL
  '0817': PhoneOperator.xl,
  '0818': PhoneOperator.xl,
  '0819': PhoneOperator.xl,
  '0859': PhoneOperator.xl,
  '0877': PhoneOperator.xl,
  '0878': PhoneOperator.xl,
  // AXIS
  '0831': PhoneOperator.axis,
  '0832': PhoneOperator.axis,
  '0837': PhoneOperator.axis,
  '0838': PhoneOperator.axis,
  // Tri (3)
  '0895': PhoneOperator.three,
  '0896': PhoneOperator.three,
  '0897': PhoneOperator.three,
  '0898': PhoneOperator.three,
  '0899': PhoneOperator.three,
  // Smartfren
  '0881': PhoneOperator.smartfren,
  '0882': PhoneOperator.smartfren,
  '0883': PhoneOperator.smartfren,
  '0884': PhoneOperator.smartfren,
  '0885': PhoneOperator.smartfren,
  '0886': PhoneOperator.smartfren,
  '0887': PhoneOperator.smartfren,
  '0888': PhoneOperator.smartfren,
};

/// Normalisasi ke format 08xx (terima juga input +62/62xx).
String normalizePhoneNumber(String raw) {
  var n = raw.trim().replaceAll(RegExp(r'[\s-]'), '');
  if (n.startsWith('+62')) n = '0${n.substring(3)}';
  if (n.startsWith('62')) n = '0${n.substring(2)}';
  return n;
}

/// Return null kalau nomor kurang dari 4 digit atau prefix tidak dikenali.
PhoneOperator? detectOperator(String rawNumber) {
  final n = normalizePhoneNumber(rawNumber);
  if (n.length < 4) return null;
  return _prefixMap[n.substring(0, 4)];
}
