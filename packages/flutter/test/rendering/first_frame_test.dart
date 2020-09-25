// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../flutter_test_alternative.dart';

void main() {
  test('Flutter dispatches first frame event on the web only', () async {
    final Completer<void> completer = Completer<void>();
    final TestRenderBinding binding = TestRenderBinding();
    const MethodChannel firstFrameChannel = MethodChannel('flutter/service_worker');
    firstFrameChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      completer.complete();
    });

    binding.handleBeginFrame(Duration.zero);
    binding.handleDrawFrame();

    await expectLater(completer.future, completes);
  }, skip: !kIsWeb);
}

class TestRenderBinding extends BindingBase with SchedulerBinding, ServicesBinding, GestureBinding, SemanticsBinding, RendererBinding {
  @override
  void initInstances() {
    super.initInstances();
  }
}
