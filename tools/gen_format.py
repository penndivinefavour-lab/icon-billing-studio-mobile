"""Generates lib/core/format.dart - money, dates and text helpers.

Ported from js/utils.js. Money is locale-stable (en-US) so a document prints
the same on every device, matching the web prototype exactly.
"""
from pathlib import Path

CONTENT = r'''library;

/// ICON Billing Studio - formatting helpers.
///
/// Ported from the web prototype's js/utils.js. Money formatting is pinned to
/// en-US so a document renders identically on every device and matches the
/// web prototype byte for byte.

import 'package:intl/intl.dart';

import '../models/models.dart' show round2;

/// Currency code -> symbol. Mirrors CURRENCY_SYMBOLS in utils.js.
const _symbols = <String, String>{
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'NGN': '₦',
  'GHS': '₵',
  'XAF': 'FCFA',
  'ZAR': 'R',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'INR': '₹',
  'JPY': '¥',
  'CHF': 'Fr',
  'KES': 'KSh',
};

String currencySymbol(String code) =>
    _symbols[code.toUpperCase()] ?? code.toUpperCase();

/// "INV-2041" style document number, padded to four digits.
String formatDocNumber(String prefix, int n) {
  final code = prefix.isEmpty ? (prefix.isEmpty ? 'INV' : prefix) : prefix;
  return '$code-${n.toString().padLeft(4, '0')}';
}

/// Money with the document's own currency symbol.
String formatMoney(double value, [String currency = 'USD']) {
  final amount = round2(value);
  final code = currency.toUpperCase();
  final symbol = currencySymbol(code);
  final body = NumberFormat.currency(
    locale: 'en_US',
    symbol: symbol,
    decimalDigits: 2,
  ).format(amount);
  return body;
}

/// Money without a currency symbol, for compact chart labels.
String formatMoneyPlain(double value, [int decimals = 0]) {
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: '',
    decimalDigits: decimals,
  ).format(round2(value));
}

String formatNumber(double value, [int decimals = 0]) =>
    NumberFormat.decimalPatternDigits(
      locale: 'en_US',
      decimalDigits: decimals,
    ).format(value);

String formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// "4 Oct 2026"
String formatDate(DateTime? date, {bool long = false}) {
  if (date == null) return '—';
  final local = date.toLocal();
  if (long) {
    return DateFormat('EEE, d MMMM y', 'en_US').format(local);
  }
  return DateFormat('d MMM y', 'en_US').format(local);
}

/// Plain ISO date used for storage keys and comparisons.
String isoDate(DateTime d) {
  final local = d.toLocal();
  return '${local.year.toString().padLeft(4, '0')}'
      '-${local.month.toString().padLeft(2, '0')}'
      '-${local.day.toString().padLeft(2, '0')}';
}

DateTime? parseIso(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final p = s.trim().split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

DateTime addDays(DateTime d, int days) => d.add(Duration(days: days));

int daysBetween(DateTime a, DateTime b) =>
    DateTime(b.year, b.month, b.day).difference(DateTime(a.year, a.month, a.day)).inDays;

/// Relative due label shown next to a document. null when not applicable.
DueHint? relativeDue(DateTime? dueDate, String status) {
  if (status == 'paid' || status == 'draft' || dueDate == null) return null;
  final diff = daysBetween(DateTime.now(), dueDate);
  if (diff < 0) return DueHint('${-diff}d overdue', DueTone.danger);
  if (diff == 0) return DueHint('Due today', DueTone.warning);
  if (diff <= 7) return DueHint('Due in ${diff}d', DueTone.warning);
  return DueHint('Due in ${diff}d', DueTone.muted);
}

enum DueTone { danger, warning, muted }

class DueHint {
  final String label;
  final DueTone tone;
  const DueHint(this.label, this.tone);
}

/// Truncate long names with an ellipsis.
String clampText(String? s, [int n = 40]) {
  final v = (s ?? '').trim();
  return v.length > n ? '${v.substring(0, n - 1)}…' : v;
}

/// Two-letter avatar mark.
String initials(String? name) {
  final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return words
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
}

/// Filesystem-safe token for generated file names: "Adiba Njoh" -> "Adiba-Njoh".
String slugify(String? s, [int max = 32]) {
  final raw = (s ?? '').trim();
  if (raw.isEmpty) return 'Document';
  final cleaned = raw
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  final out = cleaned.isEmpty ? 'Document' : cleaned;
  return out.length > max ? out.substring(0, max) : out;
}

/// "INV-2041-Adiba-Njoh.pdf"
String pdfFileName(String number, String clientName, bool isQuotation) {
  final prefix = isQuotation ? 'QUO' : 'INV';
  return '$prefix-${number.replaceAll(RegExp(r'^[A-Z]+-'), '')}'
      '-${slugify(clientName)}.pdf';
}
'''


def main() -> None:
    p = Path('lib/core/format.dart')
    p.write_text(CONTENT, encoding='utf-8')
    back = p.read_text(encoding='utf-8')
    if back != CONTENT:
        raise SystemExit('read-back mismatch')
    print('OK lib/core/format.dart (%d chars)' % len(CONTENT))


if __name__ == '__main__':
    main()
