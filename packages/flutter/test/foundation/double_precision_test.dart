// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter/foundation.dart';
import '../flutter_test_alternative.dart';

void main() {
  test('debugFormatDouble formats doubles', () {
    expect(debugFormatDouble(1), '1.0');
    expect(debugFormatDouble(1.1), '1.1');
    expect(debugFormatDouble(null), 'null');
  });

  test('debugDoublePrecision can control double precision', () {
    debugDoublePrecision = 3;
    expect(debugFormatDouble(1), '1.00');
    debugDoublePrecision = null;
  });
}
