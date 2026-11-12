import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/app_state.dart';

void main() {
  testWidgets('ReLoopApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
        ],
        child: const ReLoopApp(),
      ),
    );

    // Verify ReLoop app header is rendered
    expect(find.text('ReLoop'), findsOneWidget);
  });
}
