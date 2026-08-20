import 'package:flutter/material.dart';

/// Caps how wide content is allowed to get.
///
/// The app is designed for a phone and also runs in a desktop browser, where
/// an unconstrained [ListView] stretches a card to nineteen hundred pixels and
/// the eye has to travel the whole width to read one alert. 720 is about the
/// widest a single column of text stays comfortable, and it matches the point
/// where the phone layout stops looking like a stretched phone layout.
///
/// Centred rather than left-aligned so it reads the same in Arabic and
/// English — a column pinned to one edge looks deliberate in one direction and
/// broken in the other.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  static const double defaultMaxWidth = 720;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
