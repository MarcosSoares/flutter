// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Can dispose without keyboard', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();
    await tester.pumpWidget(RawKeyboardListener(focusNode: focusNode, onKey: null, child: Container()));
    await tester.pumpWidget(RawKeyboardListener(focusNode: focusNode, onKey: null, child: Container()));
    await tester.pumpWidget(Container());
  });

  testWidgets('Fuchsia key event', (WidgetTester tester) async {
    final List<RawKeyEvent> events = <RawKeyEvent>[];

    final FocusNode focusNode = FocusNode();

    await tester.pumpWidget(
      RawKeyboardListener(
        focusNode: focusNode,
        onKey: events.add,
        child: Container(),
      ),
    );

    focusNode.requestFocus();
    await tester.idle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.idle();

    expect(events.length, 2);
    expect(events[1].runtimeType, equals(RawKeyUpEvent));
    expect(events[1].data.runtimeType, equals(RawKeyEventDataFuchsia));
    final RawKeyEventDataFuchsia typedData = events[1].data;
    expect(typedData.hidUsage, 0x700e3);
    expect(typedData.codePoint, 0x0);
    expect(typedData.modifiers, RawKeyEventDataFuchsia.modifierLeftMeta);
    expect(typedData.isModifierPressed(ModifierKey.metaModifier, side: KeyboardSide.left), isTrue);

    await tester.pumpWidget(Container());
    focusNode.dispose();
  });

  testWidgets('Defunct listeners do not receive events', (WidgetTester tester) async {
    final List<RawKeyEvent> events = <RawKeyEvent>[];

    final FocusNode focusNode = FocusNode();

    await tester.pumpWidget(
      RawKeyboardListener(
        focusNode: focusNode,
        onKey: events.add,
        child: Container(),
      ),
    );

    focusNode.requestFocus();
    await tester.idle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.idle();

    expect(events.length, 2);
    events.clear();

    await tester.pumpWidget(Container());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');

    await tester.idle();

    expect(events.length, 0);

    await tester.pumpWidget(Container());
    focusNode.dispose();
  });
}
