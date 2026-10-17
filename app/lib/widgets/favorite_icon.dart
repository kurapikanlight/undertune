import 'package:flutter/material.dart';

/// Keep the established heart and color; only soften the state change.
class FavoriteIcon extends StatelessWidget {
  const FavoriteIcon({super.key, required this.liked, this.size = 21});
  final bool liked;
  final double size;
  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      liked ? Icons.favorite : Icons.favorite_border,
      key: ValueKey(liked),
      size: size,
      color: liked ? const Color(0xfff2a4a1) : null,
    );
    if (MediaQuery.disableAnimationsOf(context)) return icon;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: icon,
    );
  }
}
