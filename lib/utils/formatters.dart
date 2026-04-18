import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat('#,##0', 'en_KE');
final _dateFormat = DateFormat('EEEE, d MMM yyyy');
final _shortDateFormat = DateFormat('d MMM yyyy');
final _dateIdFormat = DateFormat('yyyy-MM-dd');

String formatCurrency(double amount) {
  return 'KES ${_currencyFormat.format(amount)}';
}

String formatVariance(double variance) {
  if (variance >= 0) {
    return '+KES ${_currencyFormat.format(variance)}';
  } else {
    return '−KES ${_currencyFormat.format(variance.abs())}';
  }
}

String formatWeight(double amount, String productType) {
  if (productType == 'weight') {
    return '${amount.toStringAsFixed(2)} kg';
  } else {
    if (amount == amount.roundToDouble()) {
      return '${amount.toInt()} units';
    }
    return '${amount.toStringAsFixed(1)} units';
  }
}

String formatDate(DateTime date) => _dateFormat.format(date);

String formatShortDate(DateTime date) => _shortDateFormat.format(date);

String dateToId(DateTime date) => _dateIdFormat.format(date);

DateTime idToDate(String id) => _dateIdFormat.parse(id);

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
