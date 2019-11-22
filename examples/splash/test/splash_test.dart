// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splash/main.dart' as entrypoint;

void main() {
  testWidgets('Displays flutter logo', (WidgetTester tester) async {
    entrypoint.main();

    expect(find.byType(FlutterLogo), findsOneWidget);
  });
}
