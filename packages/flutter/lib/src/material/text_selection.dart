// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'flat_button.dart';
import 'material.dart';
import 'theme.dart';

const double _kHandleSize = 22.0; // pixels
const double _kToolbarScreenPadding = 8.0; // pixels

/// Manages a copy/paste text selection toolbar.
class _TextSelectionToolbar extends StatelessWidget {
  const _TextSelectionToolbar(
    this.delegate,
    this._handleCut,
    this._handleCopy,
    this._handlePaste,
    this._handleSelectAll,
    {Key key}) : super(key: key);

  final TextSelectionDelegate delegate;
  TextEditingValue get value => delegate.textEditingValue;

  final VoidCallback _handleCut;
  final VoidCallback _handleCopy;
  final VoidCallback _handlePaste;
  final VoidCallback _handleSelectAll;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];

    if (!value.selection.isCollapsed) {
      items.add(new FlatButton(child: const Text('CUT'), onPressed: _handleCut));
      items.add(new FlatButton(child: const Text('COPY'), onPressed: _handleCopy));
    }
    items.add(new FlatButton(
      child: const Text('PASTE'),
      // TODO(mpcomplete): This should probably be grayed-out if there is nothing to paste.
      onPressed: _handlePaste,
    ));
    if (value.text.isNotEmpty) {
      if (value.selection.isCollapsed)
        items.add(new FlatButton(child: const Text('SELECT ALL'), onPressed: _handleSelectAll));
    }

    return new Material(
      elevation: 1.0,
      child: new Container(
        height: 44.0,
        child: new Row(mainAxisSize: MainAxisSize.min, children: items)
      )
    );
  }
}

/// Centers the toolbar around the given position, ensuring that it remains on
/// screen.
class _TextSelectionToolbarLayout extends SingleChildLayoutDelegate {
  _TextSelectionToolbarLayout(this.screenSize, this.globalEditableRegion, this.position);

  /// The size of the screen at the time that the toolbar was last laid out.
  final Size screenSize;

  /// Size and position of the editing region at the time the toolbar was last
  /// laid out, in global coordinates.
  final Rect globalEditableRegion;

  /// Anchor position of the toolbar, relative to the top left of the
  /// [globalEditableRegion].
  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Offset globalPosition = globalEditableRegion.topLeft + position;

    double x = globalPosition.dx - childSize.width / 2.0;
    double y = globalPosition.dy - childSize.height;

    if (x < _kToolbarScreenPadding)
      x = _kToolbarScreenPadding;
    else if (x + childSize.width > screenSize.width - _kToolbarScreenPadding)
      x = screenSize.width - childSize.width - _kToolbarScreenPadding;

    if (y < _kToolbarScreenPadding)
      y = _kToolbarScreenPadding;
    else if (y + childSize.height > screenSize.height - _kToolbarScreenPadding)
      y = screenSize.height - childSize.height - _kToolbarScreenPadding;

    return new Offset(x, y);
  }

  @override
  bool shouldRelayout(_TextSelectionToolbarLayout oldDelegate) {
    return position != oldDelegate.position;
  }
}

/// Draws a single text selection handle. The [type] determines where the handle
/// points (e.g. the [left] handle points up and to the right).
class _TextSelectionHandlePainter extends CustomPainter {
  _TextSelectionHandlePainter({ this.color });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = new Paint()..color = color;
    final double radius = size.width/2.0;
    canvas.drawCircle(new Offset(radius, radius), radius, paint);
    canvas.drawRect(new Rect.fromLTWH(0.0, 0.0, radius, radius), paint);
  }

  @override
  bool shouldRepaint(_TextSelectionHandlePainter oldPainter) {
    return color != oldPainter.color;
  }
}

class _MaterialTextSelectionControls extends TextSelectionControls {
  @override
  Size handleSize = const Size(_kHandleSize, _kHandleSize);

  /// Builder for material-style copy/paste text selection toolbar.
  @override
  Widget buildToolbar(BuildContext context, Rect globalEditableRegion, Offset position, TextSelectionDelegate delegate) {
    assert(debugCheckHasMediaQuery(context));
    return new ConstrainedBox(
      constraints: new BoxConstraints.tight(globalEditableRegion.size),
      child: new CustomSingleChildLayout(
        delegate: new _TextSelectionToolbarLayout(
          MediaQuery.of(context).size,
          globalEditableRegion,
          position,
        ),
        child: new _TextSelectionToolbar(
          delegate,
          () => handleCut(delegate),
          () => handleCopy(delegate),
          () => handlePaste(delegate),
          () => handleSelectAll(delegate),
        ),
      )
    );
  }

  /// Builder for material-style text selection handles.
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type) {
    final Widget handle = new SizedBox(
      width: _kHandleSize,
      height: _kHandleSize,
      child: new CustomPaint(
        painter: new _TextSelectionHandlePainter(
          color: Theme.of(context).textSelectionHandleColor
        )
      )
    );

    // [handle] is a circle, with a rectangle in the top left quadrant of that
    // circle (an onion pointing to 10:30). We rotate [handle] to point
    // straight up or up-right depending on the handle type.
    switch (type) {
      case TextSelectionHandleType.left:  // points up-right
        return new Transform(
          transform: new Matrix4.rotationZ(math.PI / 2.0),
          child: handle
        );
      case TextSelectionHandleType.right:  // points up-left
        return handle;
      case TextSelectionHandleType.collapsed:  // points up
        return new Transform(
          transform: new Matrix4.rotationZ(math.PI / 4.0),
          child: handle
        );
    }
    assert(type != null);
    return null;
  }
}

/// Text selection controls that follow the Material Design specification.
final TextSelectionControls materialTextSelectionControls = new _MaterialTextSelectionControls();
