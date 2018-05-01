// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'system_channels.dart';

/// Specifies a particular device orientation.
///
/// To determine which values correspond to which orientations, first position
/// the device in its default orientation (this is the orientation that the
/// system first uses for its boot logo, or the orientation in which the
/// hardware logos or markings are upright, or the orientation in which the
/// cameras are at the top). If this is a portrait orientation, then this is
/// [portraitUp]. Otherwise, it's [landscapeLeft]. As you rotate the device by
/// 90 degrees in a counter-clockwise direction around the axis that pierces the
/// screen, you step through each value in this enum in the order given.
///
/// For a device with a landscape default orientation, the orientation obtained
/// by rotating the device 90 degrees clockwise from its default orientation is
/// [portraitUp].
///
/// Used by [SystemChrome.setPreferredOrientations].
enum DeviceOrientation {
  /// If the device shows its boot logo in portrait, then the boot logo is shown
  /// in [portraitUp]. Otherwise, the device shows its boot logo in landscape
  /// and this orientation is obtained by rotating the device 90 degrees
  /// clockwise from its boot orientation.
  portraitUp,

  /// The orientation that is 90 degrees clockwise from [portraitUp].
  ///
  /// If the device shows its boot logo in landscape, then the boot logo is
  /// shown in [landscapeLeft].
  landscapeLeft,

  /// The orientation that is 180 degrees from [portraitUp].
  portraitDown,

  /// The orientation that is 90 degrees counterclockwise from [portraitUp].
  landscapeRight,
}

/// Specifies a description of the application that is pertinent to the
/// embedder's application switcher (also known as "recent tasks") user
/// interface.
///
/// Used by [SystemChrome.setApplicationSwitcherDescription].
@immutable
class ApplicationSwitcherDescription {
  /// Creates an ApplicationSwitcherDescription.
  const ApplicationSwitcherDescription({ this.label, this.primaryColor });

  /// A label and description of the current state of the application.
  final String label;

  /// The application's primary color.
  ///
  /// This may influence the color that the operating system uses to represent
  /// the application.
  final int primaryColor;
}

/// Specifies a system overlay at a particular location.
///
/// Used by [SystemChrome.setEnabledSystemUIOverlays].
enum SystemUiOverlay {
  /// The status bar provided by the embedder on the top of the application
  /// surface, if any.
  top,

  /// The status bar provided by the embedder on the bottom of the application
  /// surface, if any.
  bottom,
}

/// Specifies a dark vs light preference for certain system chrome options.
enum SystemChromeTheme {
  /// Whether the setting should be drawn to be compatible with a light color.
  light,
  /// Whether the setting should be drawn to be compatible with a dark color.
  dark,
}

/// Specifies a preference for the style of the system overlays.
///
/// Used by [SystemChrome.setSystemUIOverlayStyle].
class SystemUiOverlayStyle {
  /// System overlays should be drawn with a light color. Intended for
  /// applications with a dark background.
  static const SystemUiOverlayStyle light = const SystemUiOverlayStyle(
    navigationBarColor: 0xFF000000,
    navigationDividerColor: null,
    statusBarColor: null,
    navigationIconTheme: SystemChromeTheme.light,
    statusBarTheme: SystemChromeTheme.light,
  );

  /// System overlays should be drawn with a dark color. Intended for
  /// applications with a light background.
  static const SystemUiOverlayStyle dark = const SystemUiOverlayStyle(
    navigationBarColor: 0xFFFFFFFF,
    navigationDividerColor: null,
    statusBarColor: null,
    navigationIconTheme: SystemChromeTheme.dark,
    statusBarTheme: SystemChromeTheme.dark,
  );

  /// Creates a new [SystemUiOverlayStyle].
  const SystemUiOverlayStyle({
    this.navigationBarColor,
    this.navigationDividerColor,
    this.statusBarColor,
    this.statusBarTheme,
    this.navigationIconTheme,
  });

  /// The color of the bottom navigation bar.
  /// 
  /// Only honored in Android versions O and greater.
  final int navigationBarColor;

  /// The color of the divider between the bottom navigation and content.
  /// 
  /// Only honored in Android versions P and greater.
  final int navigationDividerColor;

  /// The color of top status bar.
  /// 
  /// Only honored in Android version O and greater.
  final int statusBarColor;

  /// The theme of top status bar.
  /// 
  /// Only honored in iOS and Android version O and greater.
  final SystemChromeTheme statusBarTheme;

  /// The theme of the navigation bar buttons.
  /// 
  /// Only honored in Android versions O and greater.
  final SystemChromeTheme navigationIconTheme;

