// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rendering_tester.dart';

void main() {
  // Create non-const instances, otherwise tests pass even if the
  // operator override is incorrect.
  ViewConfiguration createViewConfiguration({
    Size size = const Size(20, 20),
    double devicePixelRatio = 2.0,
  }) {
    return ViewConfiguration(size: size, devicePixelRatio: devicePixelRatio);
  }

  group('RenderView', () {
    test('accounts for device pixel ratio in paintBounds', () {
      layout(RenderAspectRatio(aspectRatio: 1.0));
      pumpFrame();
      final Size logicalSize = renderer.renderView.configuration.size;
      final double devicePixelRatio = renderer.renderView.configuration.devicePixelRatio;
      final Size physicalSize = logicalSize * devicePixelRatio;
      expect(renderer.renderView.paintBounds, Offset.zero & physicalSize);
    });

    test('does not replace the root layer unnecessarily', () {
      final ui.FlutterView window = TestWindow(window: ui.window);
      final RenderView view = RenderView(
        configuration: createViewConfiguration(),
        window: window,
      );
      final PipelineOwner owner = PipelineOwner();
      owner.rootNode = view;
      view.prepareInitialFrame();
      final ContainerLayer firstLayer = view.debugLayer!;
      view.configuration = createViewConfiguration();
      expect(identical(view.debugLayer, firstLayer), true);

      view.configuration = createViewConfiguration(devicePixelRatio: 5.0);
      expect(identical(view.debugLayer, firstLayer), false);
    });
  });

  test('ViewConfiguration == and hashCode', () {
    final ViewConfiguration viewConfigurationA = createViewConfiguration();
    final ViewConfiguration viewConfigurationB = createViewConfiguration();
    final ViewConfiguration viewConfigurationC = createViewConfiguration(devicePixelRatio: 3.0);

    expect(viewConfigurationA == viewConfigurationB, true);
    expect(viewConfigurationA != viewConfigurationC, true);
    expect(viewConfigurationA.hashCode, viewConfigurationB.hashCode);
    expect(viewConfigurationA.hashCode != viewConfigurationC.hashCode, true);
  });
}
