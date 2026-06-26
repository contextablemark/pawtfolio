import 'package:flutter_test/flutter_test.dart';
import 'package:pawtfolio/app.dart';

void main() {
  testWidgets('app builds and shows the header + empty state', (tester) async {
    // No backend in the test env, so the pet name falls back to "your pet".
    await tester.pumpWidget(const PawtfolioApp());
    expect(find.text('Pawtfolio'), findsOneWidget);
    expect(find.text("Ask about your pet's spending"), findsOneWidget);
  });
}