  /// Convert this event to a map for serialization.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'navigationBarColor': navigationBarColor,
      'navigationDividerColor': navigationDividerColor,
      'statusBarColor': statusBarColor,
      'statusBarTheme': statusBarTheme?.toString(),
      'navigationIconTheme': navigationIconTheme?.toString(),
    };
  }

  @override
  int get hashCode => hashValues(navigationBarColor, navigationDividerColor, statusBarColor, statusBarTheme, statusBarColor);

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final SystemUiOverlayStyle typedOther = other;
    return typedOther.navigationBarColor == navigationBarColor
      && typedOther.navigationDividerColor == navigationDividerColor
      && typedOther.statusBarColor == statusBarColor
      && typedOther.statusBarTheme == statusBarTheme
      && typedOther.navigationIconTheme == navigationIconTheme;
  }
}

List<String> _stringify(List<dynamic> list) {
  final List<String> result = <String>[];
  for (dynamic item in list)
    result.add(item.toString());
  return result;
}

/// Controls specific aspects of the operating system's graphical interface and
/// how it interacts with the application.
class SystemChrome {
  SystemChrome._();

  /// Specifies the set of orientations the application interface can
  /// be displayed in.
  ///
  /// The `orientation` argument is a list of [DeviceOrientation] enum values.
  /// The empty list causes the application to defer to the operating system
  /// default.
  static Future<Null> setPreferredOrientations(List<DeviceOrientation> orientations) async {
    await SystemChannels.platform.invokeMethod(
      'SystemChrome.setPreferredOrientations',
      _stringify(orientations),
    );
  }

  /// Specifies the description of the current state of the application as it
  /// pertains to the application switcher (also known as "recent tasks").
  ///
  /// Any part of the description that is unsupported on the current platform
  /// will be ignored.
  static Future<Null> setApplicationSwitcherDescription(ApplicationSwitcherDescription description) async {
    await SystemChannels.platform.invokeMethod(
      'SystemChrome.setApplicationSwitcherDescription',
      <String, dynamic>{
        'label': description.label,
        'primaryColor': description.primaryColor,
      },
    );
  }

  /// Specifies the set of system overlays to have visible when the application
  /// is running.
  ///
  /// The `overlays` argument is a list of [SystemUiOverlay] enum values
  /// denoting the overlays to show.
  ///
  /// If a particular overlay is unsupported on the platform, enabling or
  /// disabling that overlay will be ignored.
  static Future<Null> setEnabledSystemUIOverlays(List<SystemUiOverlay> overlays) async {
    await SystemChannels.platform.invokeMethod(
      'SystemChrome.setEnabledSystemUIOverlays',
      _stringify(overlays),
    );
 }

  /// Specifies the style to use for the system overlays that are visible (if
  /// any).
  ///
  /// This method will schedule the embedder update to be run in a microtask.
  /// Any subsequent calls to this method during the current event loop will
  /// overwrite the pending value, such that only the last specified value takes
  /// effect.
  ///
  /// Call this API in code whose lifecycle matches that of the desired
  /// system UI styles. For instance, to change the system UI style on a new
  /// page, consider calling when pushing/popping a new [PageRoute].
  ///
  /// However, the [AppBar] widget automatically sets the system overlay style
  /// based on its [AppBar.brightness], so configure that instead of calling
  /// this method directly. Likewise, do the same for [CupertinoNavigationBar]
  /// via [CupertinoNavigationBar.backgroundColor].
  ///
  /// If a particular style is not supported on the platform, selecting it will
  /// have no effect.
  ///
  /// ## Sample Code
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  ///   return /* ... */;
  /// }
  /// ```
  static void setSystemUIOverlayStyle(SystemUiOverlayStyle style) {
    assert(style != null);

    if (_pendingStyle != null) {
      // The microtask has already been queued; just update the pending value.
      _pendingStyle = style;
      return;
    }

    if (style == _latestStyle) {
      // Trivial success: no microtask has been queued and the given style is
      // already in effect, so no need to queue a microtask.
      return;
    }

    _pendingStyle = style;
    scheduleMicrotask(() {
      assert(_pendingStyle != null);
      if (_pendingStyle != _latestStyle) {
        SystemChannels.platform.invokeMethod(
          'SystemChrome.setSystemUIOverlayStyle',
          _pendingStyle.toMap(),
        );
        _latestStyle = _pendingStyle;
      }
      _pendingStyle = null;
    });
  }

  static SystemUiOverlayStyle _pendingStyle;
  static SystemUiOverlayStyle _latestStyle;
}
