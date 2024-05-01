// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

void main() {
  // Changes made in https://github.com/flutter/flutter/pull/145523
  ButtonBar();

  // Changes made in https://github.com/flutter/flutter/pull/145523
  ThemeData theme = ThemeData();
  theme = ThemeData(buttonBarTheme: ButtonBarThemeData());
}
