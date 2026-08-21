import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_pro/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    // Formatters pakai locale 'id_ID' - harus di-init dulu sebelum dipakai,
    // sama seperti yang dilakukan main.dart saat app benar-benar jalan.
    await initializeDateFormatting('id_ID', null);
  });

  group('Formatters.rupiah', () {
    test('format angka positif dengan simbol Rp dan pemisah ribuan', () {
      final result = Formatters.rupiah(15000);
      expect(result, contains('Rp'));
      expect(result, contains('15.000'));
    });

    test('format nol', () {
      final result = Formatters.rupiah(0);
      expect(result, contains('Rp'));
      expect(result, contains('0'));
    });

    test('tidak menampilkan angka desimal (decimalDigits: 0)', () {
      final result = Formatters.rupiah(1234567);
      expect(result, isNot(contains(',')));
    });
  });

  group('Formatters.date & dateTime', () {
    test('date menghasilkan string non-kosong untuk tanggal valid', () {
      final result = Formatters.date(DateTime(2026, 8, 21));
      expect(result, isNotEmpty);
      expect(result, contains('2026'));
    });

    test('dateTime menyertakan jam:menit', () {
      final result = Formatters.dateTime(DateTime(2026, 8, 21, 14, 30));
      expect(result, contains('14:30'));
    });

    test('time cuma jam:menit', () {
      final result = Formatters.time(DateTime(2026, 8, 21, 9, 5));
      expect(result, '09:05');
    });
  });
}
