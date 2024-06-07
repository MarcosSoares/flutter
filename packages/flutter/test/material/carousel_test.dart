// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CarouselView defaults', (WidgetTester tester) async {
    final ThemeData theme = ThemeData();
    final ColorScheme colorScheme = theme.colorScheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CarouselView(
            itemExtent: 200,
            children: List<Widget>.generate(10, (int index) {
              return Center(child: Text('Item $index'));
            }),
          ),
        ),
      ),
    );

    final Finder carouselViewMaterial = find.descendant(
      of: find.byType(CarouselView),
      matching: find.byType(Material),
    ).first;

    final Material material = tester.widget<Material>(carouselViewMaterial);
    expect(material.clipBehavior, Clip.antiAlias);
    expect(material.color, colorScheme.surface);
    expect(material.elevation, 0.0);
    expect(material.shape, const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28.0))
    ));
  });

  testWidgets('CarouselView items customization', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    final ThemeData theme = ThemeData();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CarouselView(
            padding: const EdgeInsets.all(20.0),
            backgroundColor: Colors.amber,
            elevation: 10.0,
            shape: const StadiumBorder(),
            overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.yellow;
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.red;
              }
              if (states.contains(WidgetState.focused)) {
                return Colors.purple;
              }
              return null;
            }),
            itemExtent: 200,
            children: List<Widget>.generate(10, (int index) {
              if (index == 0) {
                return Center(
                  key: key,
                  child: Center(child: Text('Item $index')),
                );
              }
              return Center(child: Text('Item $index'));
            }),
          ),
        ),
      ),
    );

    final Finder carouselViewMaterial = find.descendant(
      of: find.byType(CarouselView),
      matching: find.byType(Material),
    ).first;

    expect(tester.getSize(carouselViewMaterial).width, 200 - 20 - 20); // Padding is 20 on both side.
    final Material material = tester.widget<Material>(carouselViewMaterial);
    expect(material.color, Colors.amber);
    expect(material.elevation, 10.0);
    expect(material.shape, const StadiumBorder());

    RenderObject inkFeatures = tester.allRenderObjects.firstWhere((RenderObject object) => object.runtimeType.toString() == '_RenderInkFeatures');

    // On hovered.
    final TestGesture gesture = await _pointGestureToCarouselItem(tester, key);
    await tester.pumpAndSettle();
    expect(inkFeatures, paints..rect(color: Colors.red.withOpacity(1.0)));

    // On pressed.
    await tester.pumpAndSettle();
    await gesture.down(tester.getCenter(find.byKey(key)));
    await tester.pumpAndSettle();
    inkFeatures = tester.allRenderObjects.firstWhere((RenderObject object) => object.runtimeType.toString() == '_RenderInkFeatures');
    expect(inkFeatures, paints..rect()..rect(color: Colors.yellow.withOpacity(1.0)));

    await tester.pumpAndSettle();
    await gesture.up();
    await gesture.removePointer();

    // On focused.
    final Element inkWellElement = tester.element(find.descendant(of: carouselViewMaterial, matching: find.byType(InkWell)));
    expect(inkWellElement.widget, isA<InkWell>());
    final InkWell inkWell = inkWellElement.widget as InkWell;

    const MaterialState state = MaterialState.focused;

    // Check overlay color in focused state
    expect(inkWell.overlayColor?.resolve(<WidgetState>{state}), Colors.purple);
  });

  testWidgets('CarouselView respect onTap', (WidgetTester tester) async {
    final List<GlobalKey> keys = List<GlobalKey>.generate(10, (_) => GlobalKey());
    final ThemeData theme = ThemeData();
    int tapIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CarouselView(
            itemExtent: 50,
            onTap: (int index) {
              tapIndex = index;
            },
            children: List<Widget>.generate(10, (int index) {
              return Center(
                key: keys.elementAt(index),
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      ),
    );

    final Finder item1 = find.byKey(keys.elementAt(1));
    await tester.tap(find.ancestor(of: item1, matching: find.byType(Stack)));
    await tester.pump();
    expect(tapIndex, 1);

    final Finder item2 = find.byKey(keys.elementAt(2));
    await tester.tap(find.ancestor(of: item2, matching: find.byType(Stack)));
    await tester.pump();
    expect(tapIndex, 2);
  });

  testWidgets('CarouselView layout (Uncontained layout)', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            itemExtent: 250,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    final Size viewportSize = MediaQuery.sizeOf(tester.element(find.byType(CarouselView)));
    expect(viewportSize, const Size(800, 600));

    expect(find.text('Item 0'), findsOneWidget);
    final Rect rect0 = tester.getRect(getItem(0));
    expect(rect0, const Rect.fromLTRB(0.0, 0.0, 250.0, 600.0));

    expect(find.text('Item 1'), findsOneWidget);
    final Rect rect1 = tester.getRect(getItem(1));
    expect(rect1, const Rect.fromLTRB(250.0, 0.0, 500.0, 600.0));

    expect(find.text('Item 2'), findsOneWidget);
    final Rect rect2 = tester.getRect(getItem(2));
    expect(rect2, const Rect.fromLTRB(500.0, 0.0, 750.0, 600.0));

    expect(find.text('Item 3'), findsOneWidget);
    final Rect rect3 = tester.getRect(getItem(3));
    expect(rect3, const Rect.fromLTRB(750.0, 0.0, 800.0, 600.0));

    expect(find.text('Item 4'), findsNothing);
  });

  testWidgets('CarouselView.weighted layout', (WidgetTester tester) async {
    Widget buildCarouselView({ required List<int> weights }) {
      return MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            layoutWeights: weights,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCarouselView(weights: <int>[4,3,2,1]));

    final Size viewportSize = MediaQuery.of(tester.element(find.byType(CarouselView))).size;
    expect(viewportSize, const Size(800, 600));

    expect(find.text('Item 0'), findsOneWidget);
    Rect rect0 = tester.getRect(getItem(0));
    // Item width is 4/10 of the viewport.
    expect(rect0, const Rect.fromLTRB(0.0, 0.0, 320.0, 600.0));

    expect(find.text('Item 1'), findsOneWidget);
    Rect rect1 = tester.getRect(getItem(1));
    // Item width is 3/10 of the viewport.
    expect(rect1, const Rect.fromLTRB(320.0, 0.0, 560.0, 600.0));

    expect(find.text('Item 2'), findsOneWidget);
    final Rect rect2 = tester.getRect(getItem(2));
    // Item width is 2/10 of the viewport.
    expect(rect2, const Rect.fromLTRB(560.0, 0.0, 720.0, 600.0));

    expect(find.text('Item 3'), findsOneWidget);
    final Rect rect3 = tester.getRect(getItem(3));
    // Item width is 1/10 of the viewport.
    expect(rect3, const Rect.fromLTRB(720.0, 0.0, 800.0, 600.0));

    expect(find.text('Item 4'), findsNothing);

    // Test shorter weight list.
    await tester.pumpWidget(buildCarouselView(weights: <int>[7,1]));
    await tester.pumpAndSettle();
    expect(viewportSize, const Size(800, 600));

    expect(find.text('Item 0'), findsOneWidget);
    rect0 = tester.getRect(getItem(0));
    // Item width is 7/8 of the viewport.
    expect(rect0, const Rect.fromLTRB(0.0, 0.0, 700.0, 600.0));

    expect(find.text('Item 1'), findsOneWidget);
    rect1 = tester.getRect(getItem(1));
    // Item width is 1/8 of the viewport.
    expect(rect1, const Rect.fromLTRB(700.0, 0.0, 800.0, 600.0));

    expect(find.text('Item 2'), findsNothing);
  });

  testWidgets('CarouselController initialItem', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            controller: CarouselController(initialItem: 5),
            itemExtent: 400,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    final Size viewportSize = MediaQuery.sizeOf(tester.element(find.byType(CarouselView)));
    expect(viewportSize, const Size(800, 600));

    expect(find.text('Item 5'), findsOneWidget);
    final Rect rect5 = tester.getRect(getItem(5));
    // Item width is 400.
    expect(rect5, const Rect.fromLTRB(0.0, 0.0, 400.0, 600.0));

    expect(find.text('Item 6'), findsOneWidget);
    final Rect rect6 = tester.getRect(getItem(6));
    // Item width is 400.
    expect(rect6, const Rect.fromLTRB(400.0, 0.0, 800.0, 600.0));

    expect(find.text('Item 4'), findsNothing);
    expect(find.text('Item 7'), findsNothing);
  });

  testWidgets('CarouselView.weighted respects CarouselController.initialItem', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            controller: CarouselController(initialItem: 5),
            layoutWeights: const <int>[7,1],
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    final Size viewportSize = MediaQuery.of(tester.element(find.byType(CarouselView))).size;
    expect(viewportSize, const Size(800, 600));

    expect(find.text('Item 5'), findsOneWidget);
    final Rect rect5 = tester.getRect(getItem(5));
    // Item width is 7/8 of the viewport.
    expect(rect5, const Rect.fromLTRB(0.0, 0.0, 700.0, 600.0));

    expect(find.text('Item 6'), findsOneWidget);
    final Rect rect6 = tester.getRect(getItem(6));
    // Item width is 1/8 of the viewport.
    expect(rect6, const Rect.fromLTRB(700.0, 0.0, 800.0, 600.0));

    expect(find.text('Item 4'), findsNothing);
    expect(find.text('Item 7'), findsNothing);
  });

  testWidgets('The initialItem should be the first item with expanded size(max extent)', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            controller: CarouselController(initialItem: 5),
            layoutWeights: const <int>[1,8,1],
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    final Size viewportSize = MediaQuery.of(tester.element(find.byType(CarouselView))).size;
    expect(viewportSize, const Size(800, 600));

    // Item 5 should have be the expanded item.
    expect(find.text('Item 5'), findsOneWidget);
    final Rect rect5 = tester.getRect(getItem(5));
    // Item width is 8/10 of the viewport.
    expect(rect5, const Rect.fromLTRB(80.0, 0.0, 720.0, 600.0));

    expect(find.text('Item 6'), findsOneWidget);
    final Rect rect6 = tester.getRect(getItem(6));
    // Item width is 1/10 of the viewport.
    expect(rect6, const Rect.fromLTRB(720.0, 0.0, 800.0, 600.0));

    expect(find.text('Item 4'), findsOneWidget);
    final Rect rect4 = tester.getRect(getItem(4));
    // Item width is 1/10 of the viewport.
    expect(rect4, const Rect.fromLTRB(0.0, 0.0, 80.0, 600.0));

    expect(find.text('Item 7'), findsNothing);
  });

  testWidgets('Carousel respects itemSnapping', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            itemSnapping: true,
            itemExtent: 300,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    void checkOriginalExpectations() {
      expect(getItem(0), findsOneWidget);
      expect(getItem(1), findsOneWidget);
      expect(getItem(2), findsOneWidget);
      expect(getItem(3), findsNothing);
    }

    checkOriginalExpectations();

    // Snap back to the original item.
    await tester.drag(getItem(0), const Offset(-150, 0));
    await tester.pumpAndSettle();

    checkOriginalExpectations();

    // Snap back to the original item.
    await tester.drag(getItem(0), const Offset(100, 0));
    await tester.pumpAndSettle();

    checkOriginalExpectations();

    // Snap to the next item.
    await tester.drag(getItem(0), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(getItem(0), findsNothing);
    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsOneWidget);
  });

  testWidgets('Carousel.weighted respects itemSnapping', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            itemSnapping: true,
            allowFullyExpand: false,
            layoutWeights: const <int>[1,7],
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    void checkOriginalExpectations() {
      expect(getItem(0), findsOneWidget);
      expect(getItem(1), findsOneWidget);
      expect(getItem(2), findsNothing);
    }

    checkOriginalExpectations();

    // Snap back to the original item.
    await tester.drag(getItem(0), const Offset(-20, 0));
    await tester.pumpAndSettle();

    checkOriginalExpectations();

    // Snap back to the original item.
    await tester.drag(getItem(0), const Offset(50, 0));
    await tester.pumpAndSettle();

    checkOriginalExpectations();

    // Snap to the next item.
    await tester.drag(getItem(0), const Offset(-70, 0));
    await tester.pumpAndSettle();

    expect(getItem(0), findsNothing);
    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsNothing);
  });

  testWidgets('Carousel respect itemSnapping when fling', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            itemSnapping: true,
            itemExtent: 300,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    // Show item 0, 1, and 2.
    expect(getItem(0), findsOneWidget);
    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsNothing);

    // Snap to the next item. Show item 1, 2 and 3.
    await tester.fling(getItem(0), const Offset(-100, 0), 800);
    await tester.pumpAndSettle();

    expect(getItem(0), findsNothing);
    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsOneWidget);
    expect(getItem(4), findsNothing);

    // Snap to the next item. Show item 2, 3 and 4.
    await tester.fling(getItem(1), const Offset(-100, 0), 800);
    await tester.pumpAndSettle();

    expect(getItem(0), findsNothing);
    expect(getItem(1), findsNothing);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsOneWidget);
    expect(getItem(4), findsOneWidget);
    expect(getItem(5), findsNothing);

    // Fling back to the previous item. Show item 1, 2 and 3.
    await tester.fling(getItem(2), const Offset(100, 0), 800);
    await tester.pumpAndSettle();

    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsOneWidget);
    expect(getItem(4), findsNothing);
  });

  testWidgets('Carousel.weighted respect itemSnapping when fling', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            itemSnapping: true,
            allowFullyExpand: false,
            layoutWeights: const <int>[1,8,1],
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('$index'),
              );
            }),
          ),
        ),
      )
    );
    await tester.pumpAndSettle();

    // Show item 0, 1, and 2.
    expect(getItem(0), findsOneWidget);
    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsNothing);

    // Should snap to item 2 because of a long drag(-100). Show item 2, 3 and 4.
    await tester.fling(getItem(0), const Offset(-100, 0), 800);
    await tester.pumpAndSettle();

    expect(getItem(0), findsNothing);
    expect(getItem(1), findsNothing);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsOneWidget);
    expect(getItem(4), findsOneWidget);

    // Fling to the next item (item 3). Show item 3, 4 and 5.
    await tester.fling(getItem(2), const Offset(-50, 0), 800);
    await tester.pumpAndSettle();

    expect(getItem(2), findsNothing);
    expect(getItem(3), findsOneWidget);
    expect(getItem(4), findsOneWidget);
    expect(getItem(5), findsOneWidget);

    // Fling back to the previous item. Show item 2, 3 and 4.
    await tester.fling(getItem(3), const Offset(50, 0), 800);
    await tester.pumpAndSettle();

    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsOneWidget);
    expect(getItem(4), findsOneWidget);
    expect(getItem(5), findsNothing);
  });

  testWidgets('CarouselView respects scrollingDirection: Axis.vertical', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            itemExtent: 200,
            padding: EdgeInsets.zero,
            scrollDirection: Axis.vertical,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );
    await tester.pumpAndSettle();

    expect(getItem(0), findsOneWidget);
    expect(getItem(1), findsOneWidget);
    expect(getItem(2), findsOneWidget);
    expect(getItem(3), findsNothing);
    final Rect rect0 = tester.getRect(getItem(0));
    // Item width is 200 of the viewport.
    expect(rect0, const Rect.fromLTRB(0.0, 0.0, 800.0, 200.0));

    // Simulate a scroll up
    await tester.drag(find.byType(CarouselView), const Offset(0, -200), kind: PointerDeviceKind.trackpad);
    await tester.pumpAndSettle();
    expect(getItem(0), findsNothing);
    expect(getItem(3), findsOneWidget);
  });

  testWidgets('Carousel respects reverse', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            itemExtent: 200,
            reverse: true,
            padding: EdgeInsets.zero,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );
    await tester.pumpAndSettle();

    expect(getItem(0), findsOneWidget);
    final Rect rect0 = tester.getRect(getItem(0));
    // Item 0 should be placed on the end of the screen.
    expect(rect0, const Rect.fromLTRB(600.0, 0.0, 800.0, 600.0));

    expect(getItem(1), findsOneWidget);
    final Rect rect1 = tester.getRect(getItem(1));
    // Item 1 should be placed before item 0.
    expect(rect1, const Rect.fromLTRB(400.0, 0.0, 600.0, 600.0));

    expect(getItem(2), findsOneWidget);
    final Rect rect2 = tester.getRect(getItem(2));
    // Item 2 should be placed before item 1.
    expect(rect2, const Rect.fromLTRB(200.0, 0.0, 400.0, 600.0));

    expect(getItem(3), findsOneWidget);
    final Rect rect3 = tester.getRect(getItem(3));
    // Item 3 should be placed before item 2.
    expect(rect3, const Rect.fromLTRB(0.0, 0.0, 200.0, 600.0));
  });

  testWidgets('Carousel respects shrinkExtent', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView(
            itemExtent: 350,
            shrinkExtent: 300,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );
    await tester.pumpAndSettle();

    final Rect rect0 = tester.getRect(getItem(0));
    expect(rect0, const Rect.fromLTRB(0.0, 0.0, 350.0, 600.0));

    final Rect rect1 = tester.getRect(getItem(1));
    expect(rect1, const Rect.fromLTRB(350.0, 0.0, 700.0, 600.0));

    final Rect rect2 = tester.getRect(getItem(2));
    // The extent of item 2 is 300, and only 100 is on screen.
    expect(rect2, const Rect.fromLTRB(700.0, 0.0, 1000.0, 600.0));

    await tester.drag(find.byType(CarouselView), const Offset(-50, 0), kind: PointerDeviceKind.trackpad);
    await tester.pump();
    // The item 0 should be pinned and has a size change from 350 to 50.
    expect(tester.getRect(getItem(0)), const Rect.fromLTRB(0.0, 0.0, 300.0, 600.0));
    // Keep dragging to left, extent of item 0 won't change (still 300) and part of item 0 will
    // be off screen.
    await tester.drag(find.byType(CarouselView), const Offset(-50, 0), kind: PointerDeviceKind.trackpad);
    await tester.pump();
    expect(tester.getRect(getItem(0)), const Rect.fromLTRB(-50, 0.0, 250, 600));
  });

  testWidgets('CarouselView.weighted respects allowFullyExpand', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            layoutWeights: const <int>[1,2,4,2,1],
            itemSnapping: true,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );

    // The initial item is item 0. To make sure the layout stays the same, the
    // first item should be placed at the middle of the screen and there are some
    // white space as if there are two more shinked items before the first item.
    final Rect rect0 = tester.getRect(getItem(0));
    expect(rect0, const Rect.fromLTRB(240.0, 0.0, 560.0, 600.0));

    for (int i = 0; i < 7; i++) {
      await tester.drag(find.byType(CarouselView), const Offset(-80.0, 0.0));
      await tester.pumpAndSettle();
    }

    // After scrolling the carousel 7 times, the last item(item 9) should be on
    // the end of the screen.
    expect(getItem(9), findsOneWidget);
    expect(tester.getRect(getItem(9)), const Rect.fromLTRB(720.0, 0.0, 800.0, 600.0));

    // Keep snapping twice. Item 9 should be fully expanded to the max size.
    for (int i = 0; i < 2; i++) {
      await tester.drag(find.byType(CarouselView), const Offset(-80.0, 0.0));
      await tester.pumpAndSettle();
    }
    expect(getItem(9), findsOneWidget);
    expect(tester.getRect(getItem(9)), const Rect.fromLTRB(240.0, 0.0, 560.0, 600.0));
  });

  testWidgets('While scrolling, one more item will show at the end of the screen during items transition', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselView.weighted(
            layoutWeights: const <int>[1,2,4,2,1],
            allowFullyExpand: false,
            children: List<Widget>.generate(10, (int index) {
              return Center(
                child: Text('Item $index'),
              );
            }),
          ),
        ),
      )
    );
    await tester.pumpAndSettle();

    for (int i = 0; i < 5; i++) {
      expect(getItem(i), findsOneWidget);
    }

    // Drag the first item to the middle. So the progress for the first item size change
    // is 50%, original width is 80.
    await tester.drag(getItem(0), const Offset(-40.0, 0.0), kind: PointerDeviceKind.trackpad);
    await tester.pump();
    expect(tester.getRect(getItem(0)).width, 40.0);

    // The size of item 1 is changing to the size of item 0, so the size of item 1
    // now should be item1.originalExtent - 50% * (item1.extent - item0.extent).
    // Item1 originally should be 2/(1+2+4+2+1) * 800 = 160.0.
    expect(tester.getRect(getItem(1)).width, 160 - 0.5 * (160 - 80));

    // The extent of item 2 should be: item2.originalExtent - 50% * (item2.extent - item1.extent).
    // the extent of item 2 originally should be 4/(1+2+4+2+1) * 800 = 320.0.
    expect(tester.getRect(getItem(2)).width, 320 - 0.5 * (320 - 160));

    // The extent of item 3 should be: item3.originalExtent + 50% * (item2.extent - item3.extent).
    // the extent of item 3 originally should be 2/(1+2+4+2+1) * 800 = 160.0.
    expect(tester.getRect(getItem(3)).width, 160 + 0.5 * (320 - 160));

    // The extent of item 4 should be: item4.originalExtent + 50% * (item3.extent - item4.extent).
    // the extent of item 4 originally should be 1/(1+2+4+2+1) * 800 = 80.0.
    expect(tester.getRect(getItem(4)).width, 80 + 0.5 * (160 - 80));

    // The sum of the first 5 items during transition is less than the screen width.
    double sum = 0;
    for (int i = 0; i < 5; i++) {
      sum += tester.getRect(getItem(i)).width;
    }
    expect(sum, lessThan(MediaQuery.of(tester.element(find.byType(CarouselView))).size.width));
    final double difference = MediaQuery.of(tester.element(find.byType(CarouselView))).size.width - sum;

    // One more item should show on screen to fill the rest of the viewport.
    expect(getItem(5), findsOneWidget);
    expect(tester.getRect(getItem(5)).width, difference);
  });
}

Finder getItem(int index) {
  return find.descendant(of: find.byType(CarouselView), matching: find.ancestor(of: find.text('Item $index'), matching: find.byType(Padding)));
}

Future<TestGesture> _pointGestureToCarouselItem(WidgetTester tester, GlobalKey key) async {
  final Offset center = tester.getCenter(find.byKey(key));
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );

  // On hovered.
  await gesture.addPointer();
  await gesture.moveTo(center);
  return gesture;
}
