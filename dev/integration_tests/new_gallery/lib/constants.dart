// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Only put constants shared between files here.

import 'dart:typed_data';

// Height of the 'Gallery' header
const double galleryHeaderHeight = 64;

// The font size delta for headline4 font.
const double desktopDisplay1FontDelta = 16;

// The width of the settingsDesktop.
const double desktopSettingsWidth = 520;

// Sentinel value for the system text scale factor option.
const double systemTextScaleFactorOption = -1;

// The splash page animation duration.
const Duration splashPageAnimationDuration = Duration(milliseconds: 300);

// Half the splash page animation duration.
const Duration halfSplashPageAnimationDuration = Duration(milliseconds: 150);

// Duration for settings panel to open on mobile.
const Duration settingsPanelMobileAnimationDuration =
    Duration(milliseconds: 200);

// Duration for settings panel to open on desktop.
const Duration settingsPanelDesktopAnimationDuration =
    Duration(milliseconds: 600);

// Duration for home page elements to fade in.
const Duration entranceAnimationDuration = Duration(milliseconds: 200);

// The desktop top padding for a page's first header (e.g. Gallery, Settings)
const double firstHeaderDesktopTopPadding = 5.0;

// A transparent image used to avoid loading images when they are not needed.
final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x06,
  0x62,
  0x4B,
  0x47,
  0x44,
  0x00,
  0xFF,
  0x00,
  0xFF,
  0x00,
  0xFF,
  0xA0,
  0xBD,
  0xA7,
  0x93,
  0x00,
  0x00,
  0x00,
  0x09,
  0x70,
  0x48,
  0x59,
  0x73,
  0x00,
  0x00,
  0x0B,
  0x13,
  0x00,
  0x00,
  0x0B,
  0x13,
  0x01,
  0x00,
  0x9A,
  0x9C,
  0x18,
  0x00,
  0x00,
  0x00,
  0x07,
  0x74,
  0x49,
  0x4D,
  0x45,
  0x07,
  0xE6,
  0x03,
  0x10,
  0x17,
  0x07,
  0x1D,
  0x2E,
  0x5E,
  0x30,
  0x9B,
  0x00,
  0x00,
  0x00,
  0x0B,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0x60,
  0x00,
  0x02,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0xE2,
  0x26,
  0x05,
  0x9B,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
