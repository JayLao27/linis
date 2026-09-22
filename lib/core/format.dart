import 'package:intl/intl.dart';

final NumberFormat _peso =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

String peso(num amount) => _peso.format(amount);

String pesoRange(num min, num max) =>
    min == max ? peso(min) : '${peso(min)} – ${peso(max)}';

String formatDate(DateTime d) => DateFormat('EEE, MMM d, yyyy').format(d);

String formatShortDate(DateTime d) => DateFormat('MMM d').format(d);

String formatDateTime(DateTime d) => DateFormat('MMM d, h:mm a').format(d);

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatShortDate(d);
}
