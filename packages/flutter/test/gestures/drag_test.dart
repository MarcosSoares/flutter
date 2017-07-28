// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';

import 'gesture_tester.dart';

void main() {
  setUp(ensureGestureBinding);

  testGesture('Should recognize pan', (GestureTester tester) {
    final PanGestureRecognizer pan = new PanGestureRecognizer();
    final TapGestureRecognizer tap = new TapGestureRecognizer();

    bool didStartPan = false;
    pan.onStart = (_) {
      didStartPan = true;
    };

    Offset updatedScrollDelta;
    pan.onUpdate = (DragUpdateDetails details) {
      updatedScrollDelta = details.delta;
    };

    bool didEndPan = false;
    pan.onEnd = (DragEndDetails details) {
      didEndPan = true;
    };

    bool didTap = false;
    tap.onTap = () {
      didTap = true;
    };

    final TestPointer pointer = new TestPointer(5);
    final PointerDownEvent down = pointer.down(const Offset(10.0, 10.0));
    pan.addPointer(down);
    tap.addPointer(down);
    tester.closeArena(5);
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(down);
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    // touch should give up when it hits kTouchSlop, which was 18.0 when this test was last updated.

    tester.route(pointer.move(const Offset(20.0, 20.0))); // moved 10 horizontally and 10 vertically which is 14 total
    expect(didStartPan, isFalse); // 14 < 18
    tester.route(pointer.move(const Offset(20.0, 30.0))); // moved 10 horizontally and 20 vertically which is 22 total
    expect(didStartPan, isTrue); // 22 > 18
    didStartPan = false;
    expect(updatedScrollDelta, const Offset(10.0, 20.0));
    updatedScrollDelta = null;
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(pointer.move(const Offset(20.0, 25.0)));
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, const Offset(0.0, -5.0));
    updatedScrollDelta = null;
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(pointer.up());
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isTrue);
    didEndPan = false;
    expect(didTap, isFalse);

    pan.dispose();
    tap.dispose();
  });

  testGesture('Should recognize drag', (GestureTester tester) {
    final HorizontalDragGestureRecognizer drag = new HorizontalDragGestureRecognizer();

    bool didStartDrag = false;
    drag.onStart = (_) {
      didStartDrag = true;
    };

    double updatedDelta;
    drag.onUpdate = (DragUpdateDetails details) {
      updatedDelta = details.primaryDelta;
    };

    bool didEndDrag = false;
    drag.onEnd = (DragEndDetails details) {
      didEndDrag = true;
    };

    final TestPointer pointer = new TestPointer(5);
    final PointerDownEvent down = pointer.down(const Offset(10.0, 10.0));
    drag.addPointer(down);
    tester.closeArena(5);
    expect(didStartDrag, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndDrag, isFalse);

    tester.route(down);
    expect(didStartDrag, isTrue);
    expect(updatedDelta, isNull);
    expect(didEndDrag, isFalse);

    tester.route(pointer.move(const Offset(20.0, 25.0)));
    expect(didStartDrag, isTrue);
    didStartDrag = false;
    expect(updatedDelta, 10.0);
    updatedDelta = null;
    expect(didEndDrag, isFalse);

    tester.route(pointer.move(const Offset(20.0, 25.0)));
    expect(didStartDrag, isFalse);
    expect(updatedDelta, 0.0);
    updatedDelta = null;
    expect(didEndDrag, isFalse);

    tester.route(pointer.up());
    expect(didStartDrag, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndDrag, isTrue);
    didEndDrag = false;

    drag.dispose();
  });

  testGesture('Drag with multiple pointers', (GestureTester tester) {
    final HorizontalDragGestureRecognizer drag1 = new HorizontalDragGestureRecognizer();
    final VerticalDragGestureRecognizer drag2 = new VerticalDragGestureRecognizer();

    final List<String> log = <String>[];
    drag1.onDown = (_) { log.add('drag1-down'); };
    drag1.onStart = (_) { log.add('drag1-start'); };
    drag1.onUpdate = (_) { log.add('drag1-update'); };
    drag1.onEnd = (_) { log.add('drag1-end'); };
    drag1.onCancel = () { log.add('drag1-cancel'); };
    drag2.onDown = (_) { log.add('drag2-down'); };
    drag2.onStart = (_) { log.add('drag2-start'); };
    drag2.onUpdate = (_) { log.add('drag2-update'); };
    drag2.onEnd = (_) { log.add('drag2-end'); };
    drag2.onCancel = () { log.add('drag2-cancel'); };

    final TestPointer pointer5 = new TestPointer(5);
    final PointerDownEvent down5 = pointer5.down(const Offset(10.0, 10.0));
    drag1.addPointer(down5);
    drag2.addPointer(down5);
    tester.closeArena(5);
    tester.route(down5);
    log.add('-a');

    tester.route(pointer5.move(const Offset(100.0, 0.0)));
    log.add('-b');
    tester.route(pointer5.move(const Offset(50.0, 50.0)));
    log.add('-c');

    final TestPointer pointer6 = new TestPointer(6);
    final PointerDownEvent down6 = pointer6.down(const Offset(20.0, 20.0));
    drag1.addPointer(down6);
    drag2.addPointer(down6);
    tester.closeArena(6);
    tester.route(down6);
    log.add('-d');

    tester.route(pointer5.move(const Offset(0.0, 100.0)));
    log.add('-e');
    tester.route(pointer5.move(const Offset(70.0, 70.0)));
    log.add('-f');

    tester.route(pointer5.up());
    tester.route(pointer6.up());

    drag1.dispose();
    drag2.dispose();

    expect(log, <String>[
      'drag1-down',
      'drag2-down',
      '-a',
      'drag2-cancel',
      'drag1-start',
      'drag1-update',
      '-b',
      'drag1-update',
      '-c',
      'drag2-down',
      'drag2-cancel',
      '-d',
      'drag1-update',
      '-e',
      'drag1-update',
      '-f',
      'drag1-end'
    ]);
  });

  testGesture('Clamp max velocity', (GestureTester tester) {
    final HorizontalDragGestureRecognizer drag = new HorizontalDragGestureRecognizer();

    Velocity velocity;
    double primaryVelocity;
    drag.onEnd = (DragEndDetails details) {
      velocity = details.velocity;
      primaryVelocity = details.primaryVelocity;
    };

    final TestPointer pointer = new TestPointer(5);
    final PointerDownEvent down = pointer.down(const Offset(10.0, 25.0), timeStamp: const Duration(milliseconds: 10));
    drag.addPointer(down);
    tester.closeArena(5);
    tester.route(down);
    tester.route(pointer.move(const Offset(20.0, 25.0), timeStamp: const Duration(milliseconds: 10)));
    tester.route(pointer.move(const Offset(30.0, 25.0), timeStamp: const Duration(milliseconds: 11)));
    tester.route(pointer.move(const Offset(40.0, 25.0), timeStamp: const Duration(milliseconds: 12)));
    tester.route(pointer.move(const Offset(50.0, 25.0), timeStamp: const Duration(milliseconds: 13)));
    tester.route(pointer.move(const Offset(60.0, 25.0), timeStamp: const Duration(milliseconds: 14)));
    tester.route(pointer.move(const Offset(70.0, 25.0), timeStamp: const Duration(milliseconds: 15)));
    tester.route(pointer.move(const Offset(80.0, 25.0), timeStamp: const Duration(milliseconds: 16)));
    tester.route(pointer.move(const Offset(90.0, 25.0), timeStamp: const Duration(milliseconds: 17)));
    tester.route(pointer.move(const Offset(100.0, 25.0), timeStamp: const Duration(milliseconds: 18)));
    tester.route(pointer.move(const Offset(110.0, 25.0), timeStamp: const Duration(milliseconds: 19)));
    tester.route(pointer.move(const Offset(120.0, 25.0), timeStamp: const Duration(milliseconds: 20)));
    tester.route(pointer.up(timeStamp: const Duration(milliseconds: 20)));
    expect(velocity.pixelsPerSecond.dx, inInclusiveRange(0.99 * kMaxFlingVelocity, kMaxFlingVelocity));
    expect(velocity.pixelsPerSecond.dy, moreOrLessEquals(0.0));
    expect(primaryVelocity, velocity.pixelsPerSecond.dx);

    drag.dispose();
  });

  testGesture('Drag details', (GestureTester tester) {
    expect(new DragDownDetails(), hasOneLineDescription);
    expect(new DragStartDetails(), hasOneLineDescription);
    expect(new DragUpdateDetails(globalPosition: Offset.zero), hasOneLineDescription);
    expect(new DragEndDetails(), hasOneLineDescription);
  });
}
