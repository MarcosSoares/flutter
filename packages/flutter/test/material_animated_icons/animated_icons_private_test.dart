// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This is the test for the private implementation of animated icons.
// To make the private API accessible from the test we do not import the 
// material material_animated_icons library, but instead, this test file is an
// implementation of that library, using some of the parts of the real
// material_animated_icons, this give the test access to the private APIs.
library material_animated_icons;

import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

part '../../lib/src/material_animated_icons/animated_icons.dart';
part '../../lib/src/material_animated_icons/animated_icons_data.dart';
part '../../lib/src/material_animated_icons/data/menu_arrow.g.dart';

void main () {
  group('Interpolate points', () {
    test('- single point', () {
      final List<Point<double>> points = const <Point<double>>[
        const Point<double>(25.0, 1.0),
      ];
      expect(_interpolatePoint(points, 0.0), const Point<double>(25.0, 1.0));
      expect(_interpolatePoint(points, 0.5), const Point<double>(25.0, 1.0));
      expect(_interpolatePoint(points, 1.0), const Point<double>(25.0, 1.0));
    });

    test('- two points', () {
      final List<Point<double>> points = const <Point<double>>[
        const Point<double>(25.0, 1.0),
        const Point<double>(12.0, 12.0),
      ];
      expect(_interpolatePoint(points, 0.0), const Point<double>(25.0, 1.0));
      expect(_interpolatePoint(points, 0.5), const Point<double>(18.5, 6.5));
      expect(_interpolatePoint(points, 1.0), const Point<double>(12.0, 12.0));
    });

    test('- three points', () {
      final List<Point<double>> points = const <Point<double>>[
        const Point<double>(25.0, 1.0),
        const Point<double>(12.0, 12.0),
        const Point<double>(23.0, 9.0),
      ];
      expect(_interpolatePoint(points, 0.0), const Point<double>(25.0, 1.0));
      expect(_interpolatePoint(points, 0.25), const Point<double>(18.5, 6.5));
      expect(_interpolatePoint(points, 0.5), const Point<double>(12.0, 12.0));
      expect(_interpolatePoint(points, 0.75), const Point<double>(17.5, 10.5));
      expect(_interpolatePoint(points, 1.0), const Point<double>(23.0, 9.0));
    });
  });
}
