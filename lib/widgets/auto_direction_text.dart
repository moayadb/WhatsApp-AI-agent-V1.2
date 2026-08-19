import 'package:flutter/material.dart';

/// Detects a string's intrinsic direction from its first strongly-directional
/// character. Message and AI text can be Arabic, English, or mixed — forcing
/// the ambient RTL onto an English string pushes trailing punctuation to the
/// start of the line (`.employees or service available`).
TextDirection detectDirection(String text, {TextDirection fallback = TextDirection.rtl}) {
  for (final rune in text.runes) {
    // Strong RTL: Arabic + supplements + presentation forms, Hebrew.
    if ((rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    // Strong LTR: Latin, Greek, Cyrillic.
    if ((rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F) ||
        (rune >= 0x0370 && rune <= 0x04FF)) {
      return TextDirection.ltr;
    }
    // Digits, punctuation, whitespace are direction-neutral — keep scanning.
  }
  return fallback;
}

/// Wrap a value so the surrounding sentence cannot re-order it.
///
/// For a whole paragraph, [AutoDirectionText] picks a direction. This is for
/// the other case: a Latin fragment sitting inside an Arabic line — an agent
/// called "Alex", a number like +971501234567, a pairing code. Without an
/// isolate the bidi algorithm lets the fragment and the punctuation around it
/// trade places, so a line ends up reading `+971501234567 :الموظف`.
///
/// FSI (first-strong isolate) picks the fragment's own direction; PDI closes
/// it. Both are zero-width, so nothing changes visually when the text was
/// already homogeneous.
/// Written as escapes on purpose: the characters themselves are invisible and
/// reorder the source line in an editor, which is exactly the confusion they
/// exist to prevent elsewhere.
String bidiIsolate(String text) => '\u2068$text\u2069';

/// A [Text] whose direction (and alignment) follows the string's own script
/// instead of the ambient layout direction. The surrounding chrome stays RTL;
/// only content strings use this.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final direction = detectDirection(text, fallback: Directionality.of(context));
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: direction,
        // `start` follows the detected direction: English anchors left,
        // Arabic anchors right — like WhatsApp renders mixed threads.
        textAlign: TextAlign.start,
      ),
    );
  }
}
