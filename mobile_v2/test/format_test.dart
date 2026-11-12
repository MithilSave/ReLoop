import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format.dart';

void main() {
  group('format', () {
    test('kilograms use Indian digit grouping and one decimal', () {
      expect(kg(123456.78), '1,23,456.8 kg');
      expect(kg(null), '—');
    });
    test('reporting period follows the Indian financial year', () {
      expect(currentReportingPeriod(DateTime(2026, 11, 12)), 'FY2026-27');
      expect(currentReportingPeriod(DateTime(2027, 3, 31)), 'FY2026-27');
      expect(currentReportingPeriod(DateTime(2027, 4, 1)), 'FY2027-28');
    });
    test('kg validation allows up to three decimals', () {
      expect(kgError('12.345'), isNull);
      expect(kgError('12.3456'), isNotNull);
      expect(kgError('0'), isNotNull);
      expect(kgError('0', allowZero: true), isNull);
      expect(kgError(''), isNotNull);
    });
    test('CSV escapes commas, quotes and newlines', () {
      expect(toCsv([
        ['a', 'b,c'],
        ['say "hi"', null],
      ]), 'a,"b,c"\n"say ""hi""",');
    });
    test('short batch codes keep the last six characters', () {
      expect(shortCode('RL-MUM-2026-000105'), '…000105');
      expect(humanize('REQUIRES_CORRECTION'), 'Requires correction');
    });
  });
}
