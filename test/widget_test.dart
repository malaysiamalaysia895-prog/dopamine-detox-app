import 'package:flutter_test/flutter_test.dart';
import 'package:dopamine_detox/main.dart';

void main() {
  testWidgets('Gunvanti English anime briefing enters gameplay scene', (tester) async {
    await tester.pumpWidget(const GunvantiGameApp());

    expect(find.text('GUNVANTI'), findsOneWidget);
    expect(find.text('Animated Story Mode'), findsOneWidget);
    expect(find.textContaining('Gunwanti legend in English'), findsOneWidget);

    await tester.tap(find.text('Watch cinematic intro'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gunwanti: Secret Suryavanshi Capital'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mission: Find the 5 Brahm-Mani'), findsOneWidget);
    expect(find.text('Collect Mani'), findsOneWidget);
  });
}
