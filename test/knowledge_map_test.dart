import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallmind/domain.dart';
import 'package:recallmind/knowledge_map.dart';

void main() {
  testWidgets('Map supports selection, orbit, zoom and practice on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StudyCard? practiced;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KnowledgeMap(
              cards: seedCards,
              onPractice: (c) => practiced = c,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Logarithms'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('knowledge-graph')),
      const Offset(80, 30),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate automatically'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Pause rotation'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Practice this concept'));
    await tester.tap(find.text('Practice this concept'));
    expect(practiced?.concept, 'Logarithms');
    expect(tester.takeException(), isNull);
  });

  test('Perspective projection stays finite and changes when orbited', () {
    final a = projectConcepts(8, const Size(390, 360), 0, 0, 1);
    final b = projectConcepts(8, const Size(390, 360), 1, .5, 1);
    expect(a.first.position, isNot(b.first.position));
    expect(
      a.every(
        (p) => p.position.dx.isFinite && p.position.dy.isFinite && p.scale > 0,
      ),
      isTrue,
    );
    expect(projectConcepts(0, const Size(390, 360), 0, 0, 1), isEmpty);
  });
}
