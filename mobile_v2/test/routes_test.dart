import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/core/roles.dart';

void main() {
  test('every navigation item has a route, restricted to its role', () {
    kNav.forEach((role, groups) {
      for (final g in groups) {
        for (final it in g.items) {
          final def = kRoutes[it.to];
          expect(def, isNotNull, reason: '${it.to} has no route');
          expect(def!.roles, contains(role));
        }
      }
    });
  });

  test('no workspace screen exists without a navigation item (profile is in the account menu)', () {
    final navCount = kNav.values.expand((g) => g).expand((g) => g.items).length;
    expect(kRoutes.length, navCount + 1);
  });
}
