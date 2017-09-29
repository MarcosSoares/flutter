// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'semantics_tester.dart';

void main() {
  testWidgets('MergeSemantics', (WidgetTester tester) async {
    final SemanticsTester semantics = new SemanticsTester(tester);

    print('>>>>> not merged');
    // not merged
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Row(
          children: <Widget>[
            new Semantics(
                label: 'test1',
                textDirection: TextDirection.ltr,
                child: new Container()
            ),
            new Semantics(
                label: 'test2',
                textDirection: TextDirection.ltr,
                child: new Container()
            )
          ],
        ),
      ),
    );

    expect(semantics, hasSemantics(new TestSemantics.root(
      children: <TestSemantics>[
        new TestSemantics.rootChild(id: 1, label: 'test1'),
        new TestSemantics.rootChild(id: 2, label: 'test2'),
      ],
    ), ignoreRect: true, ignoreTransform: true));

    print('>>>>> merged');
    //merged
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new MergeSemantics(
          child: new Row(
            children: <Widget>[
              new Semantics(
                  label: 'test1',
                  textDirection: TextDirection.ltr,
                  child: new Container()
              ),
              new Semantics(
                  label: 'test2',
                  textDirection: TextDirection.ltr,
                  child: new Container()
              )
            ],
          ),
        ),
      ),
    );

    expect(semantics, hasSemantics(new TestSemantics.root(label: 'test1\ntest2')));

    print('>>>>> not merged');
    // not merged
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Row(
          children: <Widget>[
            new Semantics(
                label: 'test1',
                textDirection: TextDirection.ltr,
                child: new Container()
            ),
            new Semantics(
                label: 'test2',
                textDirection: TextDirection.ltr,
                child: new Container()
            )
          ],
        ),
      ),
    );

    debugDumpSemanticsTree(DebugSemanticsDumpOrder.inverseHitTest);

    expect(semantics, hasSemantics(new TestSemantics.root(
      children: <TestSemantics>[
        new TestSemantics.rootChild(id: 1, label: 'test1'),
        new TestSemantics.rootChild(id: 2, label: 'test2'),
      ],
    ), ignoreRect: true, ignoreTransform: true));

    semantics.dispose();
  });
}
