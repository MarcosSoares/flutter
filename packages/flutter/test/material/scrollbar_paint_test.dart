// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import '../rendering/mock_canvas.dart';

Widget _buildSingleChildScrollViewWithScrollbar({
  TextDirection textDirection = TextDirection.ltr,
  EdgeInsets padding = EdgeInsets.zero,
  Widget child}
) {
  return Directionality(
    textDirection: textDirection,
    child: MediaQuery(
      data: MediaQueryData(padding: padding),
      child: Scrollbar(
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('Viewport basic test (LTR)', (WidgetTester tester) async {
    await tester.pumpWidget(_buildSingleChildScrollViewWithScrollbar(
      child: const SizedBox(width: 4000.0, height: 4000.0),
    ));
    expect(find.byType(Scrollbar), isNot(paints..rect()));
    await tester.fling(find.byType(SingleChildScrollView), const Offset(0.0, -10.0), 10.0);
    expect(find.byType(Scrollbar), paints..rect(rect: const Rect.fromLTRB(800.0 - 6.0, 1.5, 800.0, 91.5)));
  });

  testWidgets('Viewport basic test (RTL)', (WidgetTester tester) async {
    await tester.pumpWidget(_buildSingleChildScrollViewWithScrollbar(
      textDirection: TextDirection.rtl,
      child: const SizedBox(width: 4000.0, height: 4000.0),
    ));
    expect(find.byType(Scrollbar), isNot(paints..rect()));
    await tester.fling(find.byType(SingleChildScrollView), const Offset(0.0, -10.0), 10.0);
    expect(find.byType(Scrollbar), paints..rect(rect: const Rect.fromLTRB(0.0, 1.5, 6.0, 91.5)));
  });

  testWidgets('workds with MaterialApp and Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.fromLTRB(0, 20, 0, 34)
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Title')),
          body: Scrollbar(
            child: ListView(
              children: const <Widget>[SizedBox(width: 4000, height: 4000)]
            ),
          ),
        ),
      ),
    ));

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    // On Android it should not overscroll.
    await gesture.moveBy(const Offset(0, 100));
    // Trigger fade in animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Scrollbar), paints..rect(
      rect: const Rect.fromLTWH(
        800.0 - 6, // screen width - thickness
        0,         // the paint area starts from the bottom of the app bar
        6,         // thickness
        // 56 being the height of the app bar
        (600.0 - 56 - 34 - 20) / 4000 * (600 - 56 - 34 - 20),
      ),
    ));
  });
}
