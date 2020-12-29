// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'button.dart';
import 'colors.dart';

const TextStyle _kToolbarButtonFontStyle = TextStyle(
  inherit: false,
  fontSize: 14.0,
  letterSpacing: -0.15,
  fontWeight: FontWeight.w400,
);

// Colors extracted from https://developer.apple.com/design/resources/.
// TODO(LongCatIsLooong): https://github.com/flutter/flutter/issues/41507.
const Color _kToolbarBackgroundColor = Color(0xEB202020);

// TODO(justinmc): Deduplicate this constant with cupertino/text_selection.dart.
// Values extracted from https://developer.apple.com/design/resources/.
// The height of the toolbar, including the arrow.
const double _kToolbarHeight = 43.0;

// Eyeballed value.
const EdgeInsets _kToolbarButtonPadding = EdgeInsets.symmetric(vertical: 10.0, horizontal: 18.0);
// TODO(justinmc): Deduplicate with cupertino/text_selection_toolbar.dart.
const Size _kToolbarArrowSize = Size(14.0, 7.0);

/// A button in the style of the iOS text selection toolbar buttons.
class CupertinoTextSelectionToolbarButton extends StatelessWidget {
  /// Create an instance of [CupertinoTextSelectionToolbarButton].
  const CupertinoTextSelectionToolbarButton({
    Key? key,
    required this.isArrowPointingDown,
    required this.child,
    this.onPressed,
  }) : super(key: key);

  /// The child of this button.
  ///
  /// Usually a [Text] or an [Icon].
  final Widget child;

  /// Called when this button is pressed.
  final VoidCallback? onPressed;

  // TODO(justinmc): Rethink isArrowPointingDown, is it needed?
  final bool isArrowPointingDown;

  /// Returns a [Text] widget in the style of the iOS text selection toolbar
  /// buttons, to be passed as [child].
  static Text getText(String string, [bool enabled = true]) {
    return Text(
      string,
      overflow: TextOverflow.ellipsis,
      style: _kToolbarButtonFontStyle.copyWith(
        color: enabled ? CupertinoColors.white : CupertinoColors.inactiveGray,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets arrowPadding = isArrowPointingDown
      ? EdgeInsets.only(bottom: _kToolbarArrowSize.height)
      : EdgeInsets.only(top: _kToolbarArrowSize.height);

    return CupertinoButton(
      child: child,
      borderRadius: null,
      color: _kToolbarBackgroundColor,
      disabledColor: _kToolbarBackgroundColor,
      minSize: _kToolbarHeight,
      onPressed: onPressed,
      padding: _kToolbarButtonPadding.add(arrowPadding),
      pressedOpacity: onPressed == null ? 1.0 : 0.7,
    );
  }
}
