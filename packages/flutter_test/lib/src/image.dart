// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

final Map<int, ui.Image> _cache = <int, ui.Image>{};

/// Creates an arbitrarily sized image for testing.
///
/// If [color] isn't provided, fully transparent black color is used.
/// If the [cache] parameter is set to true, the image will be cached for the
/// rest of this suite. This is normally desirable, assuming a test suite uses
/// images with the same dimensions in most tests, as it will save on memory
/// usage and CPU time over the course of the suite. However, it should be
/// avoided for images that are used only once in a test suite, especially if
/// the image is large, as it will require holding on to the memory for that
/// image for the duration of the suite.
ui.Image createTestImage({
  int width = 1,
  int height = 1,
  ui.Color color = const ui.Color(0x00000000),
  bool cache = true,
}) {
  assert(width != null && width > 0);
  assert(height != null && height > 0);
  assert(cache != null);

  final int cacheKey = Object.hash(width, height);
  if (cache && _cache.containsKey(cacheKey)) {
    return _cache[cacheKey]!.clone();
  }

  final ui.Image image = _createImage(width, height, color);
  if (cache) {
    _cache[cacheKey] = image.clone();
  }
  return image;
}

ui.Image _createImage(int width, int height, ui.Color color) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas pictureCanvas = ui.Canvas(recorder);
  pictureCanvas.drawColor(color, ui.BlendMode.src);
  final ui.Picture picture = recorder.endRecording();
  return picture.toImageSync(width, height);
}
