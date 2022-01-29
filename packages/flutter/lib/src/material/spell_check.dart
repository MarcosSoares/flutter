import 'package:flutter/src/painting/text_span.dart';
import 'package:flutter/src/painting/text_style.dart';
import 'package:flutter/src/widgets/spell_check.dart';
import 'package:flutter/widgets.dart';

/// Provides logic for displaying spell check suggestions for Android.
class MaterialSpellCheckerControls extends SpellCheckerControls{
    /// Responsible for causing the SpellCheckerSuggestionsToolbar to appear.
    /// This toolbar will allow for tap and replace of suggestions for misspelled 
    /// words.
    /// See calls in
    /// (1) _TextFieldSelectionGestureDetectorBuilder [material/text_field.dart]
    /// (2) EditableTextState [editable_text.dart]
    /// (3) MaterialTextSelectionControls [material/text_selection.dart]
    Widget showSpellCheckerSuggestions(
        List<SpellCheckerSuggestionSpan> spellCheckerSuggestionSpans) {
            //TODO(camillesimon): Show suggestions toolbar here.
        }
}
/// Provides logic for indicating misspelled words for Android.
class MaterialMisspelledWordsHandler extends MisspelledWordsHandler {
    //TODO(camillesimon): add comments
    int scssSpans_consumed_index = 0;

    /// Responsible for rebuilding the TextSpan with the TextStyle changed for all 
    /// of the misspelled words.
    /// See call in EditableTextState [editable_text.dart]
    TextSpan buildWithMisspelledWordsIndicated(List<SpellCheckerSuggestionSpan> spellCheckerSuggestionSpans, 
        TextEditingValue value, TextStyle style) {
        return TextSpan(
            style: style,
            children: <TextSpan>[
                TextSpan(children: buildSubtreesWithMisspelledWordsIndicated(spellCheckerSuggestionSpans, value.composing.textBefore(value.text), style)),
                TextSpan(children: buildSubtreesWithMisspelledWordsIndicated(spellCheckerSuggestionSpans, value.composing.textInside(value.text), style?.merge(const TextStyle(decoration: TextDecoration.underline))
                    ?? const TextStyle(decoration: TextDecoration.underline))),
                TextSpan(children: buildSubtreesWithMisspelledWordsIndicated(spellCheckerSuggestionSpans, value.composing.textAfter(value.text), style)),
            ],
        );
    }

    List<TextSpan> buildSubtreesWithMisspelledWordsIndicated(List<SpellCheckerSuggestionSpan> spellCheckerSuggestionSpans, String text, TextStyle, style) {
        List<TextSpan> tsTreeChildren = <TextSpan>[];
        int text_pointer = 0;
        int scss_pointer = scssSpans_consumed_index;
        SpellCheckerSuggestionSpan currScssSpan = spellCheckerSuggestionSpans[scss_pointer];
        int span_pointer = currScssSpan.start;

        while (text_pointer < text.length && scss_pointer < spellCheckerSuggestionSpans.length && currScssSpan.start < text.length) {
            int end_index;
             if (currScssSpan.start > text_pointer) {
                 end_index = currScssSpan.start < text.length ? currScssSpan.start : text.length;
                tsTreeChildren.add(TextSpan(style: composing ? styl,
                                            text: text[text_pointer : currScssSpan.start]));
                text_pointer = currScssSpan.start + 1;
             }
             else {
                end_index = currScssSpan.end < text.length ? currScssSpan.end : text.length;
                tsTreeChildren.add(TextSpan(style: overrideTextSpanStyle(style)
                                            text: text[currScssSpan.start : end_index]));
                text_pointer = currScssSpan.end + 1;
                currScssSpan = spellCheckerSuggestionSpans[++scss_pointer];
             }
        }

        scssSpans_consumed_index = scss_pointer;
        return tsTreeChildren;
    }

    /// Responsible for defining the behavior of overriding/merging
    /// the TestStyle specified for a particular TextSpan with the style used to
    /// indicate misspelled words (straight red underline for Android).
    /// Will be used in buildWithMisspelledWordsIndicated(...) method above.
    TextStyle overrideTextSpanStyle(TextStyle currentTextStyle) {
        return style?.merge(const TextStyle(decoration: TextDecoration.underline))
            ?? const TextStyle(decoration: TextDecoration.underline,
                                decorationColor: Colors.red,
                                decorationStyle: TextDecorationStyle.wavy,);
    }
}
