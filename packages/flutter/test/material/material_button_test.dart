// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';

void main() {
  testWidgets('Default MaterialButton meets a11y contrast guidelines', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MaterialButton(
              child: const Text('MaterialButton'),
              onPressed: () { },
            ),
          ),
        ),
      ),
    );

    // Default, not disabled
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    // Highlighted (pressed)
    final Offset center = tester.getCenter(find.byType(MaterialButton));
    await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 200)); // wait for splash to be well under way
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

}
