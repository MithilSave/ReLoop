// Renders every screen of every role, at phone (390×844) and desktop (1400×900) sizes, against real API
// responses recorded from the seeded backend (test/fixtures/api.json). Fails on any exception during build or
// layout, including overflow and unbounded-constraint errors.
//
// Regenerate the fixtures after backend changes:
//   cd backend && python seed_data.py && python ../mobile_v2/tool/dump_fixtures.py ../mobile_v2/test/fixtures/api.json

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app.dart';
import 'package:mobile/core/api.dart';
import 'package:mobile/core/auth.dart';
import 'package:mobile/core/query.dart';
import 'package:mobile/pages/shared.dart';
import 'package:mobile/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, dynamic> fixtures = jsonDecode(File('test/fixtures/api.json').readAsStringSync()) as Map<String, dynamic>;

// 1×1 transparent PNG for the batch QR endpoint.
final List<int> _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

MockClient clientFor(String role) {
  final fx = fixtures[role] as Map<String, dynamic>;
  return MockClient((req) async {
    final path = req.url.path.replaceFirst('/api/v1', '');
    if (req.url.path == '/health') return http.Response(jsonEncode({'status': 'ok'}), 200);
    if (path.endsWith('/qr')) return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});
    final key = req.url.query.isEmpty ? path : '$path?${req.url.query}';
    final hit = (fx[key] ?? fx[path]) as Map<String, dynamic>?;
    if (hit == null) {
      return http.Response(jsonEncode({'error': {'code': 'NOT_IN_FIXTURE', 'message': 'No recorded response for $key'}}), 404);
    }
    return http.Response(jsonEncode(hit['body']), hit['status'] as int, headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Future<void> openScreen(WidgetTester tester, String role, String path, Size size, {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  Api.client = clientFor(role);
  Api.access = 'test-access';
  Api.refresh = 'test-refresh';
  queryBus.cache.clear();
  auth.me = (fixtures[role]['/auth/me'] as Map<String, dynamic>)['body'] as Map<String, dynamic>;
  auth.status = AuthStatus.authenticated;
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: messengerKey,
    theme: buildTheme(brightness),
    initialRoute: path,
    onGenerateRoute: onGenerateRoute,
    onGenerateInitialRoutes: (name) => [onGenerateRoute(RouteSettings(name: name))],
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

List<String> pathsFor(String role) {
  final out = <String>[
    for (final e in kRoutes.entries)
      if (e.value.roles?.contains(role) ?? false) e.key,
  ];
  if (role != 'admin') out.add('/profile');
  final batches = ((fixtures[role]['/batches'] as Map<String, dynamic>)['body'] as List).cast<Map<String, dynamic>>();
  if (batches.isNotEmpty) out.add('/passport/${batches.first['batch_code']}');
  if (role == 'ngo') {
    final cases = ((fixtures[role]['/ngo/verifications'] as Map<String, dynamic>)['body'] as List).cast<Map<String, dynamic>>();
    if (cases.isNotEmpty) out.add('/n/cases/${cases.first['id']}');
  }
  return out;
}

void main() {
  testWidgets('login screen renders at phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const LoginPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final role in ['generator', 'collector', 'recycler', 'ngo', 'epr', 'admin']) {
    group(role, () {
      for (final path in pathsFor(role)) {
        for (final size in const [Size(390, 844), Size(1400, 900)]) {
          testWidgets('$path at ${size.width.toInt()}px', (tester) async {
            await openScreen(tester, role, path, size);
            expect(tester.takeException(), isNull);
            expect(find.byType(ErrorWidget), findsNothing);
          });
        }
      }
      testWidgets('home screen in dark mode', (tester) async {
        await openScreen(tester, role, pathsFor(role).first, const Size(390, 844), brightness: Brightness.dark);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
