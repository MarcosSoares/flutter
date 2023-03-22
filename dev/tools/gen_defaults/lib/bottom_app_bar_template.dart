// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'template.dart';

class BottomAppBarTemplate extends TokenTemplate {
  const BottomAppBarTemplate(super.blockName, super.fileName, super.tokens, {
    super.colorSchemePrefix = '_colors.',
  });

  @override
  String generate() => '''
class _${blockName}DefaultsM3 extends BottomAppBarTheme {
  _${blockName}DefaultsM3(this.context)
    : super(
      elevation: ${elevation('md.comp.bottom-app-bar.container')},
      height: ${tokens['md.comp.bottom-app-bar.container.height']},
    );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get color => ${componentColor('md.comp.bottom-app-bar.container')};

  @override
  Color? get surfaceTintColor => ${componentColor('md.comp.bottom-app-bar.container.surface-tint-layer')};

  @override
  Color? get shadowColor => Colors.transparent;
}
''';
}
