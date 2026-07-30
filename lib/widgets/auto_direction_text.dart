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
