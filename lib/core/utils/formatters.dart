import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String rupiah(num value) => _rupiah.format(value);

  static final DateFormat _shortDate = DateFormat('d MMM yyyy', 'id_ID');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _time = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _dayLabel = DateFormat('EEE', 'id_ID');

  static String date(DateTime dt) => _shortDate.format(dt.toLocal());
  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());
  static String time(DateTime dt) => _time.format(dt.toLocal());
  static String dayLabel(DateTime dt) => _dayLabel.format(dt.toLocal());
}
