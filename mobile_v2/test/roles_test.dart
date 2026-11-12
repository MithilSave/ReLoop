import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/roles.dart';

Map<String, dynamic> me(String orgType, {bool admin = false}) => {
      'user': {'id': '1', 'full_name': 'x', 'is_platform_admin': admin},
      'active_org': {'id': 'o', 'org_type': orgType, 'legal_name': 'L'},
    };

void main() {
  group('roleOf', () {
    test('maps org types', () {
      expect(roleOf(me('EPR_CLIENT')), 'epr');
      expect(roleOf(me('NGO')), 'ngo');
      expect(roleOf(me('GENERATOR')), 'generator');
    });
    test('treats platform admin as admin even though the seeded admin org is NGO-typed', () {
      expect(roleOf(me('NGO', admin: true)), 'admin');
    });
    test('every role has a home screen and navigation', () {
      for (final r in kRoleLabel.keys) {
        expect(kBase[r], isNotNull);
        expect(kNav[r], isNotEmpty);
      }
      expect(kMobileFirst, ['generator', 'collector', 'recycler']);
    });
  });
}
