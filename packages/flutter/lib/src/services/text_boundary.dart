// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:characters/characters.dart' show CharacterRange;

import 'text_layout_metrics.dart';

// Examples can assume:
// late TextLayoutMetrics textLayout;
// late TextSpan text;
// bool isWhitespace(int? codeUnit) => true;

/// Signature for a predicate that takes an offset into a UTF-16 string, and a
/// boolean that indicates the search direction.
typedef UntilPredicate = bool Function(int offset, bool forward);

/// An interface for retrieving the logical text boundary (as opposed to the
/// visual boundary) at a given code unit offset in a document.
///
/// Either the [getTextBoundaryAt] method, or both the
/// [getLeadingTextBoundaryAt] method and the [getTrailingTextBoundaryAt] method
/// must be implemented.
abstract class TextBoundary {
  /// A constant constructor to enable subclass override.
  const TextBoundary();

  /// Returns the offset of the closest text boundary before or at the given
  /// `position`, or null if no boundaries can be found.
  ///
  /// The return value, if not null, is usually less than or equal to `position`.
  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0) {
      return null;
    }
    final int start = getTextBoundaryAt(position).start;
    return start >= 0 ? start : null;
  }

  /// Returns the offset of the closest text boundaries after the given `position`,
  /// or null if there is no boundaries can be found after `position`.
  ///
  /// The return value, if not null, is usually greater than `position`.
  int? getTrailingTextBoundaryAt(int position) {
    final int end = getTextBoundaryAt(max(0, position)).end;
    return end >= 0 ? end : null;
  }

  /// Returns the text boundary range that encloses the input position.
  ///
  /// The returned [TextRange] may contain `-1`, which indicates no boundaries
  /// can be found in that direction.
  TextRange getTextBoundaryAt(int position) {
    final int start = getLeadingTextBoundaryAt(position) ?? -1;
    final int end = getTrailingTextBoundaryAt(position) ?? -1;
    return TextRange(start: start, end: end);
  }
}

/// A [TextBoundary] subclass for retriving the range of the grapheme the given
/// `position` is in.
///
/// The class is implemented using the
/// [characters](https://pub.dev/packages/characters) package.
class CharacterBoundary extends TextBoundary {
  /// Creates a [CharacterBoundary] with the text.
  const CharacterBoundary(this._text);

  final String _text;

  @override
  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0) {
      return null;
    }
    final int graphemeStart = CharacterRange.at(_text, min(position, _text.length)).stringBeforeLength;
    assert(CharacterRange.at(_text, graphemeStart).isEmpty);
    return graphemeStart;
  }

  @override
  int? getTrailingTextBoundaryAt(int position) {
    if (position >= _text.length) {
      return null;
    }
    final CharacterRange rangeAtPosition = CharacterRange.at(_text, max(0, position + 1));
    final int nextBoundary = rangeAtPosition.stringBeforeLength + rangeAtPosition.current.length;
    assert(nextBoundary == _text.length || CharacterRange.at(_text, nextBoundary).isEmpty);
    return nextBoundary;
  }

  @override
  TextRange getTextBoundaryAt(int position) {
    if (position < 0) {
      return TextRange(start: -1, end: getTrailingTextBoundaryAt(position) ?? -1);
    } else if (position >= _text.length) {
      return TextRange(start: getLeadingTextBoundaryAt(position) ?? -1, end: -1);
    }
    final CharacterRange rangeAtPosition = CharacterRange.at(_text, position);
    return rangeAtPosition.isNotEmpty
      ? TextRange(start: rangeAtPosition.stringBeforeLength, end: rangeAtPosition.stringBeforeLength + rangeAtPosition.current.length)
      // rangeAtPosition is empty means `position` is a grapheme boundary.
      : TextRange(start: rangeAtPosition.stringBeforeLength, end: getTrailingTextBoundaryAt(position) ?? -1);
  }
}

/// A text boundary that uses the entire document as logical boundary.
class DocumentBoundary extends TextBoundary {
  /// Creates a [DocumentBoundary] with the text
  const DocumentBoundary(this._text);

  final String _text;

  @override
  int? getLeadingTextBoundaryAt(int position) => position < 0 ? null : 0;
  @override
  int? getTrailingTextBoundaryAt(int position) => position >= _text.length ? null : _text.length;
}
