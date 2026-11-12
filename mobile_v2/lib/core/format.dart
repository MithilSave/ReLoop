import 'package:intl/intl.dart';

final NumberFormat _nf1 = NumberFormat('#,##,##0.0', 'en_IN');
final NumberFormat _nf0 = NumberFormat('#,##,##0', 'en_IN');
final NumberFormat _inr2 = NumberFormat('#,##,##0.00', 'en_IN');
final DateFormat _dt = DateFormat('d MMM yyyy, hh:mm a');
final DateFormat _d = DateFormat('d MMM yyyy');
final DateFormat _my = DateFormat('MMM yyyy');

bool _ok(double? v) => v != null && v.isFinite;

String kg(double? v) => _ok(v) ? '${_nf1.format(v)} kg' : '—';
String num1(double? v) => _ok(v) ? _nf1.format(v) : '—';
String num0(double? v) => _ok(v) ? _nf0.format(v) : '—';
String pct(double? v) => _ok(v) ? '${((v! * 10).round() / 10).toStringAsFixed(1)}%' : '—';
String inr(double? v, {bool decimals = true}) => _ok(v) ? '₹${(decimals ? _inr2 : _nf0).format(v)}' : '—';

DateTime? parseIso(dynamic iso) {
  if (iso == null) return null;
  final s = iso.toString();
  if (s.isEmpty) return null;
  // The backend may send naive UTC timestamps; treat them as UTC.
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
  final d = DateTime.tryParse(hasZone || !s.contains('T') ? s : '${s}Z');
  return d?.toLocal();
}

String dateTime(dynamic iso) {
  final d = parseIso(iso);
  return d == null ? '—' : _dt.format(d);
}

String date(dynamic iso) {
  final d = parseIso(iso);
  return d == null ? '—' : _d.format(d);
}

String monthYear(DateTime d) => _my.format(d);

/// Local date/time values picked on this device (no time-zone conversion).
String localDate(DateTime d) => _d.format(d);
String localDateTime(DateTime d) => _dt.format(d);

/// "RL-MUM-2026-000123" → "…000123" for dense tables.
String shortCode(String code) => (code.startsWith('RL-') && code.length > 6) ? '…${code.substring(code.length - 6)}' : code;

String humanize(dynamic s) {
  if (s == null) return '—';
  final t = s.toString();
  if (t.isEmpty) return '—';
  final l = t.toLowerCase().replaceAll('_', ' ');
  return l[0].toUpperCase() + l.substring(1);
}

const Map<String, String> kCategoryLabel = {
  'CAT_I': 'Cat I · Rigid',
  'CAT_II': 'Cat II · Flexible',
  'CAT_III': 'Cat III · Multilayer',
  'CAT_IV': 'Cat IV · Compostable',
};
String categoryLabel(dynamic c) => kCategoryLabel[c?.toString()] ?? (c?.toString() ?? '—');

/// Indian financial year, e.g. FY2026-27 (April to March).
String currentReportingPeriod([DateTime? now]) {
  final d = now ?? DateTime.now();
  final y = d.month >= 4 ? d.year : d.year - 1;
  return 'FY$y-${((y + 1) % 100).toString().padLeft(2, '0')}';
}

/// ISO string in UTC for the API.
String toIsoUtc(DateTime d) => d.toUtc().toIso8601String();

final RegExp _kgRe = RegExp(r'^\d+(\.\d{1,3})?$');

/// Validates a positive kilogram amount with up to 3 decimals. Returns an error message or null.
String? kgError(String raw, {String label = 'Quantity', bool allowZero = false}) {
  final v = raw.trim();
  if (v.isEmpty) return 'Enter ${label.toLowerCase()} in kg';
  if (!_kgRe.hasMatch(v)) return 'Use a number with up to 3 decimals';
  if (!allowZero && double.parse(v) <= 0) return 'Must be greater than 0';
  return null;
}

/// CSV text for data already fetched from the API.
String toCsv(List<List<Object?>> rows) {
  return rows.map((r) {
    return r.map((c) {
      final s = c == null ? '' : c.toString();
      return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }).join(',');
  }).join('\n');
}
