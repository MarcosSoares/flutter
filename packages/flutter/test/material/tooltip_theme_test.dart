// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rendering/mock_canvas.dart';
import '../widgets/semantics_tester.dart';

const String tooltipText = 'TIP';
const double _customPaddingValue = 10.0;

void _ensureTooltipVisible(GlobalKey key) {
  // This function uses "as dynamic"to defeat the static analysis. In general
  // you want to avoid using this style in your code, as it will cause the
  // analyzer to be unable to help you catch errors.
  //
  // In this case, we do it because we are trying to call internal methods of
  // the tooltip code in order to test it. Normally, the state of a tooltip is a
  // private class, but by using a GlobalKey we can get a handle to that object
  // and by using "as dynamic" we can bypass the analyzer's type checks and call
  // methods that we aren't supposed to be able to know about.
  //
  // It's ok to do this in tests, but you really don't want to do it in
  // production code.
  // ignore: avoid_dynamic_calls
  (key.currentState as dynamic).ensureTooltipVisible();
}

void main() {
  test('TooltipThemeData copyWith, ==, hashCode basics', () {
    expect(const TooltipThemeData(), const TooltipThemeData().copyWith());
    expect(const TooltipThemeData().hashCode, const TooltipThemeData().copyWith().hashCode);
  });

  test('TooltipThemeData defaults', () {
    const TooltipThemeData theme = TooltipThemeData();
    expect(theme.height, null);
    expect(theme.padding, null);
    expect(theme.verticalOffset, null);
    expect(theme.preferBelow, null);
    expect(theme.excludeFromSemantics, null);
    expect(theme.decoration, null);
    expect(theme.textStyle, null);
    expect(theme.waitDuration, null);
    expect(theme.showDuration, null);
    expect(theme.triggerMode, null);
    expect(theme.enableFeedback, null);
  });

  testWidgets('Default TooltipThemeData debugFillProperties', (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
    const TooltipThemeData().debugFillProperties(builder);

    final List<String> description = builder.properties
        .where((DiagnosticsNode node) => !node.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode node) => node.toString())
        .toList();

    expect(description, <String>[]);
  });

  testWidgets('TooltipThemeData implements debugFillProperties', (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
    const Duration wait = Duration(milliseconds: 100);
    const Duration show = Duration(milliseconds: 200);
    const TooltipTriggerMode triggerMode = TooltipTriggerMode.longPress;
    const bool enableFeedback = true;
    const TooltipThemeData(
      height: 15.0,
      padding: EdgeInsets.all(20.0),
      verticalOffset: 10.0,
      preferBelow: false,
      excludeFromSemantics: true,
      decoration: BoxDecoration(color: Color(0xffffffff)),
      textStyle: TextStyle(decoration: TextDecoration.underline),
      waitDuration: wait,
      showDuration: show,
      triggerMode: triggerMode,
      enableFeedback: enableFeedback,
    ).debugFillProperties(builder);

    final List<String> description = builder.properties
        .where((DiagnosticsNode node) => !node.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode node) => node.toString())
        .toList();

    expect(description, <String>[
      'height: 15.0',
      'padding: EdgeInsets.all(20.0)',
      'vertical offset: 10.0',
      'position: above',
      'semantics: excluded',
      'decoration: BoxDecoration(color: Color(0xffffffff))',
      'textStyle: TextStyle(inherit: true, decoration: TextDecoration.underline)',
      'wait duration: ${wait.toString()}',
      'show duration: ${show.toString()}',
      'triggerMode: $triggerMode',
      'enableFeedback: true',
    ]);
  });

  testWidgets('Tooltip verticalOffset, preferBelow; center prefer above fits - ThemeData.tooltipTheme',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              height: 100.0,
              padding: EdgeInsets.zero,
              verticalOffset: 100.0,
              preferBelow: false,
            ),
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 400.0,
                        top: 300.0,
                        child: Tooltip(
                          key: key,
                          message: tooltipText,
                          child: const SizedBox(
                            width: 0.0,
                            height: 0.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    /********************* 800x600 screen
     *        ___        * }- 10.0 margin
     *       |___|       * }-100.0 height
     *         |         * }-100.0 vertical offset
     *         o         * y=300.0
     *                   *
     *                   *
     *                   *
     *********************/

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent! as RenderBox;
    expect(tip.size.height, equals(100.0));
    expect(tip.localToGlobal(tip.size.topLeft(Offset.zero)).dy, equals(100.0));
    expect(tip.localToGlobal(tip.size.bottomRight(Offset.zero)).dy, equals(200.0));
  });

  testWidgets('Tooltip verticalOffset, preferBelow; center prefer above fits - TooltipTheme',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TooltipTheme(
          data: const TooltipThemeData(
            height: 100.0,
            padding: EdgeInsets.zero,
            verticalOffset: 100.0,
            preferBelow: false,
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 400.0,
                        top: 300.0,
                        child: Tooltip(
                          key: key,
                          message: tooltipText,
                          child: const SizedBox(
                            width: 0.0,
                            height: 0.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    /********************* 800x600 screen
     *        ___        * }- 10.0 margin
     *       |___|       * }-100.0 height
     *         |         * }-100.0 vertical offset
     *         o         * y=300.0
     *                   *
     *                   *
     *                   *
     *********************/

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent! as RenderBox;
    expect(tip.size.height, equals(100.0));
    expect(tip.localToGlobal(tip.size.topLeft(Offset.zero)).dy, equals(100.0));
    expect(tip.localToGlobal(tip.size.bottomRight(Offset.zero)).dy, equals(200.0));
  });

  testWidgets('Tooltip verticalOffset, preferBelow; center prefer above does not fit - ThemeData.tooltipTheme',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              height: 190.0,
              padding: EdgeInsets.zero,
              verticalOffset: 100.0,
              preferBelow: false,
            ),
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 400.0,
                        top: 299.0,
                        child: Tooltip(
                          key: key,
                          message: tooltipText,
                          child: const SizedBox(
                            width: 0.0,
                            height: 0.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    // we try to put it here but it doesn't fit:
    /********************* 800x600 screen
     *        ___        * }- 10.0 margin
     *       |___|       * }-190.0 height (starts at y=9.0)
     *         |         * }-100.0 vertical offset
     *         o         * y=299.0
     *                   *
     *                   *
     *                   *
     *********************/

    // so we put it here:
    /********************* 800x600 screen
     *                   *
     *                   *
     *         o         * y=299.0
     *        _|_        * }-100.0 vertical offset
     *       |___|       * }-190.0 height
     *                   * }- 10.0 margin
     *********************/

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent! as RenderBox;
    expect(tip.size.height, equals(190.0));
    expect(tip.localToGlobal(tip.size.topLeft(Offset.zero)).dy, equals(399.0));
    expect(tip.localToGlobal(tip.size.bottomRight(Offset.zero)).dy, equals(589.0));
  });

  testWidgets('Tooltip verticalOffset, preferBelow; center prefer above does not fit - TooltipTheme',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TooltipTheme(
          data: const TooltipThemeData(
            height: 190.0,
            padding: EdgeInsets.zero,
            verticalOffset: 100.0,
            preferBelow: false,
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 400.0,
                        top: 299.0,
                        child: Tooltip(
                          key: key,
                          message: tooltipText,
                          child: const SizedBox(
                            width: 0.0,
                            height: 0.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    // we try to put it here but it doesn't fit:
    /********************* 800x600 screen
     *        ___        * }- 10.0 margin
     *       |___|       * }-190.0 height (starts at y=9.0)
     *         |         * }-100.0 vertical offset
     *         o         * y=299.0
     *                   *
     *                   *
     *                   *
     *********************/

    // so we put it here:
    /********************* 800x600 screen
     *                   *
     *                   *
     *         o         * y=299.0
     *        _|_        * }-100.0 vertical offset
     *       |___|       * }-190.0 height
     *                   * }- 10.0 margin
     *********************/

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent! as RenderBox;
    expect(tip.size.height, equals(190.0));
    expect(tip.localToGlobal(tip.size.topLeft(Offset.zero)).dy, equals(399.0));
    expect(tip.localToGlobal(tip.size.bottomRight(Offset.zero)).dy, equals(589.0));
  });

  testWidgets('Tooltip verticalOffset, preferBelow; center preferBelow fits - ThemeData.tooltipTheme',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              height: 190.0,
              padding: EdgeInsets.zero,
              verticalOffset: 100.0,
              preferBelow: true,
            ),
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 400.0,
                        top: 300.0,
                        child: Tooltip(
                          key: key,
                          message: tooltipText,
                          child: const SizedBox(
                            width: 0.0,
                            height: 0.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pumpAndSettle(); // faded in, show timer started (and at 0.0)

    /********************* 800x600 screen
     *                   *
     *                   *
     *         o         * y=300.0
     *        _|_        * }-100.0 vertical offset
     *       |___|       * }-190.0 height
     *                   * }- 10.0 margin
     *********************/

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent! as RenderBox;
    expect(tip.size.height, equals(190.0));
    expect(tip.localToGlobal(tip.size.topLeft(Offset.zero)).dy, equals(400.0));
    expect(tip.localToGlobal(tip.size.bottomRight(Offset.zero)).dy, equals(590.0));
  });

  testWidgets('Tooltip verticalOffset, preferBelow; center prefer below fits - TooltipTheme',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TooltipTheme(
          data: const TooltipThemeData(
            height: 190.0,
            padding: EdgeInsets.zero,
            verticalOffset: 100.0,
            preferBelow: true,
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 400.0,
                        top: 300.0,
                        child: Tooltip(
                          key: key,
                          message: tooltipText,
                          child: const SizedBox(
                            width: 0.0,
                            height: 0.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pumpAndSettle(); // faded in, show timer started (and at 0.0)

    /********************* 800x600 screen
     *                   *
     *                   *
     *         o         * y=300.0
     *        _|_        * }-100.0 vertical offset
     *       |___|       * }-190.0 height
     *                   * }- 10.0 margin
     *********************/

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent! as RenderBox;
    expect(tip.size.height, equals(190.0));
    expect(tip.localToGlobal(tip.size.topLeft(Offset.zero)).dy, equals(400.0));
    expect(tip.localToGlobal(tip.size.bottomRight(Offset.zero)).dy, equals(590.0));
  });

  testWidgets('Tooltip margin - ThemeData', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) {
                return Theme(
                  data: ThemeData(
                    tooltipTheme: const TooltipThemeData(
                      padding: EdgeInsets.zero,
                      margin: EdgeInsets.all(_customPaddingValue),
                    ),
                  ),
                  child: Tooltip(
                    key: key,
                    message: tooltipText,
                    child: const SizedBox(
                      width: 0.0,
                      height: 0.0,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    final RenderBox tip =
        tester.renderObject(find.text(tooltipText)).parent!.parent!.parent!.parent!.parent! as RenderBox;
    final RenderBox tooltipContent = tester.renderObject(find.text(tooltipText));

    final Offset topLeftTipInGlobal = tip.localToGlobal(tip.size.topLeft(Offset.zero));
    final Offset topLeftTooltipContentInGlobal = tooltipContent.localToGlobal(tooltipContent.size.topLeft(Offset.zero));
    expect(topLeftTooltipContentInGlobal.dx, topLeftTipInGlobal.dx + _customPaddingValue);
    expect(topLeftTooltipContentInGlobal.dy, topLeftTipInGlobal.dy + _customPaddingValue);

    final Offset topRightTipInGlobal = tip.localToGlobal(tip.size.topRight(Offset.zero));
    final Offset topRightTooltipContentInGlobal =
        tooltipContent.localToGlobal(tooltipContent.size.topRight(Offset.zero));
    expect(topRightTooltipContentInGlobal.dx, topRightTipInGlobal.dx - _customPaddingValue);
    expect(topRightTooltipContentInGlobal.dy, topRightTipInGlobal.dy + _customPaddingValue);

    final Offset bottomLeftTipInGlobal = tip.localToGlobal(tip.size.bottomLeft(Offset.zero));
    final Offset bottomLeftTooltipContentInGlobal =
        tooltipContent.localToGlobal(tooltipContent.size.bottomLeft(Offset.zero));
    expect(bottomLeftTooltipContentInGlobal.dx, bottomLeftTipInGlobal.dx + _customPaddingValue);
    expect(bottomLeftTooltipContentInGlobal.dy, bottomLeftTipInGlobal.dy - _customPaddingValue);

    final Offset bottomRightTipInGlobal = tip.localToGlobal(tip.size.bottomRight(Offset.zero));
    final Offset bottomRightTooltipContentInGlobal =
        tooltipContent.localToGlobal(tooltipContent.size.bottomRight(Offset.zero));
    expect(bottomRightTooltipContentInGlobal.dx, bottomRightTipInGlobal.dx - _customPaddingValue);
    expect(bottomRightTooltipContentInGlobal.dy, bottomRightTipInGlobal.dy - _customPaddingValue);
  });

  testWidgets('Tooltip margin - TooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) {
                return TooltipTheme(
                  data: const TooltipThemeData(
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.all(_customPaddingValue),
                  ),
                  child: Tooltip(
                    key: key,
                    message: tooltipText,
                    child: const SizedBox(
                      width: 0.0,
                      height: 0.0,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    final RenderBox tip =
        tester.renderObject(find.text(tooltipText)).parent!.parent!.parent!.parent!.parent! as RenderBox;
    final RenderBox tooltipContent = tester.renderObject(find.text(tooltipText));

    final Offset topLeftTipInGlobal = tip.localToGlobal(tip.size.topLeft(Offset.zero));
    final Offset topLeftTooltipContentInGlobal = tooltipContent.localToGlobal(tooltipContent.size.topLeft(Offset.zero));
    expect(topLeftTooltipContentInGlobal.dx, topLeftTipInGlobal.dx + _customPaddingValue);
    expect(topLeftTooltipContentInGlobal.dy, topLeftTipInGlobal.dy + _customPaddingValue);

    final Offset topRightTipInGlobal = tip.localToGlobal(tip.size.topRight(Offset.zero));
    final Offset topRightTooltipContentInGlobal =
        tooltipContent.localToGlobal(tooltipContent.size.topRight(Offset.zero));
    expect(topRightTooltipContentInGlobal.dx, topRightTipInGlobal.dx - _customPaddingValue);
    expect(topRightTooltipContentInGlobal.dy, topRightTipInGlobal.dy + _customPaddingValue);

    final Offset bottomLeftTipInGlobal = tip.localToGlobal(tip.size.bottomLeft(Offset.zero));
    final Offset bottomLeftTooltipContentInGlobal =
        tooltipContent.localToGlobal(tooltipContent.size.bottomLeft(Offset.zero));
    expect(bottomLeftTooltipContentInGlobal.dx, bottomLeftTipInGlobal.dx + _customPaddingValue);
    expect(bottomLeftTooltipContentInGlobal.dy, bottomLeftTipInGlobal.dy - _customPaddingValue);

    final Offset bottomRightTipInGlobal = tip.localToGlobal(tip.size.bottomRight(Offset.zero));
    final Offset bottomRightTooltipContentInGlobal =
        tooltipContent.localToGlobal(tooltipContent.size.bottomRight(Offset.zero));
    expect(bottomRightTooltipContentInGlobal.dx, bottomRightTipInGlobal.dx - _customPaddingValue);
    expect(bottomRightTooltipContentInGlobal.dy, bottomRightTipInGlobal.dy - _customPaddingValue);
  });

  testWidgets('Tooltip message textStyle - ThemeData.tooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        tooltipTheme: const TooltipThemeData(
          textStyle: TextStyle(
            color: Colors.orange,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      home: Tooltip(
        key: key,
        message: tooltipText,
        child: Container(
          width: 100.0,
          height: 100.0,
          color: Colors.green[500],
        ),
      ),
    ));
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    final TextStyle textStyle = tester.widget<Text>(find.text(tooltipText)).style!;
    expect(textStyle.color, Colors.orange);
    expect(textStyle.fontFamily, null);
    expect(textStyle.decoration, TextDecoration.underline);
  });

  testWidgets('Tooltip message textStyle - TooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: TooltipTheme(
        data: const TooltipThemeData(),
        child: Tooltip(
          textStyle: const TextStyle(
            color: Colors.orange,
            decoration: TextDecoration.underline,
          ),
          key: key,
          message: tooltipText,
          child: Container(
            width: 100.0,
            height: 100.0,
            color: Colors.green[500],
          ),
        ),
      ),
    ));
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    final TextStyle textStyle = tester.widget<Text>(find.text(tooltipText)).style!;
    expect(textStyle.color, Colors.orange);
    expect(textStyle.fontFamily, null);
    expect(textStyle.decoration, TextDecoration.underline);
  });

  testWidgets('Tooltip decoration - ThemeData.tooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    const Decoration customDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: Color(0x80800000),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              decoration: customDecoration,
            ),
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Tooltip(
                    key: key,
                    message: tooltipText,
                    child: const SizedBox(
                      width: 0.0,
                      height: 0.0,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent!.parent!.parent!.parent! as RenderBox;

    expect(tip.size.height, equals(32.0));
    expect(tip.size.width, equals(74.0));
    expect(
        tip,
        paints
          ..path(
            color: const Color(0x80800000),
          ));
  });

  testWidgets('Tooltip decoration - TooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    const Decoration customDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: Color(0x80800000),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TooltipTheme(
          data: const TooltipThemeData(decoration: customDecoration),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Tooltip(
                    key: key,
                    message: tooltipText,
                    child: const SizedBox(
                      width: 0.0,
                      height: 0.0,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

    final RenderBox tip = tester.renderObject(find.text(tooltipText)).parent!.parent!.parent!.parent! as RenderBox;

    expect(tip.size.height, equals(32.0));
    expect(tip.size.width, equals(74.0));
    expect(
        tip,
        paints
          ..path(
            color: const Color(0x80800000),
          ));
  });

  testWidgets('Tooltip height and padding - ThemeData.tooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    const double customTooltipHeight = 100.0;
    const double customPaddingVal = 20.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              height: customTooltipHeight,
              padding: EdgeInsets.all(customPaddingVal),
            ),
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Tooltip(
                    key: key,
                    message: tooltipText,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pumpAndSettle();

    final RenderBox tip = tester.renderObject(find.ancestor(
      of: find.text(tooltipText),
      matching: find.byType(Padding).first, // select [Tooltip.padding] instead of [Tooltip.margin]
    ));
    final RenderBox content = tester.renderObject(find.ancestor(
      of: find.text(tooltipText),
      matching: find.byType(Center),
    ));

    expect(tip.size.height, equals(customTooltipHeight));
    expect(content.size.height, equals(customTooltipHeight - 2 * customPaddingVal));
    expect(content.size.width, equals(tip.size.width - 2 * customPaddingVal));
  });

  testWidgets('Tooltip height and padding - TooltipTheme', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    const double customTooltipHeight = 100.0;
    const double customPaddingValue = 20.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TooltipTheme(
          data: const TooltipThemeData(
            height: customTooltipHeight,
            padding: EdgeInsets.all(customPaddingValue),
          ),
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) {
                  return Tooltip(
                    key: key,
                    message: tooltipText,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    _ensureTooltipVisible(key);
    await tester.pumpAndSettle();

    final RenderBox tip = tester.renderObject(find.ancestor(
      of: find.text(tooltipText),
      matching: find.byType(Padding).first, // select [Tooltip.padding] instead of [Tooltip.margin]
    ));
    final RenderBox content = tester.renderObject(find.ancestor(
      of: find.text(tooltipText),
      matching: find.byType(Center),
    ));

    expect(tip.size.height, equals(customTooltipHeight));
    expect(content.size.height, equals(customTooltipHeight - 2 * customPaddingValue));
    expect(content.size.width, equals(tip.size.width - 2 * customPaddingValue));
  });

  testWidgets('Tooltip waitDuration - ThemeData.tooltipTheme', (WidgetTester tester) async {
    const Duration customWaitDuration = Duration(milliseconds: 500);
    final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(1.0, 1.0));
    await tester.pump();
    await gesture.moveTo(Offset.zero);

    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              waitDuration: customWaitDuration,
            ),
          ),
          child: const Center(
            child: Tooltip(
              message: tooltipText,
              child: SizedBox(
                width: 100.0,
                height: 100.0,
              ),
            ),
          ),
        ),
      ),
    );

    final Finder tooltip = find.byType(Tooltip);
    await gesture.moveTo(Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(tooltip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(tooltipText), findsNothing); // Should not appear yet
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(tooltipText), findsOneWidget); // Should appear after customWaitDuration

    await gesture.moveTo(Offset.zero);
    await tester.pump();

    // Wait for it to disappear.
    await tester.pump(customWaitDuration);
    expect(find.text(tooltipText), findsNothing);
  });

  testWidgets('Tooltip waitDuration - TooltipTheme', (WidgetTester tester) async {
    const Duration customWaitDuration = Duration(milliseconds: 500);
    final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(1.0, 1.0));
    await tester.pump();
    await gesture.moveTo(Offset.zero);

    await tester.pumpWidget(
      const MaterialApp(
        home: TooltipTheme(
          data: TooltipThemeData(waitDuration: customWaitDuration),
          child: Center(
            child: Tooltip(
              message: tooltipText,
              child: SizedBox(
                width: 100.0,
                height: 100.0,
              ),
            ),
          ),
        ),
      ),
    );

    final Finder tooltip = find.byType(Tooltip);
    await gesture.moveTo(Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(tooltip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(tooltipText), findsNothing); // Should not appear yet
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(tooltipText), findsOneWidget); // Should appear after customWaitDuration

    await gesture.moveTo(Offset.zero);
    await tester.pump();

    // Wait for it to disappear.
    await tester.pump(customWaitDuration); // Should disappear after customWaitDuration
    expect(find.text(tooltipText), findsNothing);
  });

  testWidgets('Tooltip showDuration - ThemeData.tooltipTheme', (WidgetTester tester) async {
    const Duration customShowDuration = Duration(milliseconds: 3000);
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(
              showDuration: customShowDuration,
            ),
          ),
          child: const Center(
            child: Tooltip(
              message: tooltipText,
              child: SizedBox(
                width: 100.0,
                height: 100.0,
              ),
            ),
          ),
        ),
      ),
    );

    final Finder tooltip = find.byType(Tooltip);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(tooltip));
    await tester.pump();
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    expect(find.text(tooltipText), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000)); // Tooltip should remain
    expect(find.text(tooltipText), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle(); // Tooltip should fade out after
    expect(find.text(tooltipText), findsNothing);
  });

  testWidgets('Tooltip showDuration - TooltipTheme', (WidgetTester tester) async {
    const Duration customShowDuration = Duration(milliseconds: 3000);
    await tester.pumpWidget(
      const MaterialApp(
        home: TooltipTheme(
          data: TooltipThemeData(showDuration: customShowDuration),
          child: Center(
            child: Tooltip(
              message: tooltipText,
              child: SizedBox(
                width: 100.0,
                height: 100.0,
              ),
            ),
          ),
        ),
      ),
    );

    final Finder tooltip = find.byType(Tooltip);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(tooltip));
    await tester.pump();
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    expect(find.text(tooltipText), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000)); // Tooltip should remain
    expect(find.text(tooltipText), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle(); // Tooltip should fade out after
    expect(find.text(tooltipText), findsNothing);
  });

  testWidgets('Tooltip triggerMode - ThemeData.triggerMode', (WidgetTester tester) async {
    const TooltipTriggerMode triggerMode = TooltipTriggerMode.tap;
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(
            tooltipTheme: const TooltipThemeData(triggerMode: triggerMode),
          ),
          child: const Center(
            child: Tooltip(
              message: tooltipText,
              child: SizedBox(width: 100.0, height: 100.0),
            ),
          ),
        ),
      ),
    );

    final Finder tooltip = find.byType(Tooltip);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(tooltip));
    await gesture.up();
    await tester.pump();
    expect(find.text(tooltipText), findsOneWidget); // Tooltip should show immediately after tap
  });

  testWidgets('Tooltip triggerMode - TooltipTheme', (WidgetTester tester) async {
    const TooltipTriggerMode triggerMode = TooltipTriggerMode.tap;
    await tester.pumpWidget(
      const MaterialApp(
        home: TooltipTheme(
          data: TooltipThemeData(triggerMode: triggerMode),
          child: Center(
            child: Tooltip(
              message: tooltipText,
              child: SizedBox(width: 100.0, height: 100.0),
            ),
          ),
        ),
      ),
    );

    final Finder tooltip = find.byType(Tooltip);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(tooltip));
    await gesture.up();
    await tester.pump();
    expect(find.text(tooltipText), findsOneWidget); // Tooltip should show immediately after tap
  });

  testWidgets('Semantics included by default - ThemeData.tooltipTheme', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: const Center(
          child: Tooltip(
            message: 'Foo',
            child: Text('Bar'),
          ),
        ),
      ),
    );

    expect(
        semantics,
        hasSemantics(
            TestSemantics.root(
              children: <TestSemantics>[
                TestSemantics.rootChild(
                  children: <TestSemantics>[
                    TestSemantics(
                      children: <TestSemantics>[
                        TestSemantics(
                          flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                          children: <TestSemantics>[
                            TestSemantics(
                              label: 'Foo\nBar',
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ignoreRect: true,
            ignoreId: true,
            ignoreTransform: true));

    semantics.dispose();
  });

  testWidgets('Semantics included by default - TooltipTheme', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: TooltipTheme(
          data: TooltipThemeData(),
          child: Center(
            child: Tooltip(
              message: 'Foo',
              child: Text('Bar'),
            ),
          ),
        ),
      ),
    );

    expect(
        semantics,
        hasSemantics(
            TestSemantics.root(
              children: <TestSemantics>[
                TestSemantics.rootChild(
                  children: <TestSemantics>[
                    TestSemantics(
                      children: <TestSemantics>[
                        TestSemantics(
                          flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                          children: <TestSemantics>[
                            TestSemantics(
                              label: 'Foo\nBar',
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ignoreRect: true,
            ignoreId: true,
            ignoreTransform: true));

    semantics.dispose();
  });

  testWidgets('Semantics excluded - ThemeData.tooltipTheme', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          tooltipTheme: const TooltipThemeData(
            excludeFromSemantics: true,
          ),
        ),
        home: const Center(
          child: Tooltip(
            message: 'Foo',
            child: Text('Bar'),
          ),
        ),
      ),
    );

    expect(
        semantics,
        hasSemantics(
            TestSemantics.root(
              children: <TestSemantics>[
                TestSemantics.rootChild(
                  children: <TestSemantics>[
                    TestSemantics(
                      children: <TestSemantics>[
                        TestSemantics(
                          flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                          children: <TestSemantics>[
                            TestSemantics(
                              label: 'Bar',
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ignoreRect: true,
            ignoreId: true,
            ignoreTransform: true));

    semantics.dispose();
  });

  testWidgets('Semantics excluded - TooltipTheme', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: TooltipTheme(
          data: TooltipThemeData(excludeFromSemantics: true),
          child: Center(
            child: Tooltip(
              message: 'Foo',
              child: Text('Bar'),
            ),
          ),
        ),
      ),
    );

    expect(
        semantics,
        hasSemantics(
            TestSemantics.root(
              children: <TestSemantics>[
                TestSemantics.rootChild(
                  children: <TestSemantics>[
                    TestSemantics(
                      children: <TestSemantics>[
                        TestSemantics(
                          flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                          children: <TestSemantics>[
                            TestSemantics(
                              label: 'Bar',
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ignoreRect: true,
            ignoreId: true,
            ignoreTransform: true));

    semantics.dispose();
  });

  testWidgets('has semantic events by default - ThemeData.tooltipTheme', (WidgetTester tester) async {
    final List<dynamic> semanticEvents = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility,
        (dynamic message) async {
      semanticEvents.add(message);
    });
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Center(
          child: Tooltip(
            message: 'Foo',
            child: Container(
              width: 100.0,
              height: 100.0,
              color: Colors.green[500],
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(Tooltip));
    final RenderObject object = tester.firstRenderObject(find.byType(Tooltip));

    expect(
        semanticEvents,
        unorderedEquals(<dynamic>[
          <String, dynamic>{
            'type': 'longPress',
            'nodeId': findDebugSemantics(object).id,
            'data': <String, dynamic>{},
          },
          <String, dynamic>{
            'type': 'tooltip',
            'data': <String, dynamic>{
              'message': 'Foo',
            },
          },
        ]));
    semantics.dispose();
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null);
  });

  testWidgets('has semantic events by default - TooltipTheme', (WidgetTester tester) async {
    final List<dynamic> semanticEvents = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility,
        (dynamic message) async {
      semanticEvents.add(message);
    });
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: TooltipTheme(
          data: const TooltipThemeData(),
          child: Center(
            child: Tooltip(
              message: 'Foo',
              child: Container(
                width: 100.0,
                height: 100.0,
                color: Colors.green[500],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(Tooltip));
    final RenderObject object = tester.firstRenderObject(find.byType(Tooltip));

    expect(
        semanticEvents,
        unorderedEquals(<dynamic>[
          <String, dynamic>{
            'type': 'longPress',
            'nodeId': findDebugSemantics(object).id,
            'data': <String, dynamic>{},
          },
          <String, dynamic>{
            'type': 'tooltip',
            'data': <String, dynamic>{
              'message': 'Foo',
            },
          },
        ]));
    semantics.dispose();
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null);
  });

  testWidgets('default Tooltip debugFillProperties', (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();

    const Tooltip(message: 'message').debugFillProperties(builder);

    final List<String> description = builder.properties
        .where((DiagnosticsNode node) => !node.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode node) => node.toString())
        .toList();

    expect(description, <String>[
      '"message"',
    ]);
  });
}

SemanticsNode findDebugSemantics(RenderObject object) {
  if (object.debugSemantics != null) return object.debugSemantics!;
  return findDebugSemantics(object.parent! as RenderObject);
}
