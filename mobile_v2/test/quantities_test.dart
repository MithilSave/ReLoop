import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/quantities.dart';

// Same cases as the web app's lib/quantities.test.ts.
const Map<String, dynamic> base = {
  'estimated_kg': '100.000',
  'collected_kg': null,
  'received_kg': null,
  'accepted_kg': null,
  'rejected_kg': null,
  'processed_kg': null,
  'ngo_verified_kg': null,
  'epr_allocated_kg': null,
};

void main() {
  group('quantities', () {
    test('parses backend strings and nulls', () {
      expect(q('12.500'), 12.5);
      expect(q(null), isNull);
      expect(q('abc'), isNull);
      expect(q(7), 7.0);
    });

    test('takes processing input from trace and recovered output from processed_kg', () {
      final quantities = {...base, 'collected_kg': '98.000', 'received_kg': '97.000', 'accepted_kg': '90.000', 'rejected_kg': '7.000', 'processed_kg': '81.000'};
      final trace = {
        'processing_runs': [
          {'record_code': 'PR', 'run_started_at': '', 'input_kg': 90, 'apportioned_output_kg': 81, 'yield_pct': 90, 'measurement_status': 'COMPLETE'},
        ],
      };
      final s = physicalStages(quantities, trace: trace);
      expect(s.firstWhere((x) => x.key == 'input').value, 90);
      expect(s.firstWhere((x) => x.key == 'output').value, 81);
      expect(s.map((x) => x.key).toList(), ['listed', 'collected', 'received', 'accepted', 'input', 'output']);
    });

    test('processing input is unknown without a trace, never taken from processed_kg', () {
      final s = physicalStages({...base, 'processed_kg': '81.000'});
      expect(s.firstWhere((x) => x.key == 'input').value, isNull);
    });

    test('never shows the backend fallback as NGO-verified kg', () {
      final quantities = {...base, 'accepted_kg': '90.000', 'ngo_verified_kg': '90.000'};
      expect(verifiedKg(quantities, 'VERIFIED'), isNull); // no measured output yet
      expect(verifiedKg({...quantities, 'processed_kg': '80.000', 'ngo_verified_kg': '80.000'}, 'VERIFIED'), 80);
      expect(verifiedKg({...quantities, 'processed_kg': '80.000', 'ngo_verified_kg': '80.000'}, 'FLAGGED'), isNull);
    });

    test('enforces accepted + rejected = received', () {
      expect(receiptBalances(148.5, 143.5, 5), isTrue);
      expect(receiptBalances(148.5, 140, 5), isFalse);
    });

    test('flags variances outside tolerance', () {
      final v = variances({...base, 'collected_kg': '125.000', 'received_kg': '120.000'});
      expect(v[0].outOfTolerance, isTrue); // +25% vs estimate
      expect(v[1].outOfTolerance, isTrue); // -4% transit
      final ok = variances({...base, 'collected_kg': '110.000', 'received_kg': '109.000'});
      expect(ok[0].outOfTolerance, isFalse);
      expect(ok[1].outOfTolerance, isFalse);
    });

    test('marks collected as provisional until the generator confirms', () {
      final s = physicalStages({...base, 'collected_kg': '99.000'}, pickupConfirmed: false);
      expect(s[1].provisional, isTrue);
      expect(physicalStages({...base, 'collected_kg': '99.000'}, pickupConfirmed: true)[1].provisional, isFalse);
    });

    test('derives the consignment status from its batches', () {
      expect(consStatus({'status': 'ARRIVED', 'items': [{'status': 'RECEIVED'}, {'status': 'PROCESSED'}]}), 'RECEIVED');
      expect(consStatus({'status': 'ARRIVED', 'items': [{'status': 'IN_TRANSIT'}]}), 'ARRIVED');
      expect(consStatus({'status': 'IN_TRANSIT', 'items': [{'status': 'IN_TRANSIT'}]}), 'IN_TRANSIT');
    });

    test('awaiting confirmation means weighed but still assigned', () {
      expect(awaitingConfirmation({'status': 'ASSIGNED', 'quantities': {...base, 'collected_kg': '99.000'}}), isTrue);
      expect(awaitingConfirmation({'status': 'ASSIGNED', 'quantities': base}), isFalse);
      expect(awaitingConfirmation({'status': 'PICKED_UP', 'quantities': {...base, 'collected_kg': '99.000'}}), isFalse);
    });
  });
}
