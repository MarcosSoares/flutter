// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class TestFocus extends StatefulWidget {
  const TestFocus({
    Key key,
    this.debugLabel,
    this.name = 'a',
    this.autofocus = false,
  }) : super(key: key);

  final String debugLabel;
  final String name;
  final bool autofocus;

  @override
  TestFocusState createState() => TestFocusState();
}

class TestFocusState extends State<TestFocus> {
  FocusNode focusNode = FocusNode();
  FocusAttachment focusAttachment;
  bool _didAutofocus = false;

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode(debugLabel: widget.debugLabel);
    focusAttachment = focusNode.attach(context);
  }

  @override
  Widget build(BuildContext context) {
    focusAttachment.reparent();
    if (!_didAutofocus && widget.autofocus) {
      _didAutofocus = true;
      FocusScope.of(context).autofocus(focusNode);
    }
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(focusNode);
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (BuildContext context, Widget child) {
          return Text(
            focusNode.hasFocus ? '${widget.name.toUpperCase()} FOCUSED' : widget.name.toLowerCase(),
            textDirection: TextDirection.ltr,
          );
        },
      ),
    );
  }
}

void main() {
  group(FocusScope, () {
    testWidgets('Can focus', (WidgetTester tester) async {
      final GlobalKey<TestFocusState> key = GlobalKey();

      await tester.pumpWidget(
        TestFocus(key: key, name: 'a'),
      );

      expect(key.currentState.focusNode.hasFocus, isFalse);

      FocusScope.of(key.currentContext).requestFocus(key.currentState.focusNode);
      await tester.pumpAndSettle();

      expect(key.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
    });

    testWidgets('Can unfocus', (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();
      await tester.pumpWidget(
        Column(
          children: <Widget>[
            TestFocus(key: keyA, name: 'a'),
            TestFocus(key: keyB, name: 'b'),
          ],
        ),
      );

      expect(keyA.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      // Set focus to the "B" node to unfocus the "A" node.
      FocusScope.of(keyB.currentContext).requestFocus(keyB.currentState.focusNode);
      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('B FOCUSED'), findsOneWidget);
    });

    testWidgets('Can have multiple focused children and they update accordingly', (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            TestFocus(
              key: keyA,
              name: 'a',
              autofocus: true,
            ),
            TestFocus(
              key: keyB,
              name: 'b',
            ),
          ],
        ),
      );

      // Autofocus is delayed one frame.
      await tester.pump();
      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
      await tester.tap(find.text('A FOCUSED'));
      await tester.pump();
      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
      await tester.tap(find.text('b'));
      await tester.pump();
      expect(keyA.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('B FOCUSED'), findsOneWidget);
      await tester.tap(find.text('a'));
      await tester.pump();
      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
    });

    // This moves a focus node first into a focus scope that is added to its
    // parent, and then out of that focus scope again.
    testWidgets('Can move focus in and out of FocusScope', (WidgetTester tester) async {
      final FocusScopeNode parentFocusScope = FocusScopeNode(debugLabel: 'Parent Scope Node');
      final FocusScopeNode childFocusScope = FocusScopeNode(debugLabel: 'Child Scope Node');
      final GlobalKey<TestFocusState> key = GlobalKey();

      // Initially create the focus inside of the parent FocusScope.
      await tester.pumpWidget(
        FocusScope(
          debugLabel: 'Parent Scope',
          node: parentFocusScope,
          autofocus: true,
          child: Column(
            children: <Widget>[
              TestFocus(
                key: key,
                name: 'a',
                debugLabel: 'Child',
              ),
            ],
          ),
        ),
      );

      expect(key.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);
      FocusScope.of(key.currentContext).requestFocus(key.currentState.focusNode);
      await tester.pumpAndSettle();

      expect(key.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);

      expect(parentFocusScope, hasAGoodToStringDeep);
      expect(
        parentFocusScope.toStringDeep(),
        equalsIgnoringHashCodes('FocusScopeNode#00000\n'
            ' │ context: FocusScope\n'
            ' │ FOCUSED\n'
            ' │ debugLabel: "Parent Scope Node"\n'
            ' │ focusedChild: FocusNode#00000\n'
            ' │\n'
            ' └─Child 1: FocusNode#00000\n'
            '     context: TestFocus-[LabeledGlobalKey<TestFocusState>#00000]\n'
            '     FOCUSED\n'
            '     debugLabel: "Child"\n'),
      );

      expect(WidgetsBinding.instance.focusManager.rootScope, hasAGoodToStringDeep);
      expect(
        WidgetsBinding.instance.focusManager.rootScope.toStringDeep(minLevel: DiagnosticLevel.info),
        equalsIgnoringHashCodes('FocusScopeNode#00000\n'
            ' │ FOCUSED\n'
            ' │ debugLabel: "Root Focus Scope"\n'
            ' │ focusedChild: FocusScopeNode#00000\n'
            ' │\n'
            ' └─Child 1: FocusScopeNode#00000\n'
            '   │ context: FocusScope\n'
            '   │ FOCUSED\n'
            '   │ debugLabel: "Parent Scope Node"\n'
            '   │ focusedChild: FocusNode#00000\n'
            '   │\n'
            '   └─Child 1: FocusNode#00000\n'
            '       context: TestFocus-[LabeledGlobalKey<TestFocusState>#00000]\n'
            '       FOCUSED\n'
            '       debugLabel: "Child"\n'),
      );

      // Add the child focus scope to the focus tree.
      final FocusAttachment childAttachment  = childFocusScope.attach(key.currentContext);
      parentFocusScope.setFirstFocus(childFocusScope);
      await tester.pumpAndSettle();
      expect(childFocusScope.isFirstFocus, isTrue);

      // Now add the child focus scope with no child focusable in it to the tree.
      await tester.pumpWidget(
        FocusScope(
          debugLabel: 'Parent Scope',
          node: parentFocusScope,
          child: Column(
            children: <Widget>[
              TestFocus(
                key: key,
                debugLabel: 'Child',
              ),
              FocusScope(
                debugLabel: 'Child Scope',
                node: childFocusScope,
                child: Container(),
              ),
            ],
          ),
        ),
      );

      expect(key.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);

      // Now move the existing focus node into the child focus scope.
      await tester.pumpWidget(
        FocusScope(
          debugLabel: 'Parent Scope',
          node: parentFocusScope,
          child: Column(
            children: <Widget>[
              FocusScope(
                debugLabel: 'Child Scope',
                node: childFocusScope,
                child: TestFocus(
                  key: key,
                  debugLabel: 'Child',
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(key.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);

      // Now remove the child focus scope.
      await tester.pumpWidget(
        FocusScope(
          debugLabel: 'Parent Scope',
          node: parentFocusScope,
          child: Column(
            children: <Widget>[
              TestFocus(
                key: key,
                debugLabel: 'Child',
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(key.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('a'), findsOneWidget);

      // Must detach the child because we had to attach it in order to call
      // setFirstFocus before adding to the widget.
      childAttachment.detach();
    });

    // Arguably, this isn't correct behavior, but it is what happens now.
    testWidgets("Removing focused widget doesn't move focus to next widget", (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            TestFocus(
              key: keyA,
              name: 'a',
            ),
            TestFocus(
              key: keyB,
              name: 'b',
            ),
          ],
        ),
      );

      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);

      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            TestFocus(
              key: keyB,
              name: 'b',
            ),
          ],
        ),
      );

      await tester.pump();

      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('Adding a new FocusScope attaches the child it to its parent.', (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final FocusScopeNode parentFocusScope = FocusScopeNode(debugLabel: 'Parent Scope Node');
      final FocusScopeNode childFocusScope = FocusScopeNode(debugLabel: 'Child Scope Node');

      await tester.pumpWidget(
        FocusScope(
          node: childFocusScope,
          child: TestFocus(
            debugLabel: 'Child',
            key: keyA,
          ),
        ),
      );

      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      expect(FocusScope.of(keyA.currentContext), equals(childFocusScope));
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(FocusScope.of(keyA.currentContext));

      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(childFocusScope.isFirstFocus, isTrue);

      await tester.pumpWidget(
        FocusScope(
          node: parentFocusScope,
          child: FocusScope(
            node: childFocusScope,
            child: TestFocus(
              debugLabel: 'Child',
              key: keyA,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(childFocusScope.isFirstFocus, isTrue);
      // Node keeps it's focus when moved to the new scope.
      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
    });

    // Arguably, this isn't correct behavior, but it is what happens now.
    testWidgets("Removing focused widget doesn't move focus to next widget within FocusScope", (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();
      final FocusScopeNode parentFocusScope = FocusScopeNode(debugLabel: 'Parent Scope');

      await tester.pumpWidget(
        FocusScope(
          debugLabel: 'Parent Scope',
          node: parentFocusScope,
          autofocus: true,
          child: Column(
            children: <Widget>[
              TestFocus(
                debugLabel: 'Widget A',
                key: keyA,
                name: 'a',
              ),
              TestFocus(
                debugLabel: 'Widget B',
                key: keyB,
                name: 'b',
              ),
            ],
          ),
        ),
      );

      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      final FocusScopeNode scope = FocusScope.of(keyA.currentContext);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(scope);

      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      await tester.pumpWidget(
        FocusScope(
          node: parentFocusScope,
          child: Column(
            children: <Widget>[
              TestFocus(
                key: keyB,
                name: 'b',
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('Removing a FocusScope removes its node from the tree', (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();
      final GlobalKey<TestFocusState> scopeKeyA = GlobalKey();
      final GlobalKey<TestFocusState> scopeKeyB = GlobalKey();
      final FocusScopeNode parentFocusScope = FocusScopeNode(debugLabel: 'Parent Scope');

      // This checks both FocusScopes that have their own nodes, as well as those
      // that use external nodes.
      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              key: scopeKeyA,
              node: parentFocusScope,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child A',
                    key: keyA,
                    name: 'a',
                  ),
                ],
              ),
            ),
            FocusScope(
              key: scopeKeyB,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child B',
                    key: keyB,
                    name: 'b',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      FocusScope.of(keyB.currentContext).requestFocus(keyB.currentState.focusNode);
      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      final FocusScopeNode bScope = FocusScope.of(keyB.currentContext);
      final FocusScopeNode aScope = FocusScope.of(keyA.currentContext);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(bScope);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(aScope);

      await tester.pumpAndSettle();

      expect(FocusScope.of(keyA.currentContext).isFirstFocus, isTrue);
      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      await tester.pumpWidget(Container());

      expect(WidgetsBinding.instance.focusManager.rootScope.children, isEmpty);
    });

    // Arguably, this isn't correct behavior, but it is what happens now.
    testWidgets("Removing unpinned focused scope doesn't move focus to focused widget within next FocusScope", (WidgetTester tester) async {
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();
      final FocusScopeNode parentFocusScope1 = FocusScopeNode(debugLabel: 'Parent Scope 1');
      final FocusScopeNode parentFocusScope2 = FocusScopeNode(debugLabel: 'Parent Scope 2');

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              node: parentFocusScope1,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child A',
                    key: keyA,
                    name: 'a',
                  ),
                ],
              ),
            ),
            FocusScope(
              node: parentFocusScope2,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child B',
                    key: keyB,
                    name: 'b',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      FocusScope.of(keyB.currentContext).requestFocus(keyB.currentState.focusNode);
      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      final FocusScopeNode aScope = FocusScope.of(keyA.currentContext);
      final FocusScopeNode bScope = FocusScope.of(keyB.currentContext);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(bScope);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(aScope);

      await tester.pumpAndSettle();

      expect(FocusScope.of(keyA.currentContext).isFirstFocus, isTrue);
      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      // If the FocusScope widgets are not pinned with GlobalKeys, then the first
      // one remains and gets its guts replaced with the parentFocusScope2 and the
      // "B" test widget, and in the process, the focus manager loses track of the
      // focus.
      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              node: parentFocusScope2,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    key: keyB,
                    name: 'b',
                    autofocus: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('Moving widget from one scope to another retains focus', (WidgetTester tester) async {
      final FocusScopeNode parentFocusScope1 = FocusScopeNode();
      final FocusScopeNode parentFocusScope2 = FocusScopeNode();
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              node: parentFocusScope1,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    key: keyA,
                    name: 'a',
                  ),
                ],
              ),
            ),
            FocusScope(
              node: parentFocusScope2,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    key: keyB,
                    name: 'b',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      final FocusScopeNode aScope = FocusScope.of(keyA.currentContext);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(aScope);

      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              node: parentFocusScope1,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    key: keyB,
                    name: 'b',
                  ),
                ],
              ),
            ),
            FocusScope(
              node: parentFocusScope2,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    key: keyA,
                    name: 'a',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pump();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('Moving FocusScopeNodes retains focus', (WidgetTester tester) async {
      final FocusScopeNode parentFocusScope1 = FocusScopeNode(debugLabel: 'Scope 1');
      final FocusScopeNode parentFocusScope2 = FocusScopeNode(debugLabel: 'Scope 2');
      final GlobalKey<TestFocusState> keyA = GlobalKey();
      final GlobalKey<TestFocusState> keyB = GlobalKey();

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              node: parentFocusScope1,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child A',
                    key: keyA,
                    name: 'a',
                  ),
                ],
              ),
            ),
            FocusScope(
              node: parentFocusScope2,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child B',
                    key: keyB,
                    name: 'b',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      FocusScope.of(keyA.currentContext).requestFocus(keyA.currentState.focusNode);
      final FocusScopeNode aScope = FocusScope.of(keyA.currentContext);
      WidgetsBinding.instance.focusManager.rootScope.setFirstFocus(aScope);

      await tester.pumpAndSettle();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);

      // This just swaps the FocusScopeNodes that the FocusScopes have in them.
      await tester.pumpWidget(
        Column(
          children: <Widget>[
            FocusScope(
              node: parentFocusScope2,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child A',
                    key: keyA,
                    name: 'a',
                  ),
                ],
              ),
            ),
            FocusScope(
              node: parentFocusScope1,
              child: Column(
                children: <Widget>[
                  TestFocus(
                    debugLabel: 'Child B',
                    key: keyB,
                    name: 'b',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pump();

      expect(keyA.currentState.focusNode.hasFocus, isTrue);
      expect(find.text('A FOCUSED'), findsOneWidget);
      expect(keyB.currentState.focusNode.hasFocus, isFalse);
      expect(find.text('b'), findsOneWidget);
    });
  });
  group(Focus, () {
    testWidgets('Focus.of stops at the nearest FocusScope.', (WidgetTester tester) async {
      final GlobalKey key1 = GlobalKey(debugLabel: '1');
      final GlobalKey key2 = GlobalKey(debugLabel: '2');
      final GlobalKey key3 = GlobalKey(debugLabel: '3');
      final GlobalKey key4 = GlobalKey(debugLabel: '4');
      final GlobalKey key5 = GlobalKey(debugLabel: '5');
      final GlobalKey key6 = GlobalKey(debugLabel: '6');
      await tester.pumpWidget(
        Focus(
          key: key1,
          debugLabel: 'Key 1',
          child: Container(
            key: key2,
            child: Focus(
              debugLabel: 'Key 3',
              key: key3,
              child: Container(
                key: key4,
                child: Focus(
                  debugLabel: 'Key 5',
                  key: key5,
                  child: Container(
                    key: key6,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final Element element1 = tester.element(find.byKey(key1));
      final Element element2 = tester.element(find.byKey(key2));
      final Element element3 = tester.element(find.byKey(key3));
      final Element element4 = tester.element(find.byKey(key4));
      final Element element5 = tester.element(find.byKey(key5));
      final Element element6 = tester.element(find.byKey(key6));
      final FocusNode root = element1.owner.focusManager.rootScope;

      expect(Focus.of(element1), equals(root));
      expect(Focus.of(element2).parent, equals(root));
      expect(Focus.of(element3).parent, equals(root));
      expect(Focus.of(element4).parent.parent, equals(root));
      expect(Focus.of(element5).parent.parent, equals(root));
      expect(Focus.of(element6).parent.parent.parent, equals(root));
    });
    testWidgets('Can traverse Focus children.', (WidgetTester tester) async {
      final GlobalKey key1 = GlobalKey(debugLabel: '1');
      final GlobalKey key2 = GlobalKey(debugLabel: '2');
      final GlobalKey key3 = GlobalKey(debugLabel: '3');
      final GlobalKey key4 = GlobalKey(debugLabel: '4');
      final GlobalKey key5 = GlobalKey(debugLabel: '5');
      final GlobalKey key6 = GlobalKey(debugLabel: '6');
      final GlobalKey key7 = GlobalKey(debugLabel: '7');
      final GlobalKey key8 = GlobalKey(debugLabel: '8');
      await tester.pumpWidget(
        Focus(
          child: Column(
            key: key1,
            children: <Widget>[
              Focus(
                key: key2,
                child: Container(
                  child: Focus(
                    key: key3,
                    child: Container(),
                  ),
                ),
              ),
              Focus(
                key: key4,
                child: Container(
                  child: Focus(
                    key: key5,
                    child: Container(),
                  ),
                ),
              ),
              Focus(
                key: key6,
                child: Column(
                  children: <Widget>[
                    Focus(
                      key: key7,
                      child: Container(),
                    ),
                    Focus(
                      key: key8,
                      child: Container(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      final Element firstScope = tester.element(find.byKey(key1));
      final List<FocusNode> nodes = <FocusNode>[];
      final List<Key> keys = <Key>[];
      bool visitor(FocusNode node) {
        nodes.add(node);
        keys.add(node.context.widget.key);
        return true;
      }

      await tester.pump();

      Focus.of(firstScope).descendants.forEach(visitor);
      expect(nodes.length, equals(7));
      expect(keys.length, equals(7));
      // Depth first.
      expect(keys, equals(<Key>[key3, key2, key5, key4, key7, key8, key6]));

      // Just traverses a sub-tree.
      final Element secondScope = tester.element(find.byKey(key7));
      nodes.clear();
      keys.clear();
      Focus.of(secondScope).descendants.forEach(visitor);
      expect(nodes.length, equals(2));
      expect(keys, equals(<Key>[key7, key8]));
    });
    testWidgets('Can set focus.', (WidgetTester tester) async {
      final GlobalKey key1 = GlobalKey(debugLabel: '1');
      bool gotFocus;
      await tester.pumpWidget(
        Focus(
          onFocusChange: (bool focused) => gotFocus = focused,
          child: Container(key: key1),
        ),
      );

      final Element firstNode = tester.element(find.byKey(key1));
      final FocusNode node = Focus.of(firstNode);
      node.requestFocus();

      await tester.pump();

      expect(gotFocus, isTrue);
      expect(node.hasFocus, isTrue);
    });
    testWidgets('Can focus root node.', (WidgetTester tester) async {
      final GlobalKey key1 = GlobalKey(debugLabel: '1');
      await tester.pumpWidget(
        Focus(
          key: key1,
          child: Container(),
        ),
      );

      final Element firstElement = tester.element(find.byKey(key1));
      final FocusNode rootNode = Focus.of(firstElement);
      rootNode.requestFocus();

      await tester.pump();

      expect(rootNode.hasFocus, isTrue);
      expect(rootNode, equals(firstElement.owner.focusManager.rootScope));
    });
  });
  testWidgets('Nodes are removed when all Focuses are removed.', (WidgetTester tester) async {
    final GlobalKey key1 = GlobalKey(debugLabel: '1');
    bool gotFocus;
    await tester.pumpWidget(
      FocusScope(
        child: Focus(
          onFocusChange: (bool focused) => gotFocus = focused,
          child: Container(key: key1),
        ),
      ),
    );

    final Element firstNode = tester.element(find.byKey(key1));
    final FocusNode node = Focus.of(firstNode);
    node.requestFocus();

    await tester.pump();

    expect(gotFocus, isTrue);
    expect(node.hasFocus, isTrue);

    await tester.pumpWidget(Container());

    expect(WidgetsBinding.instance.focusManager.rootScope.descendants, isEmpty);
  });
}
